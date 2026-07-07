import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class UploadService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.directusBaseUrl,
      connectTimeout: Duration(milliseconds: AppConfig.connectionTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
    ),
  );

  Future<String?> uploadFile(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        '/files',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer ${AppConfig.directusStaticToken}'},
        ),
      );

      return response.data['data']['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadBytes(Uint8List bytes, {String? filename}) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename ?? 'signature.png',
        ),
      });

      final response = await _dio.post(
        '/files',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer ${AppConfig.directusStaticToken}'},
        ),
      );

      return response.data['data']['id'] as String?;
    } catch (_) {
      return null;
    }
  }
}
