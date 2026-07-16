import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VoucherFormPage extends StatefulWidget {
  const VoucherFormPage({
    super.key,
    this.voucherId,
    this.initialData,
  });

  final String? voucherId;
  final Map<String, dynamic>? initialData;

  @override
  State<VoucherFormPage> createState() => _VoucherFormPageState();
}

class _VoucherFormPageState extends State<VoucherFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _codeController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _pointsController = TextEditingController();
  final _quantityController = TextEditingController();
  final _termsController = TextEditingController();

  String _discountType = 'percent';
  String _target = 'booking';
  bool _isActive = true;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _saving = false;

  bool get _isEdit => widget.voucherId != null;

  CollectionReference<Map<String, dynamic>> get _vouchersRef {
    return FirebaseFirestore.instance.collection('vouchers');
  }

  @override
  void initState() {
    super.initState();
    _fillInitialData();
  }

  void _fillInitialData() {
    final data = widget.initialData;
    if (data == null) {
      _pointsController.text = '0';
      _quantityController.text = '0';
      _minOrderController.text = '0';
      _maxDiscountController.text = '0';
      _startAt = DateTime.now();
      _endAt = DateTime.now().add(const Duration(days: 30));
      return;
    }

    _codeController.text = data['code'] as String? ?? '';
    _titleController.text = data['title'] as String? ?? '';
    _descriptionController.text = data['description'] as String? ?? '';
    _discountType = data['discountType'] as String? ?? 'percent';
    _target = data['target'] as String? ?? 'booking';
    _isActive = data['isActive'] as bool? ?? true;

    _discountValueController.text =
        ((data['discountValue'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
    _maxDiscountController.text =
        ((data['maxDiscountAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
    _minOrderController.text =
        ((data['minOrderAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
    _pointsController.text =
        ((data['pointsRequired'] as num?)?.toInt() ?? 0).toString();
    _quantityController.text =
        ((data['quantity'] as num?)?.toInt() ?? 0).toString();
    _termsController.text = data['terms'] as String? ?? '';

    _startAt = _toDate(data['startAt']);
    _endAt = _toDate(data['endAt']);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _maxDiscountController.dispose();
    _minOrderController.dispose();
    _pointsController.dispose();
    _quantityController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required bool isStartDate,
  }) async {
    final now = DateTime.now();
    final initial = isStartDate ? _startAt ?? now : _endAt ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('vi', 'VN'),
    );

    if (picked == null) return;

    setState(() {
      if (isStartDate) {
        _startAt = picked;
        if (_endAt != null && _endAt!.isBefore(picked)) {
          _endAt = picked.add(const Duration(days: 7));
        }
      } else {
        _endAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startAt == null || _endAt == null) {
      _showMessage('Vui lòng chọn thời gian áp dụng.');
      return;
    }

    if (_endAt!.isBefore(_startAt!)) {
      _showMessage('Ngày kết thúc phải sau ngày bắt đầu.');
      return;
    }

    setState(() => _saving = true);

    try {
      final now = FieldValue.serverTimestamp();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final data = {
        'code': _codeController.text.trim().toUpperCase(),
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'discountType': _discountType,
        'discountValue': _number(_discountValueController.text),
        'maxDiscountAmount': _number(_maxDiscountController.text),
        'minOrderAmount': _number(_minOrderController.text),
        'pointsRequired': _intNumber(_pointsController.text),
        'quantity': _intNumber(_quantityController.text),
        'usedCount': widget.initialData?['usedCount'] ?? 0,
        'target': _target,
        'terms': _termsController.text.trim(),
        'isActive': _isActive,
        'startAt': Timestamp.fromDate(_startAt!),
        'endAt': Timestamp.fromDate(_endAt!),
        'updatedAt': now,
      };

      if (_isEdit) {
        await _vouchersRef.doc(widget.voucherId).update(data);
      } else {
        await _vouchersRef.add({
          ...data,
          'createdBy': uid,
          'createdAt': now,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Đã cập nhật voucher.' : 'Đã tạo voucher.'),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(_isEdit ? 'Chỉnh sửa voucher' : 'Tạo voucher'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            _HeroBox(isEdit: _isEdit),
            const SizedBox(height: 18),
            _Section(
              title: 'Thông tin voucher',
              children: [
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã voucher',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                    hintText: 'VD: SUMMER2026',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tên voucher',
                    prefixIcon: Icon(Icons.card_giftcard_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả ưu đãi',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  validator: _required,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Giá trị ưu đãi',
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'percent',
                      label: Text('Theo %'),
                      icon: Icon(Icons.percent),
                    ),
                    ButtonSegment(
                      value: 'fixedAmount',
                      label: Text('Số tiền'),
                      icon: Icon(Icons.payments_outlined),
                    ),
                  ],
                  selected: {_discountType},
                  onSelectionChanged: (value) {
                    setState(() => _discountType = value.first);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _discountValueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _discountType == 'percent'
                        ? 'Phần trăm giảm'
                        : 'Số tiền giảm',
                    prefixIcon: const Icon(Icons.sell_outlined),
                    suffixText: _discountType == 'percent' ? '%' : 'đ',
                  ),
                  validator: _positiveNumber,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxDiscountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giảm tối đa',
                    prefixIcon: Icon(Icons.savings_outlined),
                    suffixText: 'đ',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minOrderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Đơn tối thiểu',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                    suffixText: 'đ',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Điều kiện sử dụng',
              children: [
                DropdownButtonFormField<String>(
                  value: _target,
                  decoration: const InputDecoration(
                    labelText: 'Áp dụng cho',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Tất cả dịch vụ'),
                    ),
                    DropdownMenuItem(
                      value: 'booking',
                      child: Text('Đặt phòng'),
                    ),
                    DropdownMenuItem(
                      value: 'travelActivity',
                      child: Text('Hoạt động du lịch'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _target = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Điểm cần để đổi',
                    prefixIcon: Icon(Icons.stars_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số lượng phát hành',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    helperText: 'Nhập 0 nếu không giới hạn số lượng.',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _termsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Điều khoản sử dụng',
                    prefixIcon: Icon(Icons.rule_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Thời gian & trạng thái',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Bắt đầu',
                        date: _startAt,
                        onTap: () => _pickDate(isStartDate: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateButton(
                        label: 'Kết thúc',
                        date: _endAt,
                        onTap: () => _pickDate(isStartDate: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text(
                    'Cho phép khách hàng sử dụng',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Tắt nếu muốn ẩn voucher tạm thời.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Đang lưu...' : 'Lưu voucher'),
        ),
      ),
    );
  }
}

class _HeroBox extends StatelessWidget {
  const _HeroBox({required this.isEdit});

  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF008C95),
            Color(0xFF22B8B6),
            Color(0xFFF4C95D),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
            child: Icon(Icons.travel_explore_outlined),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isEdit
                  ? 'Cập nhật ưu đãi để chiến dịch luôn hấp dẫn.'
                  : 'Tạo ưu đãi mới để khách hàng có thêm lý do đặt chuyến đi.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = date == null
        ? 'Chọn ngày'
        : DateFormat('dd/MM/yyyy').format(date!);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: colors.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Không được để trống';
  }

  return null;
}

String? _positiveNumber(String? value) {
  final number = double.tryParse((value ?? '').trim());

  if (number == null || number <= 0) {
    return 'Vui lòng nhập số lớn hơn 0';
  }

  return null;
}

double _number(String value) {
  return double.tryParse(value.trim().replaceAll(',', '')) ?? 0;
}

int _intNumber(String value) {
  return int.tryParse(value.trim().replaceAll(',', '')) ?? 0;
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}