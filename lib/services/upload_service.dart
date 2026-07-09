import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class UploadService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.directusBaseUrl,
      connectTimeout: Duration(milliseconds: AppConfig.connectionTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
    ),
  );

  Future<String?> uploadFile(String filePath, {String? folderUuid}) async {
    try {
      final Map<String, dynamic> uploadData = {
        'file': await MultipartFile.fromFile(filePath),
      };
      if (folderUuid != null) {
        uploadData['folder'] = folderUuid;
      }
      final formData = FormData.fromMap(uploadData);

      final response = await _dio.post(
        '/files',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer ${AppConfig.directusStaticToken}'},
        ),
      );

      return response.data['data']['id'] as String?;
    } catch (e, stack) {
      debugPrint('[UploadService] uploadFile failed for path: $filePath');
      debugPrint('[UploadService] Error: $e');
      if (e is DioException) {
        debugPrint('[UploadService] Dio Status Code: ${e.response?.statusCode}');
        debugPrint('[UploadService] Dio Response Body: ${e.response?.data}');
      }
      debugPrint(stack.toString());
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
