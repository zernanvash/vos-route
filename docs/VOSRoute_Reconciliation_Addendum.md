# VOSRoute — Reconciliation Addendum: Prior Specs vs. Offline-First Plans

**Purpose**: This note resolves overlap between three prior specs (UI Overhaul, Offline-First Photos/Signature/GPS, Data Integrity & Timezone) and the two plans already agreed for the outbox/network rebuild:
- `VOSRoute_Offline_First_Final_Implementation_Plan.md`
- `VOSRoute_ApiService_Network_Layer_Implementation_Plan.md`

Hand this addendum to the agent **alongside** those two plans and the three prior specs, so nothing gets built twice or in conflict.

---

## 1. UI Overhaul (theme/M3/donut chart) — Independent, no changes

No overlap with the data/sync layers. Build as originally specced, in parallel with or before the outbox work — order doesn't matter between them.

**One integration point to flag for the agent**: the Sync Log screen (offline-first plan, Phase 5) and the Home Screen performance donut chart (this spec) should both be built using whatever `AppCard`/`AppListTile`/`StatusChip` widgets this overhaul produces, rather than the Sync Log screen inventing its own styling. Sequence the Sync Log screen's UI work *after* the theme overhaul lands, even though its logic (Phase 5 of the offline-first plan) is independent.

---

## 2. Offline-First Photos, Signature Removal & GPS Fixes spec — **Superseded in part**

### 2a. Photo upload mechanism — SUPERSEDED, do not build as originally specced

The prior spec describes: a queue-level mechanism in `ActionQueueService` that intercepts `local_file_path` entries, uploads to `/files` in the background, substitutes the returned UUID into the payload, and checks record existence before creating relations.

This is now fully subsumed by:
- `outbox_table.dart`'s `depends_on` chain (file-upload row → POD-link row), offline-first plan Phase 1/2
- `PodRepository.enqueuePodUpload()`, Phase 3 Pass 1
- The worker's UUID-substitution step, Phase 4 step 4 ("File uploads: read `local_files.local_path` → POST `/files` → store `remote_uuid` → substitute into dependent row's built request")
- `idempotency.dart`'s `checkPodFileLinked(clientRef)` — the "check existence before creating relations" requirement, generalized across all entity types instead of being POD-specific
- `upload_pod_builder.dart` (network layer plan, Phase F) for the actual request shape

**Instruction to the agent**: do not implement or modify `ActionQueueService` for photo handling. `ActionQueueService` is deprecated and removed once the outbox worker lands (offline-first plan, Phase 2 note). Any photo-upload logic should be written directly against the outbox/repository/worker pattern described in the two linked plans, not against the legacy queue.

### 2b. Customer Signature Removal — Independent, build as originally specced

Pure UI/validation removal (`QuestScreen`, `StopDetailScreen`, `HomeScreen` legend — drawing fields, confirmation states, base64 upload). No interaction with the outbox or sync layers beyond the fact that, once removed, no `signature` entry type ever needs an outbox `action` — nothing to build there, just an absence. Proceed as specced.

### 2c. Aggregated Performance Slices (status counters for the donut chart) — Adjust the read path only

The original spec drafts a status-counter query "fetching invoice/stop status data across all active, pending, and past plans." Per the offline-first plan's core principle (§1: "SQLite is the single source of truth for the UI"), this query should read from **`cached_stops`/`cached_trips`**, not fetch fresh from Directus on every dashboard render. Concretely:
- Add a `TripRepository.watchPerformanceCounters()` (or equivalent on whichever repository owns aggregate stats) backed by a `drift` `watch()` query over `cached_stops`, so the donut chart updates reactively as reconciliation and outbox syncs land, and still renders correctly offline.
- The original spec's "fetch across all active, pending, and past plans" becomes the *reconciliation* fetch's job (populating `cached_stops` in the first place), not something the dashboard queries directly at render time.

### 2d. GPS Permission & Isolate Fix — Independent, build as originally specced, with one naming note

`AndroidManifest.xml` permission tags and the `BackgroundService._service.invoke` isolate message passing for trip IDs are unaffected by the outbox rebuild. Build as specced.

**Naming note for the agent**: once built, the GPS tick write path should call `GpsRepository.enqueueGpsTick()` (offline-first plan, Phase 3 Pass 1) rather than writing into any legacy GPS queue — confirm the isolate's tick handler is updated to call this method once that repository exists, rather than being left pointed at old queue code.

### 2e. Directus Date Format Mapping (UTC ISO 8601, camelCase/snake_case patching) — Relocate, don't drop

This fix (standardizing `invoiceAt` and related timestamp payloads) should not be a standalone patch scattered across call sites. It belongs inside the **per-action request-builders** (network layer plan, Phase F — e.g. `trip_transition_builder.dart`, `update_stop_status_builder.dart`), since those are the functions that turn `args_json` into the literal HTTP payload at dispatch time. Building the UTC/`Z`-suffix formatting once, inside the builders, means every action that touches a date gets it correctly for free, instead of needing the same fix applied at N call sites.

**Instruction to the agent**: when writing each request-builder, use a single shared date-formatting helper (e.g. `lib/sync/utc_date_formatter.dart`) that outputs ISO 8601 with explicit `Z` suffix, and patches both camelCase and snake_case field name variants as needed per endpoint. Do not patch dates ad hoc inside `ApiService` or inside repositories.

---

## 3. Data Integrity & Timezone Fixes spec — Mostly independent; two integration points

### 3a. Double-assignment prevention (invoices assigned to multiple active plans) — Independent, backend/SCM-web fix

This is a pre-dispatch plan creation bug in SCM web, not a mobile/outbox concern. Build as specced, independently. No interaction with the plans above.

### 3b. Timezone shift fix (missing `Z` suffix causing +8h drift) — Merge with 2e above, don't duplicate

This is the same root fix as §2e's date-format mapping. **Do not implement this twice** — one shared `utc_date_formatter.dart` (or equivalent), used both by the mobile app's request-builders and by whatever BFF/SCM-web code the timezone-fix spec touches server-side. If the two specs were written by different people/sessions, explicitly de-duplicate before the agent starts, or you'll get two slightly different UTC-formatting implementations that drift apart over time.

### 3c. Buffer-unpacking fix for MySQL bit fields (e.g. `isDispatched` returned as Buffer in Node.js) — Independent, backend/BFF fix

No mobile-app interaction. Build as specced.

### 3d. BFF exclusion filters & cancellation reset states — **Must be checked against the reconciler's `Cancelled` rule**

The offline-first plan's reconciler (Phase 4, conflict rule for trip-level `Cancelled`) halts local mutation and marks pending outbox entries `failed_permanent` when a trip is server-cancelled. If this spec's "cancellation reset states" changes what a cancelled trip's fields look like server-side (e.g. resetting assignment fields, clearing invoice links), the reconciler's fetch-and-compare logic needs to recognize the **new** cancelled-state shape, not the old one.

**Instruction to the agent**: before implementing the BFF exclusion filters/reset states, share the exact resulting shape of a cancelled `post_dispatch_plan` record with whoever builds `reconciler.dart`, so the halt-and-mark-permanent logic matches on the correct field(s) post-fix. Build this spec's server-side change first, then verify the reconciler's `Cancelled` handling against the new shape as part of that phase's QA — don't let the two be built and tested in isolation from each other.

### 3e. Target Directus folder UUIDs (POD, Trip photo folders)

Purely configuration — these UUIDs (`d3940009-...`, `13954431-...`) should be passed into the `upload_pod_builder.dart` / trip-photo equivalent builder (network layer plan, Phase F) as the target folder for the `/files` upload call. No architectural decision needed, just wiring.

---

## Summary Table — What Supersedes What

| Prior spec item | Status | Where it now lives |
|---|---|---|
| UI Overhaul (all) | Keep as-is | Independent; Sync Log/donut chart UI sequenced after it |
| Photo upload via `ActionQueueService` | **Superseded** | Outbox `depends_on` chain + `PodRepository` + worker (offline-first plan) |
| Signature removal | Keep as-is | Independent UI work |
| Aggregated performance slices | **Adjusted** | Reads from `cached_stops` via `watch()`, not live Directus fetch |
| GPS permission/isolate fix | Keep as-is | Wire final tick call to `GpsRepository.enqueueGpsTick()` |
| Date format mapping (`invoiceAt` etc.) | **Relocated** | Shared `utc_date_formatter.dart`, used inside request-builders |
| Double-assignment fix | Keep as-is | Independent SCM-web fix |
| Timezone shift fix | **Merged with above** | Same shared formatter — do not duplicate |
| Buffer-unpacking fix | Keep as-is | Independent BFF fix |
| BFF exclusion filters / cancellation reset | **Needs coordination** | Verify against `reconciler.dart`'s `Cancelled` rule before/during QA |
| Directus folder UUIDs | Keep as config | Passed into upload request-builders |

**Recommended handoff order to the agent**: 3a/3b/3c/3e (backend/data fixes, mostly independent) → offline-first plan Phases 0–2 → network layer plan Phases A–C/F (so `utc_date_formatter.dart` and request-builders exist) → offline-first plan Phases 3–4 (repositories, worker — this is where 2a/2c/2d actually get wired in) → 3d verification against the reconciler → offline-first plan Phase 5 + UI Overhaul (Sync Log screen, donut chart) → network layer plan Phase D/E polish.
