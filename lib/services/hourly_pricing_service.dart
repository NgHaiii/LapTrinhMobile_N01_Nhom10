import '../model/holiday.dart';
import '../model/pricing_quote.dart';
import '../model/room_rate_plan.dart';

class HourlyPricingService {
  const HourlyPricingService({
    this.holidays = const [],
  });

  final List<HolidayInfo> holidays;

  static const int minimumHours = 1;
  static const int maximumHours = 24 * 30;

  PricingQuote calculate({
    required DateTime checkIn,
    required DateTime checkOut,
    double baseHourlyPrice = 0,
    double firstHourPrice = 0,
    double additionalHourPrice = 0,
    double weekendSurchargePercent = 20,
    double holidaySurchargePercent = 35,
    RoomRatePlan? ratePlan,
  }) {
    _validateTime(checkIn, checkOut);

    final firstPrice = firstHourPrice > 0
        ? firstHourPrice
        : baseHourlyPrice;

    final nextPrice = additionalHourPrice > 0
        ? additionalHourPrice
        : firstPrice;

    if (firstPrice <= 0 || nextPrice <= 0) {
      throw StateError(
        'Giá giờ đầu và giá từ giờ thứ hai phải lớn hơn 0.',
      );
    }

    final durationMinutes =
        checkOut.difference(checkIn).inMinutes;
    final durationHours = durationMinutes ~/ 60;

    if (ratePlan != null &&
        !ratePlan.isEligible(
          checkIn: checkIn,
          checkOut: checkOut,
        )) {
      throw StateError(
        'Khung giờ đã chọn không phù hợp với combo '
        '${ratePlan.name}.',
      );
    }

    final weekendPercent =
        weekendSurchargePercent.clamp(0, 100).toDouble();
    final holidayPercent =
        holidaySurchargePercent.clamp(0, 100).toDouble();

    final breakdown = <String, double>{};
    final appliedRules = <String>{};

    final baseAmount = ratePlan == null
        ? firstPrice + nextPrice * (durationHours - 1)
        : ratePlan.price;

    if (ratePlan == null) {
      breakdown['firstHour'] = firstPrice;

      if (durationHours > 1) {
        breakdown['additionalHours'] =
            nextPrice * (durationHours - 1);
      }

      appliedRules.add(
        'Giờ đầu tiên: ${_money(firstPrice)}',
      );

      if (durationHours > 1) {
        appliedRules.add(
          'Từ giờ thứ hai: ${_money(nextPrice)}/giờ',
        );
      }
    } else {
      breakdown['ratePlan'] = ratePlan.price;
      appliedRules.add(
        '${ratePlan.name}: ${_money(ratePlan.price)}',
      );
    }

    var weekendSurcharge = 0.0;
    var holidaySurcharge = 0.0;

    // Chia giá combo theo số giờ để phụ thu đúng khi combo
    // đi qua nhiều ngày khác nhau.
    final comboHourlyShare = ratePlan == null
        ? 0.0
        : ratePlan.price / durationHours;

    for (var index = 0; index < durationHours; index++) {
      final moment = checkIn.add(Duration(hours: index));

      final hourlyAmount = ratePlan == null
          ? index == 0
                ? firstPrice
                : nextPrice
          : comboHourlyShare;

      final holiday = _holidayAt(moment);

      if (holiday != null) {
        // Ngày lễ được ưu tiên và không cộng thêm cuối tuần.
        holidaySurcharge +=
            hourlyAmount * holidayPercent / 100;

        appliedRules.add(
          '${holiday.name}: phụ thu '
          '${_percentLabel(holidayPercent)}',
        );
      } else if (_isWeekend(moment)) {
        weekendSurcharge +=
            hourlyAmount * weekendPercent / 100;

        appliedRules.add(
          'Cuối tuần: phụ thu '
          '${_percentLabel(weekendPercent)}',
        );
      }
    }

    if (weekendSurcharge > 0) {
      breakdown['weekendSurcharge'] = weekendSurcharge;
    }

    if (holidaySurcharge > 0) {
      breakdown['holidaySurcharge'] = holidaySurcharge;
    }

    final calendarSurcharge =
        weekendSurcharge + holidaySurcharge;
    final subtotal = baseAmount + calendarSurcharge;
    final total = _roundToThousand(subtotal);

    appliedRules.add('Thời gian tính theo bước nguyên 1 giờ');
    appliedRules.add(
      'Ngày lễ không cộng dồn phụ thu cuối tuần',
    );

    return PricingQuote(
      checkIn: checkIn,
      checkOut: checkOut,
      baseHourlyPrice: firstPrice,
      firstHourPrice: firstPrice,
      additionalHourPrice: nextPrice,
      weekendSurchargePercent: weekendPercent,
      holidaySurchargePercent: holidayPercent,
      durationMinutes: durationMinutes,
      billedMinutes: durationMinutes,
      ratePlanId: ratePlan?.id ?? '',
      ratePlanName: ratePlan?.name ?? '',
      ratePlanType: ratePlan?.type ?? '',
      ratePlanPrice: ratePlan?.price ?? 0,
      overtimeAmount: 0,
      calendarSurchargeAmount:
          _roundCurrency(calendarSurcharge),
      subtotal: _roundCurrency(subtotal),
      totalAmount: total,
      breakdown: breakdown.map(
        (key, value) => MapEntry(
          key,
          _roundCurrency(value),
        ),
      ),
      appliedRules: appliedRules.toList(),
    );
  }

  List<PricingQuote> calculateAvailableQuotes({
    required DateTime checkIn,
    required DateTime checkOut,
    required double firstHourPrice,
    required double additionalHourPrice,
    required double weekendSurchargePercent,
    required double holidaySurchargePercent,
    List<RoomRatePlan> ratePlans = const [],
  }) {
    final quotes = <PricingQuote>[
      calculate(
        checkIn: checkIn,
        checkOut: checkOut,
        firstHourPrice: firstHourPrice,
        additionalHourPrice: additionalHourPrice,
        weekendSurchargePercent:
            weekendSurchargePercent,
        holidaySurchargePercent:
            holidaySurchargePercent,
      ),
    ];

    for (final plan in ratePlans) {
      if (!plan.isEligible(
        checkIn: checkIn,
        checkOut: checkOut,
      )) {
        continue;
      }

      quotes.add(
        calculate(
          checkIn: checkIn,
          checkOut: checkOut,
          firstHourPrice: firstHourPrice,
          additionalHourPrice: additionalHourPrice,
          weekendSurchargePercent:
              weekendSurchargePercent,
          holidaySurchargePercent:
              holidaySurchargePercent,
          ratePlan: plan,
        ),
      );
    }

    quotes.sort(
      (first, second) =>
          first.totalAmount.compareTo(second.totalAmount),
    );

    return quotes;
  }

  void _validateTime(
    DateTime checkIn,
    DateTime checkOut,
  ) {
    if (!_isWholeHour(checkIn) ||
        !_isWholeHour(checkOut)) {
      throw StateError(
        'Giờ nhận và trả phòng phải là giờ tròn.',
      );
    }

    if (!checkOut.isAfter(checkIn)) {
      throw StateError(
        'Giờ trả phòng phải sau giờ nhận phòng.',
      );
    }

    final durationMinutes =
        checkOut.difference(checkIn).inMinutes;

    if (durationMinutes % 60 != 0) {
      throw StateError(
        'Thời gian thuê phải tăng theo từng bước 1 giờ.',
      );
    }

    final hours = durationMinutes ~/ 60;

    if (hours < minimumHours) {
      throw StateError(
        'Thời gian thuê tối thiểu là 1 giờ.',
      );
    }

    if (hours > maximumHours) {
      throw StateError(
        'Thời gian thuê tối đa là 30 ngày.',
      );
    }
  }

  HolidayInfo? _holidayAt(DateTime date) {
    for (final holiday in holidays) {
      if (holiday.matches(date)) return holiday;
    }

    return null;
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;
  }

  bool _isWholeHour(DateTime value) {
    return value.minute == 0 &&
        value.second == 0 &&
        value.millisecond == 0 &&
        value.microsecond == 0;
  }

  String _percentLabel(double value) {
    final normalized = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);

    return '$normalized%';
  }

  String _money(double value) {
    return '${value.round()} đ';
  }

  double _roundCurrency(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  double _roundToThousand(double value) {
    return (value / 1000).round() * 1000;
  }
}