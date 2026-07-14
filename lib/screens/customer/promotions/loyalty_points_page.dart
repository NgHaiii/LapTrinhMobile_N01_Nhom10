import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../model/loyalty_point.dart';
import '../../../model/point_transaction.dart';
import '../../../services/loyalty_service.dart';
import 'widgets/point_summary_card.dart';
import 'widgets/point_transaction_tile.dart';

class LoyaltyPointsPage extends StatelessWidget {
  const LoyaltyPointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = LoyaltyService();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Điểm thưởng')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: StreamBuilder<LoyaltyPointModel?>(
              stream: service.watchMyPoints(),
              builder: (context, snapshot) {
                final point = snapshot.data;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    children: [
                      PointSummaryCard(
                        points: point?.availablePoints ?? 0,
                        tierName: point?.tier.label ?? 'Bronze',
                        usedPoints: point?.usedPoints ?? 0,
                      ),
                      const SizedBox(height: 12),
                      _TierGuide(currentTier: point?.tier ?? LoyaltyTier.bronze),
                    ],
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Lịch sử điểm',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          StreamBuilder<List<PointTransactionModel>>(
            stream: service.watchMyTransactions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
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
                    title: 'Không thể tải lịch sử điểm',
                    message: snapshot.error.toString(),
                  ),
                );
              }

              final transactions = snapshot.data ?? [];

              if (transactions.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.stars_outlined,
                    title: 'Chưa có giao dịch điểm',
                    message: 'Điểm thưởng sẽ được ghi nhận sau khi đặt phòng hoặc đổi voucher.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return PointTransactionTile(
                      transaction: transactions[index],
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

class _TierGuide extends StatelessWidget {
  const _TierGuide({required this.currentTier});

  final LoyaltyTier currentTier;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final tiers = LoyaltyTier.values;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hạng thành viên',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...tiers.map(
              (tier) {
                final active = tier == currentTier;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: active
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                        foregroundColor: active
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                        child: Icon(_iconOf(tier), size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tier.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: active ? colors.primary : colors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _thresholdText(tier),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 18),
            Text(
              'Điểm được cộng khi hoàn thành đặt phòng và có thể dùng để đổi voucher do admin phát hành.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(LoyaltyTier tier) {
    return switch (tier) {
      LoyaltyTier.bronze => Icons.workspace_premium_outlined,
      LoyaltyTier.silver => Icons.military_tech_outlined,
      LoyaltyTier.gold => Icons.emoji_events_outlined,
      LoyaltyTier.diamond => Icons.diamond_outlined,
    };
  }

  static String _thresholdText(LoyaltyTier tier) {
    final formatter = NumberFormat.decimalPattern('vi_VN');

    return switch (tier) {
      LoyaltyTier.bronze => 'Từ 0 điểm',
      LoyaltyTier.silver => 'Từ ${formatter.format(1000)} điểm',
      LoyaltyTier.gold => 'Từ ${formatter.format(5000)} điểm',
      LoyaltyTier.diamond => 'Từ ${formatter.format(15000)} điểm',
    };
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
            Icon(icon, size: 54, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}