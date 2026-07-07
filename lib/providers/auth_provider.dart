import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/driver_profile.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  DriverProfile? _profile;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  AuthProvider() {
    checkAuth();
  }

  DriverProfile? get profile => _profile;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> checkAuth() async {
    _isLoggedIn = await _authService.isLoggedIn();
    if (_isLoggedIn) {
      _profile = await _authService.getProfile();
    }
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
    notifyListeners();
  }
}
