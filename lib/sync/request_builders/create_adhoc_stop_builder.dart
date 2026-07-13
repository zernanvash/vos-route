class CreateAdhocStopBuilder {
  static Map<String, dynamic> build({
    required int planId,
    required String remarks,
    double? distance,
    int? sequence,
  }) {
    return {
      'path': '/items/post_dispatch_plan_others',
      'method': 'POST',
      'body': {
        'post_dispatch_plan_id': planId,
        'remarks': remarks,
        if (distance != null) 'distance': distance,
        if (sequence != null) 'sequence': sequence,
        'status': 'For Dispatch',
      },
    };
  }
}
