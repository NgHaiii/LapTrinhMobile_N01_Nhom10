import 'package:flutter/material.dart';

import '../../../model/user_voucher.dart';
import '../../../model/voucher.dart';
import '../../../services/voucher_service.dart';
import 'widgets/user_voucher_card.dart';

class SelectVoucherResult {
  const SelectVoucherResult({
    required this.userVoucher,
    required this.voucher,
    required this.discountAmount,
  });

  final UserVoucherModel userVoucher;
  final VoucherModel voucher;
  final double discountAmount;
}

class SelectVoucherPage extends StatefulWidget {
  const SelectVoucherPage({
    super.key,
    required this.orderAmount,
    this.target = VoucherTarget.booking,
    this.service,
    this.selectedUserVoucherId = '',
    this.allowRemove = true,
  });

  final double orderAmount;
  final VoucherTarget target;
  final VoucherService? service;
  final String selectedUserVoucherId;
  final bool allowRemove;

  @override
  State<SelectVoucherPage> createState() => _SelectVoucherPageState();
}

class _SelectVoucherPageState extends State<SelectVoucherPage> {
  late final VoucherService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? VoucherService();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF3FBF8),
      appBar: AppBar(
        title: const Text('Săn ưu đãi'),
        backgroundColor: const Color(0xFFF3FBF8),
        actions: [
          if (widget.allowRemove)
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Bỏ chọn'),
            ),
        ],
      ),
      body: Column(
        children: [
          _HeroHeader(orderAmount: widget.orderAmount),
          Expanded(
            child: StreamBuilder<List<UserVoucherModel>>(
              stream: _service.watchMyUsableVouchers(
                target: widget.target,
                orderAmount: widget.orderAmount,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Không thể tải voucher',
                    message: _cleanError(snapshot.error),
                  );
                }

                final userVouchers = snapshot.data ?? [];

                if (userVouchers.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Chưa có deal phù hợp',
                    message:
                        'Lưu voucher ở trang Ưu đãi hoặc đổi điểm thưởng để chuyến đi nhẹ ví hơn.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: userVouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final userVoucher = userVouchers[index];

                    return FutureBuilder<VoucherModel?>(
                      future: _service.getVoucher(userVoucher.voucherId),
                      builder: (context, voucherSnapshot) {
                        if (voucherSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !voucherSnapshot.hasData) {
                          return const _LoadingVoucherCard();
                        }

                        final voucher = voucherSnapshot.data;

                        if (voucher == null || !voucher.canUse) {
                          return const SizedBox.shrink();
                        }

                        if (voucher.target != VoucherTarget.all &&
                            voucher.target != widget.target) {
                          return const SizedBox.shrink();
                        }

                        final discount = voucher
                            .calculateDiscount(widget.orderAmount)
                            .clamp(0, widget.orderAmount)
                            .toDouble();

                        if (discount <= 0) return const SizedBox.shrink();

                        return UserVoucherCard(
                          userVoucher: userVoucher,
                          voucher: voucher,
                          discountAmount: discount,
                          selected:
                              userVoucher.id == widget.selectedUserVoucherId,
                          onTap: () {
                            Navigator.pop(
                              context,
                              SelectVoucherResult(
                                userVoucher: userVoucher,
                                voucher: voucher,
                                discountAmount: discount,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.orderAmount});

  final double orderAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF008C95),
            Color(0xFF17C5B5),
            Color(0xFFFFC56E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF008C95).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -22,
            child: Icon(
              Icons.flight_takeoff_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            right: 28,
            bottom: 14,
            child: Icon(
              Icons.beach_access_rounded,
              size: 46,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.local_activity_rounded, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn deal cho chuyến đi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Đơn hiện tại ${_money(orderAmount)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _LoadingVoucherCard extends StatelessWidget {
  const _LoadingVoucherCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(26),
        child: Center(child: CircularProgressIndicator()),
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
            CircleAvatar(
              radius: 38,
              backgroundColor: const Color(0xFFA7F3F7),
              foregroundColor: colors.primary,
              child: Icon(icon, size: 38),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _money(num value) {
  final raw = value.round().toString();

  return '${raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  )}đ';
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}