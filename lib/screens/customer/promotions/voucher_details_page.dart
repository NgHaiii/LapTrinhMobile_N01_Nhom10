import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../model/loyalty_point.dart';
import '../../../model/voucher.dart';
import '../../../services/loyalty_service.dart';
import '../../../services/voucher_service.dart';

class VoucherDetailsPage extends StatefulWidget {
  const VoucherDetailsPage({
    super.key,
    required this.voucherId,
  });

  final String voucherId;

  @override
  State<VoucherDetailsPage> createState() =>
      _VoucherDetailsPageState();
}

class _VoucherDetailsPageState
    extends State<VoucherDetailsPage> {
  final VoucherService _voucherService = VoucherService();
  final LoyaltyService _loyaltyService = LoyaltyService();

  bool _submitting = false;

  Future<void> _redeemVoucher(
    VoucherModel voucher,
  ) async {
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      if (voucher.requiredPoints > 0) {
        await _voucherService.redeemVoucherByPoints(
          voucher,
        );
      } else {
        await _voucherService.claimFreeVoucher(
          voucher,
        );
      }

      if (!mounted) return;

      final message = voucher.requiredPoints > 0
          ? voucher.isNotStarted
              ? 'Đã đổi voucher bằng ${voucher.requiredPoints} điểm. '
                  'Voucher có hiệu lực từ ${_date(voucher.startAt)}.'
              : 'Đã đổi voucher bằng ${voucher.requiredPoints} điểm.'
          : voucher.isNotStarted
              ? 'Đã lưu voucher. Voucher có hiệu lực từ '
                  '${_date(voucher.startAt)}.'
              : 'Đã lưu voucher vào tài khoản.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Chi tiết voucher'),
      ),
      body: FutureBuilder<VoucherModel?>(
        future: _voucherService.getVoucher(
          widget.voucherId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Không thể tải voucher',
              message: _cleanError(snapshot.error),
            );
          }

          final voucher = snapshot.data;

          if (voucher == null) {
            return const _EmptyState(
              icon: Icons.search_off_outlined,
              title: 'Voucher không tồn tại',
              message:
                  'Voucher có thể đã bị xóa hoặc ngừng áp dụng.',
            );
          }

          return StreamBuilder<LoyaltyPointModel?>(
            stream: _loyaltyService.watchMyPoints(),
            builder: (context, pointSnapshot) {
              final availablePoints =
                  pointSnapshot.data?.availablePoints ?? 0;

              final enoughPoints =
                  availablePoints >= voucher.requiredPoints;

              // canClaim cho phép đổi trước ngày áp dụng.
              // Việc sử dụng voucher vẫn được kiểm tra bằng canUse
              // trong VoucherService.
              final canRedeem =
                  voucher.canClaim && enoughPoints;

              final remaining =
                  _remainingQuantity(voucher);

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  24,
                ),
                children: [
                  _VoucherHero(voucher: voucher),
                  const SizedBox(height: 16),

                  if (voucher.isNotStarted)
                    _UpcomingNotice(voucher: voucher),

                  if (voucher.isNotStarted)
                    const SizedBox(height: 16),

                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon:
                            Icons.confirmation_number_outlined,
                        label: 'Mã voucher',
                        value: voucher.code,
                      ),
                      _InfoRow(
                        icon: Icons.discount_outlined,
                        label: 'Giá trị',
                        value: _discountText(voucher),
                      ),
                      _InfoRow(
                        icon:
                            Icons.shopping_bag_outlined,
                        label: 'Đơn tối thiểu',
                        value:
                            voucher.minOrderAmount <= 0
                                ? 'Không yêu cầu'
                                : _money(
                                    voucher.minOrderAmount,
                                  ),
                      ),
                      _InfoRow(
                        icon: Icons.category_outlined,
                        label: 'Áp dụng',
                        value: voucher.target.label,
                      ),
                      _InfoRow(
                        icon: Icons.stars_outlined,
                        label: 'Điểm cần đổi',
                        value:
                            voucher.requiredPoints <= 0
                                ? 'Miễn phí'
                                : '${voucher.requiredPoints} điểm',
                      ),
                      _InfoRow(
                        icon: Icons
                            .account_balance_wallet_outlined,
                        label: 'Điểm của bạn',
                        value: '$availablePoints điểm',
                      ),
                      _InfoRow(
                        icon:
                            Icons.event_available_outlined,
                        label: 'Hiệu lực',
                        value:
                            '${_date(voucher.startAt)} - '
                            '${_date(voucher.endAt)}',
                      ),
                      _InfoRow(
                        icon: voucher.isNotStarted
                            ? Icons.schedule_outlined
                            : Icons
                                .check_circle_outline,
                        label: 'Trạng thái',
                        value: _statusText(voucher),
                      ),
                      _InfoRow(
                        icon:
                            Icons.inventory_2_outlined,
                        label: 'Số lượng còn lại',
                        value: voucher.quantity <= 0
                            ? 'Không giới hạn'
                            : '$remaining',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (voucher.terms.isNotEmpty)
                    _TermsCard(terms: voucher.terms),

                  if (voucher.terms.isNotEmpty)
                    const SizedBox(height: 18),

                  FilledButton.icon(
                    onPressed:
                        canRedeem && !_submitting
                            ? () => _redeemVoucher(
                                  voucher,
                                )
                            : null,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.redeem_outlined,
                          ),
                    label: Text(
                      _buttonLabel(voucher),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _RedeemHint(
                    voucher: voucher,
                    enoughPoints: enoughPoints,
                    remaining: remaining,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _UpcomingNotice extends StatelessWidget {
  const _UpcomingNotice({
    required this.voucher,
  });

  final VoucherModel voucher;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(
          alpha: 0.65,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.schedule_outlined,
              color: colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Voucher chưa đến ngày áp dụng. '
                'Bạn vẫn có thể ${voucher.requiredPoints > 0 ? 'đổi' : 'lưu'} '
                'ngay, nhưng chỉ sử dụng được từ '
                '${_date(voucher.startAt)}.',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherHero extends StatelessWidget {
  const _VoucherHero({
    required this.voucher,
  });

  final VoucherModel voucher;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF087F8C),
            Color(0xFF10B8C6),
            Color(0xFFFFB86B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(
              alpha: 0.22,
            ),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -28,
            child: Icon(
              Icons.local_offer,
              size: 150,
              color: Colors.white.withValues(
                alpha: 0.12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.18,
                    ),
                    borderRadius:
                        BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: 0.28,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Text(
                      voucher.target.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  voucher.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  voucher.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.88,
                    ),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  voucher.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: colors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({
    required this.terms,
  });

  final List<String> terms;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Điều kiện áp dụng',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...terms.map(
              (term) => Padding(
                padding:
                    const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        term,
                        style: TextStyle(
                          color:
                              colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
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
}

class _RedeemHint extends StatelessWidget {
  const _RedeemHint({
    required this.voucher,
    required this.enoughPoints,
    required this.remaining,
  });

  final VoucherModel voucher;
  final bool enoughPoints;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    late final String message;
    late final Color color;

    if (!voucher.isActive) {
      message = 'Voucher đang tạm ngừng.';
      color = colors.error;
    } else if (voucher.isExpired) {
      message = 'Voucher đã hết hạn.';
      color = colors.error;
    } else if (voucher.quantity > 0 &&
        remaining <= 0) {
      message = 'Voucher đã hết số lượng.';
      color = colors.error;
    } else if (!voucher.canClaim) {
      message = 'Voucher hiện không còn khả dụng.';
      color = colors.error;
    } else if (!enoughPoints) {
      message =
          'Bạn chưa đủ ${voucher.requiredPoints} điểm để đổi voucher này.';
      color = colors.error;
    } else if (voucher.isNotStarted &&
        voucher.requiredPoints > 0) {
      message =
          'Bạn có thể đổi ngay bằng ${voucher.requiredPoints} điểm. '
          'Voucher chỉ sử dụng được từ ${_date(voucher.startAt)}.';
      color = colors.primary;
    } else if (voucher.isNotStarted) {
      message =
          'Bạn có thể lưu ngay. Voucher chỉ sử dụng được từ '
          '${_date(voucher.startAt)}.';
      color = colors.primary;
    } else if (voucher.requiredPoints > 0) {
      message =
          '${voucher.requiredPoints} điểm sẽ được trừ ngay khi đổi voucher.';
      color = colors.primary;
    } else {
      message =
          'Lưu voucher vào tài khoản để dùng khi đặt phòng.';
      color = colors.primary;
    }

    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        height: 1.35,
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
            Icon(
              icon,
              size: 54,
              color: colors.primary,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _buttonLabel(VoucherModel voucher) {
  if (voucher.requiredPoints > 0) {
    return 'Đổi bằng ${voucher.requiredPoints} điểm';
  }

  return 'Lưu voucher';
}

String _statusText(VoucherModel voucher) {
  if (!voucher.isActive) {
    return 'Tạm ngừng';
  }

  if (voucher.isExpired) {
    return 'Đã hết hạn';
  }

  if (voucher.isOutOfStock) {
    return 'Đã hết số lượng';
  }

  if (voucher.isNotStarted) {
    return 'Sắp có hiệu lực';
  }

  return 'Đang có hiệu lực';
}

String _discountText(VoucherModel voucher) {
  return switch (voucher.discountType) {
    VoucherDiscountType.percentage =>
      'Giảm ${voucher.discountValue.round()}%',
    VoucherDiscountType.fixed =>
      'Giảm ${_money(voucher.discountValue)}',
  };
}

String _money(num value) {
  final text = value
      .round()
      .toString()
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );

  return '$textđ';
}

String _date(DateTime? value) {
  if (value == null) {
    return 'Không giới hạn';
  }

  return DateFormat('dd/MM/yyyy').format(value);
}

int _remainingQuantity(VoucherModel voucher) {
  if (voucher.quantity <= 0) {
    return 999999;
  }

  return (voucher.quantity - voucher.usedCount)
      .clamp(0, voucher.quantity);
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}