import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../services/secure_storage_service.dart';
import '../services/auth_session_policy.dart';

class AuthRefreshInterceptor extends Interceptor {
  final SecureStorageService _secure = SecureStorageService();
  Future<String>? _refreshInFlight;
  final void Function()? onUnauthorized;
  final Dio Function() _refreshDioFactory;
  final Dio Function() _retryDioFactory;

  AuthRefreshInterceptor({
    this.onUnauthorized,
    Dio Function()? refreshDioFactory,
    Dio Function()? retryDioFactory,
  }) : _refreshDioFactory = refreshDioFactory ?? _newSpringDio,
       _retryDioFactory = retryDioFactory ?? _newSpringDio;

  static Dio _newSpringDio() => Dio(
    BaseOptions(
      baseUrl: AppConfig.springBaseUrl,
      connectTimeout: Duration(milliseconds: AppConfig.connectionTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
      headers: {'Content-Type': 'application/json'},
    ),
  );

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

    if (err.requestOptions.path == '/auth/login' ||
        err.requestOptions.extra['authRetried'] == true) {
      handler.next(err);
      return;
    }

    var startedAt = await _secure.readSessionStartedAt();
    if (startedAt == null) {
      startedAt = DateTime.now().toUtc();
      await _secure.writeSessionStartedAt(startedAt);
    }
    if (AuthSessionPolicy.isExpired(
      startedAt: startedAt,
      now: DateTime.now().toUtc(),
    )) {
      await _secure.clearAuthentication();
      onUnauthorized?.call();
      handler.next(err);
      return;
    }

    try {
      final newToken = await _refreshToken();
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      err.requestOptions.extra['authRetried'] = true;
      final retryDio = _retryDioFactory();
      final retryResponse = await retryDio.fetch(err.requestOptions);
      handler.resolve(retryResponse);
    } catch (refreshError) {
      final isConfirmedAuthFailure =
          refreshError is DioException &&
          (refreshError.response?.statusCode == 401 ||
              refreshError.response?.statusCode == 403);
      if (isConfirmedAuthFailure) {
        await _secure.clearAuthentication();
        onUnauthorized?.call();
      }
      handler.next(err);
    }
  }

  Future<String> _refreshToken() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    late final Future<String> operation;
    operation = _performRefresh().whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = operation;
    return operation;
  }

  Future<String> _performRefresh() async {
    final email = await _secure.readLoginEmail();
    final passwordHash = await _secure.readPasswordHash();

    if (email == null || passwordHash == null) {
      throw Exception('No stored credentials for refresh');
    }

    final response = await _refreshDioFactory().post(
      '/auth/login',
      data: {'email': email, 'hashPassword': passwordHash},
    );

    final token = response.data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Refresh returned empty token');
    }

    await _secure.writeToken(token);
    return token;
  }
}
