import 'package:flutter/material.dart';

import '../../../model/review.dart';

class AdminReviewStatistics extends StatelessWidget {
  const AdminReviewStatistics({
    super.key,
    required this.reviews,
  });

  final List<ReviewModel> reviews;

  @override
  Widget build(BuildContext context) {
    final critical = reviews.where((review) {
      return review.severity == ReviewSeverity.critical &&
          !_isClosed(review);
    }).length;

    final needsAction = reviews.where((review) {
      return !_isClosed(review) &&
          (review.moderationStatus ==
                  ReviewModerationStatus.pendingReview ||
              review.moderationStatus ==
                  ReviewModerationStatus.investigating ||
              review.moderationStatus ==
                  ReviewModerationStatus.providerContacted);
    }).length;

    final providerAction = reviews.where((review) {
      return review.providerActionRequired && !_isClosed(review);
    }).length;

    final resolved = reviews.where((review) {
      return review.moderationStatus ==
          ReviewModerationStatus.resolved;
    }).length;

    final statistics = [
      _StatisticData(
        icon: Icons.crisis_alert_outlined,
        label: 'Nghiêm trọng',
        value: critical,
        color: const Color(0xFFB3261E),
      ),
      _StatisticData(
        icon: Icons.pending_actions_outlined,
        label: 'Cần xử lý',
        value: needsAction,
        color: const Color(0xFFD35400),
      ),
      _StatisticData(
        icon: Icons.storefront_outlined,
        label: 'Chờ nhà cung cấp',
        value: providerAction,
        color: const Color(0xFF8A5A00),
      ),
      _StatisticData(
        icon: Icons.task_alt_outlined,
        label: 'Đã xử lý',
        value: resolved,
        color: const Color(0xFF1B7F5A),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        const spacing = 10.0;

        final availableWidth =
            constraints.maxWidth - spacing * (columns - 1);
        final itemWidth = availableWidth / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: statistics.map((statistic) {
            return SizedBox(
              width: itemWidth,
              height: 116,
              child: _StatItem(data: statistic),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatisticData {
  const _StatisticData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.data,
  });

  final _StatisticData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: '${data.label}: ${data.value}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      data.icon,
                      size: 21,
                      color: data.color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${data.value}',
                    style: TextStyle(
                      color: data.color,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isClosed(ReviewModel review) {
  return review.moderationStatus ==
          ReviewModerationStatus.resolved ||
      review.moderationStatus ==
          ReviewModerationStatus.dismissed;
}