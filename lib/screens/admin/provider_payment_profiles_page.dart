import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../model/provider_payment_profile.dart';
import '../../services/admin_service.dart';

class ProviderPaymentProfilesPage extends StatefulWidget {
  const ProviderPaymentProfilesPage({super.key});

  @override
  State<ProviderPaymentProfilesPage> createState() =>
      _ProviderPaymentProfilesPageState();
}

class _ProviderPaymentProfilesPageState
    extends State<ProviderPaymentProfilesPage> {
  final AdminService _service = AdminService();

  String _status = 'pending';
  String? _processingId;

  Future<void> _approve(
    ProviderPaymentProfile profile,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.verified_outlined),
          title: const Text('Xác minh tài khoản?'),
          content: Text(
            '${profile.bankName}\n'
            '${profile.accountNumber}\n'
            '${profile.accountName}\n\n'
            'Sau khi xác minh, nhà cung cấp có thể '
            'nhận thanh toán VietQR.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Xác minh'),
            ),
          ],
        );
      },
    );

    if (!mounted || accepted != true) return;

    setState(() => _processingId = profile.providerId);

    try {
      await _service.approvePaymentProfile(
        profile.providerId,
      );

      if (!mounted) return;
      _message('Đã xác minh tài khoản ngân hàng.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _reject(
    ProviderPaymentProfile profile,
  ) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.cancel_outlined),
          title: const Text('Từ chối tài khoản'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Lý do từ chối',
              hintText:
                  'Ví dụ: Tên chủ tài khoản không khớp hồ sơ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                controller.text,
              ),
              child: const Text('Từ chối'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || reason == null) return;

    setState(() => _processingId = profile.providerId);

    try {
      await _service.rejectPaymentProfile(
        profile.providerId,
        reason,
      );

      if (!mounted) return;
      _message('Đã từ chối thông tin ngân hàng.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  void _showDetails(ProviderPaymentProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              4,
              24,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.account_balance_rounded,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  profile.businessName.isEmpty
                      ? 'Nhà cung cấp'
                      : profile.businessName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 20),
                _DetailRow(
                  label: 'Mã nhà cung cấp',
                  value: profile.providerId,
                ),
                _DetailRow(
                  label: 'Ngân hàng',
                  value: profile.bankName,
                ),
                _DetailRow(
                  label: 'Mã ngân hàng',
                  value: profile.bankCode,
                ),
                _DetailRow(
                  label: 'BIN',
                  value: profile.bankBin,
                ),
                _DetailRow(
                  label: 'Số tài khoản',
                  value: profile.accountNumber,
                ),
                _DetailRow(
                  label: 'Chủ tài khoản',
                  value: profile.accountName,
                ),
                _DetailRow(
                  label: 'Trạng thái',
                  value: profile.statusLabel,
                ),
                if (profile.rejectionReason.isNotEmpty)
                  _DetailRow(
                    label: 'Lý do từ chối',
                    value: profile.rejectionReason,
                  ),
                if (profile.verificationStatus ==
                        PaymentProfileStatus.pending ||
                    profile.verificationStatus ==
                        PaymentProfileStatus.rejected) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _reject(profile);
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                          label: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _approve(profile);
                          },
                          icon: const Icon(
                            Icons.verified_outlined,
                          ),
                          label: const Text('Xác minh'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác minh ngân hàng'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 58,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('all', 'Tất cả'),
                _filterChip('pending', 'Chờ xác minh'),
                _filterChip('approved', 'Đã xác minh'),
                _filterChip('rejected', 'Bị từ chối'),
                _filterChip(
                  'not_submitted',
                  'Chưa cung cấp',
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>
            >(
              stream: _service.watchPaymentProfiles(
                status: _status,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      _cleanError(snapshot.error),
                    ),
                  );
                }

                final profiles = (snapshot.data?.docs ?? [])
                    .map(
                      (document) =>
                          ProviderPaymentProfile.fromMap(
                            document.data(),
                            document.id,
                          ),
                    )
                    .toList()
                  ..sort((first, second) {
                    final firstTime =
                        first.updatedAt
                            ?.millisecondsSinceEpoch ??
                        0;

                    final secondTime =
                        second.updatedAt
                            ?.millisecondsSinceEpoch ??
                        0;

                    return secondTime.compareTo(firstTime);
                  });

                if (profiles.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    28,
                  ),
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final profile = profiles[index];

                    return _ProfileCard(
                      profile: profile,
                      processing:
                          _processingId == profile.providerId,
                      onTap: () => _showDetails(profile),
                      onApprove: () => _approve(profile),
                      onReject: () => _reject(profile),
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

  Widget _filterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 8,
        top: 10,
        bottom: 8,
      ),
      child: ChoiceChip(
        label: Text(label),
        selected: _status == value,
        onSelected: (_) {
          setState(() => _status = value);
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.processing,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  final ProviderPaymentProfile profile;
  final bool processing;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(
      profile.verificationStatus,
    );

    final canReview =
        profile.verificationStatus ==
            PaymentProfileStatus.pending ||
        profile.verificationStatus ==
            PaymentProfileStatus.rejected;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    child: Icon(
                      profile.isVerified
                          ? Icons.account_balance_rounded
                          : Icons.account_balance_outlined,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.businessName.isEmpty
                              ? 'Nhà cung cấp'
                              : profile.businessName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(profile.bankName),
                        Text(
                          '${profile.accountNumber} · '
                          '${profile.accountName}',
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    label: profile.statusLabel,
                    color: color,
                  ),
                ],
              ),
              if (processing) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ] else if (canReview) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                        label: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(
                          Icons.verified_outlined,
                        ),
                        label: const Text('Xác minh'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value.isEmpty ? 'Chưa cập nhật' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_outlined, size: 58),
          SizedBox(height: 10),
          Text('Không có tài khoản phù hợp'),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    PaymentProfileStatus.approved => Colors.green,
    PaymentProfileStatus.pending => Colors.orange,
    PaymentProfileStatus.rejected => Colors.red,
    _ => Colors.grey,
  };
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}