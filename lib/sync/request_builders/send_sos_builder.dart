class SendSosBuilder {
  static Map<String, dynamic> build({
    required String reportNo,
    required String incidentType,
    required String severity,
    String? description,
    double? latitude,
    double? longitude,
    String? locationName,
    int? vehicleId,
    int? dispatchPlanId,
    int? driverUserId,
    String? contactName,
    String? contactPhone,
    String? status,
    required DateTime occurredAt,
  }) {
    return {
      'path': '/items/fleet_emergency_reports',
      'method': 'POST',
      'body': {
        'report_no': reportNo,
        'incident_type': incidentType,
        'severity': severity,
        if (description != null) 'description': description,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationName != null) 'location_name': locationName,
        if (vehicleId != null) 'vehicle_id': vehicleId,
        if (dispatchPlanId != null) 'dispatch_plan_id': dispatchPlanId,
        if (driverUserId != null) 'driver_user_id': driverUserId,
        if (contactName != null) 'contact_name': contactName,
        if (contactPhone != null) 'contact_phone': contactPhone,
        'status': status ?? 'reported',
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      },
    };
  }
}
