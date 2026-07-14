import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../model/point_transaction.dart';

class PointTransactionTile extends StatelessWidget {
  const PointTransactionTile({
    super.key,
    required this.transaction,
  });

  final PointTransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPositive = transaction.points >= 0;
    final color = isPositive ? colors.primary : colors.error;
    final formatter = NumberFormat.decimalPattern('vi_VN');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.13),
              foregroundColor: color,
              child: Icon(_iconOf(transaction.type)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isEmpty
                        ? _typeLabel(transaction.type)
                        : transaction.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    children: [
                      _MetaText(
                        icon: Icons.category_outlined,
                        text: _sourceLabel(transaction.source),
                      ),
                      _MetaText(
  icon: Icons.schedule_outlined,
  text: transaction.createdAt == null
      ? 'Chưa có thời gian'
      : DateFormat('HH:mm dd/MM/yyyy').format(transaction.createdAt!),
),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${isPositive ? '+' : ''}${formatter.format(transaction.points)}',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(PointTransactionType type) {
    return switch (type) {
      PointTransactionType.earn => Icons.add_circle_outline,
      PointTransactionType.redeem => Icons.redeem_outlined,
      PointTransactionType.expire => Icons.timer_off_outlined,
      PointTransactionType.adjust => Icons.tune_outlined,
    };
  }

  static String _typeLabel(PointTransactionType type) {
    return switch (type) {
      PointTransactionType.earn => 'Cộng điểm',
      PointTransactionType.redeem => 'Đổi điểm',
      PointTransactionType.expire => 'Điểm hết hạn',
      PointTransactionType.adjust => 'Điều chỉnh điểm',
    };
  }

  static String _sourceLabel(PointTransactionSource source) {
    return switch (source) {
      PointTransactionSource.booking => 'Đặt phòng',
      PointTransactionSource.voucher => 'Voucher',
      PointTransactionSource.admin => 'Admin',
      PointTransactionSource.system => 'Hệ thống',
    };
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}