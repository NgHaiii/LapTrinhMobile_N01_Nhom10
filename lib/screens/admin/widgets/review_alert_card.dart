import 'package:flutter/material.dart';

import '../../../model/review.dart';

enum ReviewAdminAction {
  investigate,
  contactProvider,
  resolve,
  dismiss,
  hide,
  publish,
  createViolation,
  viewViolation,
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

  bool get _canCreateViolation {
    return review.severity == ReviewSeverity.critical &&
        !review.hasViolationRecord &&
        review.moderationStatus !=
            ReviewModerationStatus.dismissed;
  }

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
                _buildHeader(context, severityColor),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Stars(rating: review.rating),
                    Text(
                      '${review.rating}/5',
                      style: TextStyle(
                        color: severityColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _SeverityBadge(
                      severity: review.severity,
                    ),
                    _StatusBadge(
                      status: review.moderationStatus,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
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
                    if (review.hasViolationRecord)
                      const _InfoChip(
                        icon: Icons.gavel_outlined,
                        label: 'Đã có biên bản',
                        warning: true,
                      ),
                  ],
                ),
                if (review.hasProviderReply) ...[
                  const SizedBox(height: 13),
                  _MessageBox(
                    icon: Icons.storefront_outlined,
                    title: 'Phản hồi nhà cung cấp',
                    content: review.providerReply,
                    color: colors.surfaceContainerLow,
                    foreground: colors.onSurface,
                  ),
                ],
                if (review.adminNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _MessageBox(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Ghi chú quản trị',
                    content: review.adminNote,
                    color: colors.secondaryContainer
                        .withValues(alpha: 0.55),
                    foreground: colors.onSecondaryContainer,
                  ),
                ],
                if (_canCreateViolation ||
                    review.hasViolationRecord) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: review.hasViolationRecord
                        ? OutlinedButton.icon(
                            onPressed: processing
                                ? null
                                : () => onAction(
                                      ReviewAdminAction
                                          .viewViolation,
                                    ),
                            icon:
                                const Icon(Icons.gavel_outlined),
                            label:
                                const Text('Xem biên bản vi phạm'),
                          )
                        : FilledButton.icon(
                            onPressed: processing
                                ? null
                                : () => onAction(
                                      ReviewAdminAction
                                          .createViolation,
                                    ),
                            icon: const Icon(
                              Icons.add_moderator_outlined,
                            ),
                            label: const Text(
                              'Lập biên bản vi phạm',
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

  Widget _buildHeader(
    BuildContext context,
    Color severityColor,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor:
              severityColor.withValues(alpha: 0.13),
          foregroundColor: severityColor,
          child: Icon(_severityIcon(review.severity)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                review.hotelName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${review.roomType} • '
                'Phòng ${review.roomNumber}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<ReviewAdminAction>(
          enabled: !processing,
          tooltip: 'Thao tác quản trị',
          onSelected: onAction,
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: ReviewAdminAction.investigate,
              child: _MenuItem(
                icon: Icons.manage_search_outlined,
                label: 'Bắt đầu xác minh',
              ),
            ),
            const PopupMenuItem(
              value: ReviewAdminAction.contactProvider,
              child: _MenuItem(
                icon: Icons.storefront_outlined,
                label: 'Yêu cầu nhà cung cấp xử lý',
              ),
            ),
            if (_canCreateViolation)
              const PopupMenuItem(
                value: ReviewAdminAction.createViolation,
                child: _MenuItem(
                  icon: Icons.gavel_outlined,
                  label: 'Lập biên bản vi phạm',
                ),
              ),
            if (review.hasViolationRecord)
              const PopupMenuItem(
                value: ReviewAdminAction.viewViolation,
                child: _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Xem biên bản vi phạm',
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: ReviewAdminAction.resolve,
              child: _MenuItem(
                icon: Icons.task_alt_outlined,
                label: 'Đánh dấu đã xử lý',
              ),
            ),
            const PopupMenuItem(
              value: ReviewAdminAction.dismiss,
              child: _MenuItem(
                icon: Icons.remove_done_outlined,
                label: 'Không ghi nhận vi phạm',
              ),
            ),
            PopupMenuItem(
              value: review.isPublished
                  ? ReviewAdminAction.hide
                  : ReviewAdminAction.publish,
              child: _MenuItem(
                icon: review.isPublished
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                label: review.isPublished
                    ? 'Ẩn đánh giá'
                    : 'Hiện lại đánh giá',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
    required this.foreground,
  });

  final IconData icon;
  final String title;
  final String content;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            content,
            style: TextStyle(
              color: foreground,
              height: 1.4,
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _severityLabel(severity),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _statusLabel(status),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
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
    final color =
        warning ? colors.error : colors.onSurfaceVariant;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: warning
            ? colors.errorContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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