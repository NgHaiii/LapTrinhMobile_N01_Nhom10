import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../model/commission_invoice.dart';
import '../../model/vietqr_bank.dart';
import '../../services/commission_service.dart';
import '../../services/vietqr_service.dart';

class CommissionManagementPage extends StatefulWidget {
  const CommissionManagementPage({super.key});

  @override
  State<CommissionManagementPage> createState() =>
      _CommissionManagementPageState();
}

class _CommissionManagementPageState
    extends State<CommissionManagementPage> {
  final CommissionService _commissionService =
      CommissionService();

  String _status = 'all';
  String? _processingId;

  Future<void> _createInvoice() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateInvoiceDialog(
        service: _commissionService,
      ),
    );

    if (!mounted || created != true) return;

    _message('Đã tạo hóa đơn hoa hồng.');
  }

  Future<void> _configurePayment() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const _AppPaymentSettingsPage(),
      ),
    );

    if (!mounted || saved != true) return;

    _message('Đã cập nhật tài khoản nhận hoa hồng.');
  }

  Future<void> _confirm(CommissionInvoice invoice) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.verified_outlined),
          title: const Text('Xác nhận đã nhận tiền?'),
          content: Text(
            '${invoice.providerName}\n'
            '${invoice.periodLabel}\n'
            '${_money(invoice.effectiveCommissionAmount)}',
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
              child: const Text('Đã nhận tiền'),
            ),
          ],
        );
      },
    );

    if (!mounted || accepted != true) return;

    setState(() => _processingId = invoice.id);

    try {
      await _commissionService.confirmCommissionPayment(
        invoice.id,
      );

      if (!mounted) return;
      _message('Đã xác nhận thanh toán hoa hồng.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _reject(CommissionInvoice invoice) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Từ chối thanh toán'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Lý do',
              hintText: 'Chưa nhận được giao dịch',
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

    setState(() => _processingId = invoice.id);

    try {
      await _commissionService.rejectCommissionPayment(
        invoiceId: invoice.id,
        reason: reason,
      );

      if (!mounted) return;
      _message('Đã từ chối xác nhận thanh toán.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
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
        title: const Text('Quản lý hoa hồng'),
        actions: [
          IconButton(
            tooltip: 'Tài khoản nhận hoa hồng',
            onPressed: _configurePayment,
            icon: const Icon(Icons.account_balance_outlined),
          ),
          IconButton(
            tooltip: 'Tạo hóa đơn',
            onPressed: _createInvoice,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 8),
        ],
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
                _filterChip('unpaid', 'Chưa thanh toán'),
                _filterChip(
                  CommissionStatus.paymentReview,
                  'Chờ xác nhận',
                ),
                _filterChip(
                  CommissionStatus.paid,
                  'Đã thanh toán',
                ),
                _filterChip(
                  CommissionStatus.rejected,
                  'Bị từ chối',
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CommissionInvoice>>(
              stream: _commissionService.watchAllInvoices(
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

                final invoices = snapshot.data ?? [];

                if (invoices.isEmpty) {
                  return const _EmptyInvoices();
                }

                return ListView.separated(
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
                      processing:
                          _processingId == invoice.id,
                      onConfirm: () => _confirm(invoice),
                      onReject: () => _reject(invoice),
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

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.processing,
    required this.onConfirm,
    required this.onReject,
  });

  final CommissionInvoice invoice;
  final bool processing;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = invoice.isPastDue &&
            invoice.status == CommissionStatus.unpaid
        ? CommissionStatus.overdue
        : invoice.status;

    final color = _statusColor(effectiveStatus);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  child: Icon(Icons.percent_rounded),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.providerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(invoice.periodLabel),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: CommissionStatus.label(
                    effectiveStatus,
                  ),
                  color: color,
                ),
              ],
            ),
            const Divider(height: 25),
            _InvoiceRow(
              label: 'Booking',
              value: '${invoice.bookingIds.length}',
            ),
            _InvoiceRow(
              label: 'Tổng doanh thu',
              value: _money(invoice.grossRevenue),
            ),
            _InvoiceRow(
              label:
                  'Hoa hồng '
                  '${(invoice.commissionRate * 100).round()}%',
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
              const SizedBox(height: 8),
              Text(
                invoice.rejectionReason,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (processing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ] else if (invoice.status ==
                CommissionStatus.paymentReview) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                      label: const Text('Chưa nhận tiền'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(
                        Icons.verified_outlined,
                      ),
                      label: const Text('Đã nhận tiền'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateInvoiceDialog extends StatefulWidget {
  const _CreateInvoiceDialog({
    required this.service,
  });

  final CommissionService service;

  @override
  State<_CreateInvoiceDialog> createState() =>
      _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState
    extends State<_CreateInvoiceDialog> {
  late final Future<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>
  >
  _providersFuture;

  String? _providerId;
  late int _month;
  late int _year;

  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final previousMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month - 1,
    );

    _month = previousMonth.month;
    _year = previousMonth.year;

    _providersFuture = FirebaseFirestore.instance
        .collection('providers')
        .where('status', isEqualTo: 'active')
        .get()
        .then((snapshot) => snapshot.docs);
  }

  Future<void> _create() async {
    if (_providerId == null || _creating) return;

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      await widget.service.createMonthlyInvoice(
        providerId: _providerId!,
        month: _month,
        year: _year,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = _cleanError(error);
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return AlertDialog(
      title: const Text('Tạo hóa đơn hoa hồng'),
      content: SizedBox(
        width: 430,
        child: FutureBuilder<
          List<QueryDocumentSnapshot<Map<String, dynamic>>>
        >(
          future: _providersFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 160,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final providers = snapshot.data!;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _providerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nhà cung cấp',
                    prefixIcon: Icon(
                      Icons.storefront_outlined,
                    ),
                  ),
                  items: providers.map((document) {
                    final data = document.data();

                    return DropdownMenuItem(
                      value: document.id,
                      child: Text(
                        data['businessName']?.toString() ??
                            'Nhà cung cấp',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _providerId = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _month,
                        decoration: const InputDecoration(
                          labelText: 'Tháng',
                        ),
                        items: List.generate(12, (index) {
                          final month = index + 1;

                          return DropdownMenuItem(
                            value: month,
                            child: Text('Tháng $month'),
                          );
                        }),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _month = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _year,
                        decoration: const InputDecoration(
                          labelText: 'Năm',
                        ),
                        items: [
                          currentYear - 1,
                          currentYear,
                        ].map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text('$year'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _year = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .error,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating
              ? null
              : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed:
              _creating || _providerId == null
              ? null
              : _create,
          icon: _creating
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.add_rounded),
          label: Text(
            _creating ? 'Đang tạo...' : 'Tạo hóa đơn',
          ),
        ),
      ],
    );
  }
}

class _AppPaymentSettingsPage extends StatefulWidget {
  const _AppPaymentSettingsPage();

  @override
  State<_AppPaymentSettingsPage> createState() =>
      _AppPaymentSettingsPageState();
}

class _AppPaymentSettingsPageState
    extends State<_AppPaymentSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _nameController = TextEditingController();
  final VietQrService _vietQrService = VietQrService();

  late final Future<List<VietQrBank>> _banksFuture;

  VietQrBank? _selectedBank;
  bool _active = true;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _banksFuture = _load();
  }

  Future<List<VietQrBank>> _load() async {
    final results = await Future.wait([
      _vietQrService.getBanks(),
      FirebaseFirestore.instance
          .collection('appSettings')
          .doc('payment')
          .get(),
    ]);

    final banks = results[0] as List<VietQrBank>;
    final snapshot =
        results[1]
            as DocumentSnapshot<Map<String, dynamic>>;

    final data = snapshot.data();

    if (data != null) {
      _accountController.text =
          data['accountNumber']?.toString() ?? '';

      _nameController.text =
          data['accountName']?.toString() ?? '';

      _active = data['isActive'] != false;

      final bankBin = data['bankBin']?.toString();

      for (final bank in banks) {
        if (bank.bin == bankBin) {
          _selectedBank = bank;
          break;
        }
      }
    }

    _loaded = true;
    return banks;
  }

  Future<void> _save() async {
    if (_saving ||
        !_formKey.currentState!.validate()) {
      return;
    }

    final bank = _selectedBank;

    if (bank == null) return;

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('payment')
          .set({
            'bankBin': bank.bin,
            'bankCode': bank.code,
            'bankName': bank.name,
            'accountNumber': _accountController.text
                .replaceAll(RegExp(r'\s+'), ''),
            'accountName':
                _nameController.text.trim().toUpperCase(),
            'isActive': _active,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _accountValidator(String? value) {
    final normalized =
        value?.replaceAll(RegExp(r'\s+'), '') ?? '';

    if (!RegExp(r'^[0-9]{6,19}$').hasMatch(normalized)) {
      return 'Số tài khoản phải gồm 6-19 chữ số';
    }

    return null;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _nameController.dispose();
    _vietQrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản nhận hoa hồng'),
      ),
      body: Form(
        key: _formKey,
        child: FutureBuilder<List<VietQrBank>>(
          future: _banksFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData || !_loaded) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final banks = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                110,
              ),
              children: [
                DropdownButtonFormField<VietQrBank>(
                  initialValue: banks.contains(_selectedBank)
                      ? _selectedBank
                      : null,
                  isExpanded: true,
                  validator: (value) {
                    return value == null
                        ? 'Vui lòng chọn ngân hàng'
                        : null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Ngân hàng',
                    prefixIcon: Icon(
                      Icons.account_balance_outlined,
                    ),
                  ),
                  items: banks.map((bank) {
                    return DropdownMenuItem(
                      value: bank,
                      child: Text(
                        bank.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedBank = value);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _accountController,
                  validator: _accountValidator,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tài khoản',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  validator: (value) {
                    if ((value?.trim().length ?? 0) < 2) {
                      return 'Tên chủ tài khoản không hợp lệ';
                    }

                    return null;
                  },
                  textCapitalization:
                      TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Tên chủ tài khoản',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cho phép nhận hoa hồng'),
                  subtitle: const Text(
                    'Nhà cung cấp có thể tạo VietQR '
                    'thanh toán hóa đơn.',
                  ),
                  value: _active,
                  onChanged: (value) {
                    setState(() => _active = value);
                  },
                ),
              ],
            );
          },
        ),
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
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Đang lưu...' : 'Lưu cấu hình',
            ),
          ),
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