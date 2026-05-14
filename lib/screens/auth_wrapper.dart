import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth.dart';
import '../model/user.dart';

// Import các màn hình thực tế đã tạo
import 'auth/login_screen.dart';
import 'customer/home_screen.dart';
import 'provider/dashboard_screen.dart';
// import 'admin/admin_screen.dart'; // Mở ra khi bạn tạo folder admin

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 1. Lắng nghe trạng thái đăng nhập từ Firebase Auth
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // Trạng thái đang tải dữ liệu từ Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Nếu người dùng CHƯA đăng nhập -> Trả về màn hình Đăng nhập
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 3. Nếu ĐÃ đăng nhập -> Dùng FutureBuilder để lấy Role từ Firestore
        return FutureBuilder<UserModel?>(
          future: AuthService().getUserDetails(),
          builder: (context, userSnapshot) {

            // Đang lấy thông tin User (Role) từ Firestore
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Nếu lấy được dữ liệu người dùng thành công
            if (userSnapshot.hasData && userSnapshot.data != null) {
              UserModel user = userSnapshot.data!;

              // --- ĐIỀU HƯỚNG DỰA TRÊN VAI TRÒ (ROLE) ---

              if (user.role == 'admin') {
                // Nếu là Admin -> Vào trang quản trị
                return const Scaffold(
                  body: Center(child: Text("Giao diện Quản trị Admin (Chưa tạo)")),
                );
              }

              else if (user.role == 'provider') {
                // Nếu là Nhà cung cấp -> Vào trang quản lý của họ
                return const ProviderDashboard();
              }

              else {
                // Mặc định (hoặc role 'customer') -> Vào trang khách du lịch
                return const CustomerHomeScreen();
              }
            }

            // Trường hợp lỗi: Đã đăng nhập Auth nhưng không có dữ liệu trong Firestore
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Không tìm thấy dữ liệu người dùng!"),
                    ElevatedButton(
                      onPressed: () => AuthService().signOut(),
                      child: const Text("Đăng xuất và thử lại"),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}