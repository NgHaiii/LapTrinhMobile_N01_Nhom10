import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../model/voucher.dart';

class VoucherCard extends StatelessWidget {
  const VoucherCard({
    super.key,
    required this.voucher,
    this.onTap,
  });

  final VoucherModel voucher;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = voucher.canUse;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: available
                ? colors.primary.withValues(alpha: 0.35)
                : colors.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 86,
              height: 142,
              decoration: BoxDecoration(
                color: available ? colors.primary : colors.outline,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(22),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    color: colors.onPrimary,
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _discountText(voucher),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 15,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TargetBadge(target: voucher.target),
                        const Spacer(),
                        if (!available)
                          _StatusBadge(
                            text: 'Hết hạn',
                            color: colors.error,
                          )
                        else if (voucher.requiredPoints > 0)
                          _StatusBadge(
                            text: '${voucher.requiredPoints} điểm',
                            color: colors.tertiary,
                          )
                        else
                          _StatusBadge(
                            text: 'Miễn phí',
                            color: colors.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      voucher.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      voucher.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _MiniInfo(
                          icon: Icons.confirmation_number_outlined,
                          text: voucher.code,
                        ),
                        _MiniInfo(
                          icon: Icons.shopping_bag_outlined,
                          text: 'Tối thiểu ${_money(voucher.minOrderAmount)}',
                        ),
                       _MiniInfo(
  icon: Icons.event_outlined,
  text: voucher.endAt == null
      ? 'Không giới hạn'
      : 'Đến ${DateFormat('dd/MM').format(voucher.endAt!)}',
),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _discountText(VoucherModel voucher) {
    return switch (voucher.discountType) {
      VoucherDiscountType.percentage => '-${voucher.discountValue.round()}%',
      VoucherDiscountType.fixed => '-${_shortMoney(voucher.discountValue)}',
    };
  }

  static String _shortMoney(num value) {
    if (value >= 1000000) {
      final million = value / 1000000;
      return '${million.toStringAsFixed(million == million.roundToDouble() ? 0 : 1)}tr';
    }

    if (value >= 1000) {
      return '${(value / 1000).round()}k';
    }

    return value.round().toString();
  }

  static String _money(num value) {
    final text = value.round().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );

    return '$textđ';
  }
}

class _TargetBadge extends StatelessWidget {
  const _TargetBadge({required this.target});

  final VoucherTarget target;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          _targetLabel(target),
          style: TextStyle(
            color: colors.onPrimaryContainer,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  static String _targetLabel(VoucherTarget target) {
    return switch (target) {
      VoucherTarget.booking => 'Đặt phòng',
      VoucherTarget.travelActivity => 'Du lịch',
      VoucherTarget.all => 'Tất cả',
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
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
        Icon(icon, size: 14, color: colors.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}