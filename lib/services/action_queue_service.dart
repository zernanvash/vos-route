import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'upload_service.dart';
import '../db/app_database.dart';
import '../db/daos/outbox_dao.dart';
import '../models/action_entry.dart';
import '../sync/request_builders/trip_transition_builder.dart';
import '../sync/request_builders/gps_batch_builder.dart';
import '../sync/request_builders/send_sos_builder.dart';
import '../sync/request_builders/create_adhoc_stop_builder.dart';
import '../sync/request_builders/upload_pod_builder.dart';
import '../sync/request_builders/update_stop_status_builder.dart';

class ActionQueueService {
  final ApiService _api;
  final AppDatabase _db;
  final OutboxDao _dao;
  final UploadService _uploadService;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  Timer? _processTimer;
  bool _isProcessing = false;

  static const _maxRetries = 5;
  static const _processInterval = Duration(seconds: 10);

  ActionQueueService({
    ApiService? api,
    AppDatabase? database,
    OutboxDao? dao,
    UploadService? uploadService,
  }) : _api = api ?? ApiService(),
       _db = database ?? AppDatabase(),
       _dao = dao ?? OutboxDao(database ?? AppDatabase()),
       _uploadService = uploadService ?? UploadService();

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
    await _dao.insertAction(_entryToCompanion(entry));
    processQueue();
  }

  Future<void> enqueueBatch(List<ActionEntry> entries) async {
    if (entries.isEmpty) return;
    final companions = entries.map(_entryToCompanion).toList();
    await _dao.insertActions(companions);
    processQueue();
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;

    final isOnline = await _api.pingDirectus();
    if (!isOnline) return;

    _isProcessing = true;
    try {
      await _processPendingNonGpsByPriority(1);
      await _processPendingNonGpsByPriority(2);
      await _processPendingNonGpsByPriority(3);
      await _processGpsBatches();
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processPendingNonGpsByPriority(int priority) async {
    final pending = await _dao.getPendingNonGpsByPriority(priority);
    for (final row in pending) {
      final entry = _outboxActionToEntry(row);
      await _execute(entry);
    }
  }

  Future<void> _execute(ActionEntry entry) async {
    final now = DateTime.now().toUtc();

    await _dao.updateStatus(entry.id!, status: 'in_flight', lastAttempt: now);

    try {
      await _executeAction(entry);
      await _dao.markCompleted(entry.id!);
    } catch (e) {
      final newRetryCount = entry.retryCount + 1;
      final errorMsg = e is DioException
          ? '${e.response?.statusCode ?? "unknown"}: ${e.response?.data ?? e.message}'
          : e.toString();

      bool isPermanent = false;
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode != null &&
            statusCode >= 400 &&
            statusCode < 500 &&
            statusCode != 401) {
          isPermanent = true;
        }
      } else if (e is TypeError || e is FormatException || e is ArgumentError) {
        isPermanent = true;
      }

      if (isPermanent || newRetryCount >= _maxRetries) {
        await _dao.markFailed(entry.id!, errorMsg, newRetryCount);
      } else {
        final backoffSeconds = [
          1,
          2,
          4,
          8,
          16,
          30,
        ].elementAt(newRetryCount.clamp(1, 6) - 1);
        await _dao.markRetry(entry.id!, errorMsg, newRetryCount);
        await Future.delayed(Duration(seconds: backoffSeconds));
      }
    }
  }

  Future<void> _executeAction(ActionEntry entry) async {
    dynamic payload;
    if (entry.payload is List) {
      payload = List<dynamic>.from(entry.payload as List);
    } else {
      payload = Map<String, dynamic>.from(entry.payload as Map);
    }

    final actionType = entry.actionType.apiValue;

    // Handle local file upload for photo linking actions
    if (payload is Map<String, dynamic> &&
        payload.containsKey('local_file_path')) {
      await _uploadLocalFileIfNeeded(payload, actionType, entry.id!);
    }

    // Check for duplicate POD/trip photo links
    if (payload is Map<String, dynamic> && payload['directus_uuid'] != null) {
      if (actionType == 'link_pod_photo' || actionType == 'link_trip_photo') {
        final isAlreadyLinked = await _checkAlreadyLinked(payload, actionType);
        if (isAlreadyLinked) {
          debugPrint(
            '[ActionQueueService] Action ${entry.id} ($actionType) already linked, skipping',
          );
          return;
        }
      }
    }

    // Build and execute request using request builders
    final request = _buildRequest(actionType, payload);
    if (request == null) {
      throw ArgumentError('Unknown action type: $actionType');
    }

    final path = request['path'] as String;
    final method = request['method'] as String;
    final body = request['body'];

    switch (method) {
      case 'POST':
        if (body is List) {
          await _api.postDirectus(path, data: body);
        } else {
          await _api.postDirectus(path, data: body);
        }
        break;
      case 'PATCH':
        await _api.patchDirectus(path, data: body);
        break;
      case 'PUT':
        await _api.put(path, data: body);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  Future<void> _uploadLocalFileIfNeeded(
    Map<String, dynamic> payload,
    String actionType,
    int actionId,
  ) async {
    final localFilePath = payload['local_file_path'] as String;

    String folderUuid;
    if (actionType == 'link_pod_photo') {
      folderUuid = 'd3940009-6b99-411b-8a7a-45b8c3a83c95'; // POD folder
    } else {
      folderUuid = '13954431-1352-421b-8bcd-d41963b3d9bd'; // Trip photo folder
    }

    final directusFileId = await _uploadService.uploadFile(
      localFilePath,
      folderUuid: folderUuid,
    );

    if (directusFileId == null) {
      throw Exception('Failed to upload local file: $localFilePath');
    }

    payload.remove('local_file_path');
    payload['directus_uuid'] = directusFileId;
    payload['uploaded_at'] = DateTime.now().toUtc().toIso8601String();

    // Update outbox with the new payload
    await _db.customStatement(
      'UPDATE outbox_actions SET args_json = ? WHERE id = ?',
      [jsonEncode(payload), actionId],
    );
  }

  Future<bool> _checkAlreadyLinked(
    Map<String, dynamic> payload,
    String actionType,
  ) async {
    final planId = payload['trip_id'] ?? payload['post_dispatch_plan_id'];
    final fileId = payload['directus_uuid'];

    if (planId == null ||
        fileId == null ||
        '$planId'.isEmpty ||
        '$fileId'.isEmpty) {
      return false;
    }

    final res = await _api.getDirectus(
      '/items/post_dispatch_trip_photos',
      queryParams: {
        'filter[trip_id][_eq]': planId,
        'filter[directus_uuid][_eq]': fileId,
      },
    );
    return (res.data['data'] as List).isNotEmpty;
  }

  Map<String, dynamic>? _buildRequest(String actionType, dynamic payload) {
    switch (actionType) {
      case 'confirm_departure':
        if (payload is Map<String, dynamic>) {
          final planId = payload['plan_id'] ?? payload['trip_id'];
          final dispatchTime =
              DateTime.tryParse(payload['time_of_dispatch'] ?? '') ??
              DateTime.now();
          final remarks = payload['remarks'] as String?;
          if (planId != null) {
            return TripTransitionBuilder.buildConfirmDeparture(
              planId: planId as int,
              dispatchTime: dispatchTime,
              remarks: remarks,
            );
          }
        }
        break;

      case 'mark_arrived':
        if (payload is Map<String, dynamic>) {
          final planId = payload['plan_id'] ?? payload['trip_id'];
          final arrivalTime =
              DateTime.tryParse(payload['time_of_arrival'] ?? '') ??
              DateTime.now();
          final remarks = payload['remarks_arrival'] as String?;
          if (planId != null) {
            return TripTransitionBuilder.buildMarkArrived(
              planId: planId as int,
              arrivalTime: arrivalTime,
              remarks: remarks,
            );
          }
        }
        break;

      case 'update_stop_status':
        if (payload is Map<String, dynamic>) {
          final status = payload['status'];
          final remarks = payload['remarks'];
          if (status != null) {
            // Invoice stop update (has invoice_id)
            final invoiceId = payload['invoice_id'];
            if (invoiceId != null) {
              final driverUserId = payload['driver_user_id'] as int?;
              return UpdateStopStatusBuilder.build(
                invoiceId: invoiceId as int,
                status: status as String,
                remarks: remarks as String?,
                driverUserId: driverUserId,
                invoiceAt: payload['invoiceAt'] as String,
              );
            }
            // Other stop update (has other_stop_id)
            final otherStopId = payload['other_stop_id'];
            if (otherStopId != null) {
              return {
                'path': '/items/post_dispatch_plan_others/$otherStopId',
                'method': 'PATCH',
                'body': {
                  'status': status,
                  if (remarks != null) 'remarks': remarks,
                },
              };
            }
          }
        }
        break;

      case 'update_invoices_departure':
        if (payload is Map<String, dynamic>) {
          final invoiceIds =
              (payload['invoice_ids'] as List?)?.cast<int>() ?? [];
          final dispatchTime = payload['time_of_dispatch'];
          if (invoiceIds.isNotEmpty && dispatchTime != null) {
            return {
              'path': '/items/sales_invoice',
              'method': 'PATCH',
              'body': {
                'keys': invoiceIds,
                'data': {
                  'transaction_status': 'En Route',
                  'isDispatched': 1,
                  'dispatch_date': dispatchTime,
                },
              },
            };
          }
        }
        break;

      case 'update_orders_departure':
        if (payload is Map<String, dynamic>) {
          final orderNos =
              (payload['order_nos'] as List?)?.cast<String>() ?? [];
          if (orderNos.isNotEmpty) {
            return {
              'path': '/items/sales_order',
              'method': 'PATCH',
              'body': {
                'query': {
                  'filter': {
                    'order_no': {'_in': orderNos},
                  },
                },
                'data': {'order_status': 'En Route'},
              },
            };
          }
        }
        break;

      case 'link_pod_photo':
        if (payload is Map<String, dynamic>) {
          final invoiceId = payload['invoice_id'];
          final directusFileId = payload['directus_uuid'];
          final docNo = payload['doc_no'];
          if (invoiceId != null && directusFileId != null && docNo != null) {
            return UploadPodBuilder.build(
              invoiceId: invoiceId as int,
              directusFileUuid: directusFileId as String,
              docNo: docNo as String,
            );
          }
        }
        break;

      case 'link_trip_photo':
        if (payload is Map<String, dynamic>) {
          final tripId = payload['trip_id'] ?? payload['post_dispatch_plan_id'];
          final directusFileId = payload['directus_uuid'];
          final type = payload['type'] ?? 'outbound';
          if (tripId != null && directusFileId != null) {
            return {
              'path': '/items/post_dispatch_trip_photos',
              'method': 'POST',
              'body': {
                'trip_id': tripId as int,
                'directus_uuid': directusFileId as String,
                'type': type as String,
                'uploaded_at': payload['uploaded_at'] as String,
              },
            };
          }
        }
        break;

      case 'submit_sos':
        if (payload is Map<String, dynamic>) {
          return SendSosBuilder.build(
            reportNo: payload['report_no'] as String,
            incidentType: payload['incident_type'] as String,
            severity: payload['severity'] as String,
            description: payload['description'] as String?,
            latitude: payload['latitude'] as double?,
            longitude: payload['longitude'] as double?,
            locationName: payload['location_name'] as String?,
            vehicleId: payload['vehicle_id'] as int?,
            dispatchPlanId: payload['dispatch_plan_id'] as int?,
            driverUserId: payload['driver_user_id'] as int?,
            contactName: payload['contact_name'] as String?,
            contactPhone: payload['contact_phone'] as String?,
            status: payload['status'] as String?,
            occurredAt:
                DateTime.tryParse(payload['occurred_at'] ?? '') ??
                DateTime.now(),
          );
        }
        break;

      case 'gps_batch':
        if (payload is List) {
          final points = GpsBatchBuilder.build(
            payload.cast<Map<String, dynamic>>(),
          );
          final route = GpsBatchBuilder.buildRoute();
          return {
            'path': route['path'] as String,
            'method': route['method'] as String,
            'body': points,
          };
        }
        break;

      case 'add_ad_hoc_stop':
        if (payload is Map<String, dynamic>) {
          final planId = payload['plan_id'];
          final remarks = payload['remarks'];
          final distance = payload['distance'] as double?;
          final sequence = payload['sequence'] as int?;
          if (planId != null && remarks != null) {
            return CreateAdhocStopBuilder.build(
              planId: planId as int,
              remarks: remarks as String,
              distance: distance,
              sequence: sequence,
            );
          }
        }
        break;
    }
    return null;
  }

  Future<void> _processGpsBatches() async {
    final pendingGps = await _dao.getPendingGps();
    if (pendingGps.isEmpty) return;

    final allPoints = <Map<String, dynamic>>[];
    final ids = <int>[];

    for (final row in pendingGps) {
      final entry = _outboxActionToEntry(row);
      if (entry.payload is List) {
        allPoints.addAll((entry.payload as List).cast<Map<String, dynamic>>());
        ids.add(entry.id!);
      }
    }

    if (allPoints.isEmpty || ids.isEmpty) return;

    try {
      final points = GpsBatchBuilder.build(allPoints);
      final route = GpsBatchBuilder.buildRoute();
      await _api.postDirectus(route['path'] as String, data: points);
      for (final id in ids) {
        await _dao.markCompleted(id);
      }
    } catch (e) {
      debugPrint('[ActionQueueService] GPS batch POST failed: $e');
      for (final id in ids) {
        final row = await _dao.selectOutboxActionById(id);
        if (row != null) {
          final entry = _outboxActionToEntry(row);
          final newRetryCount = entry.retryCount + 1;
          final errorMsg = e.toString();
          if (newRetryCount >= _maxRetries) {
            await _dao.markFailed(id, errorMsg, newRetryCount);
          } else {
            await _dao.markRetry(id, errorMsg, newRetryCount);
          }
        }
      }
    }
  }

  Future<int> getPendingCount() async {
    return _dao.getPendingCount();
  }

  Future<int> getFailedCount() async {
    return _dao.getFailedCount();
  }

  Future<List<ActionEntry>> getPendingActions() async {
    final rows = await _dao.getPendingOrFailed();
    return rows.map(_outboxActionToEntry).toList();
  }

  Future<bool> hasPendingStatusActionForPlan(int planId) async {
    return _dao.hasPendingStatusActionForEntity(
      entityType: 'trip',
      entityId: planId,
    );
  }

  Future<bool> hasPendingStatusActionForInvoiceStop(int invoiceId) async {
    return _dao.hasPendingStatusActionForEntity(
      entityType: 'invoice_stop',
      entityId: invoiceId,
    );
  }

  Future<void> retryFailed() async {
    await _dao.retryAllFailed();
    processQueue();
  }

  Future<void> retryAction(int actionId) async {
    await _dao.retryAction(actionId);
    processQueue();
  }

  Future<void> clearCompleted() async {
    await _dao.clearCompleted();
  }

  Future<void> clearFailed() async {
    await _dao.clearFailed();
  }

  Future<void> clearAll() async {
    await _dao.clearAll();
  }

  OutboxActionsCompanion _entryToCompanion(ActionEntry entry) {
    return OutboxActionsCompanion(
      action: Value(entry.actionType.apiValue),
      priority: Value(entry.priority.value),
      argsJson: Value(jsonEncode(entry.payload)),
      schemaVersion: const Value(2),
      status: Value(entry.status.apiValue),
      retryCount: Value(entry.retryCount),
      maxRetries: Value(entry.maxRetries),
      createdAt: Value(entry.createdAt),
      lastAttempt: entry.lastAttempt != null
          ? Value(entry.lastAttempt!)
          : const Value.absent(),
      lastError: entry.lastError != null
          ? Value(entry.lastError!)
          : const Value.absent(),
    );
  }

  ActionEntry _outboxActionToEntry(OutboxAction row) {
    dynamic payload;
    try {
      payload = jsonDecode(row.argsJson);
    } catch (_) {
      payload = <String, dynamic>{};
    }

    return ActionEntry(
      id: row.id,
      actionType: ActionType.fromApiValue(row.action),
      payload: payload,
      endpoint: '', // Not used, derived from action type
      httpMethod: '', // Not used, derived from action type
      priority: ActionPriority.fromValue(row.priority),
      status: ActionStatus.fromApiValue(row.status),
      retryCount: row.retryCount,
      maxRetries: row.maxRetries,
      createdAt: row.createdAt,
      lastAttempt: row.lastAttempt,
      lastError: row.lastError,
    );
  }
}
