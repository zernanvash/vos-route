# VOSRoute — Fix & Feature Prompt (Batch)

Six items below: two bug fixes, one permission bug, one UI/UX fix, one business-logic fix, one data-source fix, and one architecture design task (not implementation yet). Treat the first five as direct fixes; treat the last as a plan to review before building.

---

## 1. Stop Status Update — `status` field `CONTAINS_NULL_VALUES`

Already partially diagnosed: `TripProvider.updateStopStatus()` and `updateOtherStopStatus()` both validate `status` against an allow-list and throw before enqueueing, so a null status should not be able to reach the queue through either method.

**Action**:
- Search for any other call site that enqueues a stop-status-shaped action without going through these two validated methods — in particular, trace what actually runs when the **photo quest completion flow** finishes (`markQuestStatusComplete()` only updates in-memory state; find what turns a completed quest item into an actual enqueued PATCH).
- If found, add the same allow-list guard there before enqueueing.
- Separately, check whether the three previously-failed rows (invoices 202011, 202012, 202007) predate this validation existing at all (stale rows) — if so, no new code fix is needed for those specific rows beyond manually resolving them (see item below), but confirm no other still-active path can produce a null `status` today.

## 1b. Retries not incrementing

**Symptom**: failed actions are staying at the same retry count instead of incrementing on each attempt (contradicts the intended exponential backoff behavior).

**Action**: locate wherever `retry_count`/`attempt_count` is updated after a failed attempt (in `ActionQueueService._execute()`'s catch block, or the newer outbox worker's equivalent) and confirm the increment is actually persisted — a common cause is updating an in-memory copy of the row (e.g. `ActionEntry.fromMap(row)`) without writing the incremented value back to the database before the next read, or a query that re-reads the stale pre-increment value on the next poll cycle. Add a test that asserts: given 3 consecutive simulated failures, the stored `retry_count` reads `1`, `2`, `3` in sequence, not stuck at `0`/`1`.

---

## 2. Trip Photos — "no permission" + retries incrementing (but never succeeding)

**Symptom**: trip photo uploads fail with a permission error, and — unlike item 1b — retries *are* incrementing here (consistent with the fix in 1b being needed specifically for the stop-status path, not universally broken).

**Action**:
- Determine whether "no permission" is:
  (a) an **OS-level camera/storage permission** issue (check `AndroidManifest.xml` and runtime permission requests around wherever `image_picker`/trip photo capture is triggered — this may be the same class of gap as the GPS permission fix from the earlier spec, just for camera/storage instead of location), or
  (b) a **Directus/API-level permission** issue (the static token or the driver's role lacking write access to `post_dispatch_trip_photos` or its target file folder — check the response body for a 403 vs. the OS permission dialog never appearing).
- Fix accordingly. If (a), add the missing manifest permission + runtime request, mirroring the pattern used for the GPS permission fix. If (b), this needs a Directus role/policy correction, not an app-side code change — flag it back rather than working around it client-side.
- Confirm the retry/backoff behavior here already increments correctly (per item 1b) — if this path is fine and only the stop-status path is broken, that's a useful clue that the bug in 1b is local to one code path, not the shared retry mechanism.

---

## 3. POD Photo panel — show all captured photos, don't reset; add an action button; empty state

**Current bug**: the Proof of Delivery photo panel appears to reset/clear rather than displaying all photos the driver has taken for that stop.

**Action**:
- Find the widget rendering the POD photo panel (likely in `StopDetailScreen` or a POD-specific widget) and fix whatever causes it to lose previously captured photos — check if it's reading from a single-photo state variable instead of a list, or re-initializing state on rebuild instead of reading from the persisted/cached list of captured photos for that stop.
- The panel should display **all** photos captured for the stop, not just the most recent one.
- Add a button underneath the photo panel (e.g. "Add Photo" / "Take Another Photo") to let the driver capture additional POD photos for the same stop.
- Add an empty state: if no photos have been captured yet, show a message like **"No photos taken yet"** instead of a blank panel.

---

## 4. Photo Quest should follow up on invoice status

**Requirement**: the photo quest flow should require/reflect the invoice's actual status, not run as an independent checklist disconnected from `updateStopStatus()`.

**Action**: clarify and enforce the dependency — a photo quest item likely shouldn't be markable "complete" independent of what stop status was actually recorded for that invoice (e.g. a "Fulfilled" stop needs a POD photo; a "Not Fulfilled" stop may not). Review `PhotoQuest`/`PhotoQuestItem` and `markQuestStatusComplete()`/`markQuestPhotoCaptured()` and wire the completion condition to check against the invoice's current `status` (from `InvoiceStop.status`) rather than treating photo-capture and status-selection as two independently-tracked booleans that happen to both need to be true. This is also the most likely place item 1's "bypassed call site" bug is hiding — worth checking together with item 1.

---

## 5. Performance chart should include previous dispatch plans' invoices, not just the active trip

**Current gap**: `TripProvider.aggregatedInvoiceStatusCounts` reads from `_tripCache` entries for `allPlans` excluding the active trip — confirm this actually includes `_previousDispatchPlans` (fetched via `fetchPreviousDispatchPlans()`), not just `_pendingPlans`. If `_tripCache` is only populated for plans that have been opened via `selectPlan()`, then previous plans never viewed by the driver this session won't have a cache entry and will silently contribute zero to the chart.

**Action**: ensure the aggregation either (a) proactively populates `_tripCache` for all `previousDispatchPlans`/`pendingPlans` on fetch (not lazily on-open), or (b) per the earlier offline-first plan's direction, moves this aggregation to read from the local `cached_stops` table via a `watch()` query so it reflects everything ever reconciled, regardless of whether the driver happened to open that specific plan in the UI this session.

---

## 6. Plan (not build yet) — Realtime push between Next.js (dispatcher/SCM web) and Flutter, without WebSockets

**Goal**: when a dispatcher approves a DP (dispatch plan) in the Next.js/SCM web app, the driver's phone should get a realtime push — and the reverse direction (driver action → dispatcher notified) should work the same way. "Same idea as WebSockets" but not an actual persistent socket connection.

**Do not implement this yet — produce a short design proposal covering:**
- **Mobile-bound direction (Next.js → Flutter)**: the app already initializes Firebase (`Firebase.initializeApp()` in `main.dart`) and has a `NotificationService` for local notifications — propose using **Firebase Cloud Messaging (FCM)** for this direction: Next.js/SCM web triggers a server-side call (via Firebase Admin SDK) to send a push to the driver's registered FCM token whenever a DP's status changes to approved/dispatched. Cover: where the driver's FCM token gets registered and stored (likely a new field on the driver's user profile in Directus, updated on login/app start), and what triggers the Next.js-side send (a Directus flow/webhook on `post_dispatch_plan` status change calling a Next.js API route, or Next.js's own approval action handler calling Admin SDK directly).
- **Dispatcher-bound direction (Flutter → Next.js)**: propose **Web Push via FCM's web SDK** (same Firebase project, different token type) so the dispatcher's browser tab receives a push without polling or a socket — driver-side actions (e.g. arrival, SOS) call a Next.js API route, which then triggers Admin SDK to push to subscribed dispatcher browser sessions.
- **Fallback/offline consideration**: since the driver app is offline-first, note that an FCM push arriving while the app is offline should just trigger the normal `fetchActiveTrip()`/reconciliation flow next time the app is foregrounded or reachable — the push is a wake-up signal, not the source of truth; the reconciler's existing fetch-and-replace logic still governs actual state.
- Provide a rough sequence diagram (text is fine) for both directions, and flag any new Directus fields/webhooks or Next.js API routes this would require.

Report back with the design proposal for item 6 before writing any code for it — the rest (items 1–5) can be fixed directly.
