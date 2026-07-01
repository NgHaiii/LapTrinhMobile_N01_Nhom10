import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/commission_invoice.dart';
import '../../services/commission_service.dart';

class ProviderCommissionPage extends StatefulWidget {
  const ProviderCommissionPage({super.key});

  @override
  State<ProviderCommissionPage> createState() =>
      _ProviderCommissionPageState();
}

class _ProviderCommissionPageState
    extends State<ProviderCommissionPage> {
  final CommissionService _service = CommissionService();

  String _filter = 'all';

  void _openPayment(CommissionInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CommissionPaymentScreen(
          service: _service,
          invoice: invoice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoa hồng ứng dụng'),
      ),
      body: StreamBuilder<List<CommissionInvoice>>(
        stream: _service.watchMyInvoices(),
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
              child: Text(_cleanError(snapshot.error)),
            );
          }

          final allInvoices = snapshot.data ?? [];

          final invoices = _filter == 'all'
              ? allInvoices
              : allInvoices.where((invoice) {
                  if (_filter == 'unpaid') {
                    return invoice.status ==
                            CommissionStatus.unpaid ||
                        invoice.status ==
                            CommissionStatus.overdue ||
                        invoice.status ==
                            CommissionStatus.rejected;
                  }

                  return invoice.status == _filter;
                }).toList();

          final totalRevenue = allInvoices.fold<double>(
            0,
            (total, invoice) =>
                total + invoice.grossRevenue,
          );

          final totalCommission = allInvoices.fold<double>(
            0,
            (total, invoice) =>
                total + invoice.effectiveCommissionAmount,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  10,
                ),
                child: _Summary(
                  revenue: totalRevenue,
                  commission: totalCommission,
                ),
              ),
              SizedBox(
                height: 55,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip('all', 'Tất cả'),
                    _filterChip('unpaid', 'Chưa thanh toán'),
                    _filterChip(
                      CommissionStatus.paymentReview,
                      'Đang kiểm tra',
                    ),
                    _filterChip(
                      CommissionStatus.paid,
                      'Đã thanh toán',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: invoices.isEmpty
                    ? const _EmptyInvoices()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          28,
                        ),
                        itemCount: invoices.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final invoice = invoices[index];

                          return _InvoiceCard(
                            invoice: invoice,
                            onPay: invoice.canSubmitPayment
                                ? () => _openPayment(invoice)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) {
          setState(() => _filter = value);
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.revenue,
    required this.commission,
  });

  final double revenue;
  final double commission;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            icon: Icons.payments_outlined,
            label: 'Doanh thu',
            value: _money(revenue),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryItem(
            icon: Icons.percent_rounded,
            label: 'Hoa hồng',
            value: _money(commission),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    this.onPay,
  });

  final CommissionInvoice invoice;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(invoice.status);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.receipt_long_outlined),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    invoice.periodLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusBadge(
                  label: invoice.statusLabel,
                  color: statusColor,
                ),
              ],
            ),
            const Divider(height: 25),
            _InvoiceRow(
              label: 'Booking đã thanh toán',
              value: '${invoice.bookingIds.length}',
            ),
            _InvoiceRow(
              label: 'Tổng doanh thu',
              value: _money(invoice.grossRevenue),
            ),
            _InvoiceRow(
              label:
                  'Tỷ lệ hoa hồng',
              value:
                  '${(invoice.commissionRate * 100).round()}%',
            ),
            _InvoiceRow(
              label: 'Hoa hồng phải trả',
              value: _money(
                invoice.effectiveCommissionAmount,
              ),
              highlight: true,
            ),
            if (invoice.dueDate != null)
              _InvoiceRow(
                label: 'Hạn thanh toán',
                value: _date(invoice.dueDate!),
              ),
            if (invoice.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                invoice.rejectionReason,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (onPay != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Thanh toán hoa hồng'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? Theme.of(context).colorScheme.primary
                  : null,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionPaymentScreen extends StatefulWidget {
  const _CommissionPaymentScreen({
    required this.service,
    required this.invoice,
  });

  final CommissionService service;
  final CommissionInvoice invoice;

  @override
  State<_CommissionPaymentScreen> createState() =>
      _CommissionPaymentScreenState();
}

class _CommissionPaymentScreenState
    extends State<_CommissionPaymentScreen> {
  late final Future<String> _qrFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _qrFuture = widget.service.createCommissionQrUrl(
      widget.invoice,
    );
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép $label.')),
    );
  }

  Future<void> _submit() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.account_balance_outlined),
          title: const Text('Xác nhận đã thanh toán?'),
          content: Text(
            'Hãy chắc chắn bạn đã chuyển '
            '${_money(widget.invoice.effectiveCommissionAmount)} '
            'với nội dung '
            '${widget.invoice.paymentReference}.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Kiểm tra lại'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Tôi đã thanh toán'),
            ),
          ],
        );
      },
    );

    if (!mounted || accepted != true) return;

    setState(() => _submitting = true);

    try {
      await widget.service.submitCommissionPayment(
        widget.invoice.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi xác nhận thanh toán cho admin.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán hoa hồng'),
      ),
      body: FutureBuilder<String>(
        future: _qrFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  _cleanError(snapshot.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final qrUrl = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              110,
            ),
            children: [
              Text(
                invoice.periodLabel,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Mã hóa đơn: ${invoice.id}',
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                  ),
                  child: AspectRatio(
                    aspectRatio: 540 / 640,
                    child: Image.network(
                      qrUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (
                        context,
                        child,
                        progress,
                      ) {
                        if (progress == null) return child;

                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (_, __, ___) {
                        return const Center(
                          child: Text(
                            'Không thể tải VietQR.',
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _InvoiceRow(
                label: 'Số tiền',
                value: _money(
                  invoice.effectiveCommissionAmount,
                ),
                highlight: true,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nội dung chuyển khoản'),
                subtitle: Text(
                  invoice.paymentReference,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Sao chép',
                  onPressed: () => _copy(
                    invoice.paymentReference,
                    'nội dung chuyển khoản',
                  ),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            12,
          ),
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _submitting
                  ? 'Đang gửi...'
                  : 'Tôi đã thanh toán',
            ),
          ),
        ),
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

class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 58),
          SizedBox(height: 10),
          Text('Chưa có hóa đơn hoa hồng'),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    CommissionStatus.paid => Colors.green,
    CommissionStatus.paymentReview => Colors.indigo,
    CommissionStatus.overdue => Colors.red,
    CommissionStatus.rejected => Colors.orange,
    _ => Colors.blue,
  };
}

String _date(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}

String _money(double value) {
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