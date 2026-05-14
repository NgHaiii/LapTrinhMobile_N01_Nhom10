import 'package:flutter/material.dart';
import '../../services/auth.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    String? result = await AuthService().login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (result != "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi đăng nhập: $result")),
      );
    }
    // Nếu thành công, AuthWrapper sẽ tự động chuyển màn hình
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hotel, size: 100, color: Colors.teal),
            const Text("APP DU LỊCH NHÓM 10", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Mật khẩu"), obscureText: true),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text("Đăng nhập"),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
              child: const Text("Chưa có tài khoản? Đăng ký ngay"),
            ),
          ],
        ),
      ),
    );
  }
}