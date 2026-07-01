import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/booking.dart';
import '../../services/customer_service.dart';
import '../../services/provider_payment_service.dart';
import 'widgets/payment_countdown.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.service,
    required this.booking,
  });

  final CustomerService service;
  final BookingModel booking;

  @override
  State<PaymentScreen> createState() =>
      _PaymentScreenState();
}

class _PaymentScreenState
    extends State<PaymentScreen> {
  final ProviderPaymentService _paymentService =
      ProviderPaymentService();

  bool _submitting = false;

  Future<void> _copy(
    String value,
    String label,
  ) async {
    if (value.trim().isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label.'),
      ),
    );
  }

  Future<void> _submitPayment(
    BookingModel booking,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.account_balance_outlined,
        ),
        title: const Text(
          'Xác nhận đã chuyển khoản?',
        ),
        content: Text(
          'Hãy kiểm tra chính xác:\n\n'
          'Số tiền: ${_money(booking.totalAmount)}\n'
          'Nội dung: ${booking.paymentReference}\n\n'
          'Hệ thống không tự động kiểm tra giao dịch. '
          'Nhà cung cấp sẽ xác nhận thủ công.',
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
            child: const Text(
              'Tôi đã thanh toán',
            ),
          ),
        ],
      ),
    );

    if (!mounted || accepted != true) return;

    setState(() => _submitting = true);

    try {
      await widget.service.submitPayment(
        booking.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi xác nhận. Nhà cung cấp '
            'sẽ kiểm tra giao dịch.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BookingModel?>(
      stream: widget.service.watchBooking(
        widget.booking.id,
      ),
      initialData: widget.booking,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Thanh toán'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _cleanError(snapshot.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final booking = snapshot.data;

        if (booking == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Thanh toán'),
            ),
            body: const Center(
              child: Text(
                'Không tìm thấy đơn đặt phòng.',
              ),
            ),
          );
        }

        return _PaymentContent(
          booking: booking,
          paymentService: _paymentService,
          submitting: _submitting,
          onSubmit: () =>
              _submitPayment(booking),
          onCopy: _copy,
          onExpired: () {
            if (mounted) setState(() {});
          },
        );
      },
    );
  }
}

class _PaymentContent extends StatelessWidget {
  const _PaymentContent({
    required this.booking,
    required this.paymentService,
    required this.submitting,
    required this.onSubmit,
    required this.onCopy,
    required this.onExpired,
  });

  final BookingModel booking;
  final ProviderPaymentService paymentService;
  final bool submitting;
  final VoidCallback onSubmit;
  final Future<void> Function(
    String value,
    String label,
  )
  onCopy;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canPay = booking.canCustomerPay;

    String? qrUrl;
    String? qrError;

    if (booking.hasReceiverAccount) {
      try {
        qrUrl = paymentService
            .createBookingQrUrl(booking);
      } catch (error) {
        qrError = _cleanError(error);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán VietQR'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          14,
          20,
          112,
        ),
        children: [
          Text(
            booking.hotelName,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            '${booking.roomType} · '
            'Phòng ${booking.roomNumber}',
          ),
          const SizedBox(height: 5),
          Text(
            '${_dateTime(booking.checkIn)} - '
            '${_dateTime(booking.checkOut)}',
            style: TextStyle(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (booking.paymentDeadline != null &&
              booking.paymentStatus !=
                  PaymentStatus.paid)
            CustomerPaymentCountdown(
              deadline: booking.paymentDeadline!,
              onExpired: onExpired,
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Số tiền cần thanh toán',
                  style: TextStyle(
                    color:
                        colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _money(booking.totalAmount),
                  style: TextStyle(
                    color:
                        colors.onPrimaryContainer,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  booking.usesCombo
                      ? booking.ratePlanName
                      : '${booking.durationLabel} · '
                            'tính theo giờ',
                  style: TextStyle(
                    color:
                        colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (booking.status ==
              BookingStatus.paymentReview)
            const _StatusNotice(
              icon: Icons.hourglass_top_rounded,
              title: 'Đang kiểm tra thanh toán',
              message:
                  'Nhà cung cấp đang kiểm tra giao dịch.',
            )
          else if (booking.paymentStatus ==
              PaymentStatus.paid)
            const _StatusNotice(
              icon: Icons.verified_rounded,
              title: 'Đã thanh toán',
              message:
                  'Nhà cung cấp đã xác nhận nhận tiền.',
            )
          else if (booking.isPaymentOverdue)
            const _StatusNotice(
              icon: Icons.timer_off_outlined,
              title: 'Đã quá hạn thanh toán',
              message:
                  'Mã thanh toán này không còn hiệu lực.',
              error: true,
            )
          else if (!booking.hasReceiverAccount)
            const _StatusNotice(
              icon:
                  Icons.account_balance_outlined,
              title:
                  'Chưa có thông tin nhận tiền',
              message:
                  'Nhà cung cấp chưa cập nhật tài khoản.',
              error: true,
            )
          else ...[
            if (booking.paymentStatus ==
                PaymentStatus.rejected) ...[
              const _StatusNotice(
                icon: Icons.info_outline,
                title:
                    'Chưa xác nhận được giao dịch',
                message:
                    'Hãy kiểm tra lại tài khoản, số tiền '
                    'và nội dung chuyển khoản.',
                error: true,
              ),
              const SizedBox(height: 16),
            ],
            if (qrUrl != null)
              Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                        maxWidth: 420,
                      ),
                  child: AspectRatio(
                    aspectRatio: 540 / 640,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.network(
                        qrUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (
                          context,
                          child,
                          progress,
                        ) {
                          if (progress == null) {
                            return child;
                          }

                          return const Center(
                            child:
                                CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (_, __, ___) =>
                            const _QrError(),
                      ),
                    ),
                  ),
                ),
              )
            else
              _StatusNotice(
                icon: Icons.qr_code_2_rounded,
                title: 'Không thể tạo mã QR',
                message: qrError ??
                    'Thông tin tài khoản không hợp lệ.',
                error: true,
              ),
            const SizedBox(height: 18),
            _PaymentInformation(
              booking: booking,
              onCopy: onCopy,
            ),
            const SizedBox(height: 14),
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
              child: const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sau khi chuyển khoản, nhấn '
                      '"Tôi đã thanh toán". Nhà cung cấp '
                      'sẽ kiểm tra và xác nhận thủ công.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: canPay
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  12,
                ),
                child: FilledButton.icon(
                  onPressed:
                      submitting ? null : onSubmit,
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                        )
                      : const Icon(
                          Icons
                              .check_circle_outline,
                        ),
                  label: Text(
                    submitting
                        ? 'Đang gửi xác nhận...'
                        : 'Tôi đã thanh toán',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _PaymentInformation extends StatelessWidget {
  const _PaymentInformation({
    required this.booking,
    required this.onCopy,
  });

  final BookingModel booking;
  final Future<void> Function(
    String value,
    String label,
  )
  onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _CopyRow(
            label: 'Ngân hàng',
            value: booking.receiverBankName,
          ),
          _CopyRow(
            label: 'Số tài khoản',
            value: booking.receiverAccountNumber,
            onCopy: () => onCopy(
              booking.receiverAccountNumber,
              'số tài khoản',
            ),
          ),
          _CopyRow(
            label: 'Chủ tài khoản',
            value: booking.receiverAccountName,
          ),
          _CopyRow(
            label: 'Nội dung',
            value: booking.paymentReference,
            onCopy: () => onCopy(
              booking.paymentReference,
              'nội dung chuyển khoản',
            ),
          ),
          _CopyRow(
            label: 'Số tiền',
            value: _money(booking.totalAmount),
            onCopy: () => onCopy(
              booking.totalAmount
                  .round()
                  .toString(),
              'số tiền',
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        value.isEmpty ? 'Chưa cập nhật' : value,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      trailing: onCopy == null
          ? null
          : IconButton(
              tooltip: 'Sao chép',
              onPressed: onCopy,
              icon: const Icon(
                Icons.copy_rounded,
              ),
            ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color =
        error ? colors.error : colors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: color),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QrError extends StatelessWidget {
  const _QrError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
          ),
          SizedBox(height: 8),
          Text('Không thể tải ảnh VietQR'),
        ],
      ),
    );
  }
}

String _dateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month =
      value.month.toString().padLeft(2, '0');
  final hour =
      value.hour.toString().padLeft(2, '0');
  final minute =
      value.minute.toString().padLeft(2, '0');

  return '$day/$month $hour:$minute';
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