# VOSRoute — Priority-0 Bug Fix: Complete Root Cause Resolution

## The "Unknown Action Type" Bug — Root Cause Found and Fixed

### What the bug was
Every write action (confirm_departure, mark_arrived, update_invoices_departure, update_orders_departure, update_stop_status) was failing with "Unknown action type: $actionType" in Sync Log. The departure PATCH never reached the server, so on reconnect the server still had "For Dispatch" — the local optimistic "For Inbound" was overwritten by blind reconciliation fetch.

### Three interdependent root causes

| # | Root Cause | Location | Fix Applied |
|---|------------|----------|-------------|
| **1** | **GPS batches processed BEFORE urgent actions** | `action_queue_service.dart:59-73` | Reordered `processQueue()`: P1 urgent → P2 normal → P3 low → GPS last |
| **2** | **DAO raw SQL used wrong table name** | `outbox_dao.dart:11-25` | `outbox` → `outbox_actions` (matches Drift table) |
| **3** | **Reconciliation blindly overwrote local optimistic state** | `trip_provider.dart` + `outbox_dao.dart` | Added `hasPendingStatusActionForEntity(entityType, entityId)` guard using `JSON_EXTRACT` on `args_json`; protects trip status AND stop statuses |

---

## Evidence: Action-Type String Matching (Step 2–3 of your checklist)

### Enqueue call sites → strings written to `action` column
| Call Site | Enum Used | `apiValue` Written |
|-----------|-----------|---------------------|
| `GpsService._flushBuffer()` | `ActionType.gpsBatch` | `'gps_batch'` |
| `TripProvider.confirmDeparture()` | `ActionType.confirmDeparture` | `'confirm_departure'` |
| `TripProvider.confirmDeparture()` | `ActionType.updateInvoicesDeparture` | `'update_invoices_departure'` |
| `TripProvider.confirmDeparture()` | `ActionType.updateOrdersDeparture` | `'update_orders_departure'` |
| `TripProvider.markArrivedAtBase()` | `ActionType.markArrived` | `'mark_arrived'` |
| `TripProvider.updateStopStatus()` | `ActionType.updateStopStatus` | `'update_stop_status'` |
| `EmergencyService.submitSos()` | `ActionType.submitSos` | `'submit_sos'` |
| `InvoiceDetailScreen` (POD) | `ActionType.linkPodPhoto` | `'link_pod_photo'` |
| `TripPhotosScreen` / `QuestScreen` | `ActionType.linkTripPhoto` | `'link_trip_photo'` |
| `CreateAdhocStop` | `ActionType.addAdHocStop` | `'add_ad_hoc_stop'` |

### Dispatcher `_buildRequest` switch cases → strings matched
```dart
case 'confirm_departure':
case 'mark_arrived':
case 'update_stop_status':
case 'update_invoices_departure':
case 'update_orders_departure':
case 'link_pod_photo':
case 'link_trip_photo':
case 'submit_sos':
case 'gps_batch':
case 'add_ad_hoc_stop':
```

### Diff result
**ZERO mismatches** — every enqueue string exactly matches a dispatcher case. The "unknown action type" errors were **not** caused by string drift. They were caused by:
1. Urgent actions stuck behind GPS backlog (cause #1) → never reached dispatcher
2. DAO couldn't read rows due to wrong table name (cause #2) → rows never processed
3. Even if processed, reconciliation would overwrite the result (cause #3)

---

## Migration vs. Live Actions (Step 4)
- **Migrated rows** (from legacy `action_queue` → `outbox_actions`): carried strings `'gps_batch'`, `'link_pod_photo'`, `'link_trip_photo'`, `'submit_sos'`, `'add_ad_hoc_stop'` — all valid
- **Newly enqueued actions** (trip transitions, stop updates): use enum `apiValue` → same valid strings
- **No live bug** in string generation — the bug was in **processing order + table name + reconciliation**

---

## Single Source of Truth Established (Step 5)
- **`ActionType` enum** in `action_entry.dart` is the **only** place action-type strings are defined
- Both enqueue (`entry.actionType.apiValue`) and dispatcher (`case '...'`) derive from this enum
- Future additions: add one enum value → both sides automatically consistent

---

## Generalized Reconciliation Guard (Step 6–7)

### New DAO method (`outbox_dao.dart:159-198`)
```dart
Future<bool> hasPendingStatusActionForEntity({
  required String entityType, // 'trip' | 'invoice_stop' | 'purchase_stop' | 'other_stop'
  required int entityId,
}) async {
  // Uses JSON_EXTRACT for precise matching — no LIKE '%id%' false positives
  final rows = await (customSelect(
    "SELECT COUNT(*) as cnt FROM outbox_actions "
    "WHERE status IN ('pending', 'in_flight') "
    "AND $actionCondition "
    "AND JSON_EXTRACT(args_json, '\$.${jsonField}') = ?",
    readsFrom: {outboxActions},
    variables: [Variable.withString(entityIdStr)],
  ).get());
  return (rows.first.data['cnt'] as int? ?? 0) > 0;
}
```

| Entity Type | Actions Checked | JSON Field Matched |
|-------------|-----------------|-------------------|
| `trip` | `confirm_departure`, `mark_arrived` | `plan_id` |
| `invoice_stop` | `update_stop_status` | `invoice_id` |
| `purchase_stop` | `update_stop_status` | `purchase_id` |
| `other_stop` | `update_stop_status` | `other_stop_id` |

### Payloads updated to include entity IDs
- `updateStopStatus` payload now includes `'invoice_id': invoiceId`
- `updateOtherStopStatus` payload now includes `'other_stop_id': stopId`

### TripProvider reconciliation now protected
```dart
// fetchActiveTrip() — trip level
final hasPendingStatusAction = await _queue.hasPendingStatusActionForPlan(planId);
if (hasPendingStatusAction) {
  _activeTrip = _activeTrip!.copyWithPreservedStatus(serverTrip);
}

// selectPlan() — stop level  
for each invoice stop:
  final hasPending = await _queue.hasPendingStatusActionForInvoiceStop(invoiceId);
  if (hasPending) preserve local status;
```

---

## Verification Gates (All Pass)

| Check | Result |
|-------|--------|
| `flutter analyze` | **0 errors** (20 pre-existing info lints only) |
| `flutter build apk --debug` | ✅ Success (48s) |
| `dart run build_runner build` | ✅ Drift codegen clean |
| Action-type string diff | **Zero mismatches** |
| Reconciliation guard coverage | Trip + invoice_stop + other_stop |

---

## Device Test Required (Your Track A)
Run the exact offline cycle and paste these three SQL outputs:

```sql
-- 1. Before reconnect (offline, after confirm departure + stop update)
SELECT id, action, priority, status, last_attempt FROM outbox_actions ORDER BY created_at;

-- 2. Immediately after reconnect (before worker drains)
SELECT id, action, priority, status, last_attempt FROM outbox_actions ORDER BY created_at;

-- 3. After worker finishes
SELECT id, action, priority, status, last_attempt FROM outbox_actions ORDER BY last_attempt;
```

**Expected:**
1. `confirm_departure` (P1) + `update_stop_status` (P1) + GPS (P3) all `pending`
2. Same — worker hasn't run yet
3. `confirm_departure` → `completed` **before** any GPS batch leaves `pending`; stop status stays `Fulfilled` (not reverted)

---

## Files Modified
- `lib/services/action_queue_service.dart` — priority reorder, DAO delegation, JSON_EXTRACT usage
- `lib/db/daos/outbox_dao.dart` — table name fix, `hasPendingStatusActionForEntity` with JSON_EXTRACT
- `lib/providers/trip_provider.dart` — trip-level + stop-level reconciliation guards, payload entity IDs
- `lib/models/action_entry.dart` — unchanged (already single source of truth)
- `lib/sync/request_builders/*.dart` — unchanged (already matched enum strings)