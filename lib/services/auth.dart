import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/user.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Future<String> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    UserCredential? credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = UserModel(
        uid: credential.user!.uid,
        email: email.trim().toLowerCase(),
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
      );

      await _firestore.collection('users').doc(user.uid).set(user.toMap());

      return 'success';
    } on FirebaseAuthException catch (error) {
      return _authMessage(error);
    } catch (error) {
      // Tránh tài khoản Auth tồn tại nhưng thiếu hồ sơ Firestore.
      await credential?.user?.delete();
      return 'Không thể tạo hồ sơ người dùng: $error';
    }
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return 'success';
    } on FirebaseAuthException catch (error) {
      return _authMessage(error);
    } catch (_) {
      return 'Không thể đăng nhập. Vui lòng thử lại.';
    }
  }

  Future<void> signOut() => _auth.signOut();

  Stream<UserModel?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : UserModel.fromMap(data);
    });
  }

  Future<UserModel?> getUserDetails() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final data = snapshot.data();

    return data == null ? null : UserModel.fromMap(data);
  }

  String _authMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Email không hợp lệ.',
      'email-already-in-use' => 'Email đã được sử dụng.',
      'weak-password' => 'Mật khẩu phải có ít nhất 6 ký tự.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email hoặc mật khẩu không chính xác.',
      'user-disabled' => 'Tài khoản đã bị khóa.',
      'too-many-requests' => 'Bạn thao tác quá nhiều lần. Hãy thử lại sau.',
      _ => error.message ?? 'Đã xảy ra lỗi xác thực.',
    };
  }
}
