import 'package:flutter/material.dart';import '../../services/auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    setState(() => _isLoading = true);

    String? result = await AuthService().signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result == "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đăng ký thành công!")),
      );
      Navigator.pop(context); // Quay lại trang Login
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi: $result")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đăng ký tài khoản")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Họ và tên")),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Số điện thoại")),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Mật khẩu"), obscureText: true),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text("Đăng ký ngay"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}