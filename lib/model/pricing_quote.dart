import 'package:cloud_firestore/cloud_firestore.dart';

class PricingQuote {
  const PricingQuote({
    required this.checkIn,
    required this.checkOut,
    required this.baseHourlyPrice,
    required this.durationMinutes,
    required this.billedMinutes,
    required this.subtotal,
    required this.totalAmount,
    this.firstHourPrice = 0,
    this.additionalHourPrice = 0,
    this.weekendSurchargePercent = 0,
    this.holidaySurchargePercent = 0,
    this.ratePlanId = '',
    this.ratePlanName = '',
    this.ratePlanType = '',
    this.ratePlanPrice = 0,
    this.overtimeAmount = 0,
    this.calendarSurchargeAmount = 0,
    this.breakdown = const {},
    this.appliedRules = const [],
  });

  final DateTime checkIn;
  final DateTime checkOut;

  /// Giữ tương thích code cũ.
  final double baseHourlyPrice;

  final double firstHourPrice;
  final double additionalHourPrice;

  final double weekendSurchargePercent;
  final double holidaySurchargePercent;

  final int durationMinutes;
  final int billedMinutes;

  final String ratePlanId;
  final String ratePlanName;
  final String ratePlanType;
  final double ratePlanPrice;

  final double overtimeAmount;
  final double calendarSurchargeAmount;
  final double subtotal;
  final double totalAmount;

  final Map<String, double> breakdown;
  final List<String> appliedRules;

  bool get usesCombo => ratePlanId.trim().isNotEmpty;

  double get effectiveFirstHourPrice {
    if (firstHourPrice > 0) return firstHourPrice;
    return baseHourlyPrice;
  }

  double get effectiveAdditionalHourPrice {
    if (additionalHourPrice > 0) {
      return additionalHourPrice;
    }

    return baseHourlyPrice;
  }

  double get billedHours => billedMinutes / 60;

  String get durationLabel {
    return _durationLabel(durationMinutes);
  }

  String get billedDurationLabel {
    return _durationLabel(billedMinutes);
  }

  bool get isValid {
    return checkOut.isAfter(checkIn) &&
        effectiveFirstHourPrice > 0 &&
        effectiveAdditionalHourPrice > 0 &&
        durationMinutes > 0 &&
        totalAmount > 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': Timestamp.fromDate(checkOut),
      'baseHourlyPrice': baseHourlyPrice,
      'firstHourPrice': effectiveFirstHourPrice,
      'additionalHourPrice':
          effectiveAdditionalHourPrice,
      'weekendSurchargePercent':
          weekendSurchargePercent,
      'holidaySurchargePercent':
          holidaySurchargePercent,
      'durationMinutes': durationMinutes,
      'billedMinutes': billedMinutes,
      'ratePlanId': ratePlanId.trim(),
      'ratePlanName': ratePlanName.trim(),
      'ratePlanType': ratePlanType.trim(),
      'ratePlanPrice': ratePlanPrice,
      'overtimeAmount': overtimeAmount,
      'calendarSurchargeAmount':
          calendarSurchargeAmount,
      'subtotal': subtotal,
      'totalAmount': totalAmount,
      'breakdown': breakdown,
      'appliedRules': appliedRules,
    };
  }

  factory PricingQuote.fromMap(
    Map<String, dynamic> data,
  ) {
    final checkIn =
        _asDateTime(data['checkIn']) ?? DateTime.now();

    final checkOut =
        _asDateTime(data['checkOut']) ??
        checkIn.add(const Duration(hours: 1));

    final duration = _asInt(
      data['durationMinutes'],
      fallback: checkOut.difference(checkIn).inMinutes,
    );

    final legacyHourly = _asDouble(
      data['baseHourlyPrice'],
    );

    return PricingQuote(
      checkIn: checkIn,
      checkOut: checkOut,
      baseHourlyPrice: legacyHourly,
      firstHourPrice: _asDouble(
        data['firstHourPrice'],
        fallback: legacyHourly,
      ),
      additionalHourPrice: _asDouble(
        data['additionalHourPrice'],
        fallback: legacyHourly,
      ),
      weekendSurchargePercent: _asDouble(
        data['weekendSurchargePercent'],
      ),
      holidaySurchargePercent: _asDouble(
        data['holidaySurchargePercent'],
      ),
      durationMinutes: duration,
      billedMinutes: _asInt(
        data['billedMinutes'],
        fallback: duration,
      ),
      ratePlanId: _asString(data['ratePlanId']),
      ratePlanName: _asString(data['ratePlanName']),
      ratePlanType: _asString(data['ratePlanType']),
      ratePlanPrice: _asDouble(data['ratePlanPrice']),
      overtimeAmount: _asDouble(
        data['overtimeAmount'],
      ),
      calendarSurchargeAmount: _asDouble(
        data['calendarSurchargeAmount'],
      ),
      subtotal: _asDouble(data['subtotal']),
      totalAmount: _asDouble(data['totalAmount']),
      breakdown: _readDoubleMap(data['breakdown']),
      appliedRules: _readStringList(
        data['appliedRules'],
      ),
    );
  }

  PricingQuote copyWith({
    DateTime? checkIn,
    DateTime? checkOut,
    double? baseHourlyPrice,
    double? firstHourPrice,
    double? additionalHourPrice,
    double? weekendSurchargePercent,
    double? holidaySurchargePercent,
    int? durationMinutes,
    int? billedMinutes,
    String? ratePlanId,
    String? ratePlanName,
    String? ratePlanType,
    double? ratePlanPrice,
    double? overtimeAmount,
    double? calendarSurchargeAmount,
    double? subtotal,
    double? totalAmount,
    Map<String, double>? breakdown,
    List<String>? appliedRules,
  }) {
    return PricingQuote(
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      baseHourlyPrice:
          baseHourlyPrice ?? this.baseHourlyPrice,
      firstHourPrice:
          firstHourPrice ?? this.firstHourPrice,
      additionalHourPrice:
          additionalHourPrice ??
          this.additionalHourPrice,
      weekendSurchargePercent:
          weekendSurchargePercent ??
          this.weekendSurchargePercent,
      holidaySurchargePercent:
          holidaySurchargePercent ??
          this.holidaySurchargePercent,
      durationMinutes:
          durationMinutes ?? this.durationMinutes,
      billedMinutes: billedMinutes ?? this.billedMinutes,
      ratePlanId: ratePlanId ?? this.ratePlanId,
      ratePlanName: ratePlanName ?? this.ratePlanName,
      ratePlanType: ratePlanType ?? this.ratePlanType,
      ratePlanPrice: ratePlanPrice ?? this.ratePlanPrice,
      overtimeAmount:
          overtimeAmount ?? this.overtimeAmount,
      calendarSurchargeAmount:
          calendarSurchargeAmount ??
          this.calendarSurchargeAmount,
      subtotal: subtotal ?? this.subtotal,
      totalAmount: totalAmount ?? this.totalAmount,
      breakdown: breakdown ?? this.breakdown,
      appliedRules: appliedRules ?? this.appliedRules,
    );
  }
}

String _durationLabel(int totalMinutes) {
  if (totalMinutes <= 0) return '0 phút';

  final days = totalMinutes ~/ 1440;
  final hours = (totalMinutes % 1440) ~/ 60;
  final minutes = totalMinutes % 60;

  final parts = <String>[];

  if (days > 0) parts.add('$days ngày');
  if (hours > 0) parts.add('$hours giờ');
  if (minutes > 0) parts.add('$minutes phút');

  return parts.join(' ');
}

Map<String, double> _readDoubleMap(dynamic value) {
  if (value is! Map) return {};

  final result = <String, double>{};

  value.forEach((key, item) {
    if (key is String && item is num) {
      result[key] = item.toDouble();
    }
  });

  return result;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) return [];

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;

  final result = value.toString().trim();
  return result.isEmpty ? fallback : result;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();

  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }

  return fallback;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();

  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }

  return fallback;
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) return DateTime.tryParse(value);

  return null;
}