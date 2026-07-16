import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../model/hotel.dart';
import '../../../model/pricing_quote.dart';
import '../../../model/room.dart';
import '../../../model/room_rate_plan.dart';
import '../../../model/room_reservation.dart';
import '../../../services/customer_service.dart';
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
  State<BookingFormScreen> createState() =>
      _BookingFormScreenState();
}

class _BookingFormScreenState
    extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();

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

  bool _loadingQuote = false;
  bool _submitting = false;
  int _quoteRequestId = 0;

  PricingQuote? get _selectedQuote {
    final planId = _selectedPlanId;

    if (planId != null) {
      return _comboQuotes[planId];
    }

    return _hourlyQuote;
  }

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    final defaultCheckIn = _nextWholeHour(
      DateTime.now(),
    );

    final suppliedCheckIn = widget.initialCheckIn;

    _checkIn =
        suppliedCheckIn != null &&
            suppliedCheckIn.isAfter(DateTime.now())
        ? _normalizeWholeHour(suppliedCheckIn)
        : defaultCheckIn;

    final suppliedCheckOut = widget.initialCheckOut;

    if (suppliedCheckOut != null &&
        suppliedCheckOut.isAfter(_checkIn)) {
      _checkOut = _normalizeWholeHour(
        suppliedCheckOut,
      );

      if (!_checkOut.isAfter(_checkIn)) {
        _checkOut = _checkIn.add(
          const Duration(hours: 3),
        );
      }
    } else {
      _checkOut = _checkIn.add(
        const Duration(hours: 3),
      );
    }

    _guests = widget.initialGuests.clamp(
      1,
      widget.room.maxGuests,
    );

    _nameController = TextEditingController(
      text: user?.displayName ?? '',
    );

    _emailController = TextEditingController(
      text: user?.email ?? '',
    );

    _phoneController = TextEditingController(
      text: user?.phoneNumber ?? '',
    );

    _requestController = TextEditingController();
  }

  void _onTimeChanged(
    HourlyBookingSelection? selection,
  ) {
    if (selection == null) {
      setState(() {
        _hourlyQuote = null;
        _comboQuotes = {};
        _selectedPlanId = null;
        _quoteError =
            'Không có khung giờ phù hợp để đặt phòng.';
      });
      return;
    }

    final unchanged =
        selection.checkIn.isAtSameMomentAs(_checkIn) &&
        selection.checkOut.isAtSameMomentAs(_checkOut);

    if (unchanged && _selectedQuote != null) return;

    setState(() {
      _checkIn = selection.checkIn;
      _checkOut = selection.checkOut;
      _selectedPlanId = null;
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
      final quotes =
          await widget.service.calculateAvailablePrices(
            room: widget.room,
            checkIn: _checkIn,
            checkOut: _checkOut,
          );

      if (!mounted ||
          requestId != _quoteRequestId) {
        return;
      }

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
        throw StateError(
          'Không thể tính giá thuê theo giờ.',
        );
      }

      setState(() {
        _hourlyQuote = hourlyQuote;
        _comboQuotes = comboQuotes;

        if (_selectedPlanId != null &&
            !comboQuotes.containsKey(
              _selectedPlanId,
            )) {
          _selectedPlanId = null;
        }
      });
    } catch (error) {
      if (!mounted ||
          requestId != _quoteRequestId) {
        return;
      }

      setState(() {
        _hourlyQuote = null;
        _comboQuotes = {};
        _selectedPlanId = null;
        _quoteError = _cleanError(error);
      });
    } finally {
      if (mounted &&
          requestId == _quoteRequestId) {
        setState(() => _loadingQuote = false);
      }
    }
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
                padding: const EdgeInsets.fromLTRB(
                  24,
                  4,
                  24,
                  24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Số lượng khách',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: value > 1
                              ? () => setSheetState(
                                  () => value--,
                                )
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 130,
                          child: Text(
                            '$value khách',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        ),
                        IconButton.filled(
                          onPressed:
                              value <
                                  widget.room.maxGuests
                              ? () => setSheetState(
                                  () => value++,
                                )
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          value,
                        ),
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
    if (_submitting ||
        !_formKey.currentState!.validate()) {
      return;
    }

    final quote = _selectedQuote;

    if (quote == null) {
      _message(
        _quoteError ??
            'Vui lòng chọn khung giờ hợp lệ.',
      );
      return;
    }

    if (_guests > widget.room.maxGuests) {
      _message(
        'Phòng chỉ phù hợp tối đa '
        '${widget.room.maxGuests} khách.',
      );
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.event_available_outlined,
        ),
        title: const Text('Xác nhận đặt phòng'),
        content: Text(
          '${widget.hotel.name}\n'
          '${widget.room.type} · '
          'Phòng ${widget.room.roomNumber}\n\n'
          '${_dateTime(_checkIn)}\n'
          'đến ${_dateTime(_checkOut)}\n'
          '$_guests khách\n'
          '${quote.usesCombo ? quote.ratePlanName : 'Tính theo giờ'}\n\n'
          'Tổng tiền: ${_money(quote.totalAmount)}',
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
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Không được để trống';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;

    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value!.trim())) {
      return 'Email không hợp lệ';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;

    final normalized = value!.replaceAll(
      RegExp(r'[\s.-]'),
      '',
    );

    if (!RegExp(
      r'^(0|\+84)[0-9]{9,10}$',
    ).hasMatch(normalized)) {
      return 'Số điện thoại không hợp lệ';
    }

    return null;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value)),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt phòng'),
      ),
      body: StreamBuilder<List<RoomReservation>>(
        stream: widget.service.watchRoomReservations(
          roomId: widget.room.id,
          from: DateTime.now().subtract(
            const Duration(days: 1),
          ),
          to: DateTime.now().add(
            const Duration(days: 730),
          ),
        ),
        builder: (context, reservationSnapshot) {
          if (reservationSnapshot.connectionState ==
                  ConnectionState.waiting &&
              !reservationSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (reservationSnapshot.hasError) {
            return _ErrorState(
              message: _cleanError(
                reservationSnapshot.error,
              ),
            );
          }

          final reservations =
              reservationSnapshot.data ?? [];

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                112,
              ),
              children: [
                Text(
                  widget.hotel.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${widget.room.type} · '
                  'Phòng ${widget.room.roomNumber}',
                ),
                const SizedBox(height: 24),
                HourlyBookingPicker(
                  key: ValueKey(widget.room.id),
                  reservations: reservations,
                  initialCheckIn: _checkIn,
                  initialDurationHours: _checkOut
                      .difference(_checkIn)
                      .inHours
                      .clamp(1, 48),
                  maxDurationHours: 48,
                  onChanged: _onTimeChanged,
                ),
                const SizedBox(height: 24),
                if (_loadingQuote)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  )
                else if (_quoteError != null)
                  _ErrorState(
                    message: _quoteError!,
                    onRetry: _refreshQuotes,
                  )
                else if (_hourlyQuote != null) ...[
                  CustomerRatePlanSelector(
                    hourlyQuote: _hourlyQuote!,
                    plans:
                        widget.room.enabledRatePlans,
                    comboQuotes: _comboQuotes,
                    selectedPlanId:
                        _selectedPlanId,
                    onSelected: (value) {
                      setState(
                        () => _selectedPlanId = value,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_selectedQuote != null)
                    CustomerPriceBreakdown(
                      quote: _selectedQuote!,
                    ),
                ],
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thông tin nhận phòng',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w900,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _selectGuests,
                      icon: const Icon(
                        Icons.groups_outlined,
                      ),
                      label: Text(
                        '$_guests khách',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  validator: _required,
                  textInputAction:
                      TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  validator: _validatePhone,
                  keyboardType:
                      TextInputType.phone,
                  textInputAction:
                      TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  validator: _validateEmail,
                  keyboardType:
                      TextInputType.emailAddress,
                  textInputAction:
                      TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                    ),
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
                    prefixIcon: Icon(
                      Icons.notes_rounded,
                    ),
                  ),
                ),
              ],
            ),
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
            onPressed: _submitting ||
                    _loadingQuote ||
                    _selectedQuote == null
                ? null
                : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _submitting
                  ? 'Đang gửi yêu cầu...'
                  : _selectedQuote == null
                  ? 'Chọn khung giờ'
                  : 'Đặt phòng · '
                        '${_money(_selectedQuote!.totalAmount)}',
            ),
          ),
        ),
      ),
    );
  }
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
              color:
                  Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
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
  final currentHour = DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
  );

  return currentHour.add(const Duration(hours: 1));
}

DateTime _normalizeWholeHour(DateTime value) {
  final normalized = DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
  );

  if (value.minute > 0 ||
      value.second > 0 ||
      value.millisecond > 0 ||
      value.microsecond > 0) {
    return normalized.add(
      const Duration(hours: 1),
    );
  }

  return normalized;
}

String _dateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month =
      value.month.toString().padLeft(2, '0');
  final hour =
      value.hour.toString().padLeft(2, '0');

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