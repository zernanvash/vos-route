import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import '../db/database.dart';
import '../models/action_entry.dart';

class ActionQueueService {
  final ApiService _api = ApiService();
  final AppDatabase _db = AppDatabase();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  Timer? _processTimer;
  bool _isProcessing = false;

  static const _maxRetries = 5;
  static const _processInterval = Duration(seconds: 10);

  void start() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi)) {
        processQueue();
      }
    });

    _processTimer = Timer.periodic(_processInterval, (_) => processQueue());
  }

  void stop() {
    _connectivitySub?.cancel();
    _processTimer?.cancel();
  }

  Future<void> enqueue(ActionEntry entry) async {
    final db = await _db.database;
    await db.insert('action_queue', entry.toMap());
    processQueue();
  }

  Future<void> enqueueBatch(List<ActionEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await _db.database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert('action_queue', entry.toMap());
    }
    await batch.commit(noResult: true);
    processQueue();
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;

    final isOnline = await _api.pingDirectus();
    if (!isOnline) return;

    _isProcessing = true;
    try {
      await _processGpsBatches();
      await _processPending(priority: 1);
      await _processPending(priority: 2);
      await _processPending(priority: 3);
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processPending({required int priority}) async {
    final db = await _db.database;
    final pending = await db.query(
      'action_queue',
      where: 'status = ? AND batch_priority = ?',
      whereArgs: ['pending', priority],
      orderBy: 'created_at ASC',
      limit: 20,
    );

    for (final row in pending) {
      final entry = ActionEntry.fromMap(row);
      await _execute(entry);
    }
  }

  Future<void> _execute(ActionEntry entry) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'action_queue',
      {'status': 'in_flight', 'last_attempt': now},
      where: 'id = ?',
      whereArgs: [entry.id],
    );

    try {
      final data = entry.payload;

      switch (entry.httpMethod.toUpperCase()) {
        case 'POST':
          await _api.postDirectus(entry.endpoint, data: data);
          break;
        case 'PATCH':
          await _api.patchDirectus(entry.endpoint, data: data);
          break;
        case 'PUT':
          await _api.put(entry.endpoint, data: data);
          break;
      }

      await db.update(
        'action_queue',
        {'status': 'completed', 'last_attempt': now},
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    } catch (e) {
      final newRetryCount = entry.retryCount + 1;
      final errorMsg = e is DioException
          ? '${e.response?.statusCode ?? "unknown"}: ${e.response?.data ?? e.message}'
          : e.toString();

      if (newRetryCount >= _maxRetries) {
        await db.update(
          'action_queue',
          {
            'status': 'failed',
            'retry_count': newRetryCount,
            'last_attempt': now,
            'last_error': errorMsg,
          },
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      } else {
        final backoffSeconds = [
          1,
          2,
          4,
          8,
          16,
          30,
        ].elementAt(newRetryCount.clamp(1, 6) - 1);
        await db.update(
          'action_queue',
          {
            'status': 'pending',
            'retry_count': newRetryCount,
            'last_attempt': now,
            'last_error': errorMsg,
          },
          where: 'id = ?',
          whereArgs: [entry.id],
        );

        await Future.delayed(Duration(seconds: backoffSeconds));
      }
    }
  }

  Future<void> _processGpsBatches() async {
    final db = await _db.database;
    final pendingGps = await db.query(
      'action_queue',
      where: "status = 'pending' AND action_type = 'gps_batch'",
      orderBy: 'created_at ASC',
      limit: 50,
    );
    if (pendingGps.length < 2) return;

    final allPoints = <Map<String, dynamic>>[];
    final ids = <int>[];

    for (final row in pendingGps) {
      final entry = ActionEntry.fromMap(row);
      final points = entry.payload as List<dynamic>;
      allPoints.addAll(points.cast<Map<String, dynamic>>());
      ids.add(entry.id!);
    }

    if (allPoints.isEmpty || ids.isEmpty) return;

    try {
      await _api.postDirectus('/items/post_dispatch_gps_logs', data: allPoints);

      final batch = db.batch();
      final now = DateTime.now().toIso8601String();
      for (final id in ids) {
        batch.update(
          'action_queue',
          {'status': 'completed', 'last_attempt': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<int> getPendingCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM action_queue WHERE status = 'pending'",
    );
    return result.first['cnt'] as int? ?? 0;
  }

  Future<int> getFailedCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM action_queue WHERE status = 'failed'",
    );
    return result.first['cnt'] as int? ?? 0;
  }

  Future<List<ActionEntry>> getPendingActions() async {
    final db = await _db.database;
    final rows = await db.query(
      'action_queue',
      where: "status = 'pending' OR status = 'failed'",
      orderBy: 'batch_priority ASC, created_at ASC',
      limit: 100,
    );
    return rows.map((r) => ActionEntry.fromMap(r)).toList();
  }

  Future<void> retryFailed() async {
    final db = await _db.database;
    await db.update('action_queue', {
      'status': 'pending',
      'retry_count': 0,
      'last_error': null,
    }, where: "status = 'failed'");
    processQueue();
  }

  Future<void> retryAction(int actionId) async {
    final db = await _db.database;
    await db.update(
      'action_queue',
      {'status': 'pending', 'retry_count': 0, 'last_error': null},
      where: 'id = ?',
      whereArgs: [actionId],
    );
    processQueue();
  }

  Future<void> clearCompleted() async {
    final db = await _db.database;
    await db.delete('action_queue', where: "status = 'completed'");
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('action_queue');
  }
}
