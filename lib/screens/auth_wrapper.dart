import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../model/user.dart';
import '../services/auth.dart';
import 'auth/login_screen.dart';
import 'customer/home_screen.dart';
import 'provider/dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) return const LoginScreen();

        return StreamBuilder<UserModel?>(
          stream: AuthService().watchUser(firebaseUser.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (userSnapshot.hasError) {
              return _ErrorScreen(message: userSnapshot.error.toString());
            }

            final user = userSnapshot.data;
            if (user == null) {
              return const _ErrorScreen(
                message: 'Không tìm thấy hồ sơ người dùng.',
              );
            }

            return switch (user.role) {
              UserRole.admin => const _AdminPlaceholder(),
              UserRole.provider => const ProviderDashboard(),
              UserRole.customer => const CustomerHomeScreen(),
            };
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: AuthService().signOut,
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPlaceholder extends StatelessWidget {
  const _AdminPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản trị hệ thống'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: AuthService().signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Text('Trang quản trị sẽ được bổ sung ở phần tiếp theo.'),
      ),
    );
  }
}
