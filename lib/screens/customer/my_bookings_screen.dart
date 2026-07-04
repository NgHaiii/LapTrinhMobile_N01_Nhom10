import 'package:flutter/material.dart';

import '../../model/booking.dart';
import '../../services/customer_service.dart';
import 'booking_details_screen.dart';
import 'widgets/customer_empty_state.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.service});

  final CustomerService service;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn đặt phòng')),
      body: StreamBuilder<List<BookingModel>>(
        stream: widget.service.watchMyBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return CustomerEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Không thể tải đơn',
              message: _cleanError(snapshot.error),
            );
          }

          final allBookings = snapshot.data ?? [];
          final bookings = allBookings.where((booking) {
            return _status == 'all' || _matchesFilter(booking, _status);
          }).toList();

          return Column(
            children: [
              SizedBox(
                height: 58,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filter('all', 'Tất cả', allBookings),
                    _filter('pending', 'Chờ duyệt', allBookings),
                    _filter(
                      BookingStatus.awaitingPayment,
                      'Chờ thanh toán',
                      allBookings,
                    ),
                    _filter(
                      BookingStatus.paymentReview,
                      'Đang kiểm tra',
                      allBookings,
                    ),
                    _filter(
                      BookingStatus.confirmed,
                      'Đã xác nhận',
                      allBookings,
                    ),
                    _filter(
                      BookingStatus.completed,
                      'Hoàn thành',
                      allBookings,
                    ),
                    _filter('ended', 'Đã kết thúc', allBookings),
                  ],
                ),
              ),
              Expanded(
                child: bookings.isEmpty
                    ? const CustomerEmptyState(
                        icon: Icons.event_busy_outlined,
                        title: 'Không có đơn phù hợp',
                        message: 'Các đơn đặt phòng sẽ xuất hiện tại đây.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 400),
                          );
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                          itemCount: bookings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final booking = bookings[index];

                            return _BookingSummaryCard(
                              booking: booking,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => BookingDetailsScreen(
                                      service: widget.service,
                                      booking: booking,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filter(
    String value,
    String label,
    List<BookingModel> bookings,
  ) {
    final count = value == 'all'
        ? bookings.length
        : bookings.where((booking) {
            return _matchesFilter(booking, value);
          }).length;

    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 10, bottom: 8),
      child: ChoiceChip(
        label: Text('$label · $count'),
        selected: _status == value,
        onSelected: (_) => setState(() => _status = value),
      ),
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  const _BookingSummaryCard({
    required this.booking,
    required this.onPressed,
  });

  final BookingModel booking;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overdue = booking.status == BookingStatus.awaitingPayment &&
        booking.isPaymentOverdue;

    final statusColor = overdue
        ? colors.error
        : _statusColor(booking.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: const Icon(Icons.hotel_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.hotelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${booking.roomType} · Phòng ${booking.roomNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                    label: overdue ? 'Quá hạn' : booking.statusLabel,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DateSummary(
                          icon: Icons.login_rounded,
                          label: 'Nhận phòng',
                          value: _shortDateTime(booking.checkIn),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 38,
                        color: colors.outlineVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateSummary(
                          icon: Icons.logout_rounded,
                          label: 'Trả phòng',
                          value: _shortDateTime(booking.checkOut),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    booking.durationLabel,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    _money(booking.totalAmount),
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSummary extends StatelessWidget {
  const _DateSummary({
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

    return Row(
      children: [
        Icon(icon, size: 19, color: colors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 100),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

bool _matchesFilter(BookingModel booking, String filter) {
  if (filter == 'pending') {
    return booking.status == BookingStatus.pending ||
        booking.status == BookingStatus.pendingProvider;
  }

  if (filter == 'ended') return booking.isFinished;
  return booking.status == filter;
}

Color _statusColor(String status) {
  return switch (status) {
    BookingStatus.awaitingPayment => Colors.blue,
    BookingStatus.paymentReview => Colors.indigo,
    BookingStatus.confirmed => Colors.green,
    BookingStatus.completed => Colors.teal,
    BookingStatus.cancelled => Colors.grey,
    BookingStatus.rejected || BookingStatus.expired => Colors.red,
    _ => Colors.orange,
  };
}

String _shortDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$hour:$minute · $day/$month';
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