import 'package:flutter/material.dart';

import '../../../model/loyalty_point.dart';
import '../../../model/voucher.dart';
import '../../../services/loyalty_service.dart';
import '../../../services/voucher_service.dart';
import 'loyalty_points_page.dart';
import 'my_vouchers_page.dart';
import 'voucher_details_page.dart';
import 'widgets/point_summary_card.dart';
import 'widgets/voucher_card.dart';
import 'widgets/voucher_filter_bar.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final VoucherService _voucherService = VoucherService();
  final LoyaltyService _loyaltyService = LoyaltyService();

  VoucherTarget? _selectedTarget;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Ưu đãi'),
        actions: [
          IconButton(
            tooltip: 'Voucher của tôi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyVouchersPage()),
              );
            },
            icon: const Icon(Icons.confirmation_number_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: StreamBuilder<LoyaltyPointModel?>(
                stream: _loyaltyService.watchMyPoints(),
                builder: (context, snapshot) {
                  final point = snapshot.data;

                  return PointSummaryCard(
                    points: point?.availablePoints ?? 0,
                    tierName: point?.tier.label ?? 'Bronze',
                    usedPoints: point?.usedPoints ?? 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoyaltyPointsPage(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _QuickAccessCard(
                onMyVouchers: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyVouchersPage()),
                  );
                },
                onPoints: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoyaltyPointsPage(),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: VoucherFilterBar(
              selectedTarget: _selectedTarget,
              onChanged: (value) {
                setState(() => _selectedTarget = value);
              },
            ),
          ),
          StreamBuilder<List<VoucherModel>>(
            stream: _voucherService.watchActiveVouchers(
              target: _selectedTarget,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Không thể tải ưu đãi',
                    message: _cleanError(snapshot.error),
                  ),
                );
              }

              final vouchers = snapshot.data ?? [];

              if (vouchers.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'Chưa có ưu đãi phù hợp',
                    message: 'Voucher mới sẽ được cập nhật tại đây.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverList.separated(
                  itemCount: vouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final voucher = vouchers[index];

                    return VoucherCard(
                      voucher: voucher,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VoucherDetailsPage(
                              voucherId: voucher.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.onMyVouchers,
    required this.onPoints,
  });

  final VoidCallback onMyVouchers;
  final VoidCallback onPoints;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: _QuickButton(
                icon: Icons.confirmation_number_outlined,
                label: 'Voucher của tôi',
                onTap: onMyVouchers,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickButton(
                icon: Icons.stars_outlined,
                label: 'Điểm thưởng',
                onTap: onPoints,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: colors.primary),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
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
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Icon(icon, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}