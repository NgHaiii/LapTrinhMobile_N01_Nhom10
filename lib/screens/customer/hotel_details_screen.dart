import 'package:flutter/material.dart';

import '../../model/hotel.dart';
import '../../model/room.dart';
import '../../services/customer_service.dart';
import 'widgets/customer_empty_state.dart';
import 'widgets/image_carousel.dart';
import 'widgets/room_card.dart';

class HotelDetailsScreen extends StatefulWidget {
  const HotelDetailsScreen({
    super.key,
    required this.service,
    required this.hotel,
    this.initialDateRange,
    this.initialGuests = 2,
  });

  final CustomerService service;
  final HotelModel hotel;
  final DateTimeRange? initialDateRange;
  final int initialGuests;

  @override
  State<HotelDetailsScreen> createState() => _HotelDetailsScreenState();
}

class _HotelDetailsScreenState extends State<HotelDetailsScreen> {
  DateTimeRange? _dateRange;
  late int _guests;

  String? _bookingRoomId;

  @override
  void initState() {
    super.initState();

    _dateRange = widget.initialDateRange;
    _guests = widget.initialGuests > 0 ? widget.initialGuests : 1;
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);

    final result = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 730)),
      initialDateRange: _dateRange,
      helpText: 'Chọn thời gian lưu trú',
      cancelText: 'Hủy',
      saveText: 'Xác nhận',
    );

    if (!mounted || result == null) return;

    setState(() => _dateRange = result);
  }

  Future<void> _selectGuests() async {
    var guests = _guests;

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
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: guests > 1
                              ? () {
                                  setSheetState(() {
                                    guests--;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            '$guests khách',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton.filled(
                          onPressed: guests < 30
                              ? () {
                                  setSheetState(() {
                                    guests++;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, guests);
                        },
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

  Future<void> _bookRoom(RoomModel room) async {
    if (_bookingRoomId != null) return;

    if (_dateRange == null) {
      await _selectDate();

      if (!mounted) return;

      if (_dateRange == null) {
        _showMessage('Vui lòng chọn ngày nhận và trả phòng.');
        return;
      }
    }

    if (!room.isAvailable) {
      _showMessage('Phòng hiện đang tạm đóng.');
      return;
    }

    if (_guests > room.maxGuests) {
      _showMessage(
        'Phòng chỉ phù hợp tối đa '
        '${room.maxGuests} khách.',
      );
      return;
    }

    final nights = _dateRange!.end.difference(_dateRange!.start).inDays;

    final total = room.price * nights;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.event_available_outlined),
          title: const Text('Xác nhận đặt phòng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.hotel.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '${room.type} · Phòng '
                '${room.roomNumber}',
              ),
              Text(
                '${_formatDate(_dateRange!.start)} - '
                '${_formatDate(_dateRange!.end)}',
              ),
              Text('$nights đêm · $_guests khách'),
              const SizedBox(height: 12),
              Text(
                'Tổng tiền: ${_formatMoney(total)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Đặt phòng'),
            ),
          ],
        );
      },
    );

    if (!mounted || accepted != true) return;

    setState(() => _bookingRoomId = room.id);

    try {
      await widget.service.createBooking(
        hotel: widget.hotel,
        room: room,
        checkIn: _dateRange!.start,
        checkOut: _dateRange!.end,
        guests: _guests,
      );

      if (!mounted) return;

      _showMessage(
        'Đặt phòng thành công. '
        'Đơn đang chờ nhà cung cấp xác nhận.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _bookingRoomId = null);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hotel = widget.hotel;

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết khách sạn')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomerImageCarousel(
              images: hotel.images,
              fallbackIcon: Icons.apartment_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        hotel.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const Icon(Icons.star_rounded, color: Colors.orange),
                    const SizedBox(width: 3),
                    Text(
                      hotel.rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 19,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        hotel.fullAddress.isEmpty
                            ? 'Chưa cập nhật địa chỉ'
                            : hotel.fullAddress,
                      ),
                    ),
                  ],
                ),
                if (hotel.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(hotel.description, style: const TextStyle(height: 1.5)),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _BookingFilter(
                        icon: Icons.calendar_today_outlined,
                        title: 'Thời gian',
                        value: _dateRange == null
                            ? 'Chọn ngày'
                            : '${_formatShortDate(_dateRange!.start)} - '
                                  '${_formatShortDate(_dateRange!.end)}',
                        onTap: _selectDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BookingFilter(
                        icon: Icons.group_outlined,
                        title: 'Khách',
                        value: '$_guests người',
                        onTap: _selectGuests,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Các phòng',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'Phòng phù hợp cho $_guests khách.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<RoomModel>>(
                  stream: widget.service.watchRooms(
                    hotelId: hotel.id,
                    hotelName: hotel.name,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return CustomerEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Không thể tải phòng',
                        message: _cleanError(snapshot.error),
                      );
                    }

                    final rooms = snapshot.data ?? [];

                    if (rooms.isEmpty) {
                      return const CustomerEmptyState(
                        icon: Icons.bed_outlined,
                        title: 'Khách sạn chưa có phòng',
                        message:
                            'Nhà cung cấp chưa thêm phòng '
                            'hoặc hotelId của phòng không đúng.',
                      );
                    }

                    return Column(
                      children: rooms.map((room) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: CustomerRoomCard(
                            room: room,
                            guests: _guests,
                            booking: _bookingRoomId == room.id,
                            onBook: room.canAccommodate(_guests)
                                ? () => _bookRoom(room)
                                : null,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingFilter extends StatelessWidget {
  const _BookingFilter({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11)),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';
}

String _formatMoney(double value) {
  final raw = value.toStringAsFixed(0);

  final formatted = raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );

  return '$formatted đ';
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
