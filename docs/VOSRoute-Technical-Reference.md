# VOSRoute — Technical Reference

> **Codebase state**: Current as of July 10, 2026  
> **Version**: 1.0.0+1  
> **Dart SDK**: ^3.12.2 (Flutter 3.44.4)  
> **Scope**: Complete technical reference for the VOSRoute fleet dispatch mobile app

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Project Structure](#2-project-structure)
3. [Dependencies](#3-dependencies)
4. [App Entry Point & Initialization](#4-app-entry-point--initialization)
5. [State Management (Provider Layer)](#5-state-management-provider-layer)
6. [Network Layer (ApiService)](#6-network-layer-apiservice)
7. [Authentication Flow](#7-authentication-flow)
8. [Offline Queue (Action Queue)](#8-offline-queue-action-queue)
9. [Data Models](#9-data-models)
10. [Navigation & Routing](#10-navigation--routing)
11. [Screens](#11-screens)
12. [GPS Tracking](#12-gps-tracking)
13. [Photo Upload Flow](#13-photo-upload-flow)
14. [Emergency / SOS](#14-emergency--sos)
15. [Push Notifications](#15-push-notifications)
16. [Database Layer](#16-database-layer)
17. [Theme & Design System](#17-theme--design-system)
18. [Key Flows](#18-key-flows)
19. [Error Handling](#19-error-handling)
20. [Configuration Reference](#20-configuration-reference)
21. [Development & Build Commands](#21-development--build-commands)

---

## 1. Architecture Overview

VOSRoute follows a **Provider–Service** architecture pattern with an **offline-first** write path.

```
┌─────────────────────────────────────────────────────────┐
│  UI Layer (Screens / Widgets / Core Components)         │
│  - 14 screens in lib/screens/                           │
│  - Shared widgets in lib/widgets/                       │
│  - Design system in lib/core/                           │
└──────────────┬──────────────────────────────────────────┘
               │ context.watch / context.read
┌──────────────▼──────────────────────────────────────────┐
│  Provider Layer (ChangeNotifier)                         │
│  - AuthProvider (auth state, profile, login/logout)      │
│  - TripProvider (active trip, stops, quest, cache)       │
│  - ActionQueueProvider (queue status monitoring)         │
│  - GpsProvider (tracking on/off + permissions)           │
│  - ThemeProvider (light/dark/system)                     │
└──────────────┬──────────────────────────────────────────┘
               │ calls
┌──────────────▼──────────────────────────────────────────┐
│  Service Layer (Singletons)                              │
│  - ApiService (two Dio instances)                        │
│  - AuthService (login, register-device)                  │
│  - ActionQueueService (offline flush engine)             │
│  - GpsService (timer-based GPS capture)                  │
│  - UploadService (Directus file upload)                  │
│  - NotificationService (FCM + local notifications)       │
│  - EmergencyService (SOS enqueue)                        │
│  - SecureStorageService (JWT wrapper)                    │
│  - BackgroundService (foreground service)                │
│  - TimezoneService (business tz from Directus)           │
│  - MapLaunchService (Google Maps / Waze opener)          │
└──────────────┬──────────────────────────────────────────┘
               │ reads/writes
┌──────────────▼──────────────────────────────────────────┐
│  Database Layer                                          │
│  - sqflite: vosroute.db (action_queue table)             │
│  - Drift: vosroute_drift.db (CachedSettings table)       │
└──────────────┬──────────────────────────────────────────┘
               │ HTTP
┌──────────────▼──────────────────────────────────────────┐
│  Backend                                                 │
│  - Directus CMS (:8056) — ALL operational data           │
│  - Spring Boot (:8082) — Auth + FCM registration only    │
└─────────────────────────────────────────────────────────┘
```

### Key architectural decisions

| Decision | Rationale |
|---|---|
| **Two Dio instances** | JWT (Spring Boot) and static token (Directus) never mix. Security boundary. |
| **All writes via action_queue** | No direct API mutation from UI. Enables offline-first. |
| **Timer-based GPS** (not stream) | Battery efficiency. 60s interval, batch of 5 before flush. |
| **Tab index owned by TripProvider** | Enables programmatic tab switching (e.g., Home -> Plans tab). |
| **Optimistic updates** | Local state updates immediately; API call async in background. |
| **Two databases** | sqflite for operational queue; Drift for settings cache only. |

---

## 2. Project Structure

```
lib/
├── main.dart                          # App entry + AuthGate + MainShell + bottom nav
│
├── config/
│   └── app_config.dart                # Hardcoded URLs, static token, intervals, map style
│
├── core/                              # Reusable UI design system
│   ├── app_routes.dart                # Named route constants
│   ├── app_card.dart                  # AppCard + AppInfoRow
│   ├── app_dialog.dart                # AppDialog.showConfirm / showError
│   ├── app_action_button.dart         # AppActionButton + static builders
│   ├── app_gradient_header.dart       # Brand gradient header
│   ├── app_status_badge.dart          # Color-coded status badge
│   ├── app_section_header.dart        # Section header + divider
│   ├── app_progress_bar.dart          # Progress bar + info
│   └── app_list_tile.dart             # Key-value list tile
│
├── theme/
│   ├── app_colors.dart                # VOS brand palette + status color extensions
│   ├── app_theme.dart                 # Light + dark ThemeData (Material 3)
│   ├── app_typography.dart            # Text styles
│   └── app_spacing.dart               # Inset constants
│
├── models/                            # Data models with JSON serialization
│   ├── trip.dart                      # PostDispatchPlan, Vehicle, CrewMember, BudgetLine
│   ├── stop.dart                      # InvoiceStop, PurchaseStop, OtherStop, StopGroup
│   ├── driver_profile.dart            # DriverProfile
│   ├── emergency_report.dart          # EmergencyReport
│   ├── photo_quest.dart               # PhotoQuest, PhotoQuestItem
│   └── action_entry.dart              # ActionEntry, ActionType, ActionStatus, ActionPriority enums
│
├── network/                           # Networking utilities
│   ├── app_exception.dart             # Sealed exception hierarchy
│   └── utc_date_formatter.dart        # Timezone-aware UTC formatting
│
├── services/                          # Business logic (all singletons)
│   ├── api_service.dart               # Two Dio instances + typed wrappers
│   ├── auth_service.dart              # Spring Boot login + profile fetch
│   ├── action_queue_service.dart      # Offline queue processor
│   ├── gps_service.dart               # Timer-based GPS capture
│   ├── upload_service.dart            # Directus file upload (multipart)
│   ├── notification_service.dart      # FCM + local notifications + deep links
│   ├── emergency_service.dart         # SOS report enqueue
│   ├── secure_storage_service.dart    # flutter_secure_storage wrapper
│   ├── background_service.dart        # Foreground service for BG GPS
│   ├── timezone_service.dart          # Business timezone from Directus
│   └── map_launch_service.dart        # Google Maps / Waze / Apple Maps
│
├── providers/                         # ChangeNotifier state holders
│   ├── auth_provider.dart             # Auth state, profile, login/logout
│   ├── trip_provider.dart             # ~1377 lines — central trip state
│   ├── action_queue_provider.dart     # Queue status monitoring
│   ├── gps_provider.dart              # GPS tracking start/stop
│   └── theme_provider.dart            # Theme mode persistence
│
├── db/                                # Local databases
│   ├── database.dart                  # sqflite AppDatabase (vosroute.db, v3)
│   ├── app_database.dart              # Drift AppDatabase (vosroute_drift.db)
│   ├── app_database.g.dart            # Generated Drift code
│   ├── tables/
│   │   └── cached_settings_table.dart # Drift table definition
│   └── daos/
│       ├── cached_settings_dao.dart   # Drift DAO
│       └── cached_settings_dao.g.dart # Generated Drift code
│
├── screens/                           # 14 UI screens
│   ├── login_screen.dart
│   ├── home_screen.dart               # Dashboard with pie chart + dispatch queue
│   ├── dispatch_plans_screen.dart     # Active trip + pending plans
│   ├── stops_list_screen.dart         # Grouped stops
│   ├── stop_detail_screen.dart        # Embedded MapLibre map
│   ├── invoices_screen.dart           # Customer-grouped invoices
│   ├── invoice_detail_screen.dart     # POD + status update
│   ├── quest_screen.dart              # Photo quest wizard
│   ├── budget_screen.dart             # Budget lines display
│   ├── trip_photos_screen.dart        # Outbound/inbound photos
│   ├── history_screen.dart            # Past trips
│   ├── sos_screen.dart                # Emergency SOS form
│   ├── settings_screen.dart           # Profile, theme, diagnostics
│   └── sync_log_screen.dart           # Offline queue visibility
│
├── widgets/                           # Shared widgets
│   ├── stop_card.dart                 # Polymorphic stop card
│   ├── status_chip.dart               # Color-coded status
│   ├── signature_pad.dart             # Signature capture (deprecated)
│   └── photo_capture_sheet.dart       # Camera/gallery bottom sheet
│
└── sync/
    └── request_builders/
        └── update_stop_status_builder.dart  # PATCH payload builder

test/
└── widget_test.dart                   # Single smoke test
```

---

## 3. Dependencies

| Package | Version | Purpose |
|---|---|---|
| `dio` | ^5.7.0 | HTTP client (two instances) |
| `sqflite` | ^2.4.1 | Local SQLite for action queue |
| `provider` | ^6.1.2 | State management (ChangeNotifier) |
| `maplibre_gl` | ^0.26.0 | Embedded map in stop detail |
| `image_picker` | ^1.1.2 | Camera/gallery photo capture |
| `signature` | ^5.5.0 | Signature capture widget |
| `geolocator` | ^13.0.2 | GPS location |
| `flutter_background_service` | ^5.0.6 | Background GPS service |
| `firebase_core` | ^3.10.1 | Firebase initialization |
| `firebase_messaging` | ^15.2.1 | FCM push notifications |
| `connectivity_plus` | ^6.1.2 | Network monitoring |
| `intl` | ^0.20.2 | Date formatting |
| `flutter_local_notifications` | ^18.0.1 | Local notification display |
| `url_launcher` | ^6.3.2 | Open external maps |
| `fl_chart` | ^0.70.2 | Pie/donut chart on home screen |
| `flutter_secure_storage` | ^9.2.4 | Secure JWT storage |
| `jwt_decoder` | ^2.0.1 | JWT expiry validation |
| `timezone` | ^0.10.1 | Business timezone handling |
| `drift` | ^2.14.1 | Type-safe SQL (settings cache only) |
| `sqlite3_flutter_libs` | — | SQLite native libs for Drift |
| `path_provider` | — | File system paths |
| `firebase_core_web` / `firebase_messaging_web` | — | Web platform stubs |
| `flutter_lints` | ^6.0.0 | Lint rules |

---

## 4. App Entry Point & Initialization

**File**: `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final db = AppDatabase();                                     // Drift DB
  await db.executor.ensureOpen(db);
  await ApiService().init();                                    // Two Dio instances
  await TimezoneService().load();                               // Business timezone
  runApp(const VOSRouteApp());
}
```

### Initialization order

1. `Firebase.initializeApp()` — FCM messaging
2. `AppDatabase()` — Drift settings cache (vosroute_drift.db)
3. `ApiService().init()` — Creates `_dio` (Spring Boot) and `_directusDio` (Directus) with interceptors
4. `TimezoneService().load()` — Fetches business timezone from Directus `general_setting`, falls back to local cache, then `Asia/Manila`
5. `runApp()` — Wraps in `MultiProvider` with 5 providers

### Provider tree

```
MultiProvider
├── ChangeNotifierProvider<ThemeProvider>
├── ChangeNotifierProvider<AuthProvider>
├── ChangeNotifierProvider<TripProvider>
├── ChangeNotifierProvider<ActionQueueProvider>
└── ChangeNotifierProvider<GpsProvider>
    └── MaterialApp(
          home: AuthGate()       // Splash → Login or MainShell
          onGenerateRoute        // Named routes for deep links
        )
```

### `AuthGate` logic

Checks three conditions in order:
1. `auth.isLoading` → show splash
2. `!auth.isLoggedIn` → show `LoginScreen`
3. `auth.isLoggedIn` → show `MainShell` (tab navigation)

### `MainShell` bottom navigation

4 tabs in `NavigationBar`:
| Index | Tab | Screen |
|---|---|---|
| 0 | Home | `HomeScreen` |
| 1 | Plans | `DispatchPlansScreen` |
| 2 | Stops | `StopsListScreen` |
| 3 | More | Menu → push to other screens |

Tab index is stored in `TripProvider._currentTabIndex`, enabling `DispatchPlansScreen` to programmatically switch tabs via `trip.setTabIndex(1)`.

---

## 5. State Management (Provider Layer)

### 5.1 AuthProvider (`lib/providers/auth_provider.dart`)

| Field | Type | Description |
|---|---|---|
| `_profile` | `DriverProfile?` | Current driver profile |
| `_isLoggedIn` | `bool` | Login state |
| `_isLoading` | `bool` | Loading state |
| `_error` | `String?` | Last error message |

| Method | Action |
|---|---|
| `login(email, password)` | Clears token, calls `AuthService.login()`, fetches profile, sets state |
| `logout()` | Calls `AuthService.logout()`, clears all state |
| `checkAuth()` | Validates token, fetches profile if valid |
| `onUnauthorized()` | Listens to `ApiService.onUnauthorized` stream, logs out |

### 5.2 TripProvider (`lib/providers/trip_provider.dart`)

The largest provider (~1377 lines). Central state hub for all trip data.

| Field | Type | Description |
|---|---|---|
| `_activeTrip` | `PostDispatchPlan?` | Currently active dispatch plan |
| `_invoiceStops` | `List<InvoiceStop>` | Invoice stops for active trip |
| `_purchaseStops` | `List<PurchaseStop>` | Purchase stops |
| `_otherStops` | `List<OtherStop>` | Other/ad-hoc stops |
| `_pendingPlans` | `List<PostDispatchPlan>` | Other assigned plans |
| `_selectedPlan` | `PostDispatchPlan?` | Plan selected from pending list |
| `_currentQuest` | `PhotoQuest?` | Active photo quest |
| `_invoicesConfirmed` | `bool` | Whether invoices are confirmed |
| `_currentTabIndex` | `int` | Bottom nav tab index |
| `_tripCache` | `Map<String, dynamic>?` | Fallback cache on network failure |
| `_podPhotosByStop` | `Map<int, List<String>>` | POD photo paths per stop |

| Method | Effect |
|---|---|
| `fetchActiveTrip()` | 5 parallel Directus GETs → assembles trip data |
| `fetchAllCachedData()` | Init fetch on login |
| `selectPlan(plan)` | Sets selected plan, switches tab to Plans |
| `confirmDeparture(plan, remarks)` | Enqueues departure actions (status + invoice/order updates) |
| `markArrivedAtBase(plan, remarks)` | Validates all stops terminal + invoices confirmed → enqueues arrival |
| `updateStopStatus(stop, status, ...)` | PATCH stop status via action queue |
| `confirmInvoices()` | Sets `_invoicesConfirmed = true` |
| `markQuestPhotoCaptured(stopId)` | Updates photo quest progress |

### 5.3 ActionQueueProvider (`lib/providers/action_queue_provider.dart`)

| Field | Type | Description |
|---|---|---|
| `_pendingCount` | `int` | Pending actions in queue |
| `_failedCount` | `int` | Permanently failed actions |

| Method | Description |
|---|---|
| `init()` | Starts periodic `Timer(10s)` to process queue |
| `processNow()` | Manual trigger (pull-to-refresh) |
| `retryFailed()` | Resets failed items to pending |
| `clearFailed()` | Removes failed items |

### 5.4 GpsProvider (`lib/providers/gps_provider.dart`)

| Field | Type | Description |
|---|---|---|
| `_isTracking` | `bool` | Whether GPS is actively tracking |
| `_lastPosition` | `Position?` | Last known position |

| Method | Description |
|---|---|
| `startTracking()` | Requests permissions, starts GpsService timer |
| `stopTracking()` | Stops GpsService timer |

### 5.5 ThemeProvider (`lib/providers/theme_provider.dart`)

| Method | Description |
|---|---|
| `setMode(mode)` | Sets ThemeMode (light/dark/system) |
| `toggle()` | Toggles between light and dark |

Persists to `SharedPreferences`.

---

## 6. Network Layer (ApiService)

**File**: `lib/services/api_service.dart`

### 6.1 Two Dio Instances

| Instance | Base URL | Auth | Interceptors | Used For |
|---|---|---|---|---|
| `_dio` | `http://100.105.235.94:8082` | JWT Bearer | Auth interceptor (injects token from SecureStorageService) | Login, `/auth/me`, `/api/dispatch/mobile/register-device` |
| `_directusDio` | `http://100.110.197.61:8056` | Static token `AAKv73dkIV8DfAIA5vEt3eXVdIebzmBW` | Static token header interceptor | All operational data |

### 6.2 Typed Wrappers

```dart
Future<Response> get(String endpoint, {Map<String, dynamic>? params, bool useDirectus = true})
Future<Response> post(String endpoint, dynamic data, {bool useDirectus = true})
Future<Response> patch(String endpoint, dynamic data, {bool useDirectus = true})
```

Each method accepts `useDirectus` flag (default `true`). When `true`, uses `_directusDio`; when `false`, uses `_dio` (Spring Boot).

### 6.3 Directus Wrappers

```dart
Future<Response> getDirectus(String endpoint, {Map<String, dynamic>? params})
Future<Response> postDirectus(String endpoint, dynamic data)
Future<Response> patchDirectus(String endpoint, dynamic data)
```

Convenience methods hardcoding `useDirectus: true`.

### 6.4 Auth Interceptor (on `_dio`)

- Reads JWT from `SecureStorageService` (key: `vos_access_token`)
- Injects as `Authorization: Bearer <token>` header
- On 401 response: deletes token from secure storage, emits `onUnauthorized` stream
- `onUnauthorized` is a `StreamController<void>` that `AuthProvider` listens to

### 6.5 Exception Hierarchy

**File**: `lib/network/app_exception.dart`

```
AppException (sealed)
├── NetworkException      — Timeout, no connectivity (retryable)
├── ServerException       — 5xx (retryable), has statusCode
├── ClientException       — 4xx non-auth (NOT retryable), has statusCode + body
├── AuthException         — 401 after refresh fails (force re-login)
└── ValidationException   — 422/400 (not retryable), has fieldErrors
```

---

## 7. Authentication Flow

```
┌──────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│  Driver   │    │ AuthProvider │    │ AuthService  │    │   Backend    │
│ (Screen)  │    │              │    │              │    │              │
└─────┬─────┘    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘
      │ login(email,    │                    │                   │
      │ password)        │                    │                   │
      │────────────────►│                    │                   │
      │                 │ POST /auth/login   │                   │
      │                 │───────────────────►│──────────────────►│ Spring Boot
      │                 │                    │ { email,          │ :8082
      │                 │                    │   hashPassword }  │
      │                 │                    │                   │
      │                 │                    │◄──────────────────│
      │                 │                    │ { token }         │
      │                 │◄───────────────────│                   │
      │                 │                    │                   │
      │                 │ Store JWT in       │                   │
      │                 │ SecureStorage      │                   │
      │                 │                    │                   │
      │                 │ GET /items/user    │                   │
      │                 │ filter[user_email] │                   │
      │                 │───────────────────►│──────────────────►│ Directus
      │                 │                    │                   │ :8056
      │                 │◄───────────────────│◄──────────────────│
      │                 │ DriverProfile      │                   │
      │                 │                    │                   │
      │                 │ POST /register-dev │                   │
      │                 │───────────────────►│──────────────────►│ Spring Boot
      │                 │ { fcmToken,        │                   │
      │                 │   deviceInfo }     │                   │
      │◄────────────────│                    │                   │
      │ auth.isLoggedIn  │                    │                   │
      │ = true           │                    │                   │
```

### Key details

- **Login payload uses `hashPassword`** (NOT `password`) as the field key
- **Response returns `token`** (NOT `access_token`)
- **Profile fetch is from Directus**, NOT from Spring Boot `/auth/me`
- Token stored in `flutter_secure_storage` (Android Keystore), key: `vos_access_token`
- JWT decoded via `jwt_decoder` for expiry validation
- If expired, fallback to `GET /auth/me` (Spring Boot) for refresh
- On 401 from any Spring Boot call, interceptor deletes token and emits `onUnauthorized` — no auto-redirect

---

## 8. Offline Queue (Action Queue)

### 8.1 Architecture

All mutations go through a local SQLite `action_queue` table managed by `ActionQueueService`.

```
UI → Provider.updateSomething()
          │
          ▼
    ActionQueueService.enqueue(entry)
          │
          ▼
    INSERT INTO action_queue (vosroute.db)
          │
          ▼
    Timer.periodic(10s) + connectivity_plus
          │
          ▼
    ActionQueueService._processQueue()
          │
          ▼
    HTTP call → success → DELETE from queue
              → retryable error → increment retry
              → permanent error → mark failed
```

### 8.2 Action Types (10 values)

| ActionType | Priority | HTTP Method | Endpoint | Description |
|---|---|---|---|---|
| `confirmDeparture` | 1 (Urgent) | PATCH | `/items/post_dispatch_plan/{id}` | Set status to "For Inbound" |
| `markArrived` | 1 (Urgent) | PATCH | `/items/post_dispatch_plan/{id}` | Set status to "For Clearance" |
| `updateStopStatus` | 1 (Urgent) | PATCH | `/items/post_dispatch_invoices/{id}` | Update stop status + invoiceAt |
| `updateInvoicesDeparture` | 1 (Urgent) | PATCH | `/items/sales_invoice` | Bulk update transaction_status |
| `updateOrdersDeparture` | 1 (Urgent) | PATCH | `/items/sales_order` | Bulk update order_status |
| `linkPodPhoto` | 2 (Normal) | POST | `/items/post_dispatch_nte` | Link POD file UUID to stop |
| `linkTripPhoto` | 2 (Normal) | POST | `/items/post_dispatch_trip_photos` | Link trip photo file UUID to plan |
| `submitSos` | 1 (Urgent) | POST | `/items/fleet_emergency_reports` | Submit SOS report |
| `gpsBatch` | 3 (Low) | POST | `/items/post_dispatch_gps_logs` | Batched GPS points |
| `addAdHocStop` | 1 (Urgent) | POST | `/items/post_dispatch_plan_others` | Create ad-hoc stop |

### 8.3 Database Schema

```sql
CREATE TABLE action_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action_type TEXT NOT NULL,
  action_payload TEXT NOT NULL,       -- JSON string
  endpoint TEXT NOT NULL,
  http_method TEXT NOT NULL,
  batch_group TEXT,                    -- For GPS coalescing
  batch_priority INTEGER DEFAULT 0,    -- 1=urgent, 2=normal, 3=low
  status TEXT DEFAULT 'pending',       -- pending/inFlight/completed/failed
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 5,
  created_at TEXT,
  last_attempt TEXT,
  last_error TEXT
);
```

### 8.4 Queue Processing

- **Trigger**: `connectivity_plus` stream (on reconnect) + `Timer.periodic(10s)`
- **Order**: by `batch_priority ASC` then `created_at ASC`
- **GPS batches**: coalesced into groups of 50 before POST
- **Retry**: exponential backoff — 1s, 2s, 4s, 8s, 16s, 30s (max 5 attempts)
- **Permanent failure**: Client 4xx (except 401) + type errors
- **Retryable**: Network errors, 5xx, timeouts
- **Photo de-duplication**: checks target collection for existing `file` + parent id before linking
- **Null payload guard**: rejects stop status updates with null status as permanent failure

### 8.5 v2→v3 Migration

Legacy individual tables (`cached_trips`, `gps_queue`, `pod_queue`, `trip_photo_queue`, `emergency_queue`, `ad_hoc_stop_queue`) were folded into unified `action_queue`. Old tables dropped after migration. Migration checks for table existence before migrating.

---

## 9. Data Models

### 9.1 PostDispatchPlan (`lib/models/trip.dart`)

```dart
class PostDispatchPlan {
  final int id;
  final String? docNo;
  final int? driverId;
  final int? vehicleId;
  final String? status;              // "For Dispatch" | "For Inbound" | "For Clearance"
  final String? startingPoint;
  final double? totalDistance;
  final double? amount;
  final String? estimatedTimeOfDispatch;
  final String? estimatedTimeOfArrival;
  final String? timeOfDispatch;
  final String? timeOfArrival;
  final String? dateEncoded;
  final String? remarks;
  final Vehicle? vehicle;            // Nested: vehicleId, vehiclePlate, name
  final List<CrewMember>? crew;      // List of: userId, name, role
  final List<BudgetLine>? budget;    // List of: id, coaName, amount, remarks
}

// Helpers
bool get isForDispatch  => status == 'For Dispatch';
bool get isForInbound   => status == 'For Inbound';
bool get isActive       => status == 'For Dispatch' || status == 'For Inbound';
```

### 9.2 InvoiceStop (`lib/models/stop.dart`)

```dart
class InvoiceStop {
  final int id;
  final int postDispatchPlanId;
  final int? invoiceId;
  final String? invoiceNo;
  final String? customerCode;
  final String? customerName;
  final double? amount;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distance;
  final String? status;              // "Fulfilled" | "Not Fulfilled" | "Fulfilled with Returns" | "Fulfilled with Concerns"
  final int? sequence;
  final String? remarks;
}
```

### 9.3 PurchaseStop

```dart
class PurchaseStop {
  final int id;
  final int postDispatchPlanId;
  final int? poId;
  final String? poNo;
  final String? supplierName;
  final double? distance;
  final int? sequence;
  final String? status;
}
```

### 9.4 OtherStop

```dart
class OtherStop {
  final int id;
  final int? postDispatchPlanId;
  final String? remarks;
  final double? distance;
  final double? latitude;
  final double? longitude;
  final int? sequence;
  final String? status;
}
```

### 9.5 StopGroup

Aggregates `InvoiceStop` objects by `customerCode` for the Invoices screen.

```dart
class StopGroup {
  final String? customerCode;
  final String? customerName;
  final double? latitude;
  final double? longitude;
  final List<InvoiceStop> stops;

  int get totalStops;
  int get fulfilledCount;
  int get notFulfilledCount;
  int get terminalCount;     // sum of fulfilled + notFulfilled + returns + concerns
  bool get allFulfilled;
}
```

### 9.6 DriverProfile (`lib/models/driver_profile.dart`)

```dart
class DriverProfile {
  final int? userId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? contact;
  final int? vehicleId;
  final String? vehiclePlate;
  final int? branchId;
  final String? branchName;

  // fromJson handles both camelCase and snake_case
  String get fullName => '$firstName $lastName';
}
```

### 9.7 EmergencyReport (`lib/models/emergency_report.dart`)

```dart
class EmergencyReport {
  final int? id;
  final String? reportNo;
  final String? incidentType;     // Accident | Breakdown | Medical | Security | Weather | Other
  final String? severity;         // Low | Medium | High | Critical
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final int? vehicleId;
  final int? dispatchPlanId;
  final int? driverUserId;
  final String? contactName;
  final String? contactPhone;
  final String? status;
  final bool synced;

  Map<String, dynamic> toApiPayload();  // Builds Directus POST payload
}
```

### 9.8 PhotoQuest / PhotoQuestItem (`lib/models/photo_quest.dart`)

```dart
class PhotoQuest {
  final int? tripId;
  final List<PhotoQuestItem> items;
}

class PhotoQuestItem {
  final int? invoiceStopId;
  final int? invoiceId;
  final String? invoiceNo;
  final String? customerName;
  final double? amount;
  final String? address;
  bool photoCaptured;
  String? localPhotoPath;
  String? directusFileUuid;
  String? stopStatus;
}
```

### 9.9 ActionEntry (`lib/models/action_entry.dart`)

```dart
class ActionEntry {
  final int? id;
  final ActionType actionType;
  final dynamic payload;           // JSON-serializable
  final String endpoint;
  final String httpMethod;
  final String? batchGroup;
  final ActionPriority priority;
  final ActionStatus status;
  final int retryCount;
  final int maxRetries;            // default: 5
  final String? createdAt;
  final String? lastAttempt;
  final String? lastError;
}

enum ActionType {
  confirmDeparture, markArrived, updateStopStatus,
  updateInvoicesDeparture, updateOrdersDeparture,
  linkPodPhoto, linkTripPhoto, submitSos, gpsBatch, addAdHocStop
}

enum ActionStatus { pending, inFlight, completed, failed }
enum ActionPriority { urgent(1), normal(2), low(3) }
```

---

## 10. Navigation & Routing

**File**: `lib/core/app_routes.dart`

### Named routes

| Route Constant | Path | Screen | Arguments |
|---|---|---|---|
| `stopDetail` | `/stop-detail` | `StopDetailScreen` | Stop object |
| `budget` | `/budget` | `BudgetScreen` | None |
| `tripPhotos` | `/trip-photos` | `TripPhotosScreen` | None |
| `history` | `/history` | `HistoryScreen` | None |
| `sos` | `/sos` | `SosScreen` | None |
| `settings` | `/settings` | `SettingsScreen` | None |
| `quest` | `/quest` | `QuestScreen` | None |
| `syncLog` | `/sync-log` | `SyncLogScreen` | None |

Used via `onGenerateRoute` in `MaterialApp`:

```dart
onGenerateRoute: (settings) {
  switch (settings.name) {
    case AppRoutes.stopDetail:
      final stop = settings.arguments as InvoiceStop;
      return MaterialPageRoute(builder: (_) => StopDetailScreen(stop: stop));
    // ...
  }
}
```

### Direct navigation (no named routes)

Some screens push directly via `Navigator.push(MaterialPageRoute(...))`:
- `InvoicesScreen`
- `InvoiceDetailScreen`
- `QuestScreen` (wrapped in `_QuestWrapper` ChangeNotifierProvider)

### Deep link navigation (from push notifications)

`NotificationService._navigateWithData()` maps notification payload `type` to route:

| Type | Action |
|---|---|
| `stop-detail` | `Navigator.pushNamed('/stop-detail', arguments: stop)` |
| `sos` | `Navigator.pushNamed('/sos')` |
| `budget` | `Navigator.pushNamed('/budget')` |
| `history` | `Navigator.pushNamed('/history')` |
| `settings` | `Navigator.pushNamed('/settings')` |
| `dp_approved` / `dp_dispatched` | Navigate to `/home` → triggers `fetchActiveTrip()` |

---

## 11. Screens

### 11.1 LoginScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/login_screen.dart` |
| State | Local `_email`, `_password`, `_isLoading`, `_error` |
| Validation | Email format regex, password min 4 chars |
| UX | Animated form (fade + slide), gradient Sign In button with loading spinner |
| On success | AuthProvider sets `isLoggedIn = true` → AuthGate auto-navigates to MainShell |

### 11.2 HomeScreen (Dashboard)

| Aspect | Detail |
|---|---|
| File | `lib/screens/home_screen.dart` |
| Sections | Driver header (gradient + avatar initials), performance donut chart (fl_chart), photo quest progress, dispatch queue list, GPS status card |
| Data source | `TripProvider._activeTrip`, `TripProvider._pendingPlans`, `TripProvider._currentQuest` |
| Pie chart | Shows distribution of `Fulfilled`/`Not Fulfilled`/`With Returns`/`With Concerns`/`Pending` across all invoice stops (aggregated from active + pending + cached trips) |
| Tap plan | Calls `trip.selectPlan(plan)` then switches to Plans tab via `setTabIndex(1)` |

### 11.3 DispatchPlansScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/dispatch_plans_screen.dart` |
| Active trip | Gradient header with doc no, vehicle plate, crew list (AppCard), budget (AppCard), stop progress bar |
| Action buttons | "Confirm Departure" (GPS check → dialog → PhotoQuest → invoices), "Invoices" (check quest → navigate), "Mark Arrived at Base" (validate → dialog → enqueue) |
| Pending plans | Scrollable list of other plans with `isForDispatch` status; tap to select |

### 11.4 StopsListScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/stops_list_screen.dart` |
| Sections | "Delivery Stops" (Invoice), "Pick-up Stops" (Purchase), "Other Stops" |
| StopCard | Sequence number, title, customer name, amount, address, status chip, location indicator |
| Tap invoice | → `/stop-detail` (MapLibre map) |
| Tap other | → inline status update dialog |

### 11.5 StopDetailScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/stop_detail_screen.dart` |
| Map | Embedded MapLibre (OpenFreeMap tiles: `https://tiles.openfreemap.org/styles/liberty`) with custom pin marker |
| Navigate buttons | Google Maps, Waze, Other (via `url_launcher`) |
| Fallback | Shows "No location coordinates" when lat/lng are null |

### 11.6 InvoicesScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/invoices_screen.dart` |
| Grouping | By `StopGroup` (customerCode) with expansion tiles |
| Aggregate | Each group shows total stops, fulfilled count, concerns count |
| Tap invoice | → `InvoiceDetailScreen` |
| Confirm bar | Bottom bar that enables when all stops are terminal; calls `trip.confirmInvoices()` |

### 11.7 InvoiceDetailScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/invoice_detail_screen.dart` |
| Info | Customer, invoice no, amount, address, status |
| POD photos | Grid of captured photos + "Add Photo" button → photo_capture_sheet → enqueue |
| Status buttons | Fulfilled, Not Fulfilled, Fulfilled with Returns, Fulfilled with Concerns (calls `trip.updateStopStatus()`) |

### 11.8 QuestScreen (Photo Quest)

| Aspect | Detail |
|---|---|
| File | `lib/screens/quest_screen.dart` |
| Modes | `list` (progress summary), `capturing` (camera open), `preview` (retake/accept), `complete` (celebration) |
| Flow | Departure → creates PhotoQuest → navigates to Quest → capture all → complete → Invoices screen |

### 11.9 BudgetScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/budget_screen.dart` |
| Content | All plans (active + pending) with budget lines, per-plan subtotals |
| Active plan | Highlighted with accent color |

### 11.10 TripPhotosScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/trip_photos_screen.dart` |
| Mode | Outbound (before departure) or inbound (after departure) determined by `timeOfDispatch` |
| Action | Capture → save locally → enqueue `linkTripPhoto` |

### 11.11 HistoryScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/history_screen.dart` |
| Data | Past trips (status: For Inbound, For Clearance, Posted) from Directus |
| Display | Doc no, vehicle plate, date, status badge |

### 11.12 SosScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/sos_screen.dart` |
| Fields | Incident type (dropdown), severity (dropdown), description (required textarea), contact name (optional), contact phone (optional) |
| Location | Auto-detects last known GPS position |
| Submit | → `EmergencyService` → enqueues `submitSos` (urgent priority) |

### 11.13 SettingsScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/settings_screen.dart` |
| Sections | Profile card, theme selector (Light/Dark/System), system info (GPS status, interval, server URLs), connection diagnostics (Directus ping), app version, sign out |
| Diagnostics | Pings Directus `/server/ping` |

### 11.14 SyncLogScreen

| Aspect | Detail |
|---|---|
| File | `lib/screens/sync_log_screen.dart` |
| Data | Pending + failed `ActionEntry` from `ActionQueueProvider` |
| Display | Action type, endpoint, error, retry count, status badge |
| Actions | Retry All, Clear Failed, individual Retry |
| Empty state | Cloud icon + "All synced" |

---

## 12. GPS Tracking

### 12.1 Architecture

```
Timer.periodic(60s)
       │
       ▼
  Geolocator.getCurrentPosition()
       │
       ▼
  GpsService._buffer.add(point)
       │
       ▼
  Buffer ≥ 5 OR 60s elapsed
       │
       ▼
  Enqueue gpsBatch action (coalesced to 50 per batch)
       │
       ▼
  ActionQueueService → POST /items/post_dispatch_gps_logs
```

### 12.2 GPS Payload

```json
{
  "trip_id": 123,
  "latitude": 14.12345,
  "longitude": 120.98765,
  "accuracy": 10.0,
  "speed": 0.5,
  "heading": 90.0,
  "recorded_at": "2026-07-10T12:00:00Z"
}
```

### 12.3 Lifecycle

- **Start**: on `confirmDeparture` (via `GpsProvider.startTracking()`)
- **Stop**: on `markArrivedAtBase` or app dispose
- **Re-activation**: on startup if active trip has `timeOfDispatch`
- **Dual capture**:
  - Foreground: `GpsService` (in-memory buffer → action_queue)
  - Background: `BackgroundService` (foreground service, independent GPS → Directus via `flutter_background_service`)

### 12.4 Background Service

Uses `flutter_background_service` package. Runs as a foreground service with persistent notification. Independently captures GPS and posts to Directus when app is minimized.

---

## 13. Photo Upload Flow

Photos follow a **3-step** process:

```
Step 1: Capture
image_picker → save to getApplicationDocumentsDirectory()/photos/
              (timestamped filename, persistent across app restarts)
       │
       ▼
Step 2: Upload (at queue processing time)
UploadService.uploadFile(filePath, folderUuid)
       │
       ▼
POST /files (Directus)
Headers: Authorization: Bearer <static_token>
Body: multipart/form-data (file bytes, folder UUID)
       │
       ▼
Response: { data: { id: "directus-file-uuid" } }
       │
       ▼
Step 3: Link (at queue processing time, after upload)
ActionQueueService executor:
  1. Uploads file to specific folder UUID
     - POD photos: d3940009-...
     - Trip photos: 13954431-...
  2. Swaps local_file_path with server file UUID in payload
  3. Persists updated payload to SQLite
  4. POSTs to target collection (post_dispatch_nte / post_dispatch_trip_photos)
  5. De-dupes by checking existing file + parent id before POST
```

### Folder UUIDs

| Photo type | Directus folder UUID |
|---|---|
| POD (Proof of Delivery) | `d3940009-...` |
| Trip photos | `13954431-...` |

---

## 14. Emergency / SOS

### 14.1 SOS Report Lifecycle

```
SosScreen (user fills form)
       │
       ▼
EmergencyService.enqueue(report)
       │
       ▼
ActionQueueService.enqueue(ActionType.submitSos)  →  priority = urgent(1)
       │
       ▼
ActionQueueService._execute()
       │
       ▼
POST /items/fleet_emergency_reports  (Directus)
```

### 14.2 AirTable / Legacy Sync

The sos screen has an optional AirTable sync toggle. Synchronization status is tracked via `_syncedToAirtable` flag and the `synced` field in `EmergencyReport`.

---

## 15. Push Notifications

### 15.1 NotificationService (`lib/services/notification_service.dart`)

| Responsibility | Implementation |
|---|---|
| FCM init | `Firebase.initializeApp()` + `requestPermission()` |
| Token registration | `POST /api/dispatch/mobile/register-device` to Spring Boot with `{ fcmToken, deviceInfo }` |
| Token refresh | `onTokenRefresh.listen` → re-register |
| Foreground messages | `FirebaseMessaging.onMessage.listen` → show local notification via `flutter_local_notifications` |
| Background messages | `FirebaseMessaging.onBackgroundMessage` with `@pragma('vm:entry-point')` handler `vosRouteBackgroundHandler` |
| Tap-to-navigate | `onMessageOpenedApp` + `getInitialMessage()` → `_navigateWithData()` |
| Local notifications | Sync status (failure/success), new trip assignment |

### 15.2 Deep Link Navigation

```dart
void _navigateWithData(Map<String, dynamic> data) {
  final type = data['type'];
  switch (type) {
    case 'stop-detail':  // pushNamed('/stop-detail', ...)
    case 'sos':          // pushNamed('/sos')
    case 'budget':       // pushNamed('/budget')
    case 'history':      // pushNamed('/history')
    case 'settings':     // pushNamed('/settings')
    case 'dp_approved':
    case 'dp_dispatched': // navigate to home → fetchActiveTrip()
  }
}
```

### 15.3 FCM Registration Endpoint

```http
POST /api/dispatch/mobile/register-device
Content-Type: application/json
Authorization: Bearer <jwt>

{
  "fcmToken": "string",
  "deviceInfo": "string"   // e.g., "Android/SDK 34/VOSRoute 1.0.0"
}
```

---

## 16. Database Layer

### 16.1 Two Databases

| DB | Package | File | Purpose |
|---|---|---|---|
| `vosroute.db` | `sqflite` | `lib/db/database.dart` | Operational offline queue (`action_queue` table, version 3) |
| `vosroute_drift.db` | `Drift` | `lib/db/app_database.dart` | Settings cache (`CachedSettings` table — timezone only) |

### 16.2 sqflite Database (`vosroute.db`)

```dart
// Singleton pattern in AppDatabase (lib/db/database.dart)
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'vosroute.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
}
```

Schema (version 3):
```sql
CREATE TABLE action_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action_type TEXT NOT NULL,
  action_payload TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  http_method TEXT NOT NULL,
  batch_group TEXT,
  batch_priority INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending',
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 5,
  created_at TEXT,
  last_attempt TEXT,
  last_error TEXT
);
```

Version 2→3 migration: folds legacy tables (`cached_trips`, `gps_queue`, `pod_queue`, `trip_photo_queue`, `emergency_queue`, `ad_hoc_stop_queue`) into unified `action_queue`.

### 16.3 Drift Database (`vosroute_drift.db`)

Used for the `CachedSettings` table only — caches business timezone setting from Directus.

```dart
// CachedSettingsTable (lib/db/tables/cached_settings_table.dart)
class CachedSettings extends Table {
  TextColumn get settingKey => text()();
  TextColumn? get settingValue => text().nullable()();
  DateTimeColumn? get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {settingKey};
}

// CachedSettingsDao (lib/db/daos/cached_settings_dao.dart)
class CachedSettingsDao extends DatabaseAccessor<AppDatabase> {
  Future<String?> getSetting(String key);
  Future<void> saveSetting(String key, String? value);
}
```

---

## 17. Theme & Design System

### 17.1 Color Palette

**File**: `lib/theme/app_colors.dart`

| Token | Light | Dark | Usage |
|---|---|---|---|
| Seed | `#1D4ED8` | `#3B6EF0` | Primary | 
| Background | `#F7F7FB` | `#080810` | Screen background |
| Surface | `#FFFFFF` | `#0F0F1A` | Cards, dialogs |
| Primary | `#1D4ED8` | `#3B6EF0` | Buttons, links |
| On Primary | `#FFFFFF` | `#FFFFFF` | Text on primary |

**Status colors**:
| Status | Color |
|---|---|
| Fulfilled | Green |
| Not Fulfilled | Red |
| With Returns | Orange |
| With Concerns | Yellow |
| For Dispatch | Blue |
| For Inbound | Orange |
| For Clearance | Yellow |
| Posted | Green |

### 17.2 Theme Extensions

```dart
// AppColors — custom color tokens
Theme.of(context).extension<AppColors>()!

// AppTextStyle — custom text styles
Theme.of(context).extension<AppTextStyle>()!

// Insets — spacing constants
EdgeInsets.all(Insets.sm)  // 8.0
EdgeInsets.all(Insets.md)  // 16.0
EdgeInsets.all(Insets.lg)  // 24.0
```

### 17.3 Core Components

| Component | File | Description |
|---|---|---|
| `AppCard` | `lib/core/app_card.dart` | Styled container with optional header |
| `AppDialog` | `lib/core/app_dialog.dart` | `showConfirm` / `showError` static methods |
| `AppActionButton` | `lib/core/app_action_button.dart` | Themed button with static builders for depart/arrive/invoice/quest |
| `AppGradientHeader` | `lib/core/app_gradient_header.dart` | Brand gradient bar |
| `AppStatusBadge` | `lib/core/app_status_badge.dart` | Color-coded badge |
| `AppProgressBar` | `lib/core/app_progress_bar.dart` | Linear progress with label |
| `AppListTile` | `lib/core/app_list_tile.dart` | Key-value tile |
| `AppSectionHeader` | `lib/core/app_section_header.dart` | Section title + divider |

### 17.4 Material 3 Theme

- Light and dark `ThemeData` built from seed colors
- Font family: 'Inter'
- Custom `ColorScheme` from seed
- Custom `CardTheme`, `AppBarTheme`, `BottomNavigationBarTheme`, `ElevatedButtonTheme`, `InputDecorationTheme`

---

## 18. Key Flows

### 18.1 Complete Trip Lifecycle

```
For Dispatch           (initial state — dispatcher assigns)
       │
       ▼  Driver taps "Confirm Departure"
For Inbound            (driver enqueues departure actions)
       │
       ├── 1. PATCH post_dispatch_plan { status: "For Inbound", time_of_dispatch, remarks }
       ├── 2. PATCH sales_invoice (bulk) { transaction_status: "En Route", isDispatched: 1, dispatch_date }
       ├── 3. PATCH sales_order (bulk) { order_status: "En Route" }
       ├── 4. Start GPS tracking
       ├── 5. Create PhotoQuest
       └── 6. Navigate to QuestScreen
       │
       ▼  Driver delivers stops, updates statuses, captures POD
For Inbound (continues)
       │
       ├── Update stop statuses (Fulfilled / Not Fulfilled / With Returns / With Concerns)
       ├── Capture POD photos (enqueue linkPodPhoto)
       ├── Add ad-hoc stops as needed
       └── Confirm invoices (all terminal)
       │
       ▼  Driver taps "Mark Arrived at Base"
For Clearance          (driver enqueues arrival actions)
       │
       ├── 1. Validate: all stops terminal + invoices confirmed + quest complete
       ├── 2. PATCH post_dispatch_plan { status: "For Clearance", time_of_arrival, remarks_arrival }
       └── 3. Stop GPS tracking
       │
       ▼  Dispatcher reviews, posts
Posted / Cancelled     (dispatcher-only actions)
```

### 18.2 Departure Flow (detailed)

```
1. Driver taps "Confirm Departure" on DispatchPlansScreen
2. GPS check: if GPS off, show dialog to enable
3. Report dialog: optional remarks text field
4. On confirm:
   a. TripProvider.confirmDeparture() called
   b. Enqueue confirmDeparture action (PATCH plan → "For Inbound")
   c. Enqueue updateInvoicesDeparture action (bulk PATCH sales_invoice)
   d. Enqueue updateOrdersDeparture action (bulk PATCH sales_order)
   e. Create PhotoQuest from invoice stops
   f. Save timeOfDispatch locally
   g. GpsProvider.startTracking()
   h. Navigate to QuestScreen
```

### 18.3 Arrival Flow (detailed)

```
1. Driver taps "Mark Arrived at Base" on DispatchPlansScreen
2. Validation:
   a. Are all invoice/purchase/other stops terminal? (status != null)
   b. Are invoices confirmed? (_invoicesConfirmed == true)
   c. Is PhotoQuest complete? (all items have photoCaptured)
3. If validation fails → show error dialog with details
4. If validation passes → show confirm dialog with optional remarks
5. On confirm:
   a. TripProvider.markArrivedAtBase() called
   b. Enqueue markArrived action (PATCH plan → "For Clearance")
   c. GpsProvider.stopTracking()
   d. Show success snackbar
```

### 18.4 Stop Status Update Flow

```
1. Driver taps status button on InvoiceDetailScreen
2. TripProvider.updateStopStatus(stop, status, photoPaths) called
3. If POD photos exist → enqueue linkPodPhoto actions
4. Enqueue updateStopStatus action (PATCH post_dispatch_invoices/{id} → { status, invoiceAt, remarks })
5. Optimistic update: local stop status changed immediately
6. Check: if all stops terminal → enable "Confirm Invoices" bar
```

### 18.5 Photo Quest Flow

```
1. On departure → PhotoQuest created from invoice stops (one item per stop)
2. QuestScreen opens in list mode → shows "X of Y photos captured"
3. Tap any item → opens camera (image_picker)
4. Capture → preview → accept or retake
5. On accept → save to persistent directory → mark quest item as captured
6. All items captured → "Complete Quest" button appears
7. On complete → navigate to InvoicesScreen
```

---

## 19. Error Handling

### 19.1 Exception Hierarchy

```dart
sealed class AppException implements Exception {
  final String message;
  final String? technicalDetails;
}

class NetworkException extends AppException { /* retryable */ }
class ServerException extends AppException { /* retryable, statusCode */ }
class ClientException extends AppException { /* NOT retryable, statusCode, body */ }
class AuthException extends AppException { /* force re-login */ }
class ValidationException extends AppException { /* fieldErrors */ }
```

### 19.2 Error Handling Patterns

| Layer | Strategy |
|---|---|
| Services | Most methods catch exceptions and `debugPrint()`. No user-facing error except in critical paths. |
| Providers | Error state exposed via `_error` field (e.g., `AuthProvider._error`). |
| Screens | Show error in dialogs or inline containers. LoginScreen has error display. SOS form validates required fields. |
| Action Queue | Retryable errors → exponential backoff (1/2/4/8/16/30s). Permanent errors → marked `failed` with `last_error`. |
| GPS | Both foreground and background GPS catch exceptions silently. |
| Auth interceptor | On 401: deletes token, emits `onUnauthorized`. No auto-redirect. |

### 19.3 Edge Cases

| Scenario | Handling |
|---|---|
| Network failure during fetch | `TripProvider._tripCache` fallback — cached data shown |
| GPS permission denied | `GpsProvider` shows permission dialog; tracking refused if denied |
| Null stop status payload | `ActionQueueService._execute` rejects as permanent failure |
| Duplicate photo link | `ActionQueueService` checks existing `file` + parent id before POST |
| Captive portal / flapping signal | `connectivity_plus` may report connected; action queue handles actual HTTP failure |
| JWT expired mid-session | `jwt_decoder` check before API call; fallback to `/auth/me` if available |
| App killed mid-upload | Next startup: if `status == 'inFlight'` (legacy) or pending actions exist → retry |
| Timezone unavailable | `TimezoneService` fallback chain: server → Drift cache → `Asia/Manila` |

---

## 20. Configuration Reference

**File**: `lib/config/app_config.dart`

```dart
class AppConfig {
  // Backend URLs
  static const String baseUrl = 'http://100.105.235.94:8082';         // Spring Boot
  static const String directusUrl = 'http://100.110.197.61:8056';     // Directus CMS
  static const String directusStaticToken = 'AAKv73dkIV8DfAIA5vEt3eXVdIebzmBW';

  // GPS
  static const int gpsIntervalSeconds = 60;
  static const int gpsBatchSize = 5;           // Points before flush
  static const int gpsCoalesceBatch = 50;      // Max points per HTTP batch

  // Queue
  static const int queueProcessIntervalSeconds = 10;
  static const int maxRetries = 5;

  // Map
  static const String mapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  // Theme
  static const Color lightSeed = Color(0xFF1D4ED8);
  static const Color darkSeed = Color(0xFF3B6EF0);
}
```

### Backend endpoints summary

| Endpoint | Method | Auth | Used By |
|---|---|---|---|
| `POST /auth/login` | Spring Boot | None | AuthService |
| `GET /auth/me` | Spring Boot | JWT | AuthService (fallback) |
| `POST /api/dispatch/mobile/register-device` | Spring Boot | JWT | NotificationService |
| `GET /items/post_dispatch_plan` | Directus | Static token | TripProvider |
| `GET /items/post_dispatch_plan_staff` | Directus | Static token | TripProvider |
| `GET /items/post_dispatch_budgeting` | Directus | Static token | TripProvider |
| `GET /items/post_dispatch_invoices` | Directus | Static token | TripProvider |
| `GET /items/post_dispatch_purchases` | Directus | Static token | TripProvider |
| `GET /items/post_dispatch_plan_others` | Directus | Static token | TripProvider |
| `GET /items/customer` | Directus | Static token | TripProvider |
| `GET /items/user` | Directus | Static token | AuthService |
| `GET /items/general_setting` | Directus | Static token | TimezoneService |
| `PATCH /items/post_dispatch_plan/{id}` | Directus | Static token | ActionQueueService |
| `PATCH /items/sales_invoice` | Directus | Static token | ActionQueueService |
| `PATCH /items/sales_order` | Directus | Static token | ActionQueueService |
| `PATCH /items/post_dispatch_invoices/{id}` | Directus | Static token | ActionQueueService |
| `POST /items/post_dispatch_gps_logs` | Directus | Static token | ActionQueueService |
| `POST /items/post_dispatch_nte` | Directus | Static token | ActionQueueService |
| `POST /items/post_dispatch_trip_photos` | Directus | Static token | ActionQueueService |
| `POST /items/post_dispatch_plan_others` | Directus | Static token | ActionQueueService |
| `POST /items/fleet_emergency_reports` | Directus | Static token | ActionQueueService |
| `POST /files` | Directus | Static token | UploadService |

### Trip statuses

| Status | Who Sets | Meaning |
|---|---|---|
| `For Approval` | Dispatcher | Awaiting approval |
| `For Dispatch` | Dispatcher | Assigned, awaiting driver departure |
| `For Inbound` | Driver | En route (after departure confirmation) |
| `For Clearance` | Driver | Arrived at base (after arrival confirmation) |
| `Posted` | Dispatcher | Trip completed and posted |
| `Cancelled` | Dispatcher | Trip cancelled |

### Stop statuses

| Status | Meaning |
|---|---|
| `Fulfilled` | Delivered successfully |
| `Not Fulfilled` | Could not deliver |
| `Fulfilled with Returns` | Delivered with returned items |
| `Fulfilled with Concerns` | Delivered with concerns noted |

---

## 21. Development & Build Commands

### Verification

```bash
# Get dependencies
flutter pub get

# Analyze
flutter analyze

# Format
dart format lib/

# After editing Drift tables / app_database:
dart run build_runner build --delete-conflicting-outputs
```

### Build

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle
flutter build appbundle --release
```

### Run

```bash
# Default device
flutter run

# Specific device
flutter run -d <device-id>
```

### Key Restrictions

| Action | Rule |
|---|---|
| Schema changes | Do NOT create, alter, or add columns/tables to Directus collections unless explicitly instructed. |
| Code generation | After editing Drift files, run `build_runner` to regenerate `.g.dart` files. |
| Lint | Flutter lints ^6.0.0 (default ruleset). `flutter analyze` must pass before PR. |
| File encoding | All `.dart` files must be UTF-8 without BOM to avoid parser errors. |
