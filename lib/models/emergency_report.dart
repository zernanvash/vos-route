class EmergencyReport {
  final int? id;
  final String? reportNo;
  final String incidentType;
  final String severity;
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

  EmergencyReport({
    this.id,
    this.reportNo,
    required this.incidentType,
    required this.severity,
    this.description,
    this.latitude,
    this.longitude,
    this.locationName,
    this.vehicleId,
    this.dispatchPlanId,
    this.driverUserId,
    this.contactName,
    this.contactPhone,
    this.status,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
    'report_no': reportNo,
    'incident_type': incidentType,
    'severity': severity,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'location_name': locationName,
    'vehicle_id': vehicleId,
    'dispatch_plan_id': dispatchPlanId,
    'driver_user_id': driverUserId,
    'contact_name': contactName,
    'contact_phone': contactPhone,
    'status': status,
    'synced': synced ? 1 : 0,
  };

  Map<String, dynamic> toApiPayload() {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return {
      'report_no': (reportNo == null || reportNo!.isEmpty)
          ? 'SOS-${DateTime.now().millisecondsSinceEpoch}'
          : reportNo,
      'incident_type': incidentType.toLowerCase(),
      'severity': severity.toLowerCase(),
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'vehicle_id': vehicleId,
      'dispatch_plan_id': dispatchPlanId,
      'driver_user_id': driverUserId,
      'reported_by': driverUserId,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'status': status ?? 'reported',
      'occurred_at': nowIso,
      'reported_at': nowIso,
      'created_at': nowIso,
      'updated_at': nowIso,
    };
  }

  factory EmergencyReport.fromMap(Map<String, dynamic> map) => EmergencyReport(
    id: map['id'] as int?,
    reportNo: map['report_no'] as String?,
    incidentType: map['incident_type'] as String? ?? '',
    severity: map['severity'] as String? ?? '',
    description: map['description'] as String?,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    locationName: map['location_name'] as String?,
    vehicleId: map['vehicle_id'] as int?,
    dispatchPlanId: map['dispatch_plan_id'] as int?,
    driverUserId: map['driver_user_id'] as int?,
    contactName: map['contact_name'] as String?,
    contactPhone: map['contact_phone'] as String?,
    status: map['status'] as String?,
    synced: (map['synced'] as int? ?? 0) == 1,
  );
}
