import 'package:flutter/material.dart';

import '../../../services/profile_service.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({
    super.key,
    this.service,
  });

  final ProfileService? service;

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  late final ProfileService _service;

  bool _biometricEnabled = false;
  bool _saving = false;
  bool _sendingReset = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProfileService();
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      await _service.updateSecuritySettings(
        biometricEnabled: _biometricEnabled,
      );

      if (!mounted) return;
      _message('Đã lưu cài đặt bảo mật.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_sendingReset) return;

    setState(() => _sendingReset = true);

    try {
      await _service.sendPasswordReset();

      if (!mounted) return;
      _message('Đã gửi email đặt lại mật khẩu.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      appBar: AppBar(
        title: const Text('Bảo mật'),
        backgroundColor: const Color(0xFFF4FAF9),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          const _HeroCard(
            icon: Icons.security_rounded,
            title: 'Bảo vệ tài khoản',
            subtitle: 'Quản lý đăng nhập, mật khẩu và quyền riêng tư.',
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                SwitchListTile(
                  value: _biometricEnabled,
                  onChanged: (value) {
                    setState(() => _biometricEnabled = value);
                  },
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: const Text('Đăng nhập sinh trắc học'),
                  subtitle: const Text('Tính năng mô phỏng, có thể tích hợp thật sau.'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0F7F6),
                    foregroundColor: Color(0xFF087F8C),
                    child: Icon(Icons.lock_reset_rounded),
                  ),
                  title: const Text(
                    'Đặt lại mật khẩu',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text('Gửi email đặt lại mật khẩu đến tài khoản của bạn.'),
                  trailing: _sendingReset
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _sendingReset ? null : _sendPasswordReset,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Đang lưu...' : 'Lưu cài đặt'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF073B42),
            Color(0xFF087F8C),
            Color(0xFF42D8C8),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF087F8C),
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0xFFD7E5E7)),
  );
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}