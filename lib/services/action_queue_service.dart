import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'upload_service.dart';
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
      dynamic payload;
      if (entry.payload is List) {
        payload = List<dynamic>.from(entry.payload as List);
      } else {
        payload = Map<String, dynamic>.from(entry.payload as Map);
      }

      // Sanity-check: a stop-status payload must carry a non-null status.
      // If null reaches here the call-site is broken; fail permanently so the
      // error surfaces in the sync log instead of silently reaching the server.
      if (payload is Map<String, dynamic> &&
          payload.containsKey('status') &&
          payload['status'] == null) {
        throw ArgumentError(
          'action_queue entry ${entry.id} (${entry.actionType}) has a null status field. '
          'This is a call-site bug — fix the payload builder, not this executor.',
        );
      }

      if (payload is Map<String, dynamic> && payload.containsKey('local_file_path')) {
        final localFilePath = payload['local_file_path'] as String;
        final uploadService = UploadService();
        String? folderUuid;
        if (entry.actionType == ActionType.linkPodPhoto) {
          folderUuid = 'd3940009-05ec-4fbd-ae2b-72f581013805';
        } else if (entry.actionType == ActionType.linkTripPhoto) {
          folderUuid = '13954431-1352-421b-8bcd-d41963b3d9bd';
        }
        final directusFileId = await uploadService.uploadFile(localFilePath, folderUuid: folderUuid);
        if (directusFileId == null) {
          throw Exception('Failed to upload local file: $localFilePath');
        }

        payload.remove('local_file_path');
        payload['file'] = directusFileId;

        await db.update(
          'action_queue',
          {'action_payload': jsonEncode(payload)},
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }

      bool alreadyLinked = false;
      if (payload is Map<String, dynamic> && payload['file'] != null) {
        if (entry.actionType == ActionType.linkPodPhoto) {
          final invoiceId = payload['post_dispatch_invoice_id'];
          final fileId = payload['file'];
          final res = await _api.getDirectus(
            '/items/post_dispatch_nte',
            queryParams: {
              'filter[post_dispatch_invoice_id][_eq]': invoiceId,
              'filter[file][_eq]': fileId,
            },
          );
          if ((res.data['data'] as List).isNotEmpty) {
            alreadyLinked = true;
          }
        } else if (entry.actionType == ActionType.linkTripPhoto) {
          final planId = payload['post_dispatch_plan_id'];
          final fileId = payload['file'];
          final res = await _api.getDirectus(
            '/items/post_dispatch_trip_photos',
            queryParams: {
              'filter[post_dispatch_plan_id][_eq]': planId,
              'filter[file][_eq]': fileId,
            },
          );
          if ((res.data['data'] as List).isNotEmpty) {
            alreadyLinked = true;
          }
        }
      }

      if (!alreadyLinked) {
        switch (entry.httpMethod.toUpperCase()) {
          case 'POST':
            await _api.postDirectus(entry.endpoint, data: payload);
            break;
          case 'PATCH':
            await _api.patchDirectus(entry.endpoint, data: payload);
            break;
          case 'PUT':
            await _api.put(entry.endpoint, data: payload);
            break;
        }
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

      bool isPermanent = false;
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500 && statusCode != 401) {
          isPermanent = true;
        }
      } else if (e is TypeError || e is FormatException || e is ArgumentError) {
        isPermanent = true;
      }

      if (isPermanent || newRetryCount >= _maxRetries) {
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
    if (pendingGps.isEmpty) return;

    final allPoints = <Map<String, dynamic>>[];
    final ids = <int>[];

    for (final row in pendingGps) {
      final entry = ActionEntry.fromMap(row);
      final points = entry.payload as List<dynamic>;
      allPoints.addAll(points.cast<Map<String, dynamic>>());
      ids.add(entry.id!);
    }

    if (allPoints.isEmpty || ids.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    try {
      // Directus batch-create returns { "data": [...] } (List), not a single Map.
      // postDirectus() returns the raw Dio Response — we deliberately do NOT cast
      // response.data here, so List vs Map does not matter.
      await _api.postDirectus('/items/post_dispatch_gps_logs', data: allPoints);

      final batch = db.batch();
      for (final id in ids) {
        batch.update(
          'action_queue',
          {'status': 'completed', 'last_attempt': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      // Log the failure so it is visible in debug output, but do not rethrow —
      // GPS batches are best-effort and should not block the rest of the queue.
      debugPrint('[ActionQueueService] GPS batch POST failed: $e');
    }
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
