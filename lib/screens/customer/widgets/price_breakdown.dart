import 'package:flutter/material.dart';

import '../../../model/pricing_quote.dart';

class CustomerPriceBreakdown
    extends StatelessWidget {
  const CustomerPriceBreakdown({
    super.key,
    required this.quote,
  });

  final PricingQuote quote;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final entries = quote.breakdown.entries
        .where((entry) => entry.value > 0)
        .toList();

    final roundingAmount =
        quote.totalAmount - quote.subtotal;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chi tiết giá',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _PricingTypeBadge(
                label: quote.usesCombo
                    ? 'Combo'
                    : 'Theo giờ',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PriceRow(
            label: 'Nhận phòng',
            value: _dateTime(quote.checkIn),
          ),
          _PriceRow(
            label: 'Trả phòng',
            value: _dateTime(quote.checkOut),
          ),
          _PriceRow(
            label: 'Thời lượng',
            value: quote.durationLabel,
          ),
          if (quote.usesCombo) ...[
            const Divider(height: 24),
            _PriceRow(
              label: 'Gói giá',
              value: quote.ratePlanName,
              emphasized: true,
            ),
            if (quote.ratePlanType.isNotEmpty)
              _PriceRow(
                label: 'Loại combo',
                value: _ratePlanTypeLabel(
                  quote.ratePlanType,
                ),
              ),
          ] else ...[
            const Divider(height: 24),
            _PriceRow(
              label: 'Giá giờ đầu',
              value: _money(
                quote.effectiveFirstHourPrice,
              ),
            ),
            if (quote.billedMinutes > 60)
              _PriceRow(
                label: 'Giá từ giờ thứ hai',
                value:
                    '${_money(quote.effectiveAdditionalHourPrice)}/giờ',
              ),
          ],
          if (entries.isNotEmpty) ...[
            const Divider(height: 24),
            ...entries.map(
              (entry) => _PriceRow(
                label: _breakdownLabel(entry.key),
                value: _money(entry.value),
              ),
            ),
          ],
          if (quote.calendarSurchargeAmount > 0 &&
              !quote.breakdown.containsKey(
                'weekendSurcharge',
              ) &&
              !quote.breakdown.containsKey(
                'holidaySurcharge',
              ))
            _PriceRow(
              label: 'Phụ thu theo lịch',
              value: _money(
                quote.calendarSurchargeAmount,
              ),
            ),
          if (quote.overtimeAmount > 0)
            _PriceRow(
              label: 'Thời gian ngoài combo',
              value: _money(
                quote.overtimeAmount,
              ),
            ),
          if (roundingAmount.abs() >= 1) ...[
            const Divider(height: 20),
            _PriceRow(
              label: 'Điều chỉnh làm tròn',
              value: _signedMoney(roundingAmount),
            ),
          ],
          if (quote.appliedRules.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Chính sách đã áp dụng',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...quote.appliedRules.map(
              (rule) => Padding(
                padding:
                    const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        rule,
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 25),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tổng thanh toán',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _money(quote.totalAmount),
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Số tiền này được lưu vào đơn đặt phòng '
            'và không thay đổi khi nhà cung cấp sửa giá.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
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
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasized
                    ? FontWeight.w800
                    : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: emphasized
                    ? FontWeight.w900
                    : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingTypeBadge extends StatelessWidget {
  const _PricingTypeBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.onPrimaryContainer,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _breakdownLabel(String key) {
  return switch (key) {
    'firstHour' => 'Giờ đầu tiên',
    'additionalHours' => 'Các giờ tiếp theo',
    'ratePlan' => 'Giá combo',
    'weekendSurcharge' =>
      'Phụ thu cuối tuần',
    'holidaySurcharge' =>
      'Phụ thu ngày lễ',
    'calendarSurcharge' =>
      'Phụ thu theo lịch',
    'overtime' => 'Thời gian ngoài combo',

    // Giữ tương thích dữ liệu giá cũ.
    'holiday' => 'Thời gian ngày lễ',
    'weekend' => 'Thời gian cuối tuần',
    'weekendDaytime' =>
      'Cuối tuần ban ngày',
    'weekendPeak' =>
      'Cuối tuần giờ cao điểm',
    'weekendNight' =>
      'Cuối tuần ban đêm',
    'weekdayDaytime' =>
      'Ngày thường ban ngày',
    'weekdayPeak' =>
      'Ngày thường giờ cao điểm',
    'weekdayNight' =>
      'Ngày thường ban đêm',
    _ => 'Chi phí phòng',
  };
}

String _ratePlanTypeLabel(String value) {
  return switch (value) {
    'overnight' => 'Combo qua đêm',
    'dayNight' => 'Combo ngày đêm',
    _ => 'Combo ban ngày',
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

String _signedMoney(double value) {
  if (value > 0) return '+${_money(value)}';
  if (value < 0) return '-${_money(value.abs())}';

  return _money(0);
}

String _money(double value) {
  final raw = value.round().toString();

  return '${raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  )}đ';
}