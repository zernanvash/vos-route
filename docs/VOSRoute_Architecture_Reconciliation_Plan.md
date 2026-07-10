# VOSRoute — Architecture Reconciliation & Migration Plan

**Purpose**: The prior implementation plans (`VOSRoute_Offline_First_Final_Implementation_Plan.md`, `VOSRoute_ApiService_Network_Layer_Implementation_Plan.md`) were written against an intended target architecture. The `VOSRoute-Technical-Reference.md` snapshot (July 10, 2026) shows the actual codebase never executed that migration — every subsequent bug fix in this thread was patched directly into the legacy `ActionQueueService`/`TripProvider`/raw `sqflite`. This document reconciles the two: it corrects the baseline assumptions, closes the specific contradictions found, and lays out how to actually execute the migration from where the code stands today, instead of from where the original plans assumed it would be.

---

## 1. Corrected Baseline — What's Actually in Production

| Area | Original plans assumed | Actual state (per Technical Reference) |
|---|---|---|
| Local DB | `drift` + SQLCipher, single `outbox` table | Raw `sqflite` v3, `action_queue` table only. `drift` exists but is used **only** for `CachedSettings` (timezone). No encryption. |
| Outbox schema | `action`, `priority`, `args_json`, `schema_version`, `depends_on` | `action_type`, `batch_priority` (1/2/3), `action_payload` (raw JSON), `batch_group`. No `depends_on` column — dependency ordering (file upload → link) is handled procedurally inside `_execute()`, not declaratively. |
| Repository layer | `TripRepository`/`StopRepository`/etc., screens never touch `ApiService` | Does not exist. `TripProvider` (~1377 lines, grew since the refactor was proposed) still calls `ApiService`/`getDirectus()` directly for every fetch. |
| Push notifications | Direct Directus write, Directus-native auth, no Spring Boot | Still Spring Boot: `POST /api/dispatch/mobile/register-device` with JWT. The `VOSRoute_DP_Approval_Push_Implementation.md` §3 rewrite has not shipped. |
| Network layer | Typed `AppException` hierarchy, single-flight auth refresh, split Dio timeouts | `lib/network/app_exception.dart` exists (§6.5 confirms `AppException` sealed hierarchy is real) — **partially done**. Two Dio instances exist and are correctly separated by auth type (§6.1) — matches the network plan's spirit, though not verified against the specific timeout/cancellation split proposed. |
| Timezone fix | `cached_settings` via drift, business-tz-aware formatter | **Fully shipped** — `TimezoneService`, `CachedSettingsDao`, `UtcDateFormatter` all confirmed present and wired into bootstrap correctly (§4, §16.3). |
| `invoiceAt` bug | Fixed at the `TripProvider.updateStopStatus()` root cause | **Fixed** — §8.4 confirms `updateStopStatus` payload includes `invoiceAt`, and §19.3 confirms a null-payload guard exists. |
| GPS `trip_id` | N/A (bug found mid-thread) | **Not fixed** — §12.2's payload spec still includes `trip_id` with no confirmation the isolate-handoff race is resolved. |

**Conclusion**: the app is in a stable hybrid state — several precise bug fixes have landed correctly on the legacy architecture, but the structural migration (outbox, repositories, encrypted DB, Spring-Boot-free push) has not started. This is a reasonable place to be; it means the migration can now be planned against real code instead of assumptions.

---

## 2. M0 — Immediate Fixes (do these regardless of migration timing)

These are bugs, not architecture decisions — fix them on the current legacy code now, independent of whether/when the full migration proceeds.

**M0 scope** (per July 10, 2026 decision): only §2.1 and §2.3 below. Push notification work (§2.2 removed) is out of scope — notifications stay on Spring Boot, to be planned separately with the backend dev. `VOSRoute_DP_Approval_Push_Implementation.md` and all earlier "no Spring Boot, just Directus" push discussion are superseded.

### 2.1 GPS `trip_id` null bug
- **Symptom**: GPS log rows written with `trip_id = null` (confirmed via production sample data earlier this thread).
- **Root cause (unconfirmed, needs the isolate code)**: likely a race between `BackgroundService`'s foreground-service GPS listener starting and `confirmDeparture()`/`GpsProvider.startTracking()` sending the trip ID to the isolate via `_service.invoke(...)`.
- **Action**: obtain and review `lib/services/background_service.dart` and `lib/services/gps_service.dart` for exactly when `trip_id` is set on the isolate side vs. when the isolate starts listening. Guard the isolate's tick handler so it **discards** (does not enqueue) any tick captured before a valid `trip_id` has been received, rather than enqueueing with `null`.
- **Verify**: dual-capture path noted in §12.3 — confirm both `GpsService` (foreground, in-memory buffer → `action_queue`) and `BackgroundService` (independent GPS → Directus directly) apply this guard; the reference notes these are two separate code paths, so a fix in one does not fix the other.

### 2.2 Removed — Push notification Spring Boot removal

Push notifications stay on Spring Boot. `NotificationService`, `driver_push_tokens` schema, and the `/api/dispatch/mobile/register-device` endpoint are not to be touched. Any push-related improvements will be planned separately with the backend dev. `VOSRoute_DP_Approval_Push_Implementation.md` and the earlier "no Spring Boot, just Directus" direction are superseded.

### 2.3 Performance chart cache population
- **Status**: Already fixed (confirmed July 10, 2026 code review).
- **Implementation**: `_cacheInvoiceStatusesForPlans()` at `trip_provider.dart:903` proactively fetches lightweight `{id, status}` for all previous plans' invoices during `fetchPreviousDispatchPlans()`, populating `_tripCache[planId]['invoice_stops']` before any `selectPlan()` has been called. `aggregatedInvoiceStatusCounts` iterates `allPlans` (which includes `_previousDispatchPlans`) and reads from the cache — no lazy-population gap exists.
- **No action needed** — this fix was already applied in a prior session.

---

## 3. Migration Decision — Proceed, Scoped Down

Given the accumulated point-fixes are all working and tested, a full stop-the-world rewrite is unnecessary risk. Recommend proceeding with the migration **incrementally, starting from actual current state**, not the original all-at-once phase plan. Revised sequencing:

### 3.1 Why proceed at all (not just keep patching legacy code)
The current `action_queue` design already organically converged on part of the target shape — `batch_priority` (1/2/3) is functionally the `priority` column from the outbox design, just coarser (3 tiers instead of a numeric field) and named differently. This means the gap to close is smaller than the original plan assumed. But two specific legacy-architecture limits will keep causing bugs like the ones already found:
- **No `depends_on` column** — the file-upload-then-link dependency is handled by procedural code inside `_execute()` (checking `payload['file']` presence, `alreadyLinked` checks) rather than being structurally guaranteed by the schema. This is exactly the kind of implicit ordering that's easy to break when adding a new photo-linked action type.
- **No repository layer** — `TripProvider` at 1377 lines and growing is the direct cause of every "which call site produced this bug" investigation this thread has had to do (the quest-completion flow, the null-status bug, the `invoiceAt` bug). This will keep costing debugging time linearly with the provider's size until it's split.

### 3.2 Revised phase order (supersedes the original Phase 0–5 plan's sequencing, keeps its content)

| Phase | Content | Why this order now |
|---|---|---|
| **M0** | Items in §2 above (GPS null fix, chart cache fix) — push removal dropped per July 10 decision | Bugs, ship independent of migration timing |
| **M1** | `drift` migration: `outbox` table (with `action`, `priority`, `depends_on`, `args_json`, `schema_version` per the original Phase 1 design) + SQLCipher, migrating `action_queue`'s pending rows across (per the original Migration Test) | Original Phase 0/1, unchanged — still the right foundation |
| **M2** | Network layer plan Phases A–C, F (Dio split, typed exceptions — **partially done**, verify `AppException` hierarchy in place matches the full spec, add single-flight auth refresh, request-builders) | Original plan already sequenced this before the outbox worker; still correct, and now cheaper since exceptions already partly exist |
| **M3** | Repository layer, Pass 1 only (`TripRepository` as pass-through, screens untouched) — **stop here, do not immediately do Pass 2/3** | De-risk: get `ApiService` out of the provider without yet attempting the full provider split. This alone starts shrinking `TripProvider`'s surface area for future bug investigations. |
| **M4** | Outbox worker (Phase 4 of original plan) — now sitting on a real `outbox` table and typed exceptions | Original content, now actually buildable |
| **M5** | Repository Pass 2/3 (provider split, reactive streams) — do this **after** the worker is proven stable in production, not before | Original plan had this earlier; moving it later means the riskiest UI-facing refactor (splitting a 1377-line provider that drivers depend on daily) happens once the underlying data layer is already solid, not concurrently with it |
| **M6** | Sync Log UI polish, per-item sync status indicator (from the earlier article-comparison discussion) | Cosmetic/UX layer, correctly last |

### 3.3 What this buys over the original plan
The original plan's "single release train, Phases 0–5 all at once" was written assuming a clean slate. Given the codebase has already diverged (working point-fixes on legacy code), an all-at-once cutover risks re-breaking things that are currently fixed and stable (the timezone formatter, the `invoiceAt` fix, the null-status guard) by moving them into new code paths simultaneously. Phasing M1–M2 (foundation) separately from M3 (repository extraction) separately from M5 (provider split) means each of those already-fixed behaviors gets re-verified once, in a smaller diff, instead of all at once in a single large migration.

---

## 4. Open Question (no longer blocks M0)

The driver-login auth question ("does `AuthService.login()` call Spring Boot's `/auth/login` or Directus's own `/auth/login`?") was originally raised in the now-removed §2.2 as a prerequisite for a push fix that isn't happening. It is **not** gating M0 execution.

However, it still matters for **M2** (single-flight auth refresh): the network layer plan's auth-refresh interceptor needs to know whether it's refreshing a Spring Boot JWT, a Directus-native token, or both. This should be confirmed before M2 begins, not now — M0 (GPS null fix + chart cache) works regardless of the answer.
