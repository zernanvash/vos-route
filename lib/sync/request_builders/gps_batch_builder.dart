class GpsBatchBuilder {
  static List<Map<String, dynamic>> build(List<Map<String, dynamic>> points) {
    return points
        .map(
          (p) => {
            'trip_id': p['trip_id'],
            'latitude': p['latitude'],
            'longitude': p['longitude'],
            'accuracy': p['accuracy'],
            'speed': p['speed'],
            'heading': p['heading'],
            'recorded_at': p['recorded_at'],
          },
        )
        .toList();
  }

  static Map<String, dynamic> buildRoute() {
    return {'path': '/items/post_dispatch_gps_logs', 'method': 'POST'};
  }
}
