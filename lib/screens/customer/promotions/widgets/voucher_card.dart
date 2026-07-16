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

    // canClaim cho phép voucher chưa đến ngày áp dụng
    // vẫn hiển thị và được nhận/đổi.
    final claimable = voucher.canClaim;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: claimable
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
              constraints: const BoxConstraints(
                minHeight: 142,
              ),
              decoration: BoxDecoration(
                color: claimable
                    ? colors.primary
                    : colors.outline,
                borderRadius:
                    const BorderRadius.horizontal(
                  left: Radius.circular(22),
                ),
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    color: colors.onPrimary,
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                    ),
                    child: Text(
                      _discountText(voucher),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 15,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  13,
                  12,
                  13,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TargetBadge(
                          target: voucher.target,
                        ),
                        const Spacer(),
                        _VoucherStatusBadge(
                          voucher: voucher,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      voucher.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: claimable
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
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
                          icon: Icons
                              .confirmation_number_outlined,
                          text: voucher.code,
                        ),
                        _MiniInfo(
                          icon:
                              Icons.shopping_bag_outlined,
                          text: voucher.minOrderAmount <= 0
                              ? 'Không yêu cầu đơn tối thiểu'
                              : 'Tối thiểu '
                                  '${_money(voucher.minOrderAmount)}',
                        ),

                        // Hiển thị ngày bắt đầu nếu voucher
                        // chưa đến thời gian áp dụng.
                        if (voucher.isNotStarted)
                          _MiniInfo(
                            icon:
                                Icons.schedule_outlined,
                            text: voucher.startAt == null
                                ? 'Sắp áp dụng'
                                : 'Dùng từ '
                                    '${DateFormat('dd/MM').format(voucher.startAt!)}',
                            color: colors.tertiary,
                          ),

                        _MiniInfo(
                          icon: Icons.event_outlined,
                          text: voucher.endAt == null
                              ? 'Không giới hạn'
                              : 'Đến '
                                  '${DateFormat('dd/MM').format(voucher.endAt!)}',
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

  static String _discountText(
    VoucherModel voucher,
  ) {
    return switch (voucher.discountType) {
      VoucherDiscountType.percentage =>
        '-${voucher.discountValue.round()}%',
      VoucherDiscountType.fixed =>
        '-${_shortMoney(voucher.discountValue)}',
    };
  }

  static String _shortMoney(num value) {
    if (value >= 1000000) {
      final million = value / 1000000;
      final digits =
          million == million.roundToDouble() ? 0 : 1;

      return '${million.toStringAsFixed(digits)}tr';
    }

    if (value >= 1000) {
      return '${(value / 1000).round()}k';
    }

    return value.round().toString();
  }

  static String _money(num value) {
    final text = value
        .round()
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );

    return '$textđ';
  }
}

class _VoucherStatusBadge extends StatelessWidget {
  const _VoucherStatusBadge({
    required this.voucher,
  });

  final VoucherModel voucher;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (!voucher.isActive) {
      return _StatusBadge(
        text: 'Tạm ngừng',
        color: colors.outline,
      );
    }

    if (voucher.isExpired) {
      return _StatusBadge(
        text: 'Hết hạn',
        color: colors.error,
      );
    }

    if (voucher.isOutOfStock) {
      return _StatusBadge(
        text: 'Hết lượt',
        color: colors.error,
      );
    }

    // Voucher chưa đến ngày vẫn hiển thị số điểm
    // vì khách được phép đổi trước.
    if (voucher.requiredPoints > 0) {
      return _StatusBadge(
        text: '${voucher.requiredPoints} điểm',
        color: colors.tertiary,
      );
    }

    return _StatusBadge(
      text: 'Miễn phí',
      color: colors.primary,
    );
  }
}

class _TargetBadge extends StatelessWidget {
  const _TargetBadge({
    required this.target,
  });

  final VoucherTarget target;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(
          alpha: 0.72,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
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

  static String _targetLabel(
    VoucherTarget target,
  ) {
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
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
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
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foregroundColor =
        color ?? colors.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color ?? colors.primary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}