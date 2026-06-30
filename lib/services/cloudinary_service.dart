import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/cloudinary_config.dart';

class CloudinaryService {
  CloudinaryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> uploadImage(
    XFile file, {
    required String folder,
    required String tag,
  }) async {
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw StateError('Ảnh không có dữ liệu.');
    }

    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError('Ảnh phải nhỏ hơn 5 MB.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(CloudinaryConfig.uploadUrl),
    );

    request.fields.addAll({
      'upload_preset': CloudinaryConfig.uploadPreset,
      'folder': folder,
      'tags': tag,
    });

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: file.name),
    );

    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));

    final body = await response.stream.bytesToString();
    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('Cloudinary trả về dữ liệu không hợp lệ.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : null;

      throw StateError(message ?? 'Không thể tải ảnh lên Cloudinary.');
    }

    final url = decoded['secure_url']?.toString();

    if (url == null || url.isEmpty) {
      throw StateError('Cloudinary không trả về URL ảnh.');
    }

    return url;
  }

  void dispose() {
    _client.close();
  }
}
