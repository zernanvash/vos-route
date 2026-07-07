# AGENTS.md — VOSRoute (Fleet Dispatch Mobile App)

> **Status**: Prototype. All 10 screens + 4 providers + 7 services + 6 models + 5 widgets exist and are wired.
> **Architecture**: Directus REST API for all operational queries/mutations. Spring Boot `ERP_SERVER` for auth only (+ FCM token registration).
> Design doc at `docs/VOSRoute-Documentation.md` is the architecture reference but may conflict with code — code is truth.

## Parent project
Part of the SCM monorepo at `../`. All work logged in `../scm-vault/supply-chain/Task Execution Journal.md`.

## Critical architecture — two Dio instances

`ApiService` (`lib/services/api_service.dart`) manages **two separate Dio instances**:

| Instance | Base URL | Auth | Used For |
|---|---|---|---|
| `_dio` | Spring Boot `:8082` | JWT Bearer (injected via interceptor from `vos_access_token` in SharedPreferences) | Login, FCM token registration |
| `_directusDio` | Directus `:8056` | Static token `AAKv73dkIV8DfAIA5vEt3eXVdIebzmBW` in header | **All** operational data: trip fetch, stop updates, GPS logs, photos, SOS, etc. |

**Key gotcha**: JWT is NEVER sent to Directus. Directus calls use a fixed static token hardcoded in `AppConfig`. The Spring Boot JWT is NOT used for operational data — only for `/auth/login` and `/api/dispatch/mobile/register-device`.

## Backend Contracts

### 1. Spring Boot (`http://100.105.235.94:8082`) — Auth only

| Method | Route | Payload | Notes |
|--------|-------|---------|-------|
| `POST` | `/auth/login` | `{ email, hashPassword }` | Returns `{ token }` (NOT `access_token`). Field is `hashPassword` (NOT `password`). |
| `POST` | `/api/dispatch/mobile/register-device` | `{ fcmToken, deviceInfo }` | Registers FCM token. Called from `NotificationService`. |

Driver profile is fetched from **Directus** (`/items/user?filter[user_email][_eq]=...`), NOT from Spring Boot `/auth/me` — despite the doc saying otherwise. `DriverProfile.fromJson` handles both camelCase and snake_case fields.

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
3. Insert into local queue table (`pod_queue` / `trip_photo_queue`) with UUID and local path
4. `SyncService` later links UUID to Directus collection (`post_dispatch_nte` / `post_dispatch_trip_photos`)

## Offline-first architecture

All writes go to local SQLite **first**, then sync. DB version 2 (`vosroute.db`):
- `cached_trips` — full trip payload as JSON blob
- `gps_queue` — GPS points with `synced` flag
- `pod_queue` — POD photos with `synced` flag
- `trip_photo_queue` — trip photos with `synced` flag
- `emergency_queue` — SOS reports with `synced` flag
- `ad_hoc_stop_queue` — ad-hoc stops with `synced` flag

**Migration (v1→v2)**: adds `driver_user_id` column to `emergency_queue`.

**SyncService** (`lib/services/sync_service.dart`): monitors `connectivity_plus` for reconnect + periodic 30s timer. Flushes `gps_queue` (batched), `pod_queue`, `trip_photo_queue`, `emergency_queue` in order. GPS batch size: 50 points.

## GPS tracking

- Timer-based (NOT geolocator stream): `Timer.periodic(60s)` calls `Geolocator.getCurrentPosition()` each tick
- Queued to `gps_queue` locally, synced in batches to `POST /items/post_dispatch_gps_logs`
- **Starts** on departure confirm, **stops** on arrived-at-base

## Codebase map

| Directory | Key files |
|---|---|
| `lib/config/` | `app_config.dart` — hardcoded URLs, intervals, static token |
| `lib/models/` | 6 models: `trip`, `stop`, `gps_log`, `pod`, `trip_photo`, `emergency_report` |
| `lib/services/` | `api_service` (two Dio instances), `auth_service`, `gps_service` (timer), `sync_service` (flush), `upload_service` (Directus files), `notification_service` (FCM), `emergency_service`, `map_launch_service` (Waze/Google) |
| `lib/providers/` | `auth_provider`, `trip_provider` (parallel fetch + mutations), `gps_provider`, `sync_provider` |
| `lib/db/` | `database` (schema + migration), `trip_dao`, `queue_dao` |
| `lib/screens/` | 11 screens: `login`, `home` (dashboard — `fl_chart` pie of invoice statuses + active/pending DP queue), `dispatch_plans` (active DP header + Confirm Departure/Arrive actions + trip details/crew/progress + pending plans list), `stops` (customer-grouped with aggregate indicators + inline status), `stop_detail` (required signature upload flow), `map` (maplibre_gl + OpenFreeMap tiles, customer/other-stop markers from active DP), `budget` (per-DP header cards with budget lines + subtotals), `trip_photos`, `history`, `sos`, `settings`. Bottom nav: Home/Plans/Stops/Map/More (5 tabs). |
| `lib/widgets/` | `stop_card`, `signature_pad`, `photo_capture_sheet`, `status_chip`, `sync_indicator` |

## Key conventions and gotchas

- **Offline-first**: all writes queue to SQLite; `TripProvider` falls back to `_loadFromCache()` on network failure
- **Schema discipline**: Do NOT create, alter, or add columns/tables to Directus collections (or any backend schema) unless explicitly instructed by the user. Flag the schema need in plan/doc instead.
- **Error handling**: most service methods silently catch exceptions and `print()` to debug console — no user-facing retry mechanisms except TripProvider error state
- **Auth**: JWT in SharedPreferences key `vos_access_token`. On 401, token is cleared (interceptor). No auto-redirect to login.
- **Stop status values**: `Fulfilled`, `Not Fulfilled`, `Fulfilled with Returns`, `Fulfilled with Concerns`
- **Trip statuses** (driver transitions): `For Dispatch` → `For Inbound` (depart) → `For Clearance` (arrive base). `For Approval`/`For Clearance`/`Posted`/`Cancelled` are dispatcher-only.
- **Confirmation dialogs**: required for SOS, Arrive, Depart. Uses `_showActionDialog` pattern with optional remarks text field.
- **Map navigation**: `MapLaunchService` opens address in Google Maps, Waze, or generic maps via `url_launcher`
- **External nav buttons**: shown in `StopDetailScreen` for invoice stops with addresses
- **Dark theme**, Material 3, 48dp min touch targets, bottom nav with 4 tabs
- **Deprecated `fleet-emergency-app`** legacy code is absorbed into `SosScreen` + `EmergencyService` + `EmergencyReport`

## Verification

```bash
flutter analyze          # uses flutter_lints ^6.0.0 (default rules)
dart format lib/
```

