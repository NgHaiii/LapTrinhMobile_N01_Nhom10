import 'package:flutter/material.dart';

import '../../model/booking.dart';
import '../../services/provider_service.dart';

class ProviderBookingsPage extends StatefulWidget {
  const ProviderBookingsPage({
    super.key,
    required this.service,
  });

  final ProviderService service;

  @override
  State<ProviderBookingsPage> createState() =>
      _ProviderBookingsPageState();
}

class _ProviderBookingsPageState
    extends State<ProviderBookingsPage> {
  final _searchController = TextEditingController();

  String _filter = 'all';
  String _search = '';
  String? _processingId;

  Future<void> _execute(
    BookingModel booking,
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_processingId != null) return;

    setState(() => _processingId = booking.id);

    try {
      await action();

      if (!mounted) return;
      _message(successMessage);
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  Future<void> _confirmAction({
    required BookingModel booking,
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (!mounted || accepted != true) return;

    await _execute(
      booking,
      action,
      successMessage,
    );
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BookingModel>>(
      stream: widget.service.watchBookingModels(),
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _cleanError(snapshot.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final allBookings = snapshot.data ?? [];

        final bookings = allBookings.where((booking) {
          if (_filter != 'all' &&
              !_matchesFilter(booking, _filter)) {
            return false;
          }

          if (_search.isEmpty) return true;

          final source = [
            booking.customerName,
            booking.customerPhone,
            booking.customerEmail,
            booking.hotelName,
            booking.roomNumber,
            booking.paymentReference,
          ].join(' ').toLowerCase();

          return source.contains(_search);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                8,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(
                    () => _search =
                        value.trim().toLowerCase(),
                  );
                },
                decoration: InputDecoration(
                  hintText:
                      'Tìm khách hàng, phòng, mã đơn...',
                  prefixIcon:
                      const Icon(Icons.search_rounded),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon:
                              const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip(
                    'all',
                    'Tất cả',
                    allBookings.length,
                  ),
                  _filterChip(
                    'pending',
                    'Chờ duyệt',
                    _count(
                      allBookings,
                      'pending',
                    ),
                  ),
                  _filterChip(
                    BookingStatus.awaitingPayment,
                    'Chờ thanh toán',
                    _count(
                      allBookings,
                      BookingStatus.awaitingPayment,
                    ),
                  ),
                  _filterChip(
                    BookingStatus.paymentReview,
                    'Kiểm tra tiền',
                    _count(
                      allBookings,
                      BookingStatus.paymentReview,
                    ),
                  ),
                  _filterChip(
                    BookingStatus.confirmed,
                    'Đã xác nhận',
                    _count(
                      allBookings,
                      BookingStatus.confirmed,
                    ),
                  ),
                  _filterChip(
                    BookingStatus.completed,
                    'Hoàn thành',
                    _count(
                      allBookings,
                      BookingStatus.completed,
                    ),
                  ),
                  _filterChip(
                    'ended',
                    'Đã kết thúc',
                    _count(allBookings, 'ended'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: bookings.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(
                            20,
                            6,
                            20,
                            28,
                          ),
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final booking =
                            bookings[index];

                        return _BookingCard(
                          booking: booking,
                          processing:
                              _processingId ==
                              booking.id,
                          onApprove: () =>
                              _confirmAction(
                                booking: booking,
                                title:
                                    'Xác nhận đơn?',
                                message:
                                    'Sau khi xác nhận, khách hàng có 2 giờ để thanh toán.',
                                confirmLabel:
                                    'Xác nhận',
                                action: () => widget
                                    .service
                                    .approveBooking(
                                      booking.id,
                                    ),
                                successMessage:
                                    'Đã xác nhận đơn và mở thanh toán.',
                              ),
                          onReject: () =>
                              _confirmAction(
                                booking: booking,
                                title:
                                    'Từ chối đơn?',
                                message:
                                    'Khung giờ sẽ được mở lại cho khách hàng khác.',
                                confirmLabel:
                                    'Từ chối',
                                action: () => widget
                                    .service
                                    .rejectBooking(
                                      booking.id,
                                    ),
                                successMessage:
                                    'Đã từ chối đơn.',
                              ),
                          onConfirmPayment: () =>
                              _confirmAction(
                                booking: booking,
                                title:
                                    'Đã nhận tiền?',
                                message:
                                    'Chỉ xác nhận sau khi số tiền đã vào tài khoản.',
                                confirmLabel:
                                    'Đã nhận tiền',
                                action: () => widget
                                    .service
                                    .confirmPayment(
                                      booking.id,
                                    ),
                                successMessage:
                                    'Đã xác nhận thanh toán.',
                              ),
                          onRejectPayment: () =>
                              _confirmAction(
                                booking: booking,
                                title:
                                    'Chưa nhận tiền?',
                                message:
                                    'Khách hàng sẽ có thêm 1 giờ để kiểm tra và gửi lại.',
                                confirmLabel:
                                    'Chưa nhận tiền',
                                action: () => widget
                                    .service
                                    .rejectPayment(
                                      booking.id,
                                    ),
                                successMessage:
                                    'Đã yêu cầu khách kiểm tra lại.',
                              ),
                          onComplete: () =>
                              _confirmAction(
                                booking: booking,
                                title:
                                    'Hoàn thành đơn?',
                                message:
                                    'Xác nhận khách hàng đã sử dụng xong dịch vụ.',
                                confirmLabel:
                                    'Hoàn thành',
                                action: () => widget
                                    .service
                                    .completeBooking(
                                      booking.id,
                                    ),
                                successMessage:
                                    'Đã hoàn thành đơn.',
                              ),
                          onCancel: () =>
                              _confirmAction(
                                booking: booking,
                                title: 'Hủy đơn?',
                                message:
                                    'Khung giờ của phòng sẽ được mở lại.',
                                confirmLabel:
                                    'Hủy đơn',
                                action: () => widget
                                    .service
                                    .cancelBooking(
                                      booking.id,
                                    ),
                                successMessage:
                                    'Đã hủy đơn.',
                              ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(
    String value,
    String label,
    int count,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 8,
        bottom: 8,
      ),
      child: ChoiceChip(
        label: Text('$label · $count'),
        selected: _filter == value,
        onSelected: (_) {
          setState(() => _filter = value);
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
    required this.processing,
    required this.onApprove,
    required this.onReject,
    required this.onConfirmPayment,
    required this.onRejectPayment,
    required this.onComplete,
    required this.onCancel,
  });

  final BookingModel booking;
  final bool processing;

  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onConfirmPayment;
  final VoidCallback onRejectPayment;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final pending =
        booking.status == BookingStatus.pending ||
        booking.status ==
            BookingStatus.pendingProvider;

    final canCancel =
        booking.status ==
            BookingStatus.awaitingPayment ||
        booking.status == BookingStatus.confirmed;

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
          16,
        ),
        leading: CircleAvatar(
          backgroundColor:
              colors.primaryContainer,
          foregroundColor:
              colors.onPrimaryContainer,
          child: Text(
            booking.customerName.trim().isEmpty
                ? '?'
                : booking.customerName
                      .trim()
                      .substring(0, 1)
                      .toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          booking.customerName.isEmpty
              ? 'Khách hàng'
              : booking.customerName,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${booking.hotelName} · '
            'Phòng ${booking.roomNumber}\n'
            '${_dateTime(booking.checkIn)}',
          ),
        ),
        trailing: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 112),
          child: _StatusBadge(
            text: overdue
                ? 'Quá hạn thanh toán'
                : booking.statusLabel,
            color: overdue
                ? colors.error
                : _statusColor(booking.status),
          ),
        ),
        children: [
          const Divider(),
          _Info(
            icon: Icons.phone_outlined,
            title: 'Số điện thoại',
            value: booking.customerPhone.isEmpty
                ? 'Chưa cung cấp'
                : booking.customerPhone,
          ),
          _Info(
            icon: Icons.email_outlined,
            title: 'Email',
            value: booking.customerEmail.isEmpty
                ? 'Chưa cung cấp'
                : booking.customerEmail,
          ),
          _Info(
            icon: Icons.login_rounded,
            title: 'Nhận phòng',
            value: _dateTime(booking.checkIn),
          ),
          _Info(
            icon: Icons.logout_rounded,
            title: 'Trả phòng',
            value: _dateTime(booking.checkOut),
          ),
          _Info(
            icon: Icons.groups_outlined,
            title: 'Số khách',
            value: '${booking.guests} khách',
          ),
          _Info(
            icon: booking.usesCombo
                ? Icons.local_offer_outlined
                : Icons.schedule_outlined,
            title: 'Gói giá',
            value: booking.usesCombo
                ? '${booking.ratePlanName} · '
                      '${booking.durationLabel}'
                : 'Theo giờ · '
                      '${booking.durationLabel}',
          ),
          if (booking.specialRequests.isNotEmpty)
            _Info(
              icon: Icons.notes_outlined,
              title: 'Yêu cầu',
              value: booking.specialRequests,
            ),
          if (booking.paymentDeadline != null &&
              booking.paymentStatus !=
                  PaymentStatus.paid)
            _Info(
              icon: Icons.timer_outlined,
              title: 'Hạn thanh toán',
              value: _dateTime(
                booking.paymentDeadline!,
              ),
              valueColor:
                  overdue ? colors.error : null,
            ),
          if (booking.paymentReference.isNotEmpty)
            _Info(
              icon: Icons.tag_rounded,
              title: 'Nội dung chuyển khoản',
              value: booking.paymentReference,
            ),
          const SizedBox(height: 10),
          _PricingSummary(booking: booking),
          const SizedBox(height: 14),
          if (processing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pending) ...[
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon:
                        const Icon(Icons.check_rounded),
                    label:
                        const Text('Xác nhận đơn'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon:
                        const Icon(Icons.close_rounded),
                    label: const Text('Từ chối'),
                  ),
                ],
                if (booking.status ==
                    BookingStatus.paymentReview) ...[
                  FilledButton.icon(
                    onPressed: onConfirmPayment,
                    icon: const Icon(
                      Icons
                          .account_balance_outlined,
                    ),
                    label:
                        const Text('Đã nhận tiền'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onRejectPayment,
                    icon: const Icon(
                      Icons.money_off_outlined,
                    ),
                    label:
                        const Text('Chưa nhận tiền'),
                  ),
                ],
                if (booking.status ==
                    BookingStatus.confirmed)
                  FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(
                      Icons.task_alt_outlined,
                    ),
                    label:
                        const Text('Hoàn thành'),
                  ),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(
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

class _PricingSummary extends StatelessWidget {
  const _PricingSummary({
    required this.booking,
  });

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          if (booking.usesCombo)
            _PriceRow(
              label: booking.ratePlanName,
              value: booking.ratePlanPrice,
            )
          else ...[
            _PriceRow(
              label: 'Giờ đầu tiên',
              value:
                  booking.effectiveFirstHourPrice,
            ),
            if (booking.effectiveDurationMinutes >
                60)
              _PriceRow(
                label:
                    '${booking.effectiveDurationMinutes ~/ 60 - 1} giờ tiếp theo',
                value: booking
                        .effectiveAdditionalHourPrice *
                    (booking
                            .effectiveDurationMinutes ~/
                        60 -
                        1),
              ),
          ],
          if (booking.calendarSurchargeAmount > 0)
            _PriceRow(
              label: 'Phụ thu lịch',
              value:
                  booking.calendarSurchargeAmount,
            ),
          const Divider(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tổng thanh toán',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
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
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            _money(value),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: Text(
              title,
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
              style: TextStyle(
                color: valueColor,
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
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 5,
        ),
        child: Text(
          text,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 54,
          ),
          SizedBox(height: 10),
          Text('Không tìm thấy đơn đặt phòng'),
        ],
      ),
    );
  }
}

bool _matchesFilter(
  BookingModel booking,
  String filter,
) {
  if (filter == 'pending') {
    return booking.status == BookingStatus.pending ||
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