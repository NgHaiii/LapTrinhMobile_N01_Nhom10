import 'dart:async';

import 'package:flutter/material.dart';

class CustomerPaymentCountdown extends StatefulWidget {
  const CustomerPaymentCountdown({
    super.key,
    required this.deadline,
    this.onExpired,
  });

  final DateTime deadline;
  final VoidCallback? onExpired;

  @override
  State<CustomerPaymentCountdown> createState() =>
      _CustomerPaymentCountdownState();
}

class _CustomerPaymentCountdownState
    extends State<CustomerPaymentCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _expiredNotified = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(CustomerPaymentCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.deadline != widget.deadline) {
      _expiredNotified = false;
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _updateRemaining();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final difference = widget.deadline.difference(DateTime.now());
    final remaining = difference.isNegative
        ? Duration.zero
        : difference;

    if (!mounted) return;

    setState(() => _remaining = remaining);

    if (remaining == Duration.zero) {
      _timer?.cancel();

      if (!_expiredNotified) {
        _expiredNotified = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onExpired?.call();
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining == Duration.zero;
    final colors = Theme.of(context).colorScheme;

    final color = expired ? colors.error : colors.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(
              expired
                  ? Icons.timer_off_outlined
                  : Icons.timer_outlined,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                expired
                    ? 'Đã hết thời hạn thanh toán'
                    : 'Thời gian còn lại: ${_format(_remaining)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _format(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}