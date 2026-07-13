# VOSRoute — Priority-0 Bug Fix Summary (Post-M4)

## Root Cause
Three interrelated bugs caused the "For Inbound" → "For Dispatch" status reversion after offline trip cycle:

| Bug | Severity | Evidence |
|-----|----------|----------|
| **B1 — GPS batches processed before urgent actions** | P0 | `processQueue()` ordered: GPS → P1 → P2 → P3. Urgent `confirm_departure` waited behind entire GPS backlog. |
| **B1 — DAO raw SQL referenced wrong table** | P0 | `outbox_dao.dart` used `outbox` but Drift table is `outbox_actions` → `no such table: outbox` SQLite exception. |
| **B3 — Reconciliation blindly overwrote local status** | P0 | `fetchActiveTrip()` on reconnect/refresh fetched server status ("For Dispatch") and overwrote local optimistic state ("For Inbound") without checking for pending outbox actions. |

---

## Fixes Applied

### 1. Priority Ordering Fixed (`action_queue_service.dart:59-73`)
```dart
// BEFORE (buggy):
await _processGpsBatches();
await _processPending(priority: 1);
await _processPending(priority: 2);
await _processPending(priority: 3);

// AFTER (fixed):
await _processPending(priority: 1);  // urgent first
await _processPending(priority: 2);  // normal
await _processPending(priority: 3);  // low
await _processGpsBatches();          // GPS last
```

### 2. Table Name Fixed (`outbox_dao.dart:11-25`)
```sql
-- BEFORE: "SELECT COUNT(*) FROM outbox WHERE status = 'pending'"
-- AFTER:  "SELECT COUNT(*) FROM outbox_actions WHERE status = 'pending'"
```
Both `getPendingCount()` and `getFailedCount()` corrected.

### 3. Reconciliation Guard Added
**New DAO method** (`outbox_dao.dart:156-163`):
```dart
Future<bool> hasPendingStatusActionForPlan(int planId) async {
  final planIdStr = planId.toString();
  final rows = await (customSelect(
    "SELECT COUNT(*) as cnt FROM outbox_actions "
    "WHERE status IN ('pending', 'in_flight') "
    "AND (action = 'confirm_departure' OR action = 'mark_arrived') "
    "AND args_json LIKE ?",
    readsFrom: {outboxActions},
    variables: [Variable.withString('%$planIdStr%')],
  ).get());
  return (rows.first.data['cnt'] as int? ?? 0) > 0;
}
```

**Exposed via** `ActionQueueService.hasPendingStatusActionForPlan()` → `TripProvider.fetchActiveTrip()`:

```dart
final hasPendingStatusAction = await _queue.hasPendingStatusActionForPlan(planId);
// ... fetch server trip ...
if (hasPendingStatusAction) {
  // Preserve local optimistic status while action unsynced
  _activeTrip = PostDispatchPlan(
    // ... server fields ...
    status: _activeTrip!.status,      // local "For Inbound"
    timeOfDispatch: _activeTrip!.timeOfDispatch,
    remarks: _activeTrip!.remarks,
  );
} else {
  _activeTrip = serverTrip;  // safe to use server value
}
```

---

## Verification Gates (Device Test Required)

Run offline cycle: **connectivity off → confirm departure → reconnect**

| Check | Query / Observation | Expected |
|-------|---------------------|----------|
| **1. Table resolves** | `SELECT * FROM outbox_actions LIMIT 1` | No `no such table: outbox` error |
| **2. Priority order** | `SELECT id, action, priority, status, last_attempt FROM outbox_actions ORDER BY last_attempt` | `confirm_departure` completes **before** any `gps_batch` leaves `pending` |
| **3. Status preserved** | UI after reconnect | Shows "For Inbound" (not reverted to "For Dispatch") |
| **4. Full drain** | Same query after worker idle | All rows `status = 'completed'` |

---

## Build Verification
- `flutter analyze`: **0 errors**, 19 pre-existing info lints
- `flutter build apk --debug`: ✅ (65.7s)
- `dart run build_runner build`: ✅ (Drift codegen)

---

## Next: M5 (Provider Split)
Blocked until device test passes all 4 checks above with pasted evidence.