import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'timezone_service.dart';

class BackgroundService {
  BackgroundService._();
  static final BackgroundService _instance = BackgroundService._();
  factory BackgroundService() => _instance;

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _started = false;

  static const String _channelId = 'vosroute_bg_channel';

  Future<void> ensureInitialized() async {
    if (_started) return;

    final FlutterLocalNotificationsPlugin localNotif =
        FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await localNotif.initialize(
      const InitializationSettings(android: androidSettings),
    );

    await localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'VOSRoute Background',
            importance: Importance.low,
            playSound: false,
          ),
        );

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'VOSRoute',
        initialNotificationContent: 'Monitoring pending sync',
        foregroundServiceNotificationId: 9999,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );

    await _service.startService();
    _started = true;
  }

  void startTracking(int tripId) {
    _service.invoke('setActiveTrip', {'tripId': tripId});
    _updateNotification(tripId);
  }

  void stopTracking() {
    _service.invoke('setActiveTrip', {'tripId': null});
    _updateNotification(null);
  }

  void _updateNotification(int? tripId) {
    final title = 'VOSRoute';
    final content = tripId != null
        ? 'Tracking trip #$tripId'
        : 'Monitoring pending sync';
    _service.invoke('setForegroundText', {'title': title, 'content': content});
  }

  Future<void> stop() async {
    _started = false;
    _service.invoke('stopService');
  }
}

// ── Top-level isolate callbacks ────────────────────────────────────────────
// flutter_background_service requires onStart/onForeground to be top-level or
// static functions, not instance methods.

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) {
  int? activeTripId;
  Timer? gpsTimer;

  if (service is AndroidServiceInstance) {
    service.on('setForegroundText').listen((event) {
      final data = event;
      if (data != null && data['title'] != null && data['content'] != null) {
        service.setForegroundNotificationInfo(
          title: data['title'] as String,
          content: data['content'] as String,
        );
      }
    });
  }

  service.on('stopService').listen((_) {
    gpsTimer?.cancel();
    service.stopSelf();
  });

  service.on('setActiveTrip').listen((event) {
    final data = event;
    activeTripId = data?['tripId'] as int?;
    if (service is AndroidServiceInstance) {
      final title = 'VOSRoute';
      final content = activeTripId != null
          ? 'Tracking trip #$activeTripId'
          : 'Monitoring pending sync';
      service.setForegroundNotificationInfo(title: title, content: content);
    }
  });

  Future<void> captureAndQueueGps() async {
    // Capture the trip ID this tick belongs to BEFORE the async gap.
    final tripId = activeTripId;
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
      if (activeTripId != tripId) return;

      final point = {
        'trip_id': tripId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'recorded_at': TimezoneService.formatIso8601(DateTime.now()),
      };

      final directusDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.directusBaseUrl,
          connectTimeout: Duration(milliseconds: AppConfig.connectionTimeoutMs),
          receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.directusStaticToken}',
          },
        ),
      );

      await directusDio.post('/items/post_dispatch_gps_logs', data: [point]);
    } catch (_) {
      // GPS capture failed in background — points are non-critical,
      // foreground GpsService will fill gaps when app is active.
    }
  }

  gpsTimer = Timer.periodic(
    Duration(seconds: AppConfig.gpsIntervalSeconds),
    (_) => captureAndQueueGps(),
  );
}
