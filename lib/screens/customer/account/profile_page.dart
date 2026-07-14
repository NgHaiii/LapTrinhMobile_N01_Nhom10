import 'package:flutter/material.dart';

import '../../../model/user.dart';
import '../../../services/profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.service,
  });

  final ProfileService? service;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileService _service;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _profilePicController = TextEditingController();

  bool _saving = false;
  bool _filledInitialData = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProfileService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _profilePicController.dispose();
    super.dispose();
  }

  void _fillInitialData(UserModel user) {
    if (_filledInitialData) return;

    _nameController.text = user.fullName;
    _phoneController.text = user.phoneNumber;
    _profilePicController.text = user.profilePic;
    _filledInitialData = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await _service.updateProfile(
        fullName: _nameController.text,
        phoneNumber: _phoneController.text,
        profilePic: _profilePicController.text,
      );

      if (!mounted) return;

      _message('Đã cập nhật hồ sơ.');
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
        title: const Text('Thông tin cá nhân'),
        backgroundColor: const Color(0xFFF4FAF9),
      ),
      body: StreamBuilder<UserModel?>(
        stream: _service.watchMyProfile(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          if (snapshot.connectionState == ConnectionState.waiting &&
              user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Không thể tải hồ sơ',
              message: _cleanError(snapshot.error),
            );
          }

          if (user == null) {
            return const _EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Không tìm thấy hồ sơ',
              message: 'Vui lòng đăng nhập lại để tiếp tục.',
            );
          }

          _fillInitialData(user);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              _ProfileHero(user: user),
              const SizedBox(height: 18),
              DecoratedBox(
                decoration: _cardDecoration(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) {
                            if ((value?.trim().length ?? 0) < 2) {
                              return 'Vui lòng nhập họ và tên';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: user.email,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) {
                            final phone = (value ?? '').replaceAll(
                              RegExp(r'\s+'),
                              '',
                            );

                            if (!RegExp(r'^[0-9]{9,11}$').hasMatch(phone)) {
                              return 'Số điện thoại không hợp lệ';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _profilePicController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Ảnh đại diện URL',
                            prefixIcon: Icon(Icons.image_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _saving ? 'Đang lưu...' : 'Lưu thay đổi',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final avatar = user.profilePic.trim();

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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F8C).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          _AvatarPreview(avatarUrl: avatar),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? 'TravelHub Member' : user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isEmpty) {
      return const CircleAvatar(
        radius: 34,
        backgroundColor: Colors.white,
        child: Icon(
          Icons.person_outline_rounded,
          color: Color(0xFF087F8C),
          size: 36,
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: 68,
        height: 68,
        child: Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const ColoredBox(
              color: Colors.white,
              child: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF087F8C),
                size: 36,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: const Color(0xFF087F8C)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF647A7D)),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0xFFD7E5E7)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.045),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}