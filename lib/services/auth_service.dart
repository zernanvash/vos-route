import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/driver_profile.dart';

class AuthService {
  final ApiService _api = ApiService();
  static const String _profileKey = 'cached_profile';
  static const String _emailKey = 'login_email';

  /// Returns `null` on success, or an error message string on failure.
  Future<String?> login(String email, String password) async {
    try {
      final response = await _api.post(
        '/auth/login',
        data: {'email': email, 'hashPassword': password},
      );
      final token = response.data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await _api.setToken(token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_emailKey, email);
        return null;
      }
      return 'Invalid credentials';
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Check your network.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach server (${e.message})';
      }
      if (e.response?.statusCode == 401) {
        return 'Invalid email or password';
      }
      if (e.response?.statusCode != null) {
        return 'Server error (${e.response?.statusCode})';
      }
      return 'Network error: ${e.message}';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  Future<DriverProfile?> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_emailKey);
      if (email == null) throw Exception('No login email stored');

      final response = await _api.getDirectus(
        '/items/user',
        queryParams: {
          'filter[user_email][_eq]': email,
          'fields': 'user_id,user_fname,user_lname,user_email,user_contact',
          'limit': '1',
        },
      );
      final dataList = response.data['data'] as List<dynamic>;
      if (dataList.isEmpty) throw Exception('User not found in Directus');

      final profile = DriverProfile.fromJson(
        dataList.first as Map<String, dynamic>,
      );

      await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
      return profile;
    } catch (e) {
      print('[AuthService] getProfile failed: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_profileKey);
        if (cached != null) {
          print('[AuthService] using cached profile');
          return DriverProfile.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
          );
        }
      } catch (e2) {
        print('[AuthService] cache fallback also failed: $e2');
      }
      return null;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await _api.getToken();
    return token != null && token.isNotEmpty;
  }
}
