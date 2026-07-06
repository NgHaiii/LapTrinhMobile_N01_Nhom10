import 'package:flutter/material.dart';

import '../../../model/review.dart';
import '../../../model/violation_record.dart';
import '../../../services/violation_service.dart';

class AdminReviewStatistics extends StatefulWidget {
  const AdminReviewStatistics({
    super.key,
    required this.reviews,
    this.violationService,
  });

  final List<ReviewModel> reviews;
  final ViolationService? violationService;

  @override
  State<AdminReviewStatistics> createState() =>
      _AdminReviewStatisticsState();
}

class _AdminReviewStatisticsState
    extends State<AdminReviewStatistics> {
  late ViolationService _violationService;

  @override
  void initState() {
    super.initState();

    _violationService =
        widget.violationService ??
            ViolationService();
  }

  @override
  void didUpdateWidget(
    covariant AdminReviewStatistics oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.violationService !=
        oldWidget.violationService) {
      _violationService =
          widget.violationService ??
              ViolationService();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ViolationRecord>>(
      stream:
          _violationService.watchAllViolations(),
      builder: (context, snapshot) {
        final reviewIds = widget.reviews
            .map((review) => review.id)
            .toSet();

        final relatedViolations =
            (snapshot.data ?? []).where((violation) {
          return reviewIds.contains(
            violation.reviewId,
          );
        }).toList();

        return _StatisticsContent(
          reviews: widget.reviews,
          violations: relatedViolations,
          loading:
              snapshot.connectionState ==
                      ConnectionState.waiting &&
                  !snapshot.hasData,
          hasViolationError: snapshot.hasError,
        );
      },
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({
    required this.reviews,
    required this.violations,
    required this.loading,
    required this.hasViolationError,
  });

  final List<ReviewModel> reviews;
  final List<ViolationRecord> violations;
  final bool loading;
  final bool hasViolationError;

  @override
  Widget build(BuildContext context) {
    final critical = reviews.where((review) {
      return review.severity ==
              ReviewSeverity.critical &&
          !_isClosed(review);
    }).length;

    final needsAction = reviews.where((review) {
      return !_isClosed(review) &&
          (review.moderationStatus ==
                  ReviewModerationStatus
                      .pendingReview ||
              review.moderationStatus ==
                  ReviewModerationStatus
                      .investigating ||
              review.moderationStatus ==
                  ReviewModerationStatus
                      .providerContacted);
    }).length;

    final providerAction = reviews.where((review) {
      return review.providerActionRequired &&
          !_isClosed(review);
    }).length;

    final penalized = violations.where((violation) {
      return violation.status ==
              ViolationStatus.confirmed ||
          violation.status == ViolationStatus.paid;
    }).length;

    final acceptedExplanation =
        violations.where((violation) {
      return violation.status ==
          ViolationStatus.noPenalty;
    }).length;

    final resolved = reviews.where((review) {
      return review.moderationStatus ==
              ReviewModerationStatus.resolved ||
          review.moderationStatus ==
              ReviewModerationStatus.dismissed;
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
        icon: Icons.gavel_outlined,
        label: 'Đã phạt 5%',
        value: penalized,
        color: const Color(0xFFB3261E),
        loading: loading,
      ),
      _StatisticData(
        icon: Icons.verified_outlined,
        label: 'Chấp nhận giải trình',
        value: acceptedExplanation,
        color: const Color(0xFF15803D),
        loading: loading,
      ),
      _StatisticData(
        icon: Icons.task_alt_outlined,
        label: 'Đã xử lý',
        value: resolved,
        color: const Color(0xFF0369A1),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 900
                    ? 3
                    : 2;

            const spacing = 10.0;

            final width =
                (constraints.maxWidth -
                        spacing * (columns - 1)) /
                    columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: statistics.map((statistic) {
                return SizedBox(
                  width: width,
                  height: 116,
                  child: _StatItem(
                    data: statistic,
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (hasViolationError) ...[
          const SizedBox(height: 8),
          Text(
            'Không thể tải kết quả xử lý biên bản.',
            style: TextStyle(
              color:
                  Theme.of(context).colorScheme.error,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatisticData {
  const _StatisticData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final bool loading;
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
          border: Border.all(
            color: colors.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: data.color.withValues(
                        alpha: 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      data.icon,
                      size: 21,
                      color: data.color,
                    ),
                  ),
                  const Spacer(),
                  if (data.loading)
                    SizedBox.square(
                      dimension: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: data.color,
                      ),
                    )
                  else
                    Text(
                      '${data.value}',
                      style: TextStyle(
                        color: data.color,
                        fontSize: 24,
                        fontWeight:
                            FontWeight.w900,
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