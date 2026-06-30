import 'package:flutter/material.dart';

import '../../services/provider_service.dart';

class ProviderOverviewPage extends StatefulWidget {
  const ProviderOverviewPage({
    super.key,
    required this.service,
    required this.onOpenHotels,
    required this.onOpenRooms,
    required this.onOpenBookings,
  });

  final ProviderService service;
  final VoidCallback onOpenHotels;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenBookings;

  @override
  State<ProviderOverviewPage> createState() => _ProviderOverviewPageState();
}

class _ProviderOverviewPageState extends State<ProviderOverviewPage> {
  late Future<ProviderStats> _stats;

  @override
  void initState() {
    super.initState();
    _stats = widget.service.loadStats();
  }

  Future<void> _refresh() async {
    setState(() => _stats = widget.service.loadStats());
    await _stats;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ProviderStats>(
        future: _stats,
        builder: (context, snapshot) {
          final stats = snapshot.data;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
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
                            'Trung tâm điều hành',
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Theo dõi hoạt động kinh doanh và xử lý đơn đặt.',
                            style: TextStyle(color: colors.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.insights_rounded,
                      size: 50,
                      color: colors.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              if (snapshot.hasError)
                Text(
                  'Không thể tải thống kê: ${snapshot.error}',
                  style: TextStyle(color: colors.error),
                ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  _StatCard(
                    label: 'Khách sạn',
                    value: '${stats?.hotels ?? 0}',
                    icon: Icons.apartment_rounded,
                    color: colors.primary,
                  ),
                  _StatCard(
                    label: 'Phòng',
                    value: '${stats?.rooms ?? 0}',
                    icon: Icons.bed_rounded,
                    color: colors.secondary,
                  ),
                  _StatCard(
                    label: 'Đơn chờ',
                    value: '${stats?.pendingBookings ?? 0}',
                    icon: Icons.pending_actions_rounded,
                    color: colors.tertiary,
                  ),
                  _StatCard(
                    label: 'Doanh thu',
                    value: _formatMoney(stats?.revenue ?? 0),
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
                subtitle: 'Thêm và cập nhật thông tin nơi lưu trú',
                onTap: widget.onOpenHotels,
              ),
              _ActionTile(
                icon: Icons.bed_outlined,
                title: 'Danh sách phòng',
                subtitle: 'Quản lý giá và tình trạng phòng',
                onTap: widget.onOpenRooms,
              ),
              _ActionTile(
                icon: Icons.receipt_long_outlined,
                title: 'Đơn đặt phòng',
                subtitle: 'Xác nhận và xử lý yêu cầu mới',
                onTap: widget.onOpenBookings,
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatMoney(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} triệu';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)} nghìn';
    }
    return value.toStringAsFixed(0);
  }
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
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
            Text(label),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}
