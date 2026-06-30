import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  late Future<_ProviderStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_ProviderStats> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _ProviderStats();

    final firestore = FirebaseFirestore.instance;

    final results = await Future.wait([
      firestore.collection('hotels').where('providerId', isEqualTo: uid).get(),
      firestore.collection('rooms').where('providerId', isEqualTo: uid).get(),
      firestore
          .collection('bookings')
          .where('providerId', isEqualTo: uid)
          .get(),
    ]);

    final bookings = results[2].docs;
    double revenue = 0;

    for (final booking in bookings) {
      final data = booking.data();
      final status = data['status'];
      final amount = data['totalAmount'];

      if ((status == 'completed' || status == 'confirmed') && amount is num) {
        revenue += amount.toDouble();
      }
    }

    return _ProviderStats(
      hotels: results[0].docs.length,
      rooms: results[1].docs.length,
      bookings: bookings.length,
      revenue: revenue,
    );
  }

  Future<void> _refresh() async {
    setState(() => _statsFuture = _loadStats());
    await _statsFuture;
  }

  void _showUnavailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature đang được hoàn thiện')));
  }

  void _showCreateMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.apartment_rounded),
                  title: const Text('Thêm khách sạn'),
                  subtitle: const Text('Tạo địa điểm lưu trú mới'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showUnavailable(context, 'Quản lý khách sạn');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bed_rounded),
                  title: const Text('Thêm phòng'),
                  subtitle: const Text('Thêm phòng vào khách sạn'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showUnavailable(context, 'Quản lý phòng');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trung tâm đối tác'),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            onSelected: (value) {
              if (value == 'logout') AuthService().signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Đăng xuất'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ProviderStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            final stats = snapshot.data ?? const _ProviderStats();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tổng quan hôm nay',
                              style: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Theo dõi hoạt động kinh doanh của bạn.',
                              style: TextStyle(
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.insights_rounded,
                        size: 48,
                        color: colors.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Không thể tải thống kê: ${snapshot.error}',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _StatCard(
                      label: 'Khách sạn',
                      value: '${stats.hotels}',
                      icon: Icons.apartment_rounded,
                      color: colors.primary,
                    ),
                    _StatCard(
                      label: 'Phòng',
                      value: '${stats.rooms}',
                      icon: Icons.bed_rounded,
                      color: colors.secondary,
                    ),
                    _StatCard(
                      label: 'Đơn đặt',
                      value: '${stats.bookings}',
                      icon: Icons.event_available_rounded,
                      color: colors.tertiary,
                    ),
                    _StatCard(
                      label: 'Doanh thu',
                      value: _formatMoney(stats.revenue),
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF2E7D32),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  'Quản lý nhanh',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.apartment_outlined,
                  title: 'Khách sạn của tôi',
                  subtitle: 'Thông tin, hình ảnh và trạng thái hoạt động',
                  onTap: () => _showUnavailable(context, 'Quản lý khách sạn'),
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.bed_outlined,
                  title: 'Danh sách phòng',
                  subtitle: 'Giá phòng, tiện nghi và tình trạng phòng',
                  onTap: () => _showUnavailable(context, 'Quản lý phòng'),
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Đơn đặt phòng',
                  subtitle: 'Xác nhận và cập nhật trạng thái đơn',
                  onTap: () => _showUnavailable(context, 'Quản lý đơn đặt'),
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.reviews_outlined,
                  title: 'Đánh giá khách hàng',
                  subtitle: 'Theo dõi phản hồi về dịch vụ',
                  onTap: () => _showUnavailable(context, 'Quản lý đánh giá'),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateMenu,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm mới'),
      ),
    );
  }

  String _formatMoney(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}tr';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }
}

class _ProviderStats {
  const _ProviderStats({
    this.hotels = 0,
    this.rooms = 0,
    this.bookings = 0,
    this.revenue = 0,
  });

  final int hotels;
  final int rooms;
  final int bookings;
  final double revenue;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: colors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
