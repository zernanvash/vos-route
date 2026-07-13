# VOSRoute — M0 through M4 Architecture Reconciliation Summary

## Overview
Executed Phases 1–3 of the VOSRoute Architecture Reconciliation Plan (`docs/VOSRoute_Architecture_Reconciliation_Plan.md`). Push notifications remain on Spring Boot — out of scope until a separate backend plan.

---

## M0 — Crash Fixes (pre-M1, verified on `main`)

| Fix | Files |
|-----|-------|
| GPS `trip_id` null — capture before async gap; guard with `if (_activeTripId != tripId) return` | `gps_service.dart`, `background_service.dart` |
| Performance chart cache — `notifyListeners()` after `_cacheInvoiceStatusesForPlans`; proactive cache in `fetchPendingPlans` | `trip_provider.dart` |
| `_onStart` / `captureAndQueueGps` extracted to top-level scope | `background_service.dart` |
| Foreground service type: `AndroidForegroundType.location` + `foregroundServiceType="location"` + `tools:replace` in manifest | `background_service.dart`, `AndroidManifest.xml` |

---

## M1 — Outbox + SQLCipher

| Change | Files |
|--------|-------|
| Drift `OutboxActions` table (id, action, priority, depends_on, args_json, schema_version, status, retry_count, max_retries, created_at, last_attempt, last_error) | `db/tables/outbox_table.dart` |
| Drift `OutboxDao` with full CRUD | `db/daos/outbox_dao.dart` |
| `AppDatabase` schema v2; v1→v2 migration seeds pending `action_queue` rows from old sqflite DB | `db/app_database.dart` |
| SQLCipher via `PRAGMA key` in `NativeDatabase` setup callback; 256-bit hex passphrase from `SecureStorageService.getDatabasePassphrase()` | `db/app_database.dart`, `secure_storage_service.dart` |
| `pubspec.yaml`: `sqlite3_flutter_libs` → `sqlcipher_flutter_libs: ^0.6.8` | `pubspec.yaml` |
| `ActionQueueService` rewired to `OutboxDao` (Drift); endpoint/method derived from action type | `action_queue_service.dart` |
| Old sqflite `AppDatabase` (`lib/db/database.dart`) now dead code | — |

---

## M2 — Network Layer

| Change | Files |
|--------|-------|
| `ExceptionInterceptor` — maps `DioException` → typed `AppException`; attached to both Dio instances | `network/exception_interceptor.dart` |
| `AuthRefreshInterceptor` — single-flight 401 handler: locks behind `Completer<String>`, re-logins via stored credentials, retries original request, emits `onUnauthorized` on failure | `network/auth_refresh_interceptor.dart` |
| `SecureStorageService` — added `writePasswordHash`/`readPasswordHash`/`writeLoginEmail`/`readLoginEmail`/`delete*` for silent re-auth | `secure_storage_service.dart` |
| `AuthService` — stores `passwordHash` + `email` after `login()`; exposes `refreshInFlight` | `auth_service.dart` |
| `ApiService` — `AuthRefreshInterceptor` + `ExceptionInterceptor` on `_dio`; `ExceptionInterceptor` on `_directusDio`; inline 401 handler removed | `api_service.dart` |
| 5 request builders created: `GpsBatchBuilder`, `TripTransitionBuilder`, `UploadPodBuilder`, `CreateAdhocStopBuilder`, `SendSosBuilder` | `sync/request_builders/*.dart` |

---

## M3 — TripRepository Pass-Through (Phase 3, Pass-1)

| Provider method | Repository calls |
|-----------------|------------------|
| `selectPlan()` | `fetchPlanStaff`, `fetchPlanBudget`, `fetchPlanInvoices`, `fetchPlanPurchases`, `fetchPlanOtherStops`, `fetchCustomers` |
| `fetchActiveTrip()` | `fetchPlanList`, `fetchPlanStaff`, `fetchPlanBudget`, `fetchPlanInvoices`, `fetchPlanPurchases`, `fetchPlanOtherStops`, `fetchCustomers` |
| `fetchPendingPlans()` | `fetchPlanList`, `fetchInvoiceStatusesForPlans` |
| `fetchPreviousDispatchPlans()` | `fetchPlanList`, `fetchBudgetForPlans`, `fetchInvoiceStatusesForPlans` |
| `fetchCachedHistory()` | `fetchPlanList` |
| `_cacheInvoiceStatusesForPlans()` | `fetchInvoiceStatusesForPlans` |

**New repository method:** `fetchInvoiceStatusesForPlans(List<int> planIds)` — batched invoice status fetch for home performance chart caching.

---

## M4 — Outbox Worker (Request Builder Integration)

| Before | After |
|--------|-------|
| Hardcoded `_endpointForAction` / `_httpMethodForAction` | 6 request builders: `TripTransitionBuilder`, `GpsBatchBuilder`, `SendSosBuilder`, `CreateAdhocStopBuilder`, `UploadPodBuilder`, `UpdateStopStatusBuilder` |
| Single `processQueue` loop | Priority-aware: GPS batches (low) → priority 1 (urgent) → priority 2 (normal) → priority 3 (low) |
| Manual file upload inline | Delegated to `_uploadLocalFileIfNeeded` before request build |
| Duplicate POD/trip-photo check inline | Extracted to `_checkAlreadyLinked` |

**New OutboxDao method:** `getById(int id)` — for GPS batch retry logic.

---

## Verification (all phases)

- `flutter analyze`: **0 errors**, 19 pre-existing info lints only
- `dart format lib/`: clean
- `dart run build_runner build --delete-conflicting-outputs`: Drift codegen OK

---

## Next Steps

- **M5** — Device test (`flutter build apk`) and integration smoke test
- **M6** — Push notification wiring (Spring Boot FCM token registration) per separate backend plan