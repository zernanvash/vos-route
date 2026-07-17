import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';
import '../models/action_entry.dart';
import 'action_queue_service.dart';
import 'background_service.dart';
import 'timezone_service.dart';

class GpsService {
  final ActionQueueService _queue = ActionQueueService();
  Timer? _captureTimer;
  Timer? _flushTimer;
  int? _activeTripId;
  bool _isTracking = false;
  final List<Map<String, dynamic>> _buffer = [];

  static const int _batchSize = 5;
  static const int _flushIntervalSeconds = 60;

  bool get isTracking => _isTracking;
  int get bufferedCount => _buffer.length;

  Future<void> startTracking(int tripId) async {
    if (_isTracking && _activeTripId == tripId) return;
    if (_isTracking) await stopTracking();
    _activeTripId = tripId;
    _isTracking = true;
    BackgroundService().startTracking(tripId);

    _captureTimer = Timer.periodic(
      Duration(seconds: AppConfig.gpsIntervalSeconds),
      (_) => _captureAndBuffer(),
    );

    _flushTimer = Timer.periodic(
      Duration(seconds: _flushIntervalSeconds),
      (_) => _flushBuffer(),
    );
  }

  Future<void> stopTracking() async {
    _captureTimer?.cancel();
    _flushTimer?.cancel();
    await _flushBuffer();
    _isTracking = false;
    _activeTripId = null;
    BackgroundService().stopTracking();
  }

  Future<void> _captureAndBuffer() async {
    // Capture the trip ID this tick belongs to BEFORE the async gap so we
    // don't attribute the point to whichever trip is active when the position
    // resolves (which may be a different trip or null after stopTracking()).
    final tripId = _activeTripId;
    if (tripId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        ),
      );

      // Guard against both null-out (stopTracking) and trip-switch
      // (startTracking with a new trip) during the async gap above.
      if (_activeTripId != tripId) return;

      _buffer.add({
        'trip_id': tripId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'recorded_at': TimezoneService.formatIso8601(DateTime.now()),
      });

      if (_buffer.length >= _batchSize) {
        await _flushBuffer();
      }
    } catch (_) {}
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    await _queue.enqueue(
      ActionEntry(
        actionType: ActionType.gpsBatch,
        payload: batch,
        endpoint: '/items/post_dispatch_gps_logs',
        httpMethod: 'POST',
        batchGroup: 'gps:${batch.first['trip_id']}',
        priority: ActionPriority.low,
      ),
    );
  }

  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
