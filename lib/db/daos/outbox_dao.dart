import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [OutboxActions])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  Future<int> getPendingCount() async {
    final result = await (customSelect(
      "SELECT COUNT(*) as cnt FROM outbox_actions WHERE status = 'pending'",
      readsFrom: {outboxActions},
    ).getSingle());
    return result.data['cnt'] as int? ?? 0;
  }

  Future<int> getFailedCount() async {
    final result = await (customSelect(
      "SELECT COUNT(*) as cnt FROM outbox_actions WHERE status = 'failed'",
      readsFrom: {outboxActions},
    ).getSingle());
    return result.data['cnt'] as int? ?? 0;
  }

  Future<List<OutboxAction>> getPendingByPriority(
    int priority, {
    int limit = 20,
  }) async {
    return (select(outboxActions)
          ..where(
            (t) => t.status.equals('pending') & t.priority.equals(priority),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<List<OutboxAction>> getPendingGps({int limit = 50}) async {
    return (select(outboxActions)
          ..where(
            (t) => t.status.equals('pending') & t.action.equals('gps_batch'),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<List<OutboxAction>> getPendingNonGpsByPriority(
    int priority, {
    int limit = 20,
  }) async {
    return (select(outboxActions)
          ..where(
            (t) =>
                t.status.equals('pending') &
                t.priority.equals(priority) &
                t.action.equals('gps_batch').not(),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> insertAction(OutboxActionsCompanion entry) async {
    await into(outboxActions).insert(entry);
  }

  Future<void> insertActions(List<OutboxActionsCompanion> entries) async {
    await batch((b) {
      for (final entry in entries) {
        b.insert(outboxActions, entry);
      }
    });
  }

  Future<void> updateStatus(
    int id, {
    required String status,
    DateTime? lastAttempt,
    String? lastError,
    int? retryCount,
  }) async {
    await (update(outboxActions)..where((t) => t.id.equals(id))).write(
      OutboxActionsCompanion(
        status: Value(status),
        lastAttempt: Value(lastAttempt ?? DateTime.now().toUtc()),
        retryCount: retryCount != null
            ? Value(retryCount)
            : const Value.absent(),
        lastError: lastError != null ? Value(lastError) : const Value.absent(),
      ),
    );
  }

  Future<void> markCompleted(int id) async {
    await updateStatus(id, status: 'completed');
  }

  Future<void> markFailed(int id, String error, int retryCount) async {
    await updateStatus(
      id,
      status: 'failed',
      lastError: error,
      retryCount: retryCount,
    );
  }

  Future<void> markRetry(int id, String error, int retryCount) async {
    await updateStatus(
      id,
      status: 'pending',
      lastError: error,
      retryCount: retryCount,
    );
  }

  Future<List<OutboxAction>> getPendingOrFailed({int limit = 100}) async {
    return (select(outboxActions)
          ..where((t) => t.status.isIn(['pending', 'failed']))
          ..orderBy([
            (t) => OrderingTerm(expression: t.priority),
            (t) => OrderingTerm(expression: t.createdAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> retryAllFailed() async {
    await (update(
      outboxActions,
    )..where((t) => t.status.equals('failed'))).write(
      const OutboxActionsCompanion(
        status: Value('pending'),
        retryCount: Value(0),
        lastError: Value(null),
      ),
    );
  }

  Future<void> retryAction(int id) async {
    await (update(outboxActions)..where((t) => t.id.equals(id))).write(
      const OutboxActionsCompanion(
        status: Value('pending'),
        retryCount: Value(0),
        lastError: Value(null),
      ),
    );
  }

  Future<void> clearCompleted() async {
    await (delete(
      outboxActions,
    )..where((t) => t.status.equals('completed'))).go();
  }

  Future<void> clearFailed() async {
    await (delete(outboxActions)..where((t) => t.status.equals('failed'))).go();
  }

  Future<void> clearAll() async {
    await delete(outboxActions).go();
  }

  Future<OutboxAction?> selectOutboxActionById(int id) async {
    return (select(
      outboxActions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Checks if there's any pending/in-flight outbox action that would modify
  /// the status field of the given entity. Used by reconciliation to avoid
  /// overwriting optimistic local updates with stale server values.
  Future<bool> hasPendingStatusActionForEntity({
    required String
    entityType, // 'trip', 'invoice_stop', 'purchase_stop', 'other_stop'
    required int entityId,
  }) async {
    String actionCondition;
    String jsonField;

    switch (entityType) {
      case 'trip':
        actionCondition = "action IN ('confirm_departure', 'mark_arrived')";
        jsonField = 'plan_id';
        break;
      case 'invoice_stop':
        actionCondition = "action = 'update_stop_status'";
        jsonField = 'invoice_id';
        break;
      case 'purchase_stop':
        actionCondition = "action = 'update_stop_status'";
        jsonField = 'purchase_id';
        break;
      case 'other_stop':
        actionCondition = "action = 'update_stop_status'";
        jsonField = 'other_stop_id';
        break;
      default:
        return false;
    }

    final entityIdStr = entityId.toString();
    // Use JSON_EXTRACT for precise matching instead of LIKE on raw JSON
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
}
