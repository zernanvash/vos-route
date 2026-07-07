import 'dart:convert';

enum ActionType {
  confirmDeparture,
  markArrived,
  updateStopStatus,
  updateInvoicesDeparture,
  updateOrdersDeparture,
  linkPodPhoto,
  linkTripPhoto,
  submitSos,
  gpsBatch,
  addAdHocStop;

  String get apiValue {
    switch (this) {
      case ActionType.confirmDeparture:
        return 'confirm_departure';
      case ActionType.markArrived:
        return 'mark_arrived';
      case ActionType.updateStopStatus:
        return 'update_stop_status';
      case ActionType.updateInvoicesDeparture:
        return 'update_invoices_departure';
      case ActionType.updateOrdersDeparture:
        return 'update_orders_departure';
      case ActionType.linkPodPhoto:
        return 'link_pod_photo';
      case ActionType.linkTripPhoto:
        return 'link_trip_photo';
      case ActionType.submitSos:
        return 'submit_sos';
      case ActionType.gpsBatch:
        return 'gps_batch';
      case ActionType.addAdHocStop:
        return 'add_ad_hoc_stop';
    }
  }

  static ActionType fromApiValue(String value) {
    return ActionType.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => ActionType.updateStopStatus,
    );
  }
}

enum ActionStatus {
  pending,
  inFlight,
  completed,
  failed;

  String get apiValue {
    switch (this) {
      case ActionStatus.pending:
        return 'pending';
      case ActionStatus.inFlight:
        return 'in_flight';
      case ActionStatus.completed:
        return 'completed';
      case ActionStatus.failed:
        return 'failed';
    }
  }

  static ActionStatus fromApiValue(String value) {
    return ActionStatus.values.firstWhere(
      (s) => s.apiValue == value,
      orElse: () => ActionStatus.pending,
    );
  }
}

enum ActionPriority {
  urgent, // 1 — depart, arrival, SOS, invoice status
  normal, // 2 — photo links
  low; // 3 — GPS batches

  int get value {
    switch (this) {
      case ActionPriority.urgent:
        return 1;
      case ActionPriority.normal:
        return 2;
      case ActionPriority.low:
        return 3;
    }
  }

  static ActionPriority fromValue(int v) {
    return ActionPriority.values.firstWhere(
      (p) => p.value == v,
      orElse: () => ActionPriority.low,
    );
  }
}

class ActionEntry {
  final int? id;
  final ActionType actionType;
  final dynamic payload;
  final String endpoint;
  final String httpMethod;
  final String? batchGroup;
  final ActionPriority priority;
  final ActionStatus status;
  final int retryCount;
  final int maxRetries;
  final DateTime createdAt;
  final DateTime? lastAttempt;
  final String? lastError;

  ActionEntry({
    this.id,
    required this.actionType,
    required this.payload,
    required this.endpoint,
    required this.httpMethod,
    this.batchGroup,
    this.priority = ActionPriority.normal,
    this.status = ActionStatus.pending,
    this.retryCount = 0,
    this.maxRetries = 5,
    DateTime? createdAt,
    this.lastAttempt,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now();

  ActionEntry copyWith({
    int? id,
    ActionType? actionType,
    Map<String, dynamic>? payload,
    String? endpoint,
    String? httpMethod,
    String? batchGroup,
    ActionPriority? priority,
    ActionStatus? status,
    int? retryCount,
    int? maxRetries,
    DateTime? createdAt,
    DateTime? lastAttempt,
    String? lastError,
  }) {
    return ActionEntry(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      payload: payload ?? this.payload,
      endpoint: endpoint ?? this.endpoint,
      httpMethod: httpMethod ?? this.httpMethod,
      batchGroup: batchGroup ?? this.batchGroup,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      createdAt: createdAt ?? this.createdAt,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      lastError: lastError ?? this.lastError,
    );
  }

  bool get isRetryable => retryCount < maxRetries;
  bool get isExpired => !isRetryable;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'action_type': actionType.apiValue,
    'action_payload': jsonEncode(payload),
    'endpoint': endpoint,
    'http_method': httpMethod,
    'batch_group': batchGroup,
    'batch_priority': priority.value,
    'status': status.apiValue,
    'retry_count': retryCount,
    'max_retries': maxRetries,
    'created_at': createdAt.toIso8601String(),
    'last_attempt': lastAttempt?.toIso8601String(),
    'last_error': lastError,
  };

  static dynamic _decodePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  factory ActionEntry.fromMap(Map<String, dynamic> map) => ActionEntry(
    id: map['id'] as int?,
    actionType: ActionType.fromApiValue(map['action_type'] as String? ?? ''),
    payload: _decodePayload(map['action_payload'] as String? ?? '{}'),
    endpoint: map['endpoint'] as String? ?? '',
    httpMethod: map['http_method'] as String? ?? 'POST',
    batchGroup: map['batch_group'] as String?,
    priority: ActionPriority.fromValue(map['batch_priority'] as int? ?? 3),
    status: ActionStatus.fromApiValue(map['status'] as String? ?? 'pending'),
    retryCount: map['retry_count'] as int? ?? 0,
    maxRetries: map['max_retries'] as int? ?? 5,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    lastAttempt: map['last_attempt'] != null
        ? DateTime.tryParse(map['last_attempt'] as String)
        : null,
    lastError: map['last_error'] as String?,
  );
}
