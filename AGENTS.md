# AGENTS.md — VOSRoute (Fleet Dispatch Mobile App)

> **Brain context**: `.brain/systems/VOSRoute/` has detailed architecture, module map, route map, data contracts, storage matrix, workflows, and known risks.
> **Root guidance**: `../AGENTS.md`

> Also see the monorepo root `AGENTS.md` for cross-project orientation. This file is self-contained for VOSRoute-specific work — read it in full before editing.
>
> **Architecture**: Directus REST API for all operational queries/mutations, via a Drift-backed offline outbox. Spring Boot `ERP_SERVER` for auth + FCM token registration only.
> **Source of truth for current code state**: the most recently scanned codebase-documentation pass in `docs/` (look for the latest "Scan date"). Older design docs (original offline-first plan, network-layer plan, architecture reconciliation plan, `VOSRoute-Documentation.md`) are historical context describing intended designs at various points — several describe behavior that was never fully shipped, or was shipped differently than planned. **Code is truth.** When a doc conflicts with the code, trust the code, and update the doc.
> **Verification discipline**: this app has repeat history of "fixed" reports that turned out inaccurate — a bug fixed in one code path while an identical bug remained in a second, unnoticed path; a fix described but not actually merged; a fix "verified" by re-reading source rather than running the app. **Before reporting any fix as complete, provide the actual runtime artifact** (a query against the live/local DB, a grep across the whole codebase — not just the known file — a device log, or a test run output). A source-code description of intended behavior is not sufficient evidence.

## Parent project
Part of the SCM monorepo at `../`. All work logged in `../research-vault/Task Execution Journal.md`.

---

## Behavioral Guidelines

- **Think before coding**: state assumptions explicitly, present multiple interpretations rather than silently picking one, push back if a simpler approach exists, stop and ask if something is unclear.
- **Simplicity first**: minimum code that solves the problem — no speculative features, abstractions, or configurability that wasn't requested.
- **Surgical changes**: touch only what you must. Don't "improve" adjacent code/formatting. Match existing style. Remove only the imports/variables/functions your own change made unused — flag pre-existing dead code, don't delete it unprompted. Every changed line should trace directly to the request.
- **Goal-driven execution**: define success as something verifiable, then loop until it's actually confirmed — not "make it work," but "write a test that reproduces the bug, then make it pass." **This is not optional in VOSRoute specifically** — see the Known Open Issues section below, most of which trace back to a fix being reported based on code inspection alone without holding up against real runtime behavior.

---

## Decisions Already Made — Do Not Revisit Without Explicit Instruction

- **Static Directus token stays.** Reviewed and explicitly accepted by the senior dev as a company-internal-use-only risk. Do not propose removing it, routing through Spring Boot as a proxy, or building a BFF as a "fix" — it is not a bug.
- **Push notifications stay on Spring Boot.** A migration to direct-Directus-write for token registration was drafted and explicitly reversed. Do not revisit unless a new plan is provided by the backend dev.
- **The stored `hashPassword`-for-silent-refresh pattern is a separate, still-open question** from the static token decision above — it has not been explicitly accepted the same way. If touching `AuthService`/`SecureStorageService`, flag this rather than assuming it's settled; prefer a genuine refresh-token flow if the backend can support one.
- **VOSRoute's state management is the `provider` package** (`ChangeNotifier`-based). Do not introduce Riverpod, Freezed, Flutter Hooks, or Supabase — these belong to a different stack entirely and were explicitly evaluated and rejected for this app. Don't adopt them opportunistically from a generic style guide.

---

## Critical Architecture — Two Dio Instances, One Outbox

`ApiService` (`lib/services/api_service.dart`) manages **two separate Dio instances**:

| Instance | Base URL | Auth | Used For |
|---|---|---|---|
| `_dio` | Spring Boot | JWT Bearer (via `AuthRefreshInterceptor`, single-flight lock on 401) | Login, FCM token registration |
| `_directusDio` | Directus | Static token in header | **All** operational data: trip fetch, stop updates, GPS logs, photos, SOS, etc. |

Both instances carry an `ExceptionInterceptor` mapping raw `DioException`s to a typed `AppException` hierarchy (`NetworkException` / `ServerException` / `ClientException` / `AuthException`) — consume these types in calling code rather than re-checking raw status codes.

**Key gotcha**: JWT is NEVER sent to Directus. Directus calls use the fixed static token. The Spring Boot JWT is only used for `/auth/login` and `/api/dispatch/mobile/register-device`.

For detailed architecture (offline outbox, GPS, repository layer, photo flow, screens, navigation, backend contracts):

→ `.brain/systems/VOSRoute/`

## Known Open Issues

Each of these has been reported "fixed" at least once in this project's history; some fixes did not hold, or fixed one code path while leaving a duplicate elsewhere. Re-verify with runtime evidence before relying on any of them:

1. **`invoiceAt` field receiving the driver's user ID instead of a timestamp** — root cause traced to `lib/sync/request_builders/update_stop_status_builder.dart` hardcoding `invoiceAt: driverUserId` in the builder itself, independent of what `TripProvider` enqueues. Multiple earlier fixes patched `TripProvider`'s enqueue payload instead of the builder, which did not resolve it.
2. **`outbox` vs `outbox_actions` table name mismatch** — found and fixed in at least two separate locations independently; grep the whole codebase before assuming no more instances exist.
3. **GPS batches processed before priority-1 actions** — intended order is urgent-first, GPS-last; has been both "fixed" and observed still-broken in this codebase at different points. Verify with an actual mixed-priority test run, not a code read.
4. **Photo field-name mismatches** — UI/queue code references `trip_id` in places where the live Directus schema may actually use `post_dispatch_plan_id`; de-dupe checks may query a different field (`directus_uuid`) than what the create payload actually posts (`file`). Confirm the real live schema before changing either side.
5. **Orphaned `post_dispatch_trip_photos` rows** — link rows created without a corresponding successful file upload (empty `directus_uuid`). Likely placeholder-then-patch ordering instead of upload-then-create; needs the write path traced and fixed, plus a data cleanup decision for existing orphaned rows.
6. **Notification `/stop-detail` deep link type mismatch** — `StopDetailScreen` expects a full stop object; the notification tap handler may pass only a primitive id, causing a crash on tap.
7. **GPS `trip_id` null** — an async-gap bug where a tick's trip context could go stale between starting a position fetch and the fetch resolving; fixed at least once by capturing the trip ID into a local variable before the `await`, but confirm this guard exists in both `GpsService` and `BackgroundService` (two independent capture paths).
8. **Duplicate startup fetches** — `MainShell` and `HomeScreen.initState` may both independently trigger trip fetches on launch: wasteful, and a source of inconsistent local state timing.
9. **`ForegroundServiceDidNotStartInTimeException` crash risk** — see GPS Tracking section in brain.

## Codebase Map

| Layer | Key files |
|---|---|
| `lib/config/` | `app_config.dart` — hardcoded URLs, intervals, static token, map style |
| `lib/models/` | `trip`, `stop`, `driver_profile`, `emergency_report`, `photo_quest`, `action_entry` |
| `lib/services/` | `api_service` (two Dio instances + interceptors), `auth_service`, `action_queue_service` (outbox worker), `gps_service` (timer), `upload_service` (Directus files), `notification_service` (FCM), `emergency_service`, `map_launch_service` (Waze/Google via `url_launcher`), `background_service`, `secure_storage_service`, `timezone_service` |
| `lib/repositories/` | `trip_repository.dart` — pass-through layer for `TripProvider`'s Directus reads |
| `lib/sync/request_builders/` | `TripTransitionBuilder`, `GpsBatchBuilder`, `SendSosBuilder`, `CreateAdhocStopBuilder`, `UploadPodBuilder`, `UpdateStopStatusBuilder` |
| `lib/network/` | `exception_interceptor.dart` (typed `AppException` mapping), `auth_refresh_interceptor.dart` (single-flight 401 handling) |
| `lib/providers/` | `auth_provider`, `trip_provider` (still a monolith, ~1300+ lines, owns bottom-nav tab index — not yet split), `action_queue_provider`, `gps_provider`, `theme_provider` |
| `lib/db/` | `database.dart` (legacy sqflite, dead code / migration source only), `app_database.dart` + `tables/outbox_table.dart` + `daos/outbox_dao.dart` (Drift, current real outbox + `CachedSettings`) |
| `lib/screens/` | `login`, `home`, `dispatch_plans`, `stops_list`, `stop_detail` (maplibre map), `budget`, `trip_photos`, `history`, `sos`, `settings`, `quest_screen`, `sync_log_screen`, `invoices_screen`, `invoice_detail_screen` |
| `lib/widgets/` | `stop_card`, `signature_pad`, `photo_capture_sheet`, `status_chip` |

**Bottom nav: 4 tabs** — Home / Plans / Stops / More. No Map tab; the map is embedded inside `stop_detail_screen` via `maplibre_gl` + OpenFreeMap tiles.

## Key Conventions and Gotchas

- **Offline-first**: all writes enqueue to `outbox_actions`; `TripRepository`/`TripProvider` fall back to cache on network failure (though see Repository Layer's in-memory-only trip cache gap).
- **Schema discipline**: Do NOT create, alter, or add columns/tables to Directus collections (or any backend schema) unless explicitly instructed. Flag the schema need in plan/doc instead.
- **Error handling**: many service methods still catch exceptions and only `debugPrint()` — no user-facing surfacing except `sync_log_screen`. Critical actions (departure, arrival, invoice confirmation, SOS) deserve more visible pending/failed states.
- **Auth token**: stored in `SecureStorageService`, not SharedPreferences. On 401, `AuthRefreshInterceptor` attempts a single-flight silent re-auth before falling back to logout. See Decisions section re: the stored-password-hash approach.
- **Stop status values**: `Fulfilled`, `Not Fulfilled`, `Fulfilled with Returns`, `Fulfilled with Concerns`.
- **Trip statuses** (driver transitions): `For Dispatch` → `For Inbound` (depart) → `For Clearance` (arrive base). Others (`For Approval`/`Posted`/`Cancelled`) are dispatcher-only.
- **Confirmation dialogs**: required for SOS, Arrive, Depart. SOS should distinguish "queued" (offline/pending sync) vs. "sent" (confirmed synced) in success messaging.
- **Drift codegen**: editing `lib/db/app_database.dart` or `lib/db/tables/*` requires regenerating `*.g.dart`:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- **Deprecated `fleet-emergency-app`** legacy code is absorbed into `SosScreen` + `EmergencyService` + `EmergencyReport`.
- **Code style** (Dart/Flutter general hygiene, matches existing `provider`-based patterns — do not introduce Riverpod/Freezed/Hooks per Decisions section): `const` constructors where possible; descriptive booleans (`isLoading`, `hasError`, `canSubmit`); trailing commas on multi-line widget trees; `errorBuilder` on network images; `ListView.builder` for long lists; explicit `textCapitalization`/`keyboardType`/`textInputAction` on `TextField`s; `log` over `print`/`debugPrint` for new debugging code. Match each file's existing convention (e.g. `_buildX()` methods vs. private widget classes) rather than converting a file's style as a side effect of an unrelated change.

## Verification

```bash
flutter pub get
flutter analyze          # flutter_lints ^6.0.0 — has timed out in some environments; if so, note it and proceed with manual/device verification rather than blocking on it
dart format lib/
# After editing Drift tables / app_database:
dart run build_runner build --delete-conflicting-outputs
```

**For anything touching the outbox, sync, GPS, or auth-refresh logic**: `flutter analyze` passing and a source-code description of the fix are not sufficient sign-off. Provide at least one of: an actual `outbox_actions` query result from a real or emulated run, a device log excerpt, or a test assertion result.
