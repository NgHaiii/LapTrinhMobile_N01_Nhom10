import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../model/user.dart';
import '../services/auth.dart';
import 'admin/admin_dashboard.dart';
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
          return const _LoadingScreen(
            message: 'Đang kiểm tra phiên đăng nhập...',
          );
        }

        if (authSnapshot.hasError) {
          return _ErrorScreen(
            message:
                'Không thể kiểm tra đăng nhập: '
                '${authSnapshot.error}',
          );
        }

        final firebaseUser = authSnapshot.data;

        if (firebaseUser == null) {
          return const LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen(
                message: 'Đang tải thông tin tài khoản...',
              );
            }

            if (userSnapshot.hasError) {
              return _ErrorScreen(
                message:
                    'Không thể tải tài khoản: '
                    '${userSnapshot.error}',
              );
            }

            final document = userSnapshot.data;
            final data = document?.data();

            if (document == null || !document.exists || data == null) {
              return const _MissingProfileScreen();
            }

            final isActive = data['isActive'] != false;

            if (!isActive) {
              return const _BlockedAccountScreen();
            }

            final user = UserModel.fromMap(data);

            return switch (user.role) {
              UserRole.admin => const AdminDashboard(),
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
  const _LoadingScreen({required this.message});

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
              const SizedBox.square(
                dimension: 34,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: 34,
                    color: colors.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Không thể tải ứng dụng',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: AuthService().signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingProfileScreen extends StatelessWidget {
  const _MissingProfileScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined, size: 64, color: colors.error),
                const SizedBox(height: 18),
                Text(
                  'Không tìm thấy hồ sơ',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tài khoản đã tồn tại trong Firebase Authentication '
                  'nhưng chưa có document tương ứng trong Firestore.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: AuthService().signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockedAccountScreen extends StatelessWidget {
  const _BlockedAccountScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lock_person_outlined,
                    size: 38,
                    color: colors.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tài khoản đã bị khóa',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tài khoản của bạn đang bị tạm khóa. '
                  'Vui lòng liên hệ quản trị viên để được hỗ trợ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: AuthService().signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Quay lại đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
