class TripTransitionBuilder {
  static Map<String, dynamic> buildConfirmDeparture({
    required int planId,
    required DateTime dispatchTime,
    String? remarks,
  }) {
    return {
      'path': '/items/post_dispatch_plan/$planId',
      'method': 'PATCH',
      'body': {
        'status': 'For Inbound',
        'time_of_dispatch': dispatchTime.toUtc().toIso8601String(),
        if (remarks != null) 'remarks': remarks,
      },
    };
  }

  static Map<String, dynamic> buildMarkArrived({
    required int planId,
    required DateTime arrivalTime,
    String? remarks,
  }) {
    return {
      'path': '/items/post_dispatch_plan/$planId',
      'method': 'PATCH',
      'body': {
        'status': 'For Clearance',
        'time_of_arrival': arrivalTime.toUtc().toIso8601String(),
        if (remarks != null) 'remarks_arrival': remarks,
      },
    };
  }
}
