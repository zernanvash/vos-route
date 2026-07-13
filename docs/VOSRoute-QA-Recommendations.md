# VOSRoute QA Findings And Recommendations

Status: manual code QA  
Scan date: July 11, 2026  
Verification: `flutter analyze` and `dart analyze lib test` both timed out after roughly 120 seconds in this environment.

## Executive Summary

The app has a clear driver workflow and a pragmatic offline queue design, but there are several high-risk contract mismatches that should be fixed before field use. The biggest risks are in queued writes: old queue migration may not seed, invoice status timestamps are built incorrectly, and photo linking/de-duplication appears to use fields that may not match the documented Directus schema.

Recommended order:

1. Fix confirmed queued-write contract bugs.
2. Add request-builder unit tests.
3. Run analyzer and integration smoke tests on a machine where Flutter tooling completes.
4. Harden offline restart behavior and GPS lifecycle.
5. Move secrets and backend URLs out of the client build.

## High-Priority Findings

### 1. Drift migration seeds into the wrong table

Severity: High  
Area: Offline queue migration  
Evidence:

- Drift generated table name is `outbox_actions`: `lib/db/app_database.g.dart:454`
- DAO queries `outbox_actions`: `lib/db/daos/outbox_dao.dart:13`
- Migration inserts into `outbox`: `lib/db/app_database.dart:62`

Impact:

Old pending `action_queue` rows from `vosroute.db` will not migrate into the active Drift outbox. The error is swallowed as non-fatal, so users can silently lose queued GPS, POD, SOS, or status updates during the migration path.

Recommendation:

- Change the insert target to `outbox_actions`.
- Add a migration test with a prebuilt sqflite `vosroute.db` containing at least one pending row.
- Log a visible sync warning if migration fails instead of only `debugPrint`.

### 2. Invoice status update sends `invoiceAt` as driver id

Severity: High  
Area: Stop status update contract  
Evidence:

- `TripProvider` queues `invoiceAt` with a timestamp: `lib/providers/trip_provider.dart:1286`
- `TripProvider` also queues `driver_user_id`: `lib/providers/trip_provider.dart:1288`
- Builder writes `invoiceAt: driverUserId`: `lib/sync/request_builders/update_stop_status_builder.dart:13`

Impact:

Directus receives a user id in a date/time field. Depending on Directus validation, this either fails sync permanently or corrupts invoice completion timestamps.

Recommendation:

- Update `UpdateStopStatusBuilder.build` to accept and send the queued `invoiceAt` timestamp.
- Keep `invoiced_by` as the driver id if that field exists.
- Add unit tests for every request builder.

### 3. Trip/invoice photo linking uses inconsistent field names

Severity: High  
Area: Photo upload/link sync  
Evidence:

- UI queues `trip_id`: `lib/screens/quest_screen.dart:449`, `lib/screens/invoice_detail_screen.dart:219`
- Link builder posts `trip_id` plus `file`: `lib/services/action_queue_service.dart:379`
- De-dupe queries `filter[trip_id]` and `filter[directus_uuid]`: `lib/services/action_queue_service.dart:237`
- The queued payload is updated with `directus_uuid`: `lib/services/action_queue_service.dart:211`

Impact:

The documented Directus collection uses `post_dispatch_plan_id` and `file`. Current code may fail if the collection does not have `trip_id`. Even if `trip_id` exists, duplicate checks query `directus_uuid` while the posted field is `file`, so duplicate detection can miss existing links.

Recommendation:

- Confirm the real `post_dispatch_trip_photos` schema.
- Standardize payload and filters to the actual schema fields.
- If the schema is `post_dispatch_plan_id` + `file`, update UI payloads, builder body, and de-dupe filters.
- Add an integration test or mocked Directus test for duplicate photo link handling.

### 4. Notification `/stop-detail` deep link can pass the wrong argument type

Severity: High  
Area: Notification routing  
Evidence:

- Route requires a full stop object: `lib/main.dart:98`
- Notification handler extracts an id/string: `lib/services/notification_service.dart:160`
- It pushes `/stop-detail` with that id: `lib/services/notification_service.dart:163`

Impact:

A notification payload that targets `/stop-detail` with only an id will crash at runtime because `StopDetailScreen` expects an `InvoiceStop`, `OtherStop`, or `PurchaseStop`, not a primitive id.

Recommendation:

- Route notifications to a plan/invoice screen that can resolve ids.
- Or introduce a resolver route that fetches the stop object before opening `StopDetailScreen`.
- Validate notification payload shape before navigation.

### 5. GPS tracking can start duplicate timers and may drop final buffered points

Severity: Medium-High  
Area: GPS lifecycle  
Evidence:

- `GpsService.startTracking` creates timers without cancelling existing ones: `lib/services/gps_service.dart:23`, `lib/services/gps_service.dart:28`, `lib/services/gps_service.dart:33`
- `stopTracking` calls async `_flushBuffer()` without awaiting it: `lib/services/gps_service.dart:42`
- `stopTracking` is synchronous and then clears tracking state: `lib/services/gps_service.dart:44`

Impact:

Repeated start calls can duplicate GPS capture timers. Stopping tracking can lose final buffered points because the flush future is not awaited.

Recommendation:

- Make `startTracking` idempotent: if the same trip is already tracking, return; if a different trip starts, stop old timers first.
- Make `stopTracking` return `Future<void>` and await the final flush before clearing trip state.
- Add tests around timer lifecycle with fake async.

### 6. Startup triggers duplicate trip fetches

Severity: Medium  
Area: Startup performance/network load  
Evidence:

- `MainShell` calls `fetchAllCachedData()`: `lib/main.dart:234`
- `HomeScreen.initState` also calls `fetchActiveTrip()` and `fetchPendingPlans()`: `lib/screens/home_screen.dart:38`, `lib/screens/home_screen.dart:39`

Impact:

The app makes duplicate Directus requests at startup. On weak networks this can increase load time, duplicate error states, and create inconsistent local state timing.

Recommendation:

- Keep startup data loading in one owner, preferably `MainShell` or a bootstrap provider.
- Let `HomeScreen` render provider state and only fetch on manual refresh.

### 7. Static Directus token and backend URLs are embedded in the app

Severity: Medium-High  
Area: Security/configuration  
Evidence:

- Spring URL: `lib/config/app_config.dart:4`
- Directus URL: `lib/config/app_config.dart:5`
- Directus token: `lib/config/app_config.dart:6`

Impact:

Anyone with the APK can extract the Directus token. Because operational writes use this static token, token exposure can allow unauthorized writes unless Directus permissions are tightly constrained elsewhere.

Recommendation:

- Move Directus access behind a mobile backend/BFF or issue driver-scoped Directus tokens server-side.
- Use build-time environment config for URLs.
- Rotate the current static token after changing the access model.

### 8. Offline trip cache is mostly in memory

Severity: Medium  
Area: Offline-first reliability  
Evidence:

- `TripProvider` uses `_tripCache` in memory for selected/active plan payloads.
- Drift currently persists settings and outbox actions, not a durable trip cache.
- The legacy sqflite `cached_trips` table is dropped in v3 migration.

Impact:

Queued writes can survive app restart, but the full active trip view may not be available after app restart while offline. That weakens the offline-first promise for drivers in poor connectivity areas.

Recommendation:

- Add a durable cached trip snapshot table to Drift, or explicitly document that offline continuity after process death is limited.
- Cache active plan, stops, budget, crew, and last known invoice statuses.

## Medium-Priority Findings

### 9. Directus action payloads need schema confirmation

Severity: Medium  
Area: Backend contract drift  
Examples:

- GPS payload uses `trip_id`; documentation references `post_dispatch_gps_logs` but not the exact FK field.
- Ad-hoc stop builder creates status `For Dispatch`: `lib/sync/request_builders/create_adhoc_stop_builder.dart:16`
- Invoice photos are saved as trip photos with `type: invoice`, while older docs describe POD linking via `post_dispatch_nte`.

Recommendation:

- Create a single backend contract file in docs with the exact Directus field names currently deployed.
- Add request-builder tests against that contract.
- Avoid schema changes unless explicitly approved.

### 10. Error handling is mostly silent

Severity: Medium  
Area: UX/reliability  
Impact:

Many service-level errors are swallowed or only debug-printed. Drivers may think a critical action completed even if it only queued or failed later.

Recommendation:

- Keep offline queue behavior, but surface critical pending/failed states near departure, invoice confirmation, arrival, and SOS.
- For SOS, show "queued" versus "sent" accurately.

### 11. SOS submission lacks confirmation dialog

Severity: Medium  
Area: Safety/UX  
Impact:

The project convention says SOS should require confirmation. Current screen sends after tapping `SEND SOS` if description is non-empty.

Recommendation:

- Add a final confirmation dialog before enqueueing the SOS action.
- Make the success message say "Emergency report queued" when offline or when sync has not completed.

### 12. Purchase stop map support is incomplete

Severity: Medium  
Area: Navigation UX  
Evidence:

- `StopDetailScreen` extracts coordinates from invoice and other stops only.
- Purchase stops can open the same screen but have no latitude/longitude path.

Recommendation:

- Extend `PurchaseStop` parsing to include supplier/vendor coordinates if available.
- If coordinates are unavailable, hide navigation affordances or explain that no location is available.

### 13. Sensitive auth refresh material is stored on device

Severity: Medium  
Area: Security  
Impact:

The app stores the login `hashPassword` value for token refresh. If the field is actually a password or reusable password hash, device compromise exposes long-lived credential material.

Recommendation:

- Prefer a refresh token issued by Spring Boot.
- If refresh tokens are unavailable, limit token lifetime and require re-login instead of storing reusable credentials.

### 14. Generated files and dirty worktree need discipline

Severity: Medium  
Area: Maintainability  
Observation:

The worktree contains many modified and untracked implementation files. Drift-generated files are modified alongside table/DAO changes.

Recommendation:

- Before release, separate feature changes into reviewable commits.
- Regenerate Drift files in a clean step.
- Add a CI job for `flutter analyze`, `dart format --set-exit-if-changed`, and unit tests.

## Recommended Test Plan

### Unit Tests

Add tests for:

- `TripTransitionBuilder`
- `UpdateStopStatusBuilder`
- `GpsBatchBuilder`
- `UploadPodBuilder`
- `SendSosBuilder`
- `CreateAdhocStopBuilder`
- `ActionType.fromApiValue`
- `ActionPriority.fromValue`

Minimum assertions:

- Correct path.
- Correct HTTP method.
- Correct payload field names.
- Correct timestamp format.
- No accidental user id/date field swaps.

### Queue Tests

Add tests for:

- Pending actions process by priority.
- GPS batches process before non-GPS.
- Permanent 4xx failures mark failed.
- 401 remains retryable/auth-handled.
- Local file upload mutates payload and then links photo.
- Duplicate photo detection checks the same field names as the create payload.
- Legacy `action_queue` rows migrate to `outbox_actions`.

### Provider Tests

Add tests for:

- `confirmDeparture` optimistic status and queued actions.
- `markArrivedAtBase` blocked until invoice statuses are terminal.
- `markArrivedAtBase` blocked until invoices are confirmed.
- Photo quest completion gate.
- `updateStopStatus` updates local state and cache.

### Manual Smoke Tests

Run on Android device:

1. Fresh login.
2. Active trip fetch.
3. Confirm departure with GPS enabled.
4. Confirm departure with GPS disabled.
5. Capture invoice photos.
6. Update each allowed invoice status.
7. Go offline, update status, reconnect, verify sync.
8. Go offline, capture photo, reconnect, verify file upload and link.
9. Confirm invoices, then mark arrived.
10. Submit SOS online and offline.
11. Tap push notification payloads for each supported route.
12. Restart app while offline after departure and verify visible trip state.

## Release Readiness Checklist

- `flutter analyze` completes with no errors.
- `dart format --set-exit-if-changed lib test` passes.
- Request-builder tests pass.
- Queue migration test passes.
- Directus field names are verified against the live schema.
- APK no longer contains a broad static Directus write token, or the risk is formally accepted.
- Offline restart behavior is verified on a real device.
- GPS lifecycle is idempotent and final buffer flush is awaited.
- Notification deep links resolve valid screen arguments.

## Suggested Implementation Roadmap

### Phase 1: Correctness Fixes

- Fix `outbox` versus `outbox_actions` migration.
- Fix `invoiceAt` timestamp builder.
- Fix photo field naming and duplicate checks.
- Fix notification stop-detail routing.

### Phase 2: Test Harness

- Add unit tests for request builders.
- Add queue DAO/service tests.
- Add provider tests for trip gates.

### Phase 3: Offline Hardening

- Persist active trip snapshot in Drift.
- Make GPS start/stop idempotent.
- Improve user-facing sync status around critical actions.

### Phase 4: Security And Config

- Remove static operational token from app builds.
- Move environment-specific URLs to build config.
- Replace stored credential refresh with server-issued refresh tokens.

### Phase 5: UX Polish

- Add SOS confirmation.
- Clarify "queued" versus "sent".
- Complete purchase stop coordinates/navigation.
- Reduce duplicate startup loading.
