import 'package:flutter/material.dart';

import '../../../model/review.dart';

enum ReviewAdminAction {
  investigate,
  contactProvider,
  resolve,
  dismiss,
  hide,
  publish,
}

class AdminReviewAlertCard extends StatelessWidget {
  const AdminReviewAlertCard({
    super.key,
    required this.review,
    required this.processing,
    required this.onAction,
  });

  final ReviewModel review;
  final bool processing;
  final ValueChanged<ReviewAdminAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final severityColor = _severityColor(review.severity);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 5,
            color: severityColor,
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: severityColor.withValues(
                        alpha: 0.13,
                      ),
                      foregroundColor: severityColor,
                      child: Icon(
                        _severityIcon(review.severity),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.hotelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${review.roomType} · '
                            'Phòng ${review.roomNumber}',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SeverityBadge(
                      severity: review.severity,
                    ),
                    PopupMenuButton<ReviewAdminAction>(
                      enabled: !processing,
                      tooltip: 'Thao tác quản trị',
                      onSelected: onAction,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: ReviewAdminAction.investigate,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.manage_search_outlined,
                            ),
                            title: Text('Bắt đầu xác minh'),
                          ),
                        ),
                        const PopupMenuItem(
                          value:
                              ReviewAdminAction.contactProvider,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.storefront_outlined,
                            ),
                            title: Text(
                              'Yêu cầu nhà cung cấp xử lý',
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: ReviewAdminAction.resolve,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.task_alt_outlined,
                            ),
                            title: Text('Đánh dấu đã xử lý'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: ReviewAdminAction.dismiss,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.remove_done_outlined,
                            ),
                            title: Text(
                              'Không ghi nhận vi phạm',
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: review.isPublished
                              ? ReviewAdminAction.hide
                              : ReviewAdminAction.publish,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              review.isPublished
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            title: Text(
                              review.isPublished
                                  ? 'Ẩn đánh giá'
                                  : 'Hiện lại đánh giá',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stars(rating: review.rating),
                    const SizedBox(width: 7),
                    Text(
                      '${review.rating}/5',
                      style: TextStyle(
                        color: severityColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(
                      status: review.moderationStatus,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  review.comment,
                  style: const TextStyle(height: 1.45),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _InfoChip(
                      icon: Icons.person_outline,
                      label: review.customerName,
                    ),
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: _date(review.createdAt),
                    ),
                    if (review.providerActionRequired)
                      const _InfoChip(
                        icon: Icons.priority_high_rounded,
                        label: 'Yêu cầu nhà cung cấp xử lý',
                        warning: true,
                      ),
                    if (!review.isPublished)
                      const _InfoChip(
                        icon: Icons.visibility_off_outlined,
                        label: 'Đang bị ẩn',
                        warning: true,
                      ),
                  ],
                ),
                if (review.hasProviderReply) ...[
                  const SizedBox(height: 13),
                  DecoratedBox(
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
                          const Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Phản hồi nhà cung cấp',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(review.providerReply),
                        ],
                      ),
                    ),
                  ),
                ],
                if (review.adminNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 19,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              review.adminNote,
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (processing) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(severity);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Text(
          _severityLabel(severity),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 5,
        ),
        child: Text(
          _statusLabel(status),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          size: 19,
          color: Colors.amber.shade700,
        );
      }),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final color = warning
        ? colors.error
        : colors.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: warning
            ? colors.errorContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _severityColor(String severity) {
  return switch (severity) {
    ReviewSeverity.critical => const Color(0xFFB3261E),
    ReviewSeverity.high => const Color(0xFFD94F3D),
    ReviewSeverity.warning => const Color(0xFFD98E04),
    _ => const Color(0xFF1B7F5A),
  };
}

IconData _severityIcon(String severity) {
  return switch (severity) {
    ReviewSeverity.critical => Icons.crisis_alert_rounded,
    ReviewSeverity.high => Icons.warning_amber_rounded,
    ReviewSeverity.warning => Icons.info_outline_rounded,
    _ => Icons.check_circle_outline_rounded,
  };
}

String _severityLabel(String severity) {
  return switch (severity) {
    ReviewSeverity.critical => 'NGHIÊM TRỌNG',
    ReviewSeverity.high => 'MỨC CAO',
    ReviewSeverity.warning => 'CẦN LƯU Ý',
    _ => 'BÌNH THƯỜNG',
  };
}

String _statusLabel(String status) {
  return switch (status) {
    ReviewModerationStatus.pendingReview => 'Chờ xem xét',
    ReviewModerationStatus.investigating => 'Đang xác minh',
    ReviewModerationStatus.providerContacted =>
      'Đã liên hệ NCC',
    ReviewModerationStatus.resolved => 'Đã xử lý',
    ReviewModerationStatus.dismissed => 'Không vi phạm',
    _ => 'Không cần xử lý',
  };
}

String _date(DateTime? value) {
  if (value == null) return 'Chưa rõ';

  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');

  return '$day/$month/${value.year}';
}