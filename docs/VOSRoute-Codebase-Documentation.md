# VOSRoute Codebase Documentation

Status: current code scan  
Scan date: July 11, 2026  
Scope: Flutter Android driver app in `VOSRoute`

This document describes the application as implemented in the current codebase. The older planning documents in `docs/` are useful history, but this file should be treated as the current code-oriented reference.

## 1. Product Summary

VOSRoute is a driver-facing fleet dispatch mobile app. It lets a driver:

- Log in with VOS credentials.
- View assigned dispatch plans.
- Confirm departure.
- Navigate to delivery, pickup, and other stops.
- Capture invoice/POD photos.
- Update invoice fulfillment statuses.
- Confirm invoices before returning.
- Mark arrival at base.
- Track GPS while the trip is in progress.
- Queue writes offline and sync later.
- Submit SOS/emergency reports.
- Receive Firebase push notifications.

The current UI uses four bottom navigation tabs:

| Tab | Screen | Purpose |
|---|---|---|
| Home | `HomeScreen` | Driver header, performance chart, photo quest progress, dispatch queue, GPS status |
| Plans | `DispatchPlansScreen` | Active/selected plan details, departure/arrival controls, invoice entry point |
| Stops | `StopsListScreen` | Location/navigation list for delivery, pickup, and other stops |
| More | `_MoreMenu` in `main.dart` | Sync log, budget, trip photos, history, SOS, settings |

There is no dedicated Map tab. Maps are embedded in `StopDetailScreen`.

## 2. Runtime Startup

Entry point: `lib/main.dart`.

Startup sequence:

1. Flutter binding is initialized.
2. Portrait orientation is locked.
3. Firebase is initialized; failures are logged but do not block startup.
4. Drift database `AppDatabase` is opened and migrations run.
5. `ApiService().init()` creates the Spring Boot and Directus Dio clients.
6. `TimezoneService().load()` initializes timezone data and loads business timezone.
7. The app starts with providers:
   - `ThemeProvider`
   - `AuthProvider`
   - `TripProvider`
   - `ActionQueueProvider`
   - `GpsProvider`

After authenticated shell startup, `MainShell.initState()`:

- Initializes `BackgroundService`.
- Calls `TripProvider.fetchAllCachedData()`.
- Restarts GPS tracking if active trip has `timeOfDispatch`.
- Initializes `NotificationService`.

## 3. Backend Architecture

The app uses two different backend services.

| Backend | Base URL | Auth | Code owner | Purpose |
|---|---|---|---|---|
| Spring Boot ERP server | `AppConfig.springBaseUrl` | JWT Bearer from secure storage | `_dio` in `ApiService` | Login and FCM token registration |
| Directus CMS | `AppConfig.directusBaseUrl` | Static Directus token | `_directusDio` in `ApiService` | Dispatch plans, stops, files, GPS, SOS, status updates |

Important rule: the Spring JWT is not attached to Directus calls. Directus uses the static token configured in `AppConfig`.

Current hardcoded config:

- Spring Boot: `http://100.68.114.32:8089`
- Directus: `http://100.110.197.61:8056`
- GPS interval: 60 seconds
- GPS queue batch size config: 50
- Map style: OpenFreeMap liberty style

## 4. Authentication

Main files:

- `lib/services/auth_service.dart`
- `lib/providers/auth_provider.dart`
- `lib/services/secure_storage_service.dart`
- `lib/network/auth_refresh_interceptor.dart`

Login flow:

1. `AuthProvider.login(email, password)` calls `AuthService.login`.
2. `AuthService.login` posts to Spring Boot:
   - `POST /auth/login`
   - body: `{ email, hashPassword }`
3. Response expects `token`.
4. Token, login credentials required by the existing backend, and the absolute
   15-day session start timestamp are written to encrypted secure storage.
5. Login email is also stored in shared preferences for profile lookup.
6. Driver profile is fetched from Directus `user` collection by email.

Profile flow:

- `AuthService.getProfile()` queries:
  - `GET /items/user`
  - filter: `user_email == login email`
  - fields: `user_id,user_fname,user_lname,user_email,user_contact`
- On failure, it falls back to cached profile JSON in `SharedPreferences`.

Token refresh behavior:

- Spring Boot `_dio` retries a non-login 401 once by silently logging in with
  the stored email and `hashPassword`, then replacing the JWT.
- `/auth/login` itself bypasses refresh handling. Network failures and 5xx
  responses retain the session. Confirmed silent-login 401/403, the absolute
  15-day boundary, or explicit Sign Out clears all authentication state.

## 5. Directus Operational Data

Main access layer: `lib/repositories/trip_repository.dart`.

Trip/provider composition is manual rather than a single backend aggregate endpoint.

Plan list:

- Collection: `post_dispatch_plan`
- Filters:
  - `driver_id`
  - `status[_in]`
- Default fields: `*,vehicle_id.*`

Plan details:

- Staff: `post_dispatch_plan_staff`, fields `*,user_id.*`
- Budget: `post_dispatch_budgeting`
- Invoice stops: `post_dispatch_invoices`, fields `*,invoice_id.*`
- Purchase stops: `post_dispatch_purchases`
- Other stops: `post_dispatch_plan_others`
- Customer coordinates: `customer`, fields `customer_code,customer_name,latitude,longitude,location`

Status groups:

- Active/pending plans: `For Dispatch,For Inbound`
- Previous/history plans: `For Inbound,For Clearance,Posted`

## 6. State Management

State management uses `provider`.

### AuthProvider

Owns:

- `profile`
- `isLoggedIn`
- loading and error state
- unauthorized stream subscription

### TripProvider

Owns most business state:

- Active trip.
- Selected plan.
- Invoice, purchase, and other stops.
- Previous dispatch plans.
- Pending plans.
- Cached history.
- Photo quest state.
- Invoice confirmation gate.
- In-memory trip cache.
- Bottom tab index.

Important behavior:

- Selecting the active trip clears `_selectedPlan`.
- Selecting another plan loads details into selected lists.
- `allPlans` merges active, pending, and previous plans.
- `groupedStops` groups invoice stops by customer code for `InvoicesScreen`.
- `aggregatedInvoiceStatusCounts` powers the home performance chart.

### GpsProvider

Wraps `GpsService` and exposes:

- `isTracking`
- `lastPosition`
- `startTracking(tripId)`
- `stopTracking()`

### ActionQueueProvider

Drives queue processing and exposes pending/failed counts for the sync UI.

## 7. Navigation And Screens

### Login

File: `lib/screens/login_screen.dart`

Handles email/password login through `AuthProvider`.

### Home

File: `lib/screens/home_screen.dart`

Contains:

- Driver identity header.
- Invoice status performance donut chart using `fl_chart`.
- Photo Quest progress.
- Dispatch queue.
- GPS tracking card.

### Dispatch Plans

File: `lib/screens/dispatch_plans_screen.dart`

Contains:

- Active/selected dispatch plan header.
- Confirm Departure action for active `For Dispatch` plan.
- Invoices button for active `For Inbound` plan.
- Arrived at Base action for active `For Inbound` plan.
- Trip details, crew, and progress.
- Pending plan list.

Departure flow:

1. Requires device GPS service enabled.
2. Shows confirmation dialog with optional remarks.
3. Calls `TripProvider.confirmDeparture`.
4. Starts GPS tracking.
5. Opens `QuestScreen`, then `InvoicesScreen`.

Arrival flow:

1. Shows confirmation dialog with optional remarks.
2. Calls `TripProvider.markArrivedAtBase`.
3. Stops GPS tracking after the provider future completes.

### Stops

File: `lib/screens/stops_list_screen.dart`

The Stops tab is currently location-focused:

- Delivery stops open `StopDetailScreen`.
- Pickup stops open `StopDetailScreen`.
- Other stops open an inline fulfillment dialog.

Invoice fulfillment is not primarily handled here. It is handled in the invoice flow.

### Stop Detail

File: `lib/screens/stop_detail_screen.dart`

Purpose:

- Display a MapLibre map for a stop.
- Add one marker.
- Open Google Maps, Waze, or generic maps.

Supported coordinates:

- Invoice stops use invoice/customer latitude and longitude.
- Other stops use their own latitude and longitude.
- Purchase stops currently do not expose latitude/longitude in this screen, so they can land on the no-location view.

### Invoices

Files:

- `lib/screens/invoices_screen.dart`
- `lib/screens/invoice_detail_screen.dart`
- `lib/screens/quest_screen.dart`

Invoice flow:

1. After departure, `TripProvider.confirmDeparture` creates a `PhotoQuest`.
2. `QuestScreen` walks through invoice stops and captures one photo per invoice.
3. Photos are persisted locally under app documents `photos/`.
4. A `linkTripPhoto` action is queued with type `invoice`.
5. `InvoicesScreen` groups invoice stops by customer.
6. `InvoiceDetailScreen` allows extra photos and status updates.
7. `InvoicesScreen` enables Confirm Invoices only when all invoice statuses are terminal.
8. `TripProvider.markArrivedAtBase` requires `_invoicesConfirmed == true`.

Terminal invoice statuses:

- `Fulfilled`
- `Not Fulfilled`
- `Fulfilled with Returns`
- `Fulfilled with Concerns`

### More

Defined in `lib/main.dart`.

Routes:

- `/sync-log`
- `/budget`
- `/trip-photos`
- `/history`
- `/sos`
- `/settings`

### SOS

File: `lib/screens/sos_screen.dart`

Flow:

1. Attempts to use last known position.
2. Requires a non-empty description.
3. Builds `EmergencyReport`.
4. Enqueues `submitSos` action.
5. Shows success snackbar and returns.

## 8. Offline And Outbox Architecture

Current queued-write implementation is Drift-based.

Main files:

- `lib/db/app_database.dart`
- `lib/db/tables/outbox_table.dart`
- `lib/db/daos/outbox_dao.dart`
- `lib/services/action_queue_service.dart`
- `lib/models/action_entry.dart`
- `lib/sync/request_builders/*`

Drift database:

- File: `vosroute_drift.db`
- Schema version: 2
- Tables:
  - `cached_settings`
  - `outbox_actions`

Outbox columns:

- `id`
- `action`
- `priority`
- `depends_on`
- `args_json`
- `schema_version`
- `status`
- `retry_count`
- `max_retries`
- `created_at`
- `last_attempt`
- `last_error`

Action statuses:

- `pending`
- `in_flight`
- `completed`
- `failed`

Action priorities:

- `1`: urgent, such as departure, arrival, SOS, invoice status
- `2`: normal, such as photo links
- `3`: low, such as GPS batches

Queue processing:

1. `ActionQueueService.start()` subscribes to connectivity changes.
2. A timer calls `processQueue()` every 10 seconds.
3. `processQueue()` pings Directus.
4. GPS batches are processed first.
5. Non-GPS actions are processed by priority 1, then 2, then 3.
6. Client 4xx except 401 and type/format/argument errors are treated as permanent failures.
7. Other failures retry up to 5 attempts with backoff.

Supported actions:

| Action | Directus/Spring target |
|---|---|
| `confirm_departure` | `PATCH /items/post_dispatch_plan/{id}` |
| `mark_arrived` | `PATCH /items/post_dispatch_plan/{id}` |
| `update_stop_status` | `PATCH /items/post_dispatch_invoices/{id}` or `PATCH /items/post_dispatch_plan_others/{id}` |
| `update_invoices_departure` | `PATCH /items/sales_invoice` |
| `update_orders_departure` | `PATCH /items/sales_order` |
| `link_pod_photo` | `POST /items/post_dispatch_nte` |
| `link_trip_photo` | `POST /items/post_dispatch_trip_photos` |
| `submit_sos` | `POST /items/fleet_emergency_reports` |
| `gps_batch` | `POST /items/post_dispatch_gps_logs` |
| `add_ad_hoc_stop` | `POST /items/post_dispatch_plan_others` |

Legacy sqflite database:

- File: `lib/db/database.dart`
- Class name also `AppDatabase`
- Database file: `vosroute.db`
- Schema version: 3
- Creates/migrates `action_queue`

Current operational code imports Drift `lib/db/app_database.dart` for the outbox. The sqflite class remains in the repo as migration/legacy code and should not be imported into new queue code.

## 9. GPS Tracking

Files:

- `lib/services/gps_service.dart`
- `lib/providers/gps_provider.dart`
- `lib/services/background_service.dart`

Behavior:

- Starts when departure is confirmed.
- Restarts on app startup if active trip has `timeOfDispatch`.
- Uses timer-based polling, not a geolocator stream.
- Captures current position every `AppConfig.gpsIntervalSeconds`.
- Buffers points in memory.
- Flushes when buffer reaches 5 points or every 60 seconds.
- Queues a `gps_batch` action.
- Stops when arrival at base is marked or provider is disposed.

Payload fields:

- `trip_id`
- `latitude`
- `longitude`
- `accuracy`
- `speed`
- `heading`
- `recorded_at`

## 10. File Uploads And Photos

File uploads use `UploadService`.

Directus upload endpoint:

- `POST /files`
- Multipart field: `file`
- Optional field: `folder`
- Auth: static Directus token
- Expected response: `data.id`

Queue upload flow:

1. UI saves camera result into app documents.
2. UI queues action with `local_file_path`.
3. `ActionQueueService` uploads file to Directus.
4. The local path is removed from the payload.
5. `directus_uuid` and the UTC `uploaded_at` timestamp are persisted in the queued row.
6. The link row is created only after upload succeeds, using
   `{trip_id, directus_uuid, type, uploaded_at}`. Duplicate detection uses the
   same `trip_id` and `directus_uuid` fields.
6. The action builder creates the final link request.

Folder UUIDs:

- POD folder: `d3940009-6b99-411b-8a7a-45b8c3a83c95`
- Trip/invoice photo folder: `13954431-1352-421b-8bcd-d41963b3d9bd`

Current invoice photo flow uses `post_dispatch_trip_photos` with `type: invoice`.

## 11. Notifications

File: `lib/services/notification_service.dart`

Behavior:

- Initializes local notifications.
- Creates Android notification channel.
- Requests FCM permission.
- Gets FCM token.
- Registers token with Spring Boot:
  - `POST /api/dispatch/mobile/register-device`
  - body: `{ fcmToken, deviceInfo: "Android" }`
- Registers token refresh listener.
- Shows foreground messages as local notifications.
- Handles background messages with `vosRouteBackgroundHandler`.
- Handles notification taps by route name/type in payload.

Supported notification target routes:

- `/stop-detail`
- `/sos`
- `/budget`
- `/history`
- `/settings`

## 12. Local Storage

| Storage | Technology | Purpose |
|---|---|---|
| Secure token storage | `flutter_secure_storage` | JWT token, DB passphrase, stored login email/password hash |
| Shared preferences | `shared_preferences` | Login email, cached profile, encryption marker |
| Drift DB | `vosroute_drift.db` | Settings cache and outbox actions |
| sqflite legacy DB | `vosroute.db` | Legacy `action_queue` migration source |
| App documents/photos | File system | Persistent captured photos before upload |

## 13. Build And Verification Commands

Recommended commands:

```bash
flutter pub get
flutter analyze
dart format lib/
```

If editing Drift tables, DAOs, or `app_database.dart`, regenerate generated files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

During this scan, both `flutter analyze` and `dart analyze lib test` timed out after roughly 120 seconds in this environment, so analyzer status was not confirmed.

## 14. Current Documentation Differences From Older Docs

The current code differs from older planning docs in these important ways:

- Outbox writes currently use Drift `outbox_actions`, not sqflite `action_queue`, although legacy sqflite code remains.
- Stops tab is location/navigation focused.
- Invoice/POD work is handled by `QuestScreen`, `InvoicesScreen`, and `InvoiceDetailScreen`.
- Invoice photos currently queue as `linkTripPhoto` records with `type: invoice`.
- `post_dispatch_nte` support still exists in request builders but is not the main invoice photo path in current UI.
- Bottom nav has four tabs, not five.
- MapLibre is used for embedded maps.
