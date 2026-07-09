sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);
  
  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class ServerException extends AppException {
  final int statusCode;
  const ServerException(super.message, this.statusCode);
}

class ClientException extends AppException {
  final int statusCode;
  final Map<String, dynamic>? body;
  const ClientException(super.message, this.statusCode, {this.body});
}

class AuthException extends AppException {
  const AuthException(super.message);
}

class ValidationException extends AppException {
  final Map<String, dynamic> fieldErrors;
  const ValidationException(super.message, this.fieldErrors);
}
