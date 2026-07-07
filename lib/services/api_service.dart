import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  late final Dio _dio;
  late final Dio _directusDio;
  static const String _tokenKey = 'vos_access_token';

  ApiService._();
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  Dio get dio => _dio;
  Dio get directusDio => _directusDio;

  Future<void> init() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.springBaseUrl,
        connectTimeout: Duration(milliseconds: AppConfig.connectionTimeoutMs),
        receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _directusDio = Dio(
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

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(_tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_tokenKey);
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    return await _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  // --- Directus Methods ---

  Future<Response> getDirectus(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    return await _directusDio.get(path, queryParameters: queryParams);
  }

  Future<Response> postDirectus(String path, {dynamic data}) async {
    return await _directusDio.post(path, data: data);
  }

  Future<Response> patchDirectus(String path, {dynamic data}) async {
    return await _directusDio.patch(path, data: data);
  }

  Future<bool> pingDirectus() async {
    try {
      final response = await _directusDio
          .get('/server/ping')
          .timeout(const Duration(seconds: 4));
      return response.data == 'pong';
    } catch (_) {
      return false;
    }
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
