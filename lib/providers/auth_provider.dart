import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/driver_profile.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _api = ApiService();
  DriverProfile? _profile;
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<int>? _unauthorizedSub;

  AuthProvider() {
    _init();
  }

  DriverProfile? get profile => _profile;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _init() {
    _unauthorizedSub = _api.onUnauthorized.listen((_) {
      logout();
    });
    checkAuth();
  }

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    _isLoggedIn = await _authService.validateCurrentToken();
    if (_isLoggedIn) {
      _profile = await _authService.getProfile();
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
    } else {
      _error = error;
    }

    _isLoading = false;
    notifyListeners();
    return error == null;
  }

  Future<void> logout() async {
    await _authService.logout();
    _isLoggedIn = false;
    _profile = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    super.dispose();
  }
}
