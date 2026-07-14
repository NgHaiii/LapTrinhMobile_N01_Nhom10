import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const promoItems = [
    _PromoItem(
      imageAsset: 'assets/images/auth/auth_bg.jpg',
      title: 'Create your travel profile',
      subtitle: 'Lưu thông tin, đặt phòng và theo dõi đơn dễ dàng.',
    ),
    _PromoItem(
      imageAsset: 'assets/images/auth/auth_bg_2.jpg',
      title: 'Book premium stays',
      subtitle: 'Linh hoạt theo giờ, theo ngày và theo chuyến đi.',
    ),
    _PromoItem(
      imageAsset: 'assets/images/auth/auth_bg_3.jpg',
      title: 'Become a service partner',
      subtitle: 'Sau đăng ký, bạn có thể gửi yêu cầu trở thành đối tác.',
    ),
  ];

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final result = await AuthService().signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == 'success') {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _PremiumBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _TopBar(),
                        const SizedBox(height: 16),
                        const _PremiumHeader(),
                        const SizedBox(height: 18),
                        const _LuxuryPromoCarousel(
                          items: RegisterScreen.promoItems,
                        ),
                        const SizedBox(height: 18),
                        _RegisterCard(
                          formKey: _formKey,
                          nameController: _nameController,
                          emailController: _emailController,
                          phoneController: _phoneController,
                          passwordController: _passwordController,
                          confirmController: _confirmController,
                          hidePassword: _hidePassword,
                          isLoading: _isLoading,
                          onTogglePassword: () {
                            setState(() {
                              _hidePassword = !_hidePassword;
                            });
                          },
                          onRegister: _register,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Sau khi đăng ký, bạn có thể hoàn thiện hồ sơ và gửi yêu cầu trở thành nhà cung cấp dịch vụ.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF647A7D),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7FBFA),
                  Color(0xFFEAF6F4),
                  Color(0xFFFFF7EC),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -90,
          child: _SoftGlow(
            color: const Color(0xFF087F8C).withOpacity(0.16),
            size: 230,
          ),
        ),
        Positioned(
          bottom: 180,
          left: -110,
          child: _SoftGlow(
            color: const Color(0xFFE76F51).withOpacity(0.14),
            size: 250,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 90,
              spreadRadius: 36,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton.filledTonal(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF087F8C),
                Color(0xFF13A8B5),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF087F8C).withOpacity(0.28),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              Icons.travel_explore_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TravelHub',
                style: TextStyle(
                  color: Color(0xFF102326),
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Join premium travel network',
                style: TextStyle(
                  color: Color(0xFF647A7D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PromoItem {
  const _PromoItem({
    required this.imageAsset,
    required this.title,
    required this.subtitle,
  });

  final String imageAsset;
  final String title;
  final String subtitle;
}

class _LuxuryPromoCarousel extends StatefulWidget {
  const _LuxuryPromoCarousel({required this.items});

  final List<_PromoItem> items;

  @override
  State<_LuxuryPromoCarousel> createState() => _LuxuryPromoCarouselState();
}

class _LuxuryPromoCarouselState extends State<_LuxuryPromoCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.91);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final selected = index == _index;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 7,
                    right: 7,
                    top: selected ? 0 : 12,
                    bottom: selected ? 0 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B2E32).withOpacity(
                          selected ? 0.18 : 0.08,
                        ),
                        blurRadius: selected ? 32 : 18,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                item.imageAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF087F8C),
                                          Color(0xFF13A8B5),
                                          Color(0xFFFFB86B),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.10),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.18),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 14,
                                left: 14,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 12,
                                      sigmaY: 12,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.82),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.workspace_premium_rounded,
                                              color: Color(0xFFE76F51),
                                              size: 17,
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              'Premium access',
                                              style: TextStyle(
                                                color: Color(0xFF102326),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: 14,
                                bottom: 14,
                                child: _ImageStatsPill(),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF102326),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF647A7D),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (index) {
              final selected = index == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 26 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF087F8C)
                      : const Color(0xFFC7D8DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ImageStatsPill extends StatelessWidget {
  const _ImageStatsPill();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.38),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Color(0xFFFFC857),
                  size: 17,
                ),
                SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '24/7',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmController,
    required this.hidePassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool hidePassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2E32).withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tạo tài khoản',
                style: TextStyle(
                  color: Color(0xFF102326),
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bắt đầu đặt phòng và quản lý hành trình cá nhân.',
                style: TextStyle(
                  color: Color(0xFF647A7D),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              _PremiumInput(
                controller: nameController,
                label: 'Họ và tên',
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if ((value?.trim().length ?? 0) < 2) {
                    return 'Vui lòng nhập họ và tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PremiumInput(
                controller: emailController,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Vui lòng nhập email';
                  if (!email.contains('@')) return 'Email không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PremiumInput(
                controller: phoneController,
                label: 'Số điện thoại',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final phone = (value ?? '').replaceAll(RegExp(r'\s+'), '');
                  if (!RegExp(r'^[0-9]{9,11}$').hasMatch(phone)) {
                    return 'Số điện thoại không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PremiumInput(
                controller: passwordController,
                label: 'Mật khẩu',
                icon: Icons.lock_outline_rounded,
                obscureText: hidePassword,
                textInputAction: TextInputAction.next,
                suffixIcon: IconButton(
                  tooltip: hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: onTogglePassword,
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if ((value?.length ?? 0) < 6) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PremiumInput(
                controller: confirmController,
                label: 'Nhập lại mật khẩu',
                icon: Icons.verified_user_outlined,
                obscureText: hidePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onRegister(),
                validator: (value) {
                  if (value != passwordController.text) {
                    return 'Mật khẩu nhập lại không khớp';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _GradientButton(
                loading: isLoading,
                label: isLoading ? 'Đang tạo tài khoản...' : 'Tạo tài khoản',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: isLoading ? null : onRegister,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumInput extends StatelessWidget {
  const _PremiumInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF102326),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF7FBFA),
        prefixIconColor: const Color(0xFF087F8C),
        suffixIconColor: const Color(0xFF38565A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD7E5E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD7E5E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF087F8C), width: 2),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.loading,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [
                  Color(0xFF087F8C),
                  Color(0xFF13A8B5),
                ],
              ),
        color: onPressed == null ? const Color(0xFFC7D8DB) : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF087F8C).withOpacity(0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: SizedBox(
        height: 54,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Icon(icon, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}