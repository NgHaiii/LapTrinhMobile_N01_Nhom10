import 'package:flutter/material.dart';
import '../../services/auth.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khám Phá Du Lịch'),
        backgroundColor: Colors.teal.shade200,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(), // Nút đăng xuất để test AuthWrapper
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Xin chào Khách hàng!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            // Nơi đây sẽ hiển thị danh sách khách sạn sau này
            const Center(
              child: Text("Giao diện dành cho người tìm đặt phòng"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Sau này sẽ làm chức năng nâng cấp tài khoản ở đây
                print("Mở trang đăng ký làm nhà cung cấp");
              },
              child: const Text("Bắt đầu kinh doanh với chúng tôi?"),
            )
          ],
        ),
      ),
    );
  }
}