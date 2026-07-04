import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/booking.dart';
import '../../model/hotel.dart';
import '../../services/customer_service.dart';
import '../../services/review_service.dart';
import 'payment_screen.dart';
import 'review_form_screen.dart';
import 'widgets/payment_countdown.dart';

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({
    super.key,
    required this.service,
    required this.booking,
  });

  final CustomerService service;
  final BookingModel booking;

  @override
  State<BookingDetailsScreen> createState() =>
      _BookingDetailsScreenState();
}

class _BookingDetailsScreenState
    extends State<BookingDetailsScreen> {
  late final ReviewService _reviewService;
  bool _cancelling = false;

  BookingModel get booking => widget.booking;

  @override
  void initState() {
    super.initState();
    _reviewService = ReviewService();
  }

  Future<void> _cancel() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.cancel_outlined),
        title: const Text('Hủy đơn đặt phòng?'),
        content: Text(
          'Bạn có chắc muốn hủy đơn tại "${booking.hotelName}"?\n\n'
          'Khung giờ sẽ được mở lại cho khách hàng khác.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (!mounted || accepted != true) return;

    setState(() => _cancelling = true);

    try {
      await widget.service.cancelBooking(booking);

      if (!mounted) return;

      _message('Đã hủy đơn đặt phòng.');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      setState(() => _cancelling = false);
      _message(_cleanError(error));
    }
  }

  void _openPayment() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentScreen(
          service: widget.service,
          booking: booking,
        ),
      ),
    );
  }

  void _openReview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewFormScreen(
          service: _reviewService,
          booking: booking,
        ),
      ),
    );
  }

  Future<void> _openUri(Uri uri) async {
    try {
      var opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        opened = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }

      if (!opened && mounted) {
        _message(
          'Không tìm thấy ứng dụng phù hợp để mở liên kết.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      _message(
        'Không thể mở liên kết: ${_cleanError(error)}',
      );
    }
  }

  Future<void> _openGoogleMaps(HotelModel hotel) async {
    final destination = _buildMapsAddress(hotel);

    if (destination.isEmpty) {
      _message('Khách sạn chưa cập nhật địa chỉ.');
      return;
    }

    await _openUri(
      Uri.https(
        'www.google.com',
        '/maps/dir/',
        {
          'api': '1',
          'destination': destination,
          'travelmode': 'driving',
          'dir_action': 'navigate',
        },
      ),
    );
  }

  Future<void> _openPhone(String phone) async {
    final value = phone.replaceAll(
      RegExp(r'[\s.\-()]'),
      '',
    );

    if (value.isEmpty) {
      _message('Số điện thoại không hợp lệ.');
      return;
    }

    await _openUri(Uri(scheme: 'tel', path: value));
  }

  Future<void> _openEmail(String email) async {
    final value = email.trim();

    if (value.isEmpty) {
      _message('Email không hợp lệ.');
      return;
    }

    await _openUri(
      Uri(
        scheme: 'mailto',
        path: value,
        query: _encodeQueryParameters({
          'subject':
              'Liên hệ đơn đặt phòng ${_shortBookingCode(booking.id)}',
        }),
      ),
    );
  }

  Future<void> _openZalo(String phone) async {
    final number = _zaloNumber(phone);

    if (number.isEmpty) {
      _message('Số điện thoại Zalo không hợp lệ.');
      return;
    }

    await _openUri(Uri.https('zalo.me', '/$number'));
  }

  Future<void> _openFacebook(String value) async {
    final uri = Uri.tryParse(_normalizeUrl(value));

    if (uri == null || uri.host.isEmpty) {
      _message('Liên kết Facebook không hợp lệ.');
      return;
    }

    await _openUri(uri);
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overdue =
        booking.status == BookingStatus.awaitingPayment &&
        booking.isPaymentOverdue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn đặt phòng'),
      ),
      bottomNavigationBar: _buildActions(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor:
                        colors.onPrimaryContainer,
                    child: const Icon(
                      Icons.hotel_outlined,
                      size: 29,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    booking.hotelName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking.roomType} · '
                    'Phòng ${booking.roomNumber}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusBadge(
                    label: overdue
                        ? 'Đã quá hạn thanh toán'
                        : booking.statusLabel,
                    color: overdue
                        ? colors.error
                        : _statusColor(booking.status),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Thời gian lưu trú',
            icon: Icons.calendar_month_outlined,
            children: [
              _InfoRow(
                label: 'Nhận phòng',
                value: _dateTime(booking.checkIn),
              ),
              _InfoRow(
                label: 'Trả phòng',
                value: _dateTime(booking.checkOut),
              ),
              _InfoRow(
                label: 'Thời lượng',
                value: booking.durationLabel,
              ),
              _InfoRow(
                label: 'Số khách',
                value: '${booking.guests} khách',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Thông tin đặt phòng',
            icon: Icons.receipt_long_outlined,
            children: [
              _InfoRow(
                label: 'Mã đặt phòng',
                value: _shortBookingCode(booking.id),
                selectable: true,
              ),
              _InfoRow(
                label: 'Phương án giá',
                value: booking.usesCombo
                    ? booking.ratePlanName
                    : 'Tính giá theo giờ',
              ),
              if (booking.specialRequests.trim().isNotEmpty)
                _InfoRow(
                  label: 'Yêu cầu',
                  value: booking.specialRequests,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Thanh toán',
            icon: Icons.payments_outlined,
            children: [
              _InfoRow(
                label: 'Trạng thái',
                value: _paymentStatusLabel(
                  booking.paymentStatus,
                ),
              ),
              if (booking.paymentReference.isNotEmpty)
                _InfoRow(
                  label: 'Nội dung CK',
                  value: booking.paymentReference,
                  selectable: true,
                ),
              if (booking.status ==
                      BookingStatus.awaitingPayment &&
                  booking.paymentDeadline != null) ...[
                const SizedBox(height: 6),
                CustomerPaymentCountdown(
                  deadline: booking.paymentDeadline!,
                ),
              ],
              const Divider(height: 24),
              Row(
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
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildLocationAndContact(),
        ],
      ),
    );
  }

  Widget _buildLocationAndContact() {
    if (!_canViewContact(booking.status)) {
      return const _Section(
        title: 'Vị trí và liên hệ',
        icon: Icons.location_on_outlined,
        children: [
          Text(
            'Thông tin sẽ xuất hiện sau khi nhà cung cấp duyệt đơn.',
          ),
        ],
      );
    }

    return StreamBuilder<HotelModel?>(
      stream: widget.service.watchHotel(booking.hotelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Section(
            title: 'Vị trí và liên hệ',
            icon: Icons.location_on_outlined,
            children: [
              Center(child: CircularProgressIndicator()),
            ],
          );
        }

        final hotel = snapshot.data;

        if (snapshot.hasError || hotel == null) {
          return const _Section(
            title: 'Vị trí và liên hệ',
            icon: Icons.location_on_outlined,
            children: [
              Text(
                'Không thể tải thông tin khách sạn.',
              ),
            ],
          );
        }

        return _Section(
          title: 'Vị trí và liên hệ',
          icon: Icons.location_on_outlined,
          children: [
            _ContactButton(
              icon: Icons.directions_outlined,
              title: 'Chỉ đường đến khách sạn',
              subtitle: hotel.fullAddress.isEmpty
                  ? 'Chưa cập nhật địa chỉ'
                  : hotel.fullAddress,
              emphasized: true,
              onPressed: () => _openGoogleMaps(hotel),
            ),
            if (hotel.hasContactInformation)
              const Divider(height: 20),
            if (!hotel.hasContactInformation)
              const Text(
                'Nhà cung cấp chưa cập nhật thông tin liên hệ.',
              ),
            if (hotel.contactPhone.isNotEmpty)
              _ContactButton(
                icon: Icons.phone_outlined,
                title: 'Gọi điện',
                subtitle: hotel.contactPhone,
                onPressed: () =>
                    _openPhone(hotel.contactPhone),
              ),
            if (hotel.contactEmail.isNotEmpty)
              _ContactButton(
                icon: Icons.email_outlined,
                title: 'Gửi email',
                subtitle: hotel.contactEmail,
                onPressed: () =>
                    _openEmail(hotel.contactEmail),
              ),
            if (hotel.zaloPhone.isNotEmpty)
              _ContactButton(
                icon: Icons.chat_outlined,
                title: 'Nhắn tin Zalo',
                subtitle: hotel.zaloPhone,
                onPressed: () =>
                    _openZalo(hotel.zaloPhone),
              ),
            if (hotel.facebookUrl.isNotEmpty)
              _ContactButton(
                icon: Icons.public_outlined,
                title: 'Mở Facebook',
                subtitle: 'Trang Facebook khách sạn',
                onPressed: () =>
                    _openFacebook(hotel.facebookUrl),
              ),
          ],
        );
      },
    );
  }

  Widget? _buildActions() {
    final canReview =
        booking.status == BookingStatus.completed;

    if (!booking.canCustomerPay &&
        !booking.canCustomerCancel &&
        !canReview) {
      return null;
    }

    return SafeArea(
      child: Material(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            10,
          ),
          child: Row(
            children: [
              if (booking.canCustomerCancel)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _cancelling ? null : _cancel,
                    icon: _cancelling
                        ? const SizedBox.square(
                            dimension: 18,
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
                ),
              if (booking.canCustomerCancel &&
                  booking.canCustomerPay)
                const SizedBox(width: 10),
              if (booking.canCustomerPay)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openPayment,
                    icon: const Icon(
                      Icons.qr_code_2_rounded,
                    ),
                    label: const Text('Thanh toán'),
                  ),
                ),
              if (canReview)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openReview,
                    icon: const Icon(
                      Icons.star_outline_rounded,
                    ),
                    label: const Text('Đánh giá phòng'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Text(
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

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: emphasized
          ? colors.primaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: onPressed,
        leading: CircleAvatar(
          backgroundColor: emphasized
              ? colors.primary
              : colors.secondaryContainer,
          foregroundColor: emphasized
              ? colors.onPrimary
              : colors.onSecondaryContainer,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          emphasized
              ? Icons.navigation_outlined
              : Icons.open_in_new_rounded,
        ),
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
          horizontal: 10,
          vertical: 7,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

bool _canViewContact(String status) {
  return {
    BookingStatus.awaitingPayment,
    BookingStatus.paymentReview,
    BookingStatus.confirmed,
    BookingStatus.completed,
  }.contains(status);
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

String _paymentStatusLabel(String status) {
  return switch (status) {
    PaymentStatus.submitted => 'Đã gửi xác nhận',
    PaymentStatus.paid => 'Đã thanh toán',
    PaymentStatus.rejected =>
      'Thanh toán bị từ chối',
    PaymentStatus.expired => 'Đã quá hạn',
    _ => 'Chưa thanh toán',
  };
}

String _buildMapsAddress(HotelModel hotel) {
  final parts = <String>[];

  void add(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return;

    final current = parts.join(', ').toLowerCase();

    if (!current.contains(normalized.toLowerCase())) {
      parts.add(normalized);
    }
  }

  add(hotel.address);
  add(hotel.district);
  add(hotel.province);
  add('Việt Nam');

  return parts.join(', ');
}

String _shortBookingCode(String id) {
  var hash = 2166136261;

  for (final value in id.codeUnits) {
    hash ^= value;
    hash = (hash * 16777619) & 0x7fffffff;
  }

  return (hash % 100000000)
      .toString()
      .padLeft(8, '0');
}

String _zaloNumber(String value) {
  var number = value.replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );

  if (number.startsWith('84') &&
      number.length == 11) {
    number = '0${number.substring(2)}';
  }

  return number;
}

String _normalizeUrl(String value) {
  final url = value.trim();

  if (url.startsWith('http://') ||
      url.startsWith('https://')) {
    return url;
  }

  return 'https://$url';
}

String _encodeQueryParameters(
  Map<String, String> parameters,
) {
  return parameters.entries.map((entry) {
    return '${Uri.encodeComponent(entry.key)}='
        '${Uri.encodeComponent(entry.value)}';
  }).join('&');
}

String _dateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$hour:$minute · '
      '$day/$month/${value.year}';
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