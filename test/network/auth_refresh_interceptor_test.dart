import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vosroute/network/auth_refresh_interceptor.dart';
import 'package:vosroute/services/secure_storage_service.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(Future<ResponseBody> Function(RequestOptions options) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'));
  dio.httpClientAdapter = _Adapter(handler);
  return dio;
}

ResponseBody _response(int status, [String body = '{}']) =>
    ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void _seedSession() {
  FlutterSecureStorage.setMockInitialValues({
    'vos_access_token': 'old-token',
    'vos_password_hash': 'password',
    'vos_login_email': 'driver@example.com',
    'vos_session_started_at': DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('does not refresh or broadcast logout for login 401', () async {
    _seedSession();
    var loggedOut = false;
    final dio = _dioWith((_) async => _response(401));
    dio.interceptors.add(
      AuthRefreshInterceptor(onUnauthorized: () => loggedOut = true),
    );

    await expectLater(dio.post('/auth/login'), throwsA(isA<DioException>()));

    expect(loggedOut, isFalse);
    expect(await SecureStorageService().readToken(), 'old-token');
  });

  test('retains session when silent login has a network failure', () async {
    _seedSession();
    var loggedOut = false;
    final dio = _dioWith((_) async => _response(401));
    dio.interceptors.add(
      AuthRefreshInterceptor(
        onUnauthorized: () => loggedOut = true,
        refreshDioFactory: () => _dioWith((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }),
      ),
    );

    await expectLater(dio.get('/feature'), throwsA(isA<DioException>()));

    expect(loggedOut, isFalse);
    expect(await SecureStorageService().readToken(), 'old-token');
  });

  test('clears session after confirmed silent-login 401', () async {
    _seedSession();
    var loggedOut = false;
    final dio = _dioWith((_) async => _response(401));
    dio.interceptors.add(
      AuthRefreshInterceptor(
        onUnauthorized: () => loggedOut = true,
        refreshDioFactory: () => _dioWith((_) async => _response(401)),
      ),
    );

    await expectLater(dio.get('/feature'), throwsA(isA<DioException>()));

    expect(loggedOut, isTrue);
    expect(await SecureStorageService().readToken(), isNull);
  });

  test('silently logs in and retries the original request once', () async {
    _seedSession();
    var retryCount = 0;
    final dio = _dioWith((_) async => _response(401));
    dio.interceptors.add(
      AuthRefreshInterceptor(
        refreshDioFactory: () =>
            _dioWith((_) async => _response(200, '{"token":"new-token"}')),
        retryDioFactory: () => _dioWith((_) async {
          retryCount++;
          return _response(200, '{"ok":true}');
        }),
      ),
    );

    final response = await dio.get('/feature');

    expect(response.statusCode, 200);
    expect(retryCount, 1);
    expect(await SecureStorageService().readToken(), 'new-token');
  });
}
