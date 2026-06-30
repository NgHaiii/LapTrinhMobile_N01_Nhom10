import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/cloudinary_config.dart';
import '../model/provider_application.dart';

class ProviderApplicationService {
  ProviderApplicationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _httpClient = httpClient ?? http.Client();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

  static const Duration _timeout = Duration(seconds: 45);

  Stream<ProviderApplication?> watchMyApplication() {
    final uid = _requireUser().uid;

    return _firestore
        .collection('providerApplications')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();

          if (data == null) return null;
          return ProviderApplication.fromMap(data);
        });
  }

  Future<void> submit({
    required String businessName,
    required String representativeName,
    required String phoneNumber,
    required String address,
    required String identityNumber,
    required XFile identityFront,
    required XFile identityBack,
    required XFile businessLicense,
  }) async {
    if (!CloudinaryConfig.isConfigured) {
      throw StateError(
        'Cloudinary chưa được cấu hình. Hãy kiểm tra cloudName.',
      );
    }

    try {
      final user = _requireUser();

      final applicationReference = _firestore
          .collection('providerApplications')
          .doc(user.uid);

      final oldApplication = await applicationReference.get().timeout(_timeout);

      final oldStatus = oldApplication.data()?['status'];

      if (oldStatus == 'pending') {
        throw StateError('Hồ sơ đang chờ xét duyệt.');
      }

      if (oldStatus == 'approved') {
        throw StateError('Tài khoản đã được phê duyệt.');
      }

      final identityFrontUrl = await _uploadImage(
        userId: user.uid,
        documentType: 'identity_front',
        file: identityFront,
      );

      final identityBackUrl = await _uploadImage(
        userId: user.uid,
        documentType: 'identity_back',
        file: identityBack,
      );

      final businessLicenseUrl = await _uploadImage(
        userId: user.uid,
        documentType: 'business_license',
        file: businessLicense,
      );

      final batch = _firestore.batch();

      batch.set(applicationReference, {
        'userId': user.uid,
        'businessName': businessName.trim(),
        'representativeName': representativeName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'address': address.trim(),
        'identityNumber': identityNumber.trim(),
        'identityFrontUrl': identityFrontUrl,
        'identityBackUrl': identityBackUrl,
        'businessLicenseUrl': businessLicenseUrl,
        'status': 'pending',
        'rejectionReason': '',
        'reviewedBy': '',
        'reviewedAt': null,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      batch.update(_firestore.collection('users').doc(user.uid), {
        'providerStatus': 'pending',
      });

      await batch.commit().timeout(_timeout);
    } on TimeoutException {
      throw StateError('Quá thời gian kết nối. Hãy kiểm tra mạng và thử lại.');
    } on FirebaseException catch (error) {
      throw StateError(_firebaseMessage(error));
    }
  }

  Future<String> _uploadImage({
    required String userId,
    required String documentType,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes().timeout(_timeout);

    if (bytes.isEmpty) {
      throw StateError('File ${file.name} không có dữ liệu.');
    }

    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError('Mỗi ảnh phải nhỏ hơn 5 MB.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(CloudinaryConfig.uploadUrl),
    );

    request.fields.addAll({
      'upload_preset': CloudinaryConfig.uploadPreset,
      'folder': 'provider_documents/$userId',
      'tags': 'provider_document,$documentType',
    });

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: file.name),
    );

    final response = await _httpClient.send(request).timeout(_timeout);

    final responseBody = await response.stream.bytesToString().timeout(
      _timeout,
    );

    Map<String, dynamic> decoded;

    try {
      final json = jsonDecode(responseBody);

      if (json is! Map<String, dynamic>) {
        throw const FormatException();
      }

      decoded = json;
    } on FormatException {
      throw StateError('Cloudinary trả về dữ liệu không hợp lệ.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;

      final errorData = decoded['error'];

      if (errorData is Map<String, dynamic>) {
        message = errorData['message']?.toString();
      }

      throw StateError(
        message ??
            'Cloudinary từ chối tải ảnh '
                '(${response.statusCode}).',
      );
    }

    final secureUrl = decoded['secure_url']?.toString();

    if (secureUrl == null || secureUrl.isEmpty) {
      throw StateError('Cloudinary không trả về URL ảnh.');
    }

    return secureUrl;
  }

  String _firebaseMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'Firestore từ chối quyền ghi. '
            'Hãy kiểm tra Firestore Rules.',
      'unauthenticated' =>
        'Phiên đăng nhập đã hết hạn. '
            'Hãy đăng nhập lại.',
      'unavailable' =>
        'Không thể kết nối Firestore. '
            'Hãy kiểm tra mạng.',
      _ =>
        'Lỗi Firebase [${error.code}]: '
            '${error.message ?? 'Không xác định'}',
    };
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn cần đăng nhập để gửi hồ sơ.');
    }

    return user;
  }

  void dispose() {
    _httpClient.close();
  }
}
