import 'package:flutter/material.dart';

import '../../../model/hotel.dart';
import '../../../model/room.dart';
import '../../../model/room_rate_plan.dart';
import '../../../services/customer_service.dart';
import '../bookings/booking_form_screen.dart';
import '../widgets/image_carousel.dart';

class RoomDetailsScreen extends StatelessWidget {
  const RoomDetailsScreen({
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

  Future<void> _openBookingForm(
    BuildContext context,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BookingFormScreen(
          service: service,
          hotel: hotel,
          room: room,
          initialCheckIn: initialCheckIn,
          initialCheckOut: initialCheckOut,
          initialGuests: initialGuests,
        ),
      ),
    );

    if (!context.mounted || saved != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã gửi yêu cầu. Vui lòng chờ '
          'nhà cung cấp xác nhận.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final canBook = room.isAvailable &&
        room.effectiveFirstHourPrice > 0 &&
        room.effectiveAdditionalHourPrice > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết phòng'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 112),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomerImageCarousel(
              images: room.images,
              fallbackIcon: Icons.bed_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              0,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '${room.type} · '
                  'Phòng ${room.roomNumber}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  hotel.name,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RoomFeature(
                      icon: Icons.groups_outlined,
                      label:
                          'Tối đa ${room.maxGuests} khách',
                    ),
                    if (room.area > 0)
                      _RoomFeature(
                        icon:
                            Icons.square_foot_outlined,
                        label:
                            '${room.area.toStringAsFixed(0)} m²',
                      ),
                    if (room.bedCount > 0)
                      _RoomFeature(
                        icon: Icons.bed_outlined,
                        label: '${room.bedCount} '
                            '${room.bedType.isEmpty ? 'giường' : room.bedType}',
                      ),
                    _RoomFeature(
                      icon: room.isAvailable
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                      label: room.isAvailable
                          ? 'Đang nhận khách'
                          : 'Tạm đóng',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Bảng giá',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                _PricePanel(room: room),
                if (room.enabledRatePlans.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Combo đang áp dụng',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...room.enabledRatePlans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: 8,
                      ),
                      child: _RatePlanTile(
                        plan: plan,
                      ),
                    ),
                  ),
                ],
                if (room.description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Mô tả phòng',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    room.description,
                    style: const TextStyle(
                      height: 1.5,
                    ),
                  ),
                ],
                if (room.amenities.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Tiện ích',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...room.amenities.map(
                    (amenity) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: 9,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .check_circle_outline,
                            size: 19,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(amenity),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
            onPressed: canBook
                ? () => _openBookingForm(context)
                : null,
            icon: const Icon(
              Icons.event_available_outlined,
            ),
            label: Text(
              room.isAvailable
                  ? 'Chọn ngày và khung giờ'
                  : 'Phòng đang tạm đóng',
            ),
          ),
        ),
      ),
    );
  }
}

class _PricePanel extends StatelessWidget {
  const _PricePanel({
    required this.room,
  });

  final RoomModel room;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _PriceRow(
            label: 'Giờ đầu tiên',
            value: _money(
              room.effectiveFirstHourPrice,
            ),
          ),
          const SizedBox(height: 8),
          _PriceRow(
            label: 'Từ giờ thứ hai',
            value:
                '${_money(room.effectiveAdditionalHourPrice)}/giờ',
          ),
          const Divider(height: 24),
          _PriceRow(
            label: 'Phụ thu cuối tuần',
            value:
                '${_percent(room.weekendSurchargePercent)}%',
          ),
          const SizedBox(height: 8),
          _PriceRow(
            label: 'Phụ thu ngày lễ',
            value:
                '${_percent(room.holidaySurchargePercent)}%',
          ),
          const SizedBox(height: 10),
          Text(
            'Ngày lễ không cộng dồn phụ thu cuối tuần.',
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatePlanTile extends StatelessWidget {
  const _RatePlanTile({
    required this.plan,
  });

  final RoomRatePlan plan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_outlined,
            color: colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${plan.timeLabel} · '
                  '${plan.durationHours} giờ',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _money(plan.price),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RoomFeature extends StatelessWidget {
  const _RoomFeature({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _percent(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(1);
}

String _money(double value) {
  final raw = value.round().toString();

  return '${raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  )}đ';
}