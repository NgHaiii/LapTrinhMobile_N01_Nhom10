import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. ĐĂNG KÝ (Mặc định khi đăng ký tài khoản mới luôn là 'customer')
  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    try {
      // Tạo tài khoản trên Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Tạo đối tượng UserModel để lưu thông tin bổ sung vào Firestore
      UserModel newUser = UserModel(
        uid: credential.user!.uid,
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        role: 'customer', // Mặc định là khách hàng du lịch
      );

      // Lưu dữ liệu vào collection 'users'
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(newUser.toMap());

      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  // 2. ĐĂNG NHẬP
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  // 3. ĐĂNG XUẤT (Thêm mới theo yêu cầu của bạn)
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print("Lỗi khi đăng xuất: $e");
    }
  }

  // 4. NÂNG CẤP TÀI KHOẢN LÊN PROVIDER (Chủ khách sạn)
  // Hàm này sẽ được gọi sau khi khách hàng hoàn tất thủ tục cung cấp thông tin kinh doanh
  Future<String?> updateRoleToProvider() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'role': 'provider',
        });
        return "success";
      }
      return "User not logged in";
    } catch (e) {
      return e.toString();
    }
  }

  // 5. LẤY THÔNG TIN USER CHI TIẾT (Để kiểm tra Role khi điều hướng)
  Future<UserModel?> getUserDetails() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot snap =
        await _firestore.collection('users').doc(currentUser.uid).get();
        if (snap.exists) {
          return UserModel.fromMap(snap.data() as Map<String, dynamic>);
        }
      }
    } catch (e) {
      print("Lỗi lấy dữ liệu người dùng: $e");
    }
    return null;
  }
}
