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

  void startTracking(int tripId) {
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

  void stopTracking() {
    _captureTimer?.cancel();
    _flushTimer?.cancel();
    _flushBuffer();
    _isTracking = false;
    _activeTripId = null;
    BackgroundService().stopTracking();
  }

  Future<void> _captureAndBuffer() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        ),
      );

      _buffer.add({
        'post_dispatch_plan_id': _activeTripId!,
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
    if (_buffer.isEmpty || _activeTripId == null) return;

    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    await _queue.enqueue(
      ActionEntry(
        actionType: ActionType.gpsBatch,
        payload: batch,
        endpoint: '/items/post_dispatch_gps_logs',
        httpMethod: 'POST',
        batchGroup: 'gps:$_activeTripId',
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
