import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

const String _kChannelId = 'vosroute_channel';
const String _kChannelName = 'VOSRoute Notifications';
const int _kTripNotifId = 1001;
const int _kFcmNotifIdBase = 2000;

@pragma('vm:entry-point')
Future<void> vosRouteBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _ensureChannel();
  final title = message.notification?.title ?? message.data['title'];
  final body = message.notification?.body ?? message.data['body'];
  if (title == null) return;
  final payload = message.data.isEmpty ? null : jsonEncode(message.data);
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.show(
    _kFcmNotifIdBase + (message.hashCode.abs() % 1000),
    title.toString(),
    body?.toString() ?? '',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        icon: '@mipmap/ic_launcher',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      ),
    ),
    payload: payload,
  );
}

Future<void> _ensureChannel() async {
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          importance: Importance.high,
        ),
      );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final ApiService _api = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  FirebaseMessaging? _fcm;

  void setNavigatorKey(GlobalKey<NavigatorState> key) => _navigatorKey = key;

  Future<void> init() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _ensureChannel();

      _fcm = FirebaseMessaging.instance;
      await _fcm?.requestPermission();
      final token = await _fcm?.getToken();
      if (token != null) {
        await _registerToken(token);
      }
      _fcm?.onTokenRefresh.listen(_registerToken);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(vosRouteBackgroundHandler);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);
      _handleInitialMessage();
    } catch (e) {
      debugPrint('[NotificationService] init failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if (title == null) return;
    showLocalNotification(
      title: title.toString(),
      body: body?.toString() ?? '',
      id: _kFcmNotifIdBase + (message.hashCode.abs() % 1000),
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  Future<void> _handleInitialMessage() async {
    final initial = await _fcm?.getInitialMessage();
    if (initial != null) {
      _navigateWithData(initial.data);
    }
  }

  void _handleOpenedApp(RemoteMessage message) {
    _navigateWithData(message.data);
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    int id = _kTripNotifId,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      icon: '@mipmap/ic_launcher',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  void _onNotificationTap(NotificationResponse response) {
    _handleTapPayload(response.payload);
  }

  void _handleTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      _popToRoot();
      return;
    }
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateWithData(data);
    } catch (_) {
      _popToRoot();
    }
  }

  void _navigateWithData(Map<String, dynamic> data) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    final screen = data['screen'] ?? data['type'];
    final args = data['id'] ?? data['stopId'] ?? data['tripId'];
    switch (screen) {
      case '/stop-detail':
        if (args != null) nav.pushNamed('/stop-detail', arguments: args);
        break;
      case '/sos':
        nav.pushNamed('/sos');
        break;
      case '/budget':
        nav.pushNamed('/budget');
        break;
      case '/history':
        nav.pushNamed('/history');
        break;
      case '/settings':
        nav.pushNamed('/settings');
        break;
      default:
        _popToRoot();
    }
  }

  void _popToRoot() {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
  }

  Future<void> showSyncFailureNotification({
    required int failedCount,
    String? detail,
  }) async {
    await showLocalNotification(
      title: 'Sync Issue',
      body:
          '$failedCount items failed to sync${detail != null ? ': $detail' : ''}. Open Sync Log for details.',
      id: 9000,
    );
  }

  Future<void> showSyncCompleteNotification(int syncedCount) async {
    await showLocalNotification(
      title: 'Sync Complete',
      body: '$syncedCount item(s) synced successfully.',
      id: 9001,
    );
  }

  Future<void> _registerToken(String token) async {
    try {
      await _api.post(
        '/api/dispatch/mobile/register-device',
        data: {'fcmToken': token, 'deviceInfo': 'Android'},
      );
    } catch (e) {
      debugPrint('[NotificationService] token register failed: $e');
    }
  }
}
