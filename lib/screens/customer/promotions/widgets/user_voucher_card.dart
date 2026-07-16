import 'package:flutter/material.dart';

import '../../../../model/user_voucher.dart';
import '../../../../model/voucher.dart';

class UserVoucherCard extends StatelessWidget {
  const UserVoucherCard({
    super.key,
    required this.userVoucher,
    this.voucher,
    this.discountAmount = 0,
    this.selected = false,
    this.onTap,
    this.showStatus = true,
  });

  final UserVoucherModel userVoucher;
  final VoucherModel? voucher;
  final double discountAmount;
  final bool selected;
  final VoidCallback? onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context, userVoucher.status);
    final canTap = onTap != null;
    final accent = _accentForVoucher(voucher);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: canTap ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: selected
                  ? [
                      const Color(0xFFE3FBFF),
                      const Color(0xFFFFF4D9),
                    ]
                  : [
                      Colors.white,
                      accent.withValues(alpha: 0.10),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: selected ? const Color(0xFF008C95) : accent.withValues(alpha: 0.22),
              width: selected ? 1.7 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: selected ? 0.22 : 0.10),
                blurRadius: selected ? 22 : 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -18,
                child: Icon(
                  Icons.airplane_ticket_rounded,
                  size: 96,
                  color: accent.withValues(alpha: 0.10),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 12,
                child: Icon(
                  _travelIcon(voucher),
                  size: 34,
                  color: accent.withValues(alpha: 0.18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TicketIcon(
                      color: accent,
                      statusColor: statusColor,
                      status: userVoucher.status,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: _VoucherContent(
                        userVoucher: userVoucher,
                        voucher: voucher,
                        discountAmount: discountAmount,
                        showStatus: showStatus,
                        statusColor: statusColor,
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF008C95),
                      )
                    else if (canTap)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF25646B),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketIcon extends StatelessWidget {
  const _TicketIcon({
    required this.color,
    required this.statusColor,
    required this.status,
  });

  final Color color;
  final Color statusColor;
  final UserVoucherStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.confirmation_number_rounded,
            color: color,
            size: 30,
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                _statusIcon(status),
                size: 14,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherContent extends StatelessWidget {
  const _VoucherContent({
    required this.userVoucher,
    required this.voucher,
    required this.discountAmount,
    required this.showStatus,
    required this.statusColor,
    required this.accent,
  });

  final UserVoucherModel userVoucher;
  final VoucherModel? voucher;
  final double discountAmount;
  final bool showStatus;
  final Color statusColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = voucher?.title.trim().isNotEmpty == true
        ? voucher!.title
        : userVoucher.title;
    final description = voucher?.description.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Pill(
              text: userVoucher.code,
              color: accent,
              filled: true,
            ),
            if (voucher != null)
              _Pill(
                text: voucher!.target.label,
                color: const Color(0xFFE76F51),
              ),
            if (showStatus)
              _Pill(
                text: userVoucher.statusLabel,
                color: statusColor,
              ),
          ],
        ),
        const SizedBox(height: 9),
        if (discountAmount > 0)
          _DiscountLine(
            text: 'Tiết kiệm ${_money(discountAmount)} cho chuyến này',
            color: accent,
          )
        else if (voucher != null)
          _DiscountLine(
            text: voucher!.discountLabel,
            color: accent,
          ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ],
        const SizedBox(height: 7),
        Text(
          _statusDescription(userVoucher),
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (userVoucher.redeemedByPoints) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.stars_rounded,
                size: 15,
                color: const Color(0xFFFFB000),
              ),
              const SizedBox(width: 4),
              Text(
                'Đã đổi bằng ${userVoucher.pointsSpent} điểm',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DiscountLine extends StatelessWidget {
  const _DiscountLine({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.savings_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    this.filled = false,
  });

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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

Color _statusColor(BuildContext context, UserVoucherStatus status) {
  final colors = Theme.of(context).colorScheme;

  return switch (status) {
    UserVoucherStatus.available => const Color(0xFF008C95),
    UserVoucherStatus.reserved => const Color(0xFFFF9F1C),
    UserVoucherStatus.used => colors.outline,
    UserVoucherStatus.expired => colors.error,
  };
}

IconData _statusIcon(UserVoucherStatus status) {
  return switch (status) {
    UserVoucherStatus.available => Icons.card_giftcard_rounded,
    UserVoucherStatus.reserved => Icons.lock_clock_rounded,
    UserVoucherStatus.used => Icons.task_alt_rounded,
    UserVoucherStatus.expired => Icons.event_busy_rounded,
  };
}

IconData _travelIcon(VoucherModel? voucher) {
  return switch (voucher?.target) {
    VoucherTarget.travelActivity => Icons.terrain_rounded,
    VoucherTarget.booking => Icons.hotel_rounded,
    VoucherTarget.all => Icons.travel_explore_rounded,
    null => Icons.flight_takeoff_rounded,
  };
}

Color _accentForVoucher(VoucherModel? voucher) {
  return switch (voucher?.target) {
    VoucherTarget.travelActivity => const Color(0xFF2A9D8F),
    VoucherTarget.booking => const Color(0xFF008C95),
    VoucherTarget.all => const Color(0xFFE76F51),
    null => const Color(0xFF008C95),
  };
}

String _statusDescription(UserVoucherModel voucher) {
  if (voucher.isExpired) {
    return 'Voucher đã hết hạn sử dụng.';
  }

  return switch (voucher.status) {
    UserVoucherStatus.available => 'Sẵn sàng áp dụng cho hành trình tiếp theo.',
    UserVoucherStatus.reserved => voucher.bookingId.trim().isEmpty
        ? 'Đang được giữ cho một đơn đặt phòng.'
        : 'Đang giữ cho đơn ${_shortCode(voucher.bookingId)}.',
    UserVoucherStatus.used => voucher.bookingId.trim().isEmpty
        ? 'Voucher đã được sử dụng.'
        : 'Đã dùng cho đơn ${_shortCode(voucher.bookingId)}.',
    UserVoucherStatus.expired => 'Voucher đã hết hạn sử dụng.',
  };
}

String _shortCode(String id) {
  final value = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

  if (value.length <= 8) return value;
  return value.substring(value.length - 8);
}

String _money(num value) {
  final raw = value.round().toString();

  return '${raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  )}đ';
}