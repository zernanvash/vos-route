# AGENTS.md — VOSRoute (Fleet Dispatch Mobile App)

> **Architecture**: Directus REST API for all operational queries/mutations. Spring Boot `ERP_SERVER` for auth only (+ FCM token registration).
> Design doc at `docs/VOSRoute-Documentation.md` is the architecture reference but may conflict with code — code is truth.

## Parent project
Part of the SCM monorepo at `../`. All work logged in `../scm-vault/supply-chain/Task Execution Journal.md`.

## Critical architecture — two Dio instances

`ApiService` (`lib/services/api_service.dart`) manages **two separate Dio instances**:

| Instance | Base URL | Auth | Used For |
|---|---|---|---|
| `_dio` | Spring Boot `:8082` | JWT Bearer (injected via interceptor from `SecureStorageService`) | Login, FCM token registration |
| `_directusDio` | Directus `:8056` | Static token `AAKv73dkIV8DfAIA5vEt3eXVdIebzmBW` in header | **All** operational data: trip fetch, stop updates, GPS logs, photos, SOS, etc. |

**Key gotcha**: JWT is NEVER sent to Directus. Directus calls use a fixed static token hardcoded in `AppConfig`. The Spring Boot JWT is NOT used for operational data — only for `/auth/login` and `/api/dispatch/mobile/register-device`.

## Backend Contracts

### 1. Spring Boot (`http://100.105.235.94:8082`) — Auth only

| Method | Route | Payload | Notes |
|--------|-------|---------|-------|
| `POST` | `/auth/login` | `{ email, hashPassword }` | Returns `{ token }` (NOT `access_token`). Field is `hashPassword` (NOT `password`). |
| `POST` | `/api/dispatch/mobile/register-device` | `{ fcmToken, deviceInfo }` | Registers FCM token. Called from `NotificationService`. |

Driver profile is fetched from **Directus** (`/items/user?filter[user_email][_eq]=...`), NOT from Spring Boot `/auth/me`. `DriverProfile.fromJson` handles both camelCase and snake_case fields.

### 2. Directus CMS (`http://100.110.197.61:8056`) — All operational data

Static token: `AAKv73dkIV8DfAIA5vEt3eXVdIebzmBW`

**Trip fetch (TripProvider):** makes 5 parallel `getDirectus()` calls and assembles manually:
1. `GET /items/post_dispatch_plan` — filter `driver_id` + `status[_in]=For Dispatch,For Inbound`, sort `-id`, limit 1
2. `GET /items/post_dispatch_plan_staff` — filter by plan_id
3. `GET /items/post_dispatch_budgeting` — filter by plan_id
4. `GET /items/post_dispatch_invoices` — filter by plan_id, fields `*,invoice_id.*`
5. `GET /items/post_dispatch_purchases` + `GET /items/post_dispatch_plan_others` — filter by plan_id

| Collection | Action | Endpoint | Notes |
|---|---|---|---|
| `post_dispatch_plan` | Update Status | `PATCH /items/post_dispatch_plan/{id}` | confirmDeparture: `{ status: "For Inbound", time_of_dispatch, remarks }`. markArrivedAtBase: `{ status: "For Clearance", time_of_arrival, remarks_arrival }`. |
| `sales_invoice` | Bulk Update | `PATCH /items/sales_invoice` | confirmDeparture also sets `{ transaction_status: "En Route", isDispatched: 1, dispatch_date }` on linked invoices |
| `sales_order` | Bulk Update | `PATCH /items/sales_order` | confirmDeparture also sets `{ order_status: "En Route" }` on linked orders |
| `post_dispatch_invoices` | Update Stop | `PATCH /items/post_dispatch_invoices/{id}` | `{ status, invoiceAt, remarks }` |
| `post_dispatch_gps_logs` | GPS Logs | `POST /items/post_dispatch_gps_logs` | **Batched** array payload, not single points |
| `post_dispatch_nte` | POD Link | `POST /items/post_dispatch_nte` | Links Directus file UUID to stop: `{ post_dispatch_invoice_id, file, doc_no }` |
| `post_dispatch_trip_photos` | Trip Photos | `POST /items/post_dispatch_trip_photos` | `{ post_dispatch_plan_id, file, type }` where type is `outbound` or `inbound` |
| `post_dispatch_plan_others` | Ad-Hoc Stops | `POST /items/post_dispatch_plan_others` | `{ post_dispatch_plan_id, remarks, distance, sequence, status }` |
| `fleet_emergency_reports` | SOS | `POST /items/fleet_emergency_reports` | Payload assembled by `EmergencyReport.toApiPayload()` |
| `/files` | File Upload | `POST /files` | Multipart form-data with static token Bearer auth. Returns `{ data: { id: "uuid" } }` |

## Photo flow (3-step, not 2-step)

1. Capture via `image_picker` → save local path
2. Upload to Directus `POST /files` via `UploadService` → get UUID
3. `ActionQueueService` later links the UUID to the Directus collection (`post_dispatch_nte` / `post_dispatch_trip_photos`). The `ActionEntry` payload carries a `local_file_path`; the executor uploads it to a fixed folder (`d3940009-…` for POD, `13954431-…` for trip photos) before sending. Watch for duplicate links — the executor de-dupes by checking the target collection for an existing `file` + parent id.

## Offline-first architecture — unified `action_queue`

All writes are enqueued to a local SQLite table `action_queue` (db `vosroute.db`, **version 3**), then flushed by `ActionQueueService` (`lib/services/action_queue_service.dart`):

- Triggered by `connectivity_plus` reconnect + a `Timer.periodic(10s)`.
- Processes GPS batches first, then pending actions by `batch_priority` (1 → 2 → 3).
- GPS points are coalesced into batches of **50** and POSTed as one array to `post_dispatch_gps_logs`.
- Retry: exponential backoff (1/2/4/8/16/30s), max 5 attempts. Client 4xx (except 401) and type errors are marked **permanently failed**. `sync_log_screen` shows pending/failed entries with retry + clear.
- **Legacy tables** (`cached_trips`, `gps_queue`, `pod_queue`, `trip_photo_queue`, `emergency_queue`, `ad_hoc_stop_queue`) were folded into `action_queue` during the **v2→v3** migration. Do not rely on them.

**Two `AppDatabase` classes exist** — be careful which you import:
- `lib/db/database.dart` — **sqflite**, the real operational DB (`action_queue`, `vosroute.db`). Used by `ActionQueueService`.
- `lib/db/app_database.dart` — **Drift**, a separate small DB holding only the `CachedSettings` table (`vosroute_drift.db`). Used at startup via `executor.ensureOpen()`.

## GPS tracking

- Timer-based (NOT geolocator stream): `Timer.periodic(60s)` calls `Geolocator.getCurrentPosition()` each tick (`AppConfig.gpsIntervalSeconds`).
- **Starts** on departure confirm, **stops** on arrived-at-base (or app dispose). Reactivated on startup if an in-progress trip has a `timeOfDispatch`.

## Codebase map

| Layer | Key files |
|---|---|
| `lib/config/` | `app_config.dart` — hardcoded URLs, intervals, static token, map style |
| `lib/models/` | 6 models: `trip`, `stop`, `driver_profile`, `emergency_report`, `photo_quest`, `action_entry` |
| `lib/services/` | `api_service` (two Dio instances), `auth_service`, `action_queue_service` (offline flush), `gps_service` (timer), `upload_service` (Directus files), `notification_service` (FCM), `emergency_service`, `map_launch_service` (Waze/Google via `url_launcher`), `background_service`, `secure_storage_service`, `timezone_service` |
| `lib/providers/` | `auth_provider`, `trip_provider` (parallel fetch + mutations, owns bottom-nav tab index), `action_queue_provider` (drives the flush timer), `gps_provider`, `theme_provider` |
| `lib/db/` | `database.dart` (sqflite schema + v2→v3 migration), `app_database.dart` + `tables/` + `daos/` (Drift, `CachedSettings` only) |
| `lib/screens/` | `login`, `home` (dashboard — `fl_chart` pie of invoice statuses + active/pending DP queue), `dispatch_plans` (active DP header + Confirm Departure/Arrive + trip details/crew/progress + pending plans list), `stops_list` (customer-grouped with aggregate indicators + inline status), `stop_detail` (embedded **maplibre** map + required signature upload flow), `budget`, `trip_photos`, `history`, `sos`, `settings`, `quest_screen` (Photo Quest feature), `sync_log_screen` (offline queue visibility) |
| `lib/widgets/` | `stop_card`, `signature_pad`, `photo_capture_sheet`, `status_chip` |

**Bottom nav: 4 tabs** — Home / Plans / Stops / More (NavigationBar in `main.dart`). There is **no Map tab**; the map is embedded inside `stop_detail_screen` via `maplibre_gl` + OpenFreeMap tiles.

## Key conventions and gotchas

- **Offline-first**: all writes enqueue to `action_queue`; `TripProvider` falls back to cache on network failure.
- **Schema discipline**: Do NOT create, alter, or add columns/tables to Directus collections (or any backend schema) unless explicitly instructed by the user. Flag the schema need in plan/doc instead.
- **Error handling**: most service methods catch exceptions and `debugPrint()` — no user-facing retry except the `sync_log_screen` (retry/clear failed actions).
- **Auth token**: stored in `SecureStorageService` (`flutter_secure_storage`), NOT SharedPreferences. On 401 the interceptor deletes the token and emits `onUnauthorized`. No auto-redirect to login.
- **Stop status values**: `Fulfilled`, `Not Fulfilled`, `Fulfilled with Returns`, `Fulfilled with Concerns`.
- **Trip statuses** (driver transitions): `For Dispatch` → `For Inbound` (depart) → `For Clearance` (arrive base). Others (`For Approval`/`Posted`/`Cancelled`) are dispatcher-only.
- **Confirmation dialogs**: required for SOS, Arrive, Depart (`_showActionDialog` pattern with optional remarks field).
- **Drift codegen**: editing `lib/db/app_database.dart` or `lib/db/tables/*` requires regenerating `*.g.dart`:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- **Deprecated `fleet-emergency-app`** legacy code is absorbed into `SosScreen` + `EmergencyService` + `EmergencyReport`.

## Verification

```bash
flutter pub get
flutter analyze          # flutter_lints ^6.0.0 (default rules)
dart format lib/
# After editing Drift tables / app_database:
dart run build_runner build --delete-conflicting-outputs
```
