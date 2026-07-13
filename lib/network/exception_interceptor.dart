import 'package:dio/dio.dart';
import 'app_exception.dart';

class ExceptionInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = _map(err);
    err = err.copyWith(error: appException);
    handler.next(err);
  }

  AppException _map(DioException err) {
    final statusCode = err.response?.statusCode;
    final responseData = err.response?.data;

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return const NetworkException(
        'Network timeout or connection error. Please retry.',
      );
    }

    if (statusCode == 401) {
      return const AuthException('Session expired. Please log in again.');
    }

    if (statusCode == 400 || statusCode == 422) {
      Map<String, dynamic> errors;
      if (responseData is Map<String, dynamic>) {
        errors = responseData;
      } else {
        errors = <String, dynamic>{};
      }
      return ValidationException(
        responseData?['errors']?[0]?['message'] ?? 'Validation failed.',
        errors,
      );
    }

    if (statusCode != null) {
      if (statusCode >= 400 && statusCode < 500) {
        final body = responseData is Map<String, dynamic> ? responseData : null;
        return ClientException(
          responseData?['errors']?[0]?['message'] ?? 'Client error occurred.',
          statusCode,
          body: body,
        );
      }
      return ServerException(
        'Server error occurred (HTTP $statusCode). Please retry.',
        statusCode,
      );
    }

    return NetworkException(
      'An unexpected network error occurred: ${err.message}',
    );
  }
}

extension DioExceptionExtensions on DioException {
  DioException copyWith({Object? error}) {
    return DioException(
      requestOptions: requestOptions,
      response: response,
      type: type,
      error: error ?? this.error,
      message: message,
    );
  }
}
