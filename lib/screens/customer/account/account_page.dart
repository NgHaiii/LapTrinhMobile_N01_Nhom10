import 'package:flutter/material.dart';

import '../../../services/auth.dart';
import '../../../services/customer_service.dart';
import '../my_bookings_screen.dart';
import '../promotions/loyalty_points_page.dart';
import '../promotions/my_vouchers_page.dart';
import '../promotions/promotions_page.dart';
import '../provider_application_screen.dart';
import 'notification_settings_page.dart';
import 'profile_page.dart';
import 'saved_places_page.dart';
import 'security_settings_page.dart';
import 'support_center_page.dart';

class CustomerAccountPage extends StatelessWidget {
  const CustomerAccountPage({
    super.key,
    required this.service,
  });

  final CustomerService service;

  Future<void> _logout(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (!context.mounted || accepted != true) return;
    await AuthService().signOut();
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      appBar: AppBar(
        title: const Text('Quản lý tài khoản'),
        backgroundColor: const Color(0xFFF4FAF9),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          const _AccountHero(),
          const SizedBox(height: 16),
          const _QuickStats(),
          const SizedBox(height: 20),
          const _SectionTitle(
            title: 'Chuyến đi của bạn',
            subtitle: 'Theo dõi đặt phòng, voucher và điểm thưởng.',
          ),
          const SizedBox(height: 10),
          _ActionCard(
            children: [
              _ActionTile(
                icon: Icons.event_note_rounded,
                title: 'Đơn đặt phòng',
                subtitle: 'Xem lịch sử, trạng thái và chi tiết đơn đặt phòng.',
                color: const Color(0xFF087F8C),
                onTap: () => _push(
                  context,
                  MyBookingsScreen(service: service),
                ),
              ),
              _ActionTile(
                icon: Icons.confirmation_number_rounded,
                title: 'Ưu đãi và voucher',
                subtitle: 'Khám phá ưu đãi, đổi điểm và lưu voucher.',
                color: const Color(0xFFE76F51),
                onTap: () => _push(context, const PromotionsPage()),
              ),
              _ActionTile(
                icon: Icons.card_giftcard_rounded,
                title: 'Voucher của tôi',
                subtitle: 'Quản lý voucher đã lưu, đã dùng và hết hạn.',
                color: const Color(0xFF7A5AF8),
                onTap: () => _push(context, const MyVouchersPage()),
              ),
              _ActionTile(
                icon: Icons.stars_rounded,
                title: 'Điểm thưởng',
                subtitle: 'Xem hạng thành viên và lịch sử tích điểm.',
                color: const Color(0xFF1B7F5A),
                onTap: () => _push(context, const LoyaltyPointsPage()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle(
            title: 'Cá nhân hóa',
            subtitle: 'Lưu địa điểm yêu thích và quản lý hồ sơ của bạn.',
          ),
          const SizedBox(height: 10),
          _ActionCard(
            children: [
              _ActionTile(
                icon: Icons.person_rounded,
                title: 'Thông tin cá nhân',
                subtitle: 'Cập nhật họ tên, số điện thoại và ảnh đại diện.',
                color: const Color(0xFF087F8C),
                onTap: () => _push(context, const ProfilePage()),
              ),
              _ActionTile(
                icon: Icons.favorite_rounded,
                title: 'Địa điểm đã lưu',
                subtitle: 'Xem khách sạn và điểm du lịch yêu thích.',
                color: const Color(0xFF7A5AF8),
                onTap: () => _push(context, const SavedPlacesPage()),
              ),
              _ActionTile(
                icon: Icons.notifications_rounded,
                title: 'Thông báo',
                subtitle: 'Quản lý thông báo đặt phòng và ưu đãi.',
                color: const Color(0xFFE76F51),
                onTap: () => _push(
                  context,
                  const NotificationSettingsPage(),
                ),
              ),
              _ActionTile(
                icon: Icons.security_rounded,
                title: 'Bảo mật',
                subtitle: 'Quản lý đăng nhập, quyền riêng tư và mật khẩu.',
                color: const Color(0xFF0D6EFD),
                onTap: () => _push(context, const SecuritySettingsPage()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle(
            title: 'Dịch vụ và hỗ trợ',
            subtitle: 'Đăng ký kinh doanh hoặc nhận hỗ trợ khi cần.',
          ),
          const SizedBox(height: 10),
          _ActionCard(
            children: [
              _ActionTile(
                icon: Icons.storefront_rounded,
                title: 'Trở thành nhà cung cấp',
                subtitle: 'Đăng ký kinh doanh khách sạn hoặc dịch vụ du lịch.',
                color: const Color(0xFF1B7F5A),
                onTap: () => _push(
                  context,
                  const ProviderApplicationScreen(),
                ),
              ),
              _ActionTile(
                icon: Icons.support_agent_rounded,
                title: 'Trung tâm hỗ trợ',
                subtitle: 'Hỗ trợ đặt phòng, thanh toán và tài khoản.',
                color: const Color(0xFF0D6EFD),
                onTap: () => _push(context, const SupportCenterPage()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB3261E),
                side: const BorderSide(color: Color(0xFFFFDAD6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF073B42),
            Color(0xFF087F8C),
            Color(0xFFE76F51),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F8C).withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -18,
            child: Icon(
              Icons.travel_explore_rounded,
              size: 132,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF087F8C),
                  size: 38,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TravelHub Member',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Quản lý chuyến đi, ưu đãi và hồ sơ cá nhân tại một nơi.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.workspace_premium_rounded,
            label: 'Hạng thành viên',
            value: 'Bronze',
            color: Color(0xFFE76F51),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.stars_rounded,
            label: 'Điểm thưởng',
            value: '0',
            color: Color(0xFF087F8C),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E5E7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF102326),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF647A7D),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF102326),
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF647A7D),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD7E5E7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF102326),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge!,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF647A7D),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF647A7D),
              ),
            ],
          ),
        ),
      ),
    );
  }
}