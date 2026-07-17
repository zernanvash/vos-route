import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService _instance = SecureStorageService._();
  factory SecureStorageService() => _instance;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'vos_access_token';
  static const String _dbPassphraseKey = 'vos_db_passphrase';
  static const String _passwordHashKey = 'vos_password_hash';
  static const String _loginEmailKey = 'vos_login_email';
  static const String _sessionStartedAtKey = 'vos_session_started_at';

  Future<void> writeToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<String> getDatabasePassphrase() async {
    final existing = await _storage.read(key: _dbPassphraseKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final passphrase = _generatePassphrase();
    await _storage.write(key: _dbPassphraseKey, value: passphrase);
    return passphrase;
  }

  Future<void> writePasswordHash(String hash) async {
    await _storage.write(key: _passwordHashKey, value: hash);
  }

  Future<String?> readPasswordHash() async {
    return await _storage.read(key: _passwordHashKey);
  }

  Future<void> deletePasswordHash() async {
    await _storage.delete(key: _passwordHashKey);
  }

  Future<void> writeLoginEmail(String email) async {
    await _storage.write(key: _loginEmailKey, value: email);
  }

  Future<String?> readLoginEmail() async {
    return await _storage.read(key: _loginEmailKey);
  }

  Future<void> deleteLoginEmail() async {
    await _storage.delete(key: _loginEmailKey);
  }

  Future<void> writeSessionStartedAt(DateTime value) async {
    await _storage.write(
      key: _sessionStartedAtKey,
      value: value.toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> readSessionStartedAt() async {
    final value = await _storage.read(key: _sessionStartedAtKey);
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  Future<void> deleteSessionStartedAt() async {
    await _storage.delete(key: _sessionStartedAtKey);
  }

  Future<void> clearAuthentication() async {
    await Future.wait([
      deleteToken(),
      deletePasswordHash(),
      deleteLoginEmail(),
      deleteSessionStartedAt(),
    ]);
  }

  String _generatePassphrase() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
