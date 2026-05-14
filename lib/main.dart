import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

// ĐÃ THÊM: Import bộ điều hướng phân quyền
import 'screens/auth_wrapper.dart';

void main() async {
  // Đảm bảo Flutter đã sẵn sàng để gọi Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase từ file cấu hình tự động
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hệ thống Quản lý Du lịch - Nhóm 10',
      theme: ThemeData(
        useMaterial3: true,
        // Sử dụng màu xanh Teal đặc trưng cho ngành du lịch & khách sạn
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal,
        ),
        // Sử dụng Google Fonts để giao diện app du lịch hiện đại hơn
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
      ),

      // CHỈNH SỬA QUAN TRỌNG:
      // Không gọi SplashScreen nữa mà gọi AuthWrapper để nó tự động
      // kiểm tra Login và Phân Quyền ngay khi mở App.
      home: const AuthWrapper(),
    );
  }
}