import 'package:flutter/material.dart';

import '../../model/booking.dart';
import '../../services/customer_service.dart';
import 'widgets/customer_empty_state.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.service});

  final CustomerService service;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  String _status = 'all';
  String? _cancellingId;

  Future<void> _cancelBooking(BookingModel booking) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.cancel_outlined),
          title: const Text('Hủy đơn đặt phòng?'),
          content: Text(
            'Bạn có chắc muốn hủy đơn tại '
            '"${booking.hotelName}" không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Không'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Hủy đơn'),
            ),
          ],
        );
      },
    );

    if (!mounted || accepted != true) return;

    setState(() => _cancellingId = booking.id);

    try {
      await widget.service.cancelBooking(booking);

      if (!mounted) return;

      _showMessage('Đã hủy đơn đặt phòng.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _cancellingId = null);
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

          final bookings = _status == 'all'
              ? allBookings
              : allBookings.where((booking) {
                  return booking.status == _status;
                }).toList();

          return Column(
            children: [
              SizedBox(
                height: 58,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _StatusFilter(
                      label: 'Tất cả',
                      selected: _status == 'all',
                      onTap: () {
                        setState(() => _status = 'all');
                      },
                    ),
                    _StatusFilter(
                      label: 'Chờ xác nhận',
                      selected: _status == BookingStatus.pending,
                      onTap: () {
                        setState(() {
                          _status = BookingStatus.pending;
                        });
                      },
                    ),
                    _StatusFilter(
                      label: 'Đã xác nhận',
                      selected: _status == BookingStatus.confirmed,
                      onTap: () {
                        setState(() {
                          _status = BookingStatus.confirmed;
                        });
                      },
                    ),
                    _StatusFilter(
                      label: 'Hoàn thành',
                      selected: _status == BookingStatus.completed,
                      onTap: () {
                        setState(() {
                          _status = BookingStatus.completed;
                        });
                      },
                    ),
                    _StatusFilter(
                      label: 'Đã hủy',
                      selected: _status == BookingStatus.cancelled,
                      onTap: () {
                        setState(() {
                          _status = BookingStatus.cancelled;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: bookings.isEmpty
                    ? const CustomerEmptyState(
                        icon: Icons.event_busy_outlined,
                        title: 'Không có đơn đặt phòng',
                        message: 'Các đơn phù hợp sẽ xuất hiện tại đây.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) {
                          return const SizedBox(height: 10);
                        },
                        itemBuilder: (context, index) {
                          final booking = bookings[index];

                          return _BookingCard(
                            booking: booking,
                            cancelling: _cancellingId == booking.id,
                            onCancel: booking.canCustomerCancel
                                ? () {
                                    _cancelBooking(booking);
                                  }
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
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 10, bottom: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.cancelling,
    this.onCancel,
  });

  final BookingModel booking;
  final bool cancelling;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(booking.status);

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
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.hotel_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.hotelName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${booking.roomType} · '
                        'Phòng ${booking.roomNumber}',
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Text(
                      booking.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_formatDate(booking.checkIn)} - '
                    '${_formatDate(booking.checkOut)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.group_outlined, size: 17),
                const SizedBox(width: 6),
                Text(
                  '${booking.guests} khách · '
                  '${booking.nights} đêm',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatMoney(booking.totalAmount),
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onCancel != null)
                  OutlinedButton.icon(
                    onPressed: cancelling ? null : onCancel,
                    icon: cancelling
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: const Text('Hủy đơn'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    BookingStatus.confirmed => Colors.green,
    BookingStatus.completed => Colors.blue,
    BookingStatus.cancelled => Colors.grey,
    BookingStatus.rejected => Colors.red,
    _ => Colors.orange,
  };
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
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
