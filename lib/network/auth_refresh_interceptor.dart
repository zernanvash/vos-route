import 'dart:async';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../services/secure_storage_service.dart';

class AuthRefreshInterceptor extends Interceptor {
  final SecureStorageService _secure = SecureStorageService();
  Completer<String>? _refreshInFlight;
  final void Function()? onUnauthorized;

  AuthRefreshInterceptor({this.onUnauthorized});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    try {
      final newToken = await _refreshToken();
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      final retryDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.springBaseUrl,
          connectTimeout: Duration(milliseconds: AppConfig.connectionTimeoutMs),
          receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
        ),
      );
      final retryResponse = await retryDio.fetch(err.requestOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      await _secure.deleteToken();
      onUnauthorized?.call();
      handler.next(err);
    }
  }

  Future<String> _refreshToken() async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!.future;
    }

    _refreshInFlight = Completer<String>();
    try {
      final email = await _secure.readLoginEmail();
      final passwordHash = await _secure.readPasswordHash();

      if (email == null || passwordHash == null) {
        throw Exception('No stored credentials for refresh');
      }

      final response =
          await Dio(
            BaseOptions(
              baseUrl: AppConfig.springBaseUrl,
              connectTimeout: Duration(
                milliseconds: AppConfig.connectionTimeoutMs,
              ),
              receiveTimeout: Duration(
                milliseconds: AppConfig.receiveTimeoutMs,
              ),
              headers: {'Content-Type': 'application/json'},
            ),
          ).post(
            '/auth/login',
            data: {'email': email, 'hashPassword': passwordHash},
          );

      final token = response.data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Refresh returned empty token');
      }

      await _secure.writeToken(token);
      _refreshInFlight!.complete(token);
      return token;
    } catch (e) {
      _refreshInFlight!.completeError(e);
      rethrow;
    } finally {
      _refreshInFlight = null;
    }
  }
}
