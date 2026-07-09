# VOSRoute — ApiService / Network Layer Implementation Plan

Companion to `VOSRoute_Offline_First_Final_Implementation_Plan.md`. This plan covers the client-side network layer only — timeouts, retry policy, auth refresh, exception typing, worker concurrency, cancellation, and request construction. It does not change Directus/Spring Boot endpoints.

**Dependency direction**: the offline-first plan's Phase 4 (`outbox_worker.dart`) and Phase 3 (repositories) both sit on top of `ApiService`. This plan should land **before or alongside** Phase 4, since the worker's branching logic (§Phase 4, steps 5–8) is written to consume the typed exceptions defined here.

---

## Phase A — Dio Instance Split & Timeouts

> No behavior change to existing call sites in this phase beyond timeout values — this is foundation for everything after.

#### [MODIFY] `lib/services/api_service.dart`

Replace the single shared `Dio` instance with two configured instances:

| Instance | Used by | connectTimeout | receiveTimeout | Cancellable |
|---|---|---|---|---|
| `readDio` | `TripRepository` and all `cached_*`-populating fetches | 10s | 15s | Yes — `CancelToken` tied to screen lifecycle |
| `writeDio` | Outbox worker only (business actions, SOS, ad-hoc stops) | 15s | 30s | No — never cancelled once dispatched |
| `uploadDio` | File uploads (POD photos, trip photos) specifically | 15s | 60s (sized to compressed photo upload) | No |

Rationale: reads should fail fast so the UI doesn't hang; writes are already covered by the outbox worker's own retry/backoff, so a write's HTTP timeout should be generous enough that "the request was still in flight and would have succeeded" isn't misclassified as `failed_retryable`.

#### [NEW] `lib/network/dio_factory.dart`

Constructs the three instances above with shared base config (base URL, default headers), keeping instantiation out of `ApiService` itself.

---

## Phase B — Typed Exception Hierarchy

#### [NEW] `lib/network/app_exception.dart`

```dart
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);
}

class NetworkException extends AppException {}      // no connectivity / timeout — retryable
class ServerException extends AppException {         // 5xx — retryable
  final int statusCode;
}
class ClientException extends AppException {         // 4xx non-auth — NOT retryable
  final int statusCode;
  final Map<String, dynamic>? body;
}
class AuthException extends AppException {}           // 401 after refresh also failed — force re-login
class ValidationException extends AppException {      // 422/400 with field errors
  final Map<String, dynamic> fieldErrors;
}
```

#### [NEW] `lib/network/exception_interceptor.dart`

A Dio interceptor (attached to all three instances) that catches raw `DioException`/`DioError` and rethrows as the typed hierarchy above, so no call site — repository, worker, or screen — ever branches on a raw status code or `DioExceptionType` directly.

**Consumer impact**: `outbox_worker.dart`'s branching (Phase 4 of the offline-first plan, steps 5–8) is rewritten as a `catch` per exception type rather than an `if (response.statusCode >= 500)` chain:

```dart
try {
  await dispatch(action);
  await outboxDao.markSynced(id);
} on ServerException catch (e) {
  await outboxDao.markRetryable(id, e.message, backoff(attemptCount));
} on ClientException catch (e) {
  await outboxDao.markPermanentFailure(id, e.message);
} on AuthException {
  await authService.forceReAuth();
} on NetworkException catch (e) {
  await outboxDao.markRetryable(id, e.message, backoff(attemptCount));
}
```

---

## Phase C — Single-Flight Auth Refresh

> Highest-priority fix in this plan — closes a likely source of intermittent forced-logout-mid-sync bugs.

#### [NEW] `lib/network/auth_refresh_interceptor.dart`

- Attached to `writeDio` and `readDio` (not `uploadDio` directly — upload requests share the same token state via `AuthService`, refreshed through the same lock).
- On a 401: checks a shared `Completer<String>? _refreshInFlight` on `AuthService`.
  - If null → sets it, calls the Spring Boot refresh endpoint, stores the new token via `flutter_secure_storage`, completes the `Completer`, clears it.
  - If non-null → awaits the existing `Completer` instead of firing a second refresh call.
- All requests that hit 401 during the refresh window retry once, automatically, with the refreshed token — no caller-visible difference.
- If refresh itself fails (refresh token expired/invalid) → surfaces as `AuthException`, which propagates to a global "please log in again" flow, not to the outbox worker's retry logic (an expired session is not something backoff can fix).

#### [MODIFY] `lib/services/auth_service.dart`

Add the `_refreshInFlight` lock and `refreshToken()` method used by the interceptor above. (JWT storage migration to `flutter_secure_storage` is already covered in the offline-first plan's Phase 5 — this phase assumes that's done or lands together with it.)

---

## Phase D — Worker Concurrency Pool

#### [MODIFY] `lib/sync/outbox_worker.dart` (from the offline-first plan)

Replace a strictly sequential drain with a bounded concurrency pool:

- Pool size: 3 in-flight requests at a time.
- Rows are still pulled in the established order (`priority ASC, depends_on-unsynced last, created_at ASC`), but up to 3 eligible rows (those whose `depends_on` is already satisfied) can be dispatched concurrently.
- A row whose `depends_on` parent is still in the current batch (not yet `synced`) is held out of the pool until that parent completes — dependency ordering is preserved even under concurrency.
- Rationale: after hours offline, a 50+ row backlog dispatched all-at-once saturates the connection and makes the backoff/priority design meaningless in practice; fully sequential is safe but slow enough to matter for a driver waiting for Sync Log to clear.

#### [NEW] `lib/sync/concurrency_pool.dart`

Small reusable helper (e.g. wrapping `Future.wait` with a semaphore) — not tied specifically to the outbox, so it can be reused if a similar need shows up elsewhere.

---

## Phase E — Cancellation Discipline

#### [MODIFY] `lib/repositories/trip_repository.dart` and other read-path repositories

- Every fetch method accepts/creates a `CancelToken`, cancelled when the owning screen/provider is disposed (via `ChangeNotifier.dispose()` or the equivalent stream-subscription teardown from Pass 3 of the repository refactor).
- **Writes dispatched through `writeDio`/`uploadDio` never accept a `CancelToken`.** This is enforced structurally: those Dio instances' request wrapper methods in `ApiService` simply don't expose a `cancelToken` parameter, so it's not something a future contributor can accidentally wire up on a write path and reintroduce the duplicate-risk scenario cancellation would create there.

---

## Phase F — Centralized Request Construction

> This is where the outbox worker's "request-builder" (referenced in the offline-first plan's Phase 4, step 3) actually lives.

#### [MODIFY] `lib/services/api_service.dart`

Strip down to thin HTTP primitives only:
```dart
Future<T> get<T>(String path, {Map<String, dynamic>? query});
Future<T> post<T>(String path, {Object? body});
Future<T> patch<T>(String path, {Object? body});
Future<String> uploadFile(String path, File file); // returns remote file UUID
```
No endpoint-specific business methods remain here (e.g. no `updateStopStatus(...)` living inside `ApiService` itself).

#### [NEW] `lib/sync/request_builders/` — one file per `action`

- `update_stop_status_builder.dart`, `upload_pod_builder.dart`, `create_adhoc_stop_builder.dart`, `send_sos_builder.dart`, `gps_batch_builder.dart`, `trip_transition_builder.dart`
- Each exposes a single function: `(argsJson, schemaVersion) → (path, method, body)`, called by the outbox worker at dispatch time (not at enqueue time — consistent with the offline-first plan's snapshot semantics for `args_json`).
- This is what isolates the app from a Directus field rename or endpoint change: only the one builder for the affected action changes, `ApiService` and the worker's dispatch loop do not.

---

## Sequencing Against the Offline-First Plan

| This plan's phase | Must land relative to offline-first plan |
|---|---|
| A (Dio split/timeouts) | Before Phase 4 (worker needs `writeDio`/`uploadDio` to exist) |
| B (typed exceptions) | Before Phase 4 (worker's branching logic is written against these types) |
| C (single-flight auth) | Before Phase 4 (worker draining a backlog is exactly the concurrent-401 scenario this fixes) |
| D (concurrency pool) | Alongside Phase 4 (modifies the worker directly) |
| E (cancellation) | Alongside Phase 3 Pass 1/3 (repositories) |
| F (request builders) | Alongside Phase 4 (worker dispatch step 3 depends on these existing) |

Net effect: Phases A–C and F should be built as prerequisites feeding directly into the offline-first plan's Phase 4, rather than after it — Phase 4 as originally scoped assumed this layer already existed underneath it.

---

## Verification Plan

### Automated Tests
- `test/dio_timeout_config_test.dart` — assert each Dio instance carries its specified timeout values
- `test/exception_mapping_test.dart` — feed each raw Dio error/status shape through the interceptor, assert correct typed `AppException` subtype
- `test/auth_single_flight_test.dart` — fire 5 concurrent requests that all 401 simultaneously; assert exactly one refresh call is made and all 5 retry successfully with the new token
- `test/worker_concurrency_test.dart` — seed a backlog with mixed `depends_on` chains; assert no more than 3 concurrent dispatches at any point, and that a dependent row never starts before its parent reaches `synced`
- `test/cancellation_test.dart` — dispose a provider mid-fetch, assert the read is cancelled and no stale state is written to a disposed provider; assert an equivalent "cancel" is structurally impossible to call on `writeDio`/`uploadDio`
- `test/request_builder_test.dart` — one test per builder: given `args_json` + `schema_version`, assert the exact `(path, method, body)` produced

### Manual QA Sequence
1. Force a 5xx from a test endpoint mid-sync → confirm the row lands `failed_retryable` with correct backoff, not `failed_permanent`
2. Force a 422 with field errors on a POD upload → confirm `ValidationException` surfaces a driver-visible message rather than silently retrying forever
3. Expire the access token, then trigger a reconnect with a 10+ row backlog → confirm exactly one refresh call in logs (via Sync Log or backend request logs) and no dropped rows
4. Queue 20+ mixed business/GPS rows offline, reconnect on a throttled connection → confirm the pool caps concurrency and priority ordering still holds
5. Navigate away from the trip screen mid-fetch → confirm the read is cancelled cleanly with no error surfaced to the user
