import 'package:flutter/material.dart';

import '../../../model/user_voucher.dart';
import '../../../services/voucher_service.dart';

class MyVouchersPage extends StatefulWidget {
  const MyVouchersPage({super.key});

  @override
  State<MyVouchersPage> createState() => _MyVouchersPageState();
}

class _MyVouchersPageState extends State<MyVouchersPage> {
  final VoucherService _voucherService = VoucherService();

  UserVoucherStatus? _status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Voucher của tôi')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: _status == null,
                  onTap: () => setState(() => _status = null),
                ),
                _FilterChip(
                  label: 'Khả dụng',
                  selected: _status == UserVoucherStatus.available,
                  onTap: () {
                    setState(() => _status = UserVoucherStatus.available);
                  },
                ),
                _FilterChip(
                  label: 'Đã dùng',
                  selected: _status == UserVoucherStatus.used,
                  onTap: () => setState(() => _status = UserVoucherStatus.used),
                ),
                _FilterChip(
                  label: 'Hết hạn',
                  selected: _status == UserVoucherStatus.expired,
                  onTap: () {
                    setState(() => _status = UserVoucherStatus.expired);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserVoucherModel>>(
              stream: _voucherService.watchMyVouchers(status: _status),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Không thể tải voucher',
                    message: snapshot.error.toString(),
                  );
                }

                final vouchers = snapshot.data ?? [];

                if (vouchers.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Chưa có voucher',
                    message: 'Bạn có thể đổi điểm hoặc lưu ưu đãi tại trang ưu đãi.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: vouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _UserVoucherCard(voucher: vouchers[index]);
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

class _UserVoucherCard extends StatelessWidget {
  const _UserVoucherCard({required this.voucher});

  final UserVoucherModel voucher;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (voucher.status) {
      UserVoucherStatus.available => colors.primary,
      UserVoucherStatus.used => colors.outline,
      UserVoucherStatus.expired => colors.error,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: statusColor.withValues(alpha: 0.14),
              foregroundColor: statusColor,
              child: const Icon(Icons.confirmation_number_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    voucher.code,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (voucher.redeemedByPoints) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Đã đổi bằng ${voucher.pointsSpent} điểm',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                child: Text(
                  voucher.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onTap(),
        selectedColor: colors.primaryContainer,
        labelStyle: TextStyle(
          color: selected ? colors.onPrimaryContainer : colors.onSurface,
          fontWeight: FontWeight.w800,
        ),
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
            Icon(icon, size: 54, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}