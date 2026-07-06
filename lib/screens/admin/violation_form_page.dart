import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/review.dart';
import '../../model/violation_record.dart';
import '../../services/violation_service.dart';

class ViolationFormPage extends StatefulWidget {
  const ViolationFormPage({
    super.key,
    required this.review,
    this.service,
  });

  final ReviewModel review;
  final ViolationService? service;

  @override
  State<ViolationFormPage> createState() =>
      _ViolationFormPageState();
}

class _ViolationFormPageState extends State<ViolationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _evidenceController = TextEditingController();

  late final ViolationService _service;
  late final Future<BookingFinancials> _financialsFuture;

  String _violationType = ViolationType.serviceQuality;
  bool _submitting = false;

  final _currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ViolationService();
    _financialsFuture = _service.getBookingFinancials(
      widget.review.bookingId,
    );

    _titleController.text =
        'Biên bản vi phạm dịch vụ tại ${widget.review.hotelName}';

    _descriptionController.text =
        'Đánh giá của khách hàng: ${widget.review.comment}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool issueNow}) async {
    if (_submitting) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final evidenceUrls = _evidenceController.text
          .split(RegExp(r'[\n,]'))
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList();

      final violationId = await _service.createFromReview(
        reviewId: widget.review.id,
        violationType: _violationType,
        title: _titleController.text,
        description: _descriptionController.text,
        evidenceUrls: evidenceUrls,
        issueNow: issueNow,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              issueNow
                  ? 'Đã lập và gửi biên bản cho nhà cung cấp.'
                  : 'Đã lưu bản nháp biên bản.',
            ),
          ),
        );

      Navigator.pop(context, violationId);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_cleanError(error))),
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
      appBar: AppBar(
        title: const Text('Lập biên bản vi phạm'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _ReviewInformation(review: widget.review),
              const SizedBox(height: 16),
              FutureBuilder<BookingFinancials>(
                future: _financialsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      color: colors.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _cleanError(snapshot.error),
                          style: TextStyle(
                            color: colors.onErrorContainer,
                          ),
                        ),
                      ),
                    );
                  }

                  final financials = snapshot.data!;

                  return _PenaltySummary(
                    bookingAmount: financials.bookingAmount,
                    baseCommissionRate:
                        financials.baseCommissionRate,
                    penaltyAmount: financials.penaltyAmount,
                    currency: _currency,
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Nội dung biên bản',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _violationType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Loại vi phạm',
                  prefixIcon: Icon(Icons.gavel_outlined),
                ),
                items: ViolationType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      ViolationType.label(type),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _violationType = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                enabled: !_submitting,
                maxLength: 150,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề biên bản',
                  prefixIcon: Icon(Icons.title_outlined),
                ),
                validator: (value) {
                  if ((value?.trim().length ?? 0) < 5) {
                    return 'Tiêu đề phải có ít nhất 5 ký tự.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                enabled: !_submitting,
                minLines: 5,
                maxLines: 10,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Mô tả và kết quả xác minh',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (value) {
                  if ((value?.trim().length ?? 0) < 20) {
                    return 'Nội dung phải có ít nhất 20 ký tự.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _evidenceController,
                enabled: !_submitting,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Liên kết bằng chứng',
                  hintText: 'Mỗi liên kết nhập trên một dòng',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.attach_file_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: colors.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colors.onTertiaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Đánh giá 1 sao không tự động tạo khoản phạt. '
                          'Biên bản cần được xác minh và nhà cung cấp '
                          'được quyền giải trình trước khi admin xác nhận.',
                          style: TextStyle(
                            color: colors.onTertiaryContainer,
                            height: 1.4,
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
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          elevation: 8,
          color: colors.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _submit(issueNow: false),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Lưu nháp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _submit(issueNow: true),
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('Lập biên bản'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewInformation extends StatelessWidget {
  const _ReviewInformation({required this.review});

  final ReviewModel review;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Đánh giá liên quan',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${review.rating}/5 sao',
                    style: TextStyle(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              review.hotelName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Phòng ${review.roomNumber} • ${review.customerName}',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              review.comment,
              style: const TextStyle(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PenaltySummary extends StatelessWidget {
  const _PenaltySummary({
    required this.bookingAmount,
    required this.baseCommissionRate,
    required this.penaltyAmount,
    required this.currency,
  });

  final double bookingAmount;
  final double baseCommissionRate;
  final double penaltyAmount;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final baseCommission = bookingAmount * baseCommissionRate;

    return Card(
      color: colors.errorContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _MoneyRow(
              label: 'Giá trị đơn',
              value: currency.format(bookingAmount),
            ),
            const SizedBox(height: 8),
            _MoneyRow(
              label:
                  'Hoa hồng cơ bản ${(baseCommissionRate * 100).round()}%',
              value: currency.format(baseCommission),
            ),
            const Divider(height: 24),
            _MoneyRow(
              label: 'Phụ thu vi phạm 5%',
              value: '+${currency.format(penaltyAmount)}',
              color: colors.error,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.color,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight:
                emphasized ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}