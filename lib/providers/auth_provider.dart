import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/driver_profile.dart';
import '../services/auth_session_policy.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _api = ApiService();
  DriverProfile? _profile;
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<int>? _unauthorizedSub;
  Timer? _sessionExpiryTimer;

  AuthProvider() {
    _init();
  }

  DriverProfile? get profile => _profile;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _init() {
    _unauthorizedSub = _api.onUnauthorized.listen((_) {
      logout(sessionExpired: true);
    });
    checkAuth();
  }

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    final startedAt = await _authService.getSessionStartedAt();
    final sessionExpired =
        startedAt != null &&
        AuthSessionPolicy.isExpired(
          startedAt: startedAt,
          now: DateTime.now().toUtc(),
        );
    _isLoggedIn = await _authService.validateCurrentToken();
    if (_isLoggedIn) {
      _profile = await _authService.getProfile();
      await _scheduleSessionExpiry();
    } else if (sessionExpired) {
      _error = 'Session expired. Please sign in again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final error = await _authService.login(email, password);
    if (error == null) {
      _isLoggedIn = true;
      _profile = await _authService.getProfile();
      await _scheduleSessionExpiry();
    } else {
      _error = error;
    }

    _isLoading = false;
    notifyListeners();
    return error == null;
  }

  Future<void> logout({bool sessionExpired = false}) async {
    _sessionExpiryTimer?.cancel();
    await _authService.logout();
    _isLoggedIn = false;
    _profile = null;
    _error = sessionExpired ? 'Session expired. Please sign in again.' : null;
    notifyListeners();
  }

  Future<void> _scheduleSessionExpiry() async {
    _sessionExpiryTimer?.cancel();
    final startedAt = await _authService.getSessionStartedAt();
    if (startedAt == null) return;
    final expiresAt = startedAt.add(AuthSessionPolicy.duration);
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      await logout(sessionExpired: true);
      return;
    }
    _sessionExpiryTimer = Timer(remaining, () => logout(sessionExpired: true));
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    _sessionExpiryTimer?.cancel();
    super.dispose();
  }
}
