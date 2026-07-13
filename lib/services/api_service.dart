import 'dart:async';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../network/app_exception.dart';
import '../network/auth_refresh_interceptor.dart';
import '../network/exception_interceptor.dart';
import 'secure_storage_service.dart';

class ApiService {
  late final Dio _dio;
  late final Dio _directusDio;

  final StreamController<int> _unauthorizedController =
      StreamController<int>.broadcast();
  Stream<int> get onUnauthorized => _unauthorizedController.stream;

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

    final secure = SecureStorageService();

    _dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secure.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
      AuthRefreshInterceptor(
        onUnauthorized: () {
          _unauthorizedController.add(401);
        },
      ),
      ExceptionInterceptor(),
    ]);

    _directusDio.interceptors.add(ExceptionInterceptor());
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

  Future<Response<T>> getDirectus<T>(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    return await _directusDio.get<T>(path, queryParameters: queryParams);
  }

  Future<Response<T>> postDirectus<T>(String path, {dynamic data}) async {
    return await _directusDio.post<T>(path, data: data);
  }

  Future<Response<T>> patchDirectus<T>(String path, {dynamic data}) async {
    return await _directusDio.patch<T>(path, data: data);
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
    await SecureStorageService().writeToken(token);
  }

  Future<String?> getToken() async {
    return await SecureStorageService().readToken();
  }

  Future<void> clearToken() async {
    await SecureStorageService().deleteToken();
  }

  Future<T> getDirectusGeneric<T>(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _directusDio.get(
        path,
        queryParameters: queryParams,
      );
      return response.data as T;
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error as AppException;
      rethrow;
    }
  }
}
