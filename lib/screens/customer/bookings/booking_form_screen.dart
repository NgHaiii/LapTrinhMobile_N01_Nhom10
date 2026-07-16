import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../model/hotel.dart';
import '../../../model/pricing_quote.dart';
import '../../../model/room.dart';
import '../../../model/room_rate_plan.dart';
import '../../../model/room_reservation.dart';
import '../../../model/user_voucher.dart';
import '../../../model/voucher.dart';
import '../../../services/customer_service.dart';
import '../../../services/voucher_service.dart';
import '../widgets/hourly_booking_picker.dart';
import '../widgets/price_breakdown.dart';
import '../widgets/rate_plan_selector.dart';

class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen({
    super.key,
    required this.service,
    required this.hotel,
    required this.room,
    this.initialCheckIn,
    this.initialCheckOut,
    this.initialGuests = 2,
  });

  final CustomerService service;
  final HotelModel hotel;
  final RoomModel room;
  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;
  final int initialGuests;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _voucherService = VoucherService();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _requestController;

  late DateTime _checkIn;
  late DateTime _checkOut;
  late int _guests;

  PricingQuote? _hourlyQuote;
  Map<String, PricingQuote> _comboQuotes = {};
  String? _selectedPlanId;
  String? _quoteError;

  UserVoucherModel? _selectedUserVoucher;
  VoucherModel? _selectedVoucher;
  double _voucherDiscount = 0;

  bool _loadingQuote = false;
  bool _loadingVoucher = false;
  bool _submitting = false;
  int _quoteRequestId = 0;

  PricingQuote? get _selectedQuote {
    final planId = _selectedPlanId;
    if (planId != null) return _comboQuotes[planId];
    return _hourlyQuote;
  }

  double get _subtotalAmount => _selectedQuote?.totalAmount ?? 0;

  double get _payableAmount {
    final value = _subtotalAmount - _voucherDiscount;
    return value < 0 ? 0 : value;
  }

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    final defaultCheckIn = _nextWholeHour(DateTime.now());
    final suppliedCheckIn = widget.initialCheckIn;

    _checkIn = suppliedCheckIn != null && suppliedCheckIn.isAfter(DateTime.now())
        ? _normalizeWholeHour(suppliedCheckIn)
        : defaultCheckIn;

    final suppliedCheckOut = widget.initialCheckOut;
    if (suppliedCheckOut != null && suppliedCheckOut.isAfter(_checkIn)) {
      _checkOut = _normalizeWholeHour(suppliedCheckOut);
      if (!_checkOut.isAfter(_checkIn)) {
        _checkOut = _checkIn.add(const Duration(hours: 3));
      }
    } else {
      _checkOut = _checkIn.add(const Duration(hours: 3));
    }

    _guests = widget.initialGuests.clamp(1, widget.room.maxGuests);

    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _requestController = TextEditingController();
  }

  void _onTimeChanged(HourlyBookingSelection? selection) {
    if (selection == null) {
      setState(() {
        _hourlyQuote = null;
        _comboQuotes = {};
        _selectedPlanId = null;
        _clearVoucher();
        _quoteError = 'Không có khung giờ phù hợp để đặt phòng.';
      });
      return;
    }

    final unchanged = selection.checkIn.isAtSameMomentAs(_checkIn) &&
        selection.checkOut.isAtSameMomentAs(_checkOut);

    if (unchanged && _selectedQuote != null) return;

    setState(() {
      _checkIn = selection.checkIn;
      _checkOut = selection.checkOut;
      _selectedPlanId = null;
      _clearVoucher();
    });

    _refreshQuotes();
  }

  Future<void> _refreshQuotes() async {
    final requestId = ++_quoteRequestId;

    setState(() {
      _loadingQuote = true;
      _quoteError = null;
    });

    try {
      final quotes = await widget.service.calculateAvailablePrices(
        room: widget.room,
        checkIn: _checkIn,
        checkOut: _checkOut,
      );

      if (!mounted || requestId != _quoteRequestId) return;

      PricingQuote? hourlyQuote;
      final comboQuotes = <String, PricingQuote>{};

      for (final quote in quotes) {
        if (quote.usesCombo) {
          comboQuotes[quote.ratePlanId] = quote;
        } else {
          hourlyQuote = quote;
        }
      }

      if (hourlyQuote == null) {
        throw StateError('Không thể tính giá thuê theo giờ.');
      }

      setState(() {
        _hourlyQuote = hourlyQuote;
        _comboQuotes = comboQuotes;

        if (_selectedPlanId != null &&
            !comboQuotes.containsKey(_selectedPlanId)) {
          _selectedPlanId = null;
        }
      });

      await _refreshVoucherDiscount();
    } catch (error) {
      if (!mounted || requestId != _quoteRequestId) return;

      setState(() {
        _hourlyQuote = null;
        _comboQuotes = {};
        _selectedPlanId = null;
        _clearVoucher();
        _quoteError = _cleanError(error);
      });
    } finally {
      if (mounted && requestId == _quoteRequestId) {
        setState(() => _loadingQuote = false);
      }
    }
  }

  Future<void> _refreshVoucherDiscount() async {
    final userVoucher = _selectedUserVoucher;
    final subtotal = _subtotalAmount;

    if (userVoucher == null || subtotal <= 0) {
      setState(() => _voucherDiscount = 0);
      return;
    }

    setState(() => _loadingVoucher = true);

    try {
      final discount = await _voucherService.calculateUserVoucherDiscount(
        userVoucherId: userVoucher.id,
        orderAmount: subtotal,
        target: VoucherTarget.booking,
      );

      if (!mounted) return;

      if (discount <= 0) {
        setState(() => _clearVoucher());
        _message('Voucher không còn đủ điều kiện áp dụng.');
        return;
      }

      setState(() => _voucherDiscount = discount);
    } catch (error) {
      if (!mounted) return;
      setState(() => _clearVoucher());
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _loadingVoucher = false);
    }
  }

  Future<void> _selectVoucher() async {
    final quote = _selectedQuote;

    if (quote == null) {
      _message('Vui lòng chọn khung giờ trước khi chọn voucher.');
      return;
    }

    final result = await showModalBottomSheet<_VoucherSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _VoucherPickerSheet(
          service: _voucherService,
          orderAmount: quote.totalAmount,
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedUserVoucher = result.userVoucher;
      _selectedVoucher = result.voucher;
      _voucherDiscount = result.discount;
    });
  }

  Future<void> _selectGuests() async {
    var value = _guests;

    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Số lượng khách',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: value > 1
                              ? () => setSheetState(() => value--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 130,
                          child: Text(
                            '$value khách',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton.filled(
                          onPressed: value < widget.room.maxGuests
                              ? () => setSheetState(() => value++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, value),
                        child: const Text('Xác nhận'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() => _guests = result);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    final quote = _selectedQuote;

    if (quote == null) {
      _message(_quoteError ?? 'Vui lòng chọn khung giờ hợp lệ.');
      return;
    }

    if (_guests > widget.room.maxGuests) {
      _message('Phòng chỉ phù hợp tối đa ${widget.room.maxGuests} khách.');
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.event_available_outlined),
        title: const Text('Xác nhận đặt phòng'),
        content: Text(
          '${widget.hotel.name}\n'
          '${widget.room.type} · Phòng ${widget.room.roomNumber}\n\n'
          '${_dateTime(_checkIn)}\n'
          'đến ${_dateTime(_checkOut)}\n'
          '$_guests khách\n'
          '${quote.usesCombo ? quote.ratePlanName : 'Tính theo giờ'}\n\n'
          'Tạm tính: ${_money(_subtotalAmount)}\n'
          '${_voucherDiscount > 0 ? 'Voucher: -${_money(_voucherDiscount)}\n' : ''}'
          'Tổng tiền: ${_money(_payableAmount)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kiểm tra lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );

    if (!mounted || accepted != true) return;

    setState(() => _submitting = true);

    try {
      await widget.service.createBooking(
        hotel: widget.hotel,
        room: widget.room,
        checkIn: _checkIn,
        checkOut: _checkOut,
        guests: _guests,
        customerName: _nameController.text,
        customerEmail: _emailController.text,
        customerPhone: _phoneController.text,
        specialRequests: _requestController.text,
        ratePlanId: _selectedPlanId ?? '',
        userVoucherId: _selectedUserVoucher?.id ?? '',
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _clearVoucher() {
    _selectedUserVoucher = null;
    _selectedVoucher = null;
    _voucherDiscount = 0;
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Không được để trống';
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())) {
      return 'Email không hợp lệ';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;

    final normalized = value!.replaceAll(RegExp(r'[\s.-]'), '');

    if (!RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(normalized)) {
      return 'Số điện thoại không hợp lệ';
    }

    return null;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _requestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        !_submitting && !_loadingQuote && _selectedQuote != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt phòng')),
      body: StreamBuilder<List<RoomReservation>>(
        stream: widget.service.watchRoomReservations(
          roomId: widget.room.id,
          from: DateTime.now().subtract(const Duration(days: 1)),
          to: DateTime.now().add(const Duration(days: 730)),
        ),
        builder: (context, reservationSnapshot) {
          if (reservationSnapshot.connectionState == ConnectionState.waiting &&
              !reservationSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (reservationSnapshot.hasError) {
            return _ErrorState(
              message: _cleanError(reservationSnapshot.error),
            );
          }

          final reservations = reservationSnapshot.data ?? [];

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
              children: [
                Text(
                  widget.hotel.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text('${widget.room.type} · Phòng ${widget.room.roomNumber}'),
                const SizedBox(height: 24),
                HourlyBookingPicker(
                  key: ValueKey(widget.room.id),
                  reservations: reservations,
                  initialCheckIn: _checkIn,
                  initialDurationHours:
                      _checkOut.difference(_checkIn).inHours.clamp(1, 48),
                  maxDurationHours: 48,
                  onChanged: _onTimeChanged,
                ),
                const SizedBox(height: 24),
                if (_loadingQuote)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_quoteError != null)
                  _ErrorState(message: _quoteError!, onRetry: _refreshQuotes)
                else if (_hourlyQuote != null) ...[
                  CustomerRatePlanSelector(
                    hourlyQuote: _hourlyQuote!,
                    plans: widget.room.enabledRatePlans,
                    comboQuotes: _comboQuotes,
                    selectedPlanId: _selectedPlanId,
                    onSelected: (value) async {
                      setState(() {
                        _selectedPlanId = value;
                        _clearVoucher();
                      });
                      await _refreshVoucherDiscount();
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_selectedQuote != null)
                    CustomerPriceBreakdown(quote: _selectedQuote!),
                  const SizedBox(height: 14),
                  _VoucherBox(
                    userVoucher: _selectedUserVoucher,
                    voucher: _selectedVoucher,
                    discount: _voucherDiscount,
                    loading: _loadingVoucher,
                    onSelect: _selectVoucher,
                    onRemove: () => setState(_clearVoucher),
                  ),
                  if (_voucherDiscount > 0) ...[
                    const SizedBox(height: 14),
                    _PaymentSummaryBox(
                      subtotal: _subtotalAmount,
                      discount: _voucherDiscount,
                      total: _payableAmount,
                    ),
                  ],
                ],
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thông tin nhận phòng',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _selectGuests,
                      icon: const Icon(Icons.groups_outlined),
                      label: Text('$_guests khách'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  validator: _required,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _requestController,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Yêu cầu đặc biệt',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _submitting
                  ? 'Đang gửi yêu cầu...'
                  : _selectedQuote == null
                      ? 'Chọn khung giờ'
                      : 'Đặt phòng · ${_money(_payableAmount)}',
            ),
          ),
        ),
      ),
    );
  }
}

class _VoucherBox extends StatelessWidget {
  const _VoucherBox({
    required this.userVoucher,
    required this.voucher,
    required this.discount,
    required this.loading,
    required this.onSelect,
    required this.onRemove,
  });

  final UserVoucherModel? userVoucher;
  final VoucherModel? voucher;
  final double discount;
  final bool loading;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasVoucher = userVoucher != null && voucher != null && discount > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: hasVoucher
            ? colors.primaryContainer.withValues(alpha: 0.45)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: const Icon(Icons.confirmation_number_outlined),
        ),
        title: Text(
          hasVoucher ? userVoucher!.code : 'Voucher ưu đãi',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          hasVoucher
              ? '${voucher!.title} · Giảm ${_money(discount)}'
              : 'Chọn voucher khả dụng cho đơn đặt phòng này',
        ),
        trailing: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : hasVoucher
                ? IconButton(
                    tooltip: 'Bỏ voucher',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded),
                  )
                : const Icon(Icons.chevron_right_rounded),
        onTap: loading ? null : onSelect,
      ),
    );
  }
}

class _PaymentSummaryBox extends StatelessWidget {
  const _PaymentSummaryBox({
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double total;

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
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _AmountLine(label: 'Tạm tính', value: _money(subtotal)),
            _AmountLine(
              label: 'Voucher',
              value: '-${_money(discount)}',
              color: colors.primary,
            ),
            const Divider(height: 22),
            _AmountLine(
              label: 'Tổng thanh toán',
              value: _money(total),
              color: colors.primary,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
      fontSize: bold ? 16 : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _VoucherPickerSheet extends StatelessWidget {
  const _VoucherPickerSheet({
    required this.service,
    required this.orderAmount,
  });

  final VoucherService service;
  final double orderAmount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chọn voucher',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<UserVoucherModel>>(
                stream: service.watchMyUsableVouchers(
                  target: VoucherTarget.booking,
                  orderAmount: orderAmount,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(message: _cleanError(snapshot.error));
                  }

                  final userVouchers = snapshot.data ?? [];

                  if (userVouchers.isEmpty) {
                    return const _ErrorState(
                      message: 'Bạn chưa có voucher phù hợp cho đơn này.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: userVouchers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final userVoucher = userVouchers[index];

                      return FutureBuilder<VoucherModel?>(
                        future: service.getVoucher(userVoucher.voucherId),
                        builder: (context, voucherSnapshot) {
                          final voucher = voucherSnapshot.data;

                          if (voucher == null) {
                            return const SizedBox.shrink();
                          }

                          final discount = voucher
                              .calculateDiscount(orderAmount)
                              .clamp(0, orderAmount)
                              .toDouble();

                          if (discount <= 0) return const SizedBox.shrink();

                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.local_offer_outlined),
                              ),
                              title: Text(
                                userVoucher.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                '${voucher.title}\nGiảm ${_money(discount)}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.check_circle_outline),
                              onTap: () {
                                Navigator.pop(
                                  context,
                                  _VoucherSelection(
                                    userVoucher: userVoucher,
                                    voucher: voucher,
                                    discount: discount,
                                  ),
                                );
                              },
                            ),
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
      ),
    );
  }
}

class _VoucherSelection {
  const _VoucherSelection({
    required this.userVoucher,
    required this.voucher,
    required this.discount,
  });

  final UserVoucherModel userVoucher;
  final VoucherModel voucher;
  final double discount;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

DateTime _nextWholeHour(DateTime value) {
  final currentHour = DateTime(value.year, value.month, value.day, value.hour);
  return currentHour.add(const Duration(hours: 1));
}

DateTime _normalizeWholeHour(DateTime value) {
  final normalized = DateTime(value.year, value.month, value.day, value.hour);

  if (value.minute > 0 ||
      value.second > 0 ||
      value.millisecond > 0 ||
      value.microsecond > 0) {
    return normalized.add(const Duration(hours: 1));
  }

  return normalized;
}

String _dateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');

  return '$day/$month/${value.year} $hour:00';
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