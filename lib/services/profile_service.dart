import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/user.dart';

class ProfileService {
  ProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _usersRef {
    return _firestore.collection('users');
  }

  String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  Stream<UserModel?> watchMyProfile() {
    final userId = currentUserId;

    if (userId == null) {
      return Stream.value(null);
    }

    return _usersRef.doc(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return UserModel.fromMap(data);
    }).handleError((error, stackTrace) {
      developer.log(
        'watchMyProfile failed',
        name: 'ProfileService',
        error: error,
        stackTrace: stackTrace,
      );
      throw error;
    });
  }

  Future<UserModel?> getMyProfile() async {
    final userId = currentUserId;

    if (userId == null) return null;

    final doc = await _usersRef.doc(userId).get();
    final data = doc.data();

    if (data == null) return null;

    return UserModel.fromMap(data);
  }

  Future<void> updateProfile({
    required String fullName,
    required String phoneNumber,
    String profilePic = '',
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Bạn cần đăng nhập để cập nhật hồ sơ.');
    }

    final normalizedName = fullName.trim();
    final normalizedPhone = phoneNumber.trim();
    final normalizedProfilePic = profilePic.trim();

    if (normalizedName.length < 2) {
      throw Exception('Họ và tên không hợp lệ.');
    }

    if (!RegExp(r'^[0-9]{9,11}$').hasMatch(normalizedPhone)) {
      throw Exception('Số điện thoại không hợp lệ.');
    }

    await _usersRef.doc(user.uid).set(
      {
        'uid': user.uid,
        'email': user.email ?? '',
        'fullName': normalizedName,
        'phoneNumber': normalizedPhone,
        if (normalizedProfilePic.isNotEmpty) 'profilePic': normalizedProfilePic,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if ((user.displayName ?? '').trim() != normalizedName) {
      await user.updateDisplayName(normalizedName);
    }

    if (normalizedProfilePic.isNotEmpty &&
        (user.photoURL ?? '').trim() != normalizedProfilePic) {
      await user.updatePhotoURL(normalizedProfilePic);
    }
  }

  Future<void> updateProfilePicture(String profilePicUrl) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Bạn cần đăng nhập.');
    }

    final url = profilePicUrl.trim();

    if (url.isEmpty) {
      throw Exception('Đường dẫn ảnh đại diện không hợp lệ.');
    }

    await _usersRef.doc(user.uid).set(
      {
        'profilePic': url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await user.updatePhotoURL(url);
  }

  Future<void> updateNotificationSettings({
    required bool bookingUpdates,
    required bool promotions,
    required bool travelSuggestions,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('Bạn cần đăng nhập.');
    }

    await _usersRef.doc(userId).set(
      {
        'notificationSettings': {
          'bookingUpdates': bookingUpdates,
          'promotions': promotions,
          'travelSuggestions': travelSuggestions,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateSecuritySettings({
    required bool biometricEnabled,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('Bạn cần đăng nhập.');
    }

    await _usersRef.doc(userId).set(
      {
        'securitySettings': {
          'biometricEnabled': biometricEnabled,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> sendPasswordReset() async {
    final email = _auth.currentUser?.email;

    if (email == null || email.trim().isEmpty) {
      throw Exception('Không tìm thấy email tài khoản.');
    }

    await _auth.sendPasswordResetEmail(email: email);
  }
}