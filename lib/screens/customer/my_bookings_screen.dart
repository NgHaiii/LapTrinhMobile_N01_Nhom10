import 'package:flutter/material.dart';

import '../../model/booking.dart';
import '../../services/customer_service.dart';
import 'payment_screen.dart';
import 'widgets/customer_empty_state.dart';
import 'widgets/payment_countdown.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({
    super.key,
    required this.service,
  });

  final CustomerService service;

  @override
  State<MyBookingsScreen> createState() =>
      _MyBookingsScreenState();
}

class _MyBookingsScreenState
    extends State<MyBookingsScreen> {
  String _status = 'all';
  String? _cancellingId;

  Future<void> _cancel(
    BookingModel booking,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.cancel_outlined),
        title: const Text('Hủy đơn đặt phòng?'),
        content: Text(
          'Bạn có chắc muốn hủy đơn tại '
          '"${booking.hotelName}"?\n\n'
          'Khung giờ sẽ được mở lại cho người khác.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (!mounted || accepted != true) return;

    setState(() => _cancellingId = booking.id);

    try {
      await widget.service.cancelBooking(booking);

      if (!mounted) return;
      _message('Đã hủy đơn đặt phòng.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _cancellingId = null);
      }
    }
  }

  void _openPayment(
    BookingModel booking,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentScreen(
          service: widget.service,
          booking: booking,
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn đặt phòng'),
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: widget.service.watchMyBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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
            return _status == 'all' ||
                _matchesFilter(booking, _status);
          }).toList();

          return Column(
            children: [
              SizedBox(
                height: 58,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filter(
                      'all',
                      'Tất cả',
                      allBookings.length,
                    ),
                    _filter(
                      'pending',
                      'Chờ duyệt',
                      _count(
                        allBookings,
                        'pending',
                      ),
                    ),
                    _filter(
                      BookingStatus.awaitingPayment,
                      'Chờ thanh toán',
                      _count(
                        allBookings,
                        BookingStatus
                            .awaitingPayment,
                      ),
                    ),
                    _filter(
                      BookingStatus.paymentReview,
                      'Đang kiểm tra',
                      _count(
                        allBookings,
                        BookingStatus
                            .paymentReview,
                      ),
                    ),
                    _filter(
                      BookingStatus.confirmed,
                      'Đã xác nhận',
                      _count(
                        allBookings,
                        BookingStatus.confirmed,
                      ),
                    ),
                    _filter(
                      BookingStatus.completed,
                      'Hoàn thành',
                      _count(
                        allBookings,
                        BookingStatus.completed,
                      ),
                    ),
                    _filter(
                      'ended',
                      'Đã kết thúc',
                      _count(
                        allBookings,
                        'ended',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: bookings.isEmpty
                    ? const CustomerEmptyState(
                        icon:
                            Icons.event_busy_outlined,
                        title:
                            'Không có đơn phù hợp',
                        message:
                            'Các đơn đặt phòng sẽ xuất hiện tại đây.',
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(
                              20,
                              4,
                              20,
                              32,
                            ),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder:
                            (context, index) {
                              final booking =
                                  bookings[index];

                              return _BookingCard(
                                booking: booking,
                                cancelling:
                                    _cancellingId ==
                                    booking.id,
                                onCancel: booking
                                        .canCustomerCancel
                                    ? () =>
                                          _cancel(booking)
                                    : null,
                                onPay: booking
                                        .canCustomerPay
                                    ? () => _openPayment(
                                        booking,
                                      )
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

  Widget _filter(
    String value,
    String label,
    int count,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 8,
        top: 10,
        bottom: 8,
      ),
      child: ChoiceChip(
        label: Text('$label · $count'),
        selected: _status == value,
        onSelected: (_) {
          setState(() => _status = value);
        },
      ),
    );
  }

  int _count(
    List<BookingModel> bookings,
    String filter,
  ) {
    return bookings
        .where(
          (booking) =>
              _matchesFilter(booking, filter),
        )
        .length;
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.cancelling,
    this.onCancel,
    this.onPay,
  });

  final BookingModel booking;
  final bool cancelling;
  final VoidCallback? onCancel;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overdue = booking.isPaymentOverdue &&
        booking.status ==
            BookingStatus.awaitingPayment;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(
          14,
          8,
          10,
          8,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          14,
          0,
          14,
          15,
        ),
        leading: CircleAvatar(
          backgroundColor:
              colors.primaryContainer,
          foregroundColor:
              colors.onPrimaryContainer,
          child: const Icon(
            Icons.hotel_outlined,
          ),
        ),
        title: Text(
          booking.hotelName,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${booking.roomType} · '
          'Phòng ${booking.roomNumber}\n'
          '${_dateTime(booking.checkIn)}',
        ),
        trailing: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 105),
          child: _StatusBadge(
            label: overdue
                ? 'Quá hạn'
                : booking.statusLabel,
            color: overdue
                ? colors.error
                : _statusColor(
                    booking.status,
                  ),
          ),
        ),
        children: [
          const Divider(),
          _InfoRow(
            icon: Icons.login_rounded,
            label: 'Nhận phòng',
            value: _dateTime(booking.checkIn),
          ),
          _InfoRow(
            icon: Icons.logout_rounded,
            label: 'Trả phòng',
            value: _dateTime(booking.checkOut),
          ),
          _InfoRow(
            icon: Icons.groups_outlined,
            label: 'Số khách',
            value: '${booking.guests} khách',
          ),
          _InfoRow(
            icon: booking.usesCombo
                ? Icons.local_offer_outlined
                : Icons.schedule_outlined,
            label: 'Gói giá',
            value: booking.usesCombo
                ? booking.ratePlanName
                : 'Tính theo giờ',
          ),
          _InfoRow(
            icon: Icons.timer_outlined,
            label: 'Thời lượng',
            value: booking.durationLabel,
          ),
          if (booking.specialRequests.isNotEmpty)
            _InfoRow(
              icon: Icons.notes_outlined,
              label: 'Yêu cầu',
              value: booking.specialRequests,
            ),
          if (booking.status ==
                  BookingStatus.awaitingPayment &&
              booking.paymentDeadline != null) ...[
            const SizedBox(height: 7),
            CustomerPaymentCountdown(
              deadline: booking.paymentDeadline!,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color:
                  colors.surfaceContainerLow,
              borderRadius:
                  BorderRadius.circular(8),
              border: Border.all(
                color: colors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tổng thanh toán',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _money(booking.totalAmount),
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onPay != null)
                FilledButton.icon(
                  onPressed: onPay,
                  icon: const Icon(
                    Icons.qr_code_2_rounded,
                  ),
                  label:
                      const Text('Thanh toán'),
                ),
              if (onCancel != null)
                OutlinedButton.icon(
                  onPressed:
                      cancelling ? null : onCancel,
                  icon: cancelling
                      ? const SizedBox.square(
                          dimension: 17,
                          child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                        )
                      : const Icon(
                          Icons.cancel_outlined,
                        ),
                  label: const Text('Hủy đơn'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 5,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

bool _matchesFilter(
  BookingModel booking,
  String filter,
) {
  if (filter == 'pending') {
    return booking.status ==
            BookingStatus.pending ||
        booking.status ==
            BookingStatus.pendingProvider;
  }

  if (filter == 'ended') {
    return booking.isFinished;
  }

  return booking.status == filter;
}

Color _statusColor(String status) {
  return switch (status) {
    BookingStatus.awaitingPayment => Colors.blue,
    BookingStatus.paymentReview => Colors.indigo,
    BookingStatus.confirmed => Colors.green,
    BookingStatus.completed => Colors.teal,
    BookingStatus.cancelled => Colors.grey,
    BookingStatus.rejected ||
    BookingStatus.expired => Colors.red,
    _ => Colors.orange,
  };
}

String _dateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month =
      value.month.toString().padLeft(2, '0');
  final hour =
      value.hour.toString().padLeft(2, '0');
  final minute =
      value.minute.toString().padLeft(2, '0');

  return '$day/$month/${value.year} '
      '$hour:$minute';
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