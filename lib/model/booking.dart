import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class BookingStatus {
  static const pending = 'pending';
  static const pendingProvider = 'pending_provider';
  static const awaitingPayment = 'awaiting_payment';
  static const paymentReview = 'payment_review';
  static const confirmed = 'confirmed';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const rejected = 'rejected';
  static const expired = 'expired';

  static const values = {
    pending,
    pendingProvider,
    awaitingPayment,
    paymentReview,
    confirmed,
    completed,
    cancelled,
    rejected,
    expired,
  };

  static String normalize(dynamic value) {
    final status = value?.toString().trim().toLowerCase();

    if (status != null && values.contains(status)) {
      return status;
    }

    return pendingProvider;
  }
}

abstract final class PaymentStatus {
  static const unpaid = 'unpaid';
  static const submitted = 'submitted';
  static const paid = 'paid';
  static const rejected = 'rejected';
  static const expired = 'expired';

  static const values = {
    unpaid,
    submitted,
    paid,
    rejected,
    expired,
  };

  static String normalize(dynamic value) {
    final status = value?.toString().trim().toLowerCase();

    if (status != null && values.contains(status)) {
      return status;
    }

    return unpaid;
  }
}

abstract final class PaymentMethod {
  static const vietQr = 'vietqr';
}

class BookingModel {
  const BookingModel({
    required this.id,
    required this.customerId,
    required this.providerId,
    required this.hotelId,
    required this.hotelName,
    required this.roomId,
    required this.roomNumber,
    required this.roomType,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.pricePerNight,
    required this.nights,
    required this.totalAmount,
    required this.status,
    this.customerName = '',
    this.customerEmail = '',
    this.customerPhone = '',
    this.specialRequests = '',
    this.baseHourlyPrice = 0,
    this.firstHourPrice = 0,
    this.additionalHourPrice = 0,
    this.durationMinutes = 0,
    this.pricingBreakdown = const {},
    this.ratePlanId = '',
    this.ratePlanName = '',
    this.ratePlanType = '',
    this.ratePlanPrice = 0,
    this.overtimeAmount = 0,
    this.weekendSurchargePercent = 0,
    this.holidaySurchargePercent = 0,
    this.calendarSurchargeAmount = 0,
    this.paymentMethod = PaymentMethod.vietQr,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentReference = '',
    this.paymentDeadline,
    this.paymentSubmittedAt,
    this.paymentConfirmedAt,
    this.receiverBankBin = '',
    this.receiverBankName = '',
    this.receiverAccountNumber = '',
    this.receiverAccountName = '',
    this.commissionRate = 0.10,
    this.commissionAmount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String specialRequests;
  final String providerId;
  final String hotelId;
  final String hotelName;
  final String roomId;
  final String roomNumber;
  final String roomType;

  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;

  final double pricePerNight;
  final int nights;
  final double baseHourlyPrice;
  final double firstHourPrice;
  final double additionalHourPrice;
  final int durationMinutes;

  final String ratePlanId;
  final String ratePlanName;
  final String ratePlanType;
  final double ratePlanPrice;
  final double overtimeAmount;

  final double weekendSurchargePercent;
  final double holidaySurchargePercent;
  final double calendarSurchargeAmount;

  final Map<String, double> pricingBreakdown;
  final double totalAmount;

  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String paymentReference;

  final DateTime? paymentDeadline;
  final DateTime? paymentSubmittedAt;
  final DateTime? paymentConfirmedAt;

  final String receiverBankBin;
  final String receiverBankName;
  final String receiverAccountNumber;
  final String receiverAccountName;

  final double commissionRate;
  final double commissionAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get usesCombo => ratePlanId.isNotEmpty;

  bool get canCustomerCancel {
    return status == BookingStatus.pending ||
        status == BookingStatus.pendingProvider ||
        status == BookingStatus.awaitingPayment;
  }

  bool get canCustomerPay {
    return status == BookingStatus.awaitingPayment &&
        (paymentStatus == PaymentStatus.unpaid ||
            paymentStatus == PaymentStatus.rejected) &&
        !isPaymentOverdue;
  }

  bool get isPaymentOverdue {
    return paymentDeadline != null &&
        DateTime.now().isAfter(paymentDeadline!) &&
        paymentStatus != PaymentStatus.paid;
  }

  bool get isFinished {
    return const {
      BookingStatus.completed,
      BookingStatus.cancelled,
      BookingStatus.rejected,
      BookingStatus.expired,
    }.contains(status);
  }

  bool get hasReceiverAccount {
    return receiverBankBin.isNotEmpty &&
        receiverAccountNumber.isNotEmpty &&
        receiverAccountName.isNotEmpty;
  }

  int get effectiveDurationMinutes {
    if (durationMinutes > 0) return durationMinutes;

    final result = checkOut.difference(checkIn).inMinutes;
    return result > 0 ? result : 0;
  }

  double get effectiveFirstHourPrice {
    if (firstHourPrice > 0) return firstHourPrice;
    if (baseHourlyPrice > 0) return baseHourlyPrice;
    return pricePerNight > 0 ? pricePerNight / 24 : 0;
  }

  double get effectiveAdditionalHourPrice {
    if (additionalHourPrice > 0) {
      return additionalHourPrice;
    }

    return effectiveFirstHourPrice;
  }

  double get effectiveCommissionAmount {
    if (commissionAmount > 0) return commissionAmount;
    return totalAmount * commissionRate;
  }

  String get durationLabel {
    final minutes = effectiveDurationMinutes;
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (hours == 0) return '$remaining phút';
    if (remaining == 0) return '$hours giờ';

    return '$hours giờ $remaining phút';
  }

  String get pricingLabel {
    if (usesCombo) return ratePlanName;
    return 'Tính giá theo giờ';
  }

  String get statusLabel {
    return switch (status) {
      BookingStatus.awaitingPayment => 'Chờ thanh toán',
      BookingStatus.paymentReview =>
        'Đang kiểm tra thanh toán',
      BookingStatus.confirmed => 'Đã xác nhận',
      BookingStatus.completed => 'Hoàn thành',
      BookingStatus.cancelled => 'Đã hủy',
      BookingStatus.rejected => 'Bị từ chối',
      BookingStatus.expired => 'Đã quá hạn',
      _ => 'Chờ nhà cung cấp xác nhận',
    };
  }

  factory BookingModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    final checkIn =
        _asDateTime(data['checkIn']) ?? DateTime.now();

    final checkOut =
        _asDateTime(data['checkOut']) ??
        checkIn.add(const Duration(hours: 1));

    final difference = checkOut.difference(checkIn);
    final pricePerNight = _asDouble(data['pricePerNight']);
    final baseHourlyPrice = _asDouble(
      data['baseHourlyPrice'],
      fallback:
          pricePerNight > 0 ? pricePerNight / 24 : 0,
    );

    final grossAmount = _asDouble(data['totalAmount']);
    final commissionRate = _asDouble(
      data['commissionRate'],
      fallback: 0.10,
    );

    return BookingModel(
      id: id,
      customerId: _asString(data['customerId']),
      customerName: _asString(data['customerName']),
      customerEmail: _asString(data['customerEmail']),
      customerPhone: _asString(
        data['customerPhone'] ?? data['phoneNumber'],
      ),
      specialRequests: _asString(
        data['specialRequests'],
      ),
      providerId: _asString(data['providerId']),
      hotelId: _asString(data['hotelId']),
      hotelName: _asString(
        data['hotelName'],
        fallback: 'Khách sạn',
      ),
      roomId: _asString(data['roomId']),
      roomNumber: _asString(data['roomNumber']),
      roomType: _asString(
        data['roomType'],
        fallback: 'Phòng',
      ),
      checkIn: checkIn,
      checkOut: checkOut,
      guests: _asInt(data['guests'], fallback: 1),
      pricePerNight: pricePerNight,
      nights: _asInt(data['nights'], fallback: 1),
      baseHourlyPrice: baseHourlyPrice,
      firstHourPrice: _asDouble(
        data['firstHourPrice'],
        fallback: baseHourlyPrice,
      ),
      additionalHourPrice: _asDouble(
        data['additionalHourPrice'],
        fallback: baseHourlyPrice,
      ),
      durationMinutes: _asInt(
        data['durationMinutes'],
        fallback: difference.inMinutes,
      ),
      ratePlanId: _asString(data['ratePlanId']),
      ratePlanName: _asString(data['ratePlanName']),
      ratePlanType: _asString(data['ratePlanType']),
      ratePlanPrice: _asDouble(data['ratePlanPrice']),
      overtimeAmount: _asDouble(
        data['overtimeAmount'],
      ),
      weekendSurchargePercent: _asDouble(
        data['weekendSurchargePercent'],
      ),
      holidaySurchargePercent: _asDouble(
        data['holidaySurchargePercent'],
      ),
      calendarSurchargeAmount: _asDouble(
        data['calendarSurchargeAmount'],
      ),
      pricingBreakdown: _readDoubleMap(
        data['pricingBreakdown'],
      ),
      totalAmount: grossAmount,
      status: BookingStatus.normalize(data['status']),
      paymentMethod: _asString(
        data['paymentMethod'],
        fallback: PaymentMethod.vietQr,
      ),
      paymentStatus: PaymentStatus.normalize(
        data['paymentStatus'],
      ),
      paymentReference: _asString(
        data['paymentReference'],
      ),
      paymentDeadline: _asDateTime(
        data['paymentDeadline'],
      ),
      paymentSubmittedAt: _asDateTime(
        data['paymentSubmittedAt'],
      ),
      paymentConfirmedAt: _asDateTime(
        data['paymentConfirmedAt'],
      ),
      receiverBankBin: _asString(
        data['receiverBankBin'],
      ),
      receiverBankName: _asString(
        data['receiverBankName'],
      ),
      receiverAccountNumber: _asString(
        data['receiverAccountNumber'],
      ),
      receiverAccountName: _asString(
        data['receiverAccountName'],
      ),
      commissionRate: commissionRate,
      commissionAmount: _asDouble(
        data['commissionAmount'],
        fallback: grossAmount * commissionRate,
      ),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId.trim(),
      'customerName': customerName.trim(),
      'customerEmail': customerEmail.trim(),
      'customerPhone': customerPhone.trim(),
      'specialRequests': specialRequests.trim(),
      'providerId': providerId.trim(),
      'hotelId': hotelId.trim(),
      'hotelName': hotelName.trim(),
      'roomId': roomId.trim(),
      'roomNumber': roomNumber.trim(),
      'roomType': roomType.trim(),
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': Timestamp.fromDate(checkOut),
      'guests': guests,
      'pricePerNight': pricePerNight,
      'nights': nights,
      'baseHourlyPrice': effectiveFirstHourPrice,
      'firstHourPrice': effectiveFirstHourPrice,
      'additionalHourPrice':
          effectiveAdditionalHourPrice,
      'durationMinutes': effectiveDurationMinutes,
      'ratePlanId': ratePlanId.trim(),
      'ratePlanName': ratePlanName.trim(),
      'ratePlanType': ratePlanType.trim(),
      'ratePlanPrice': ratePlanPrice,
      'overtimeAmount': overtimeAmount,
      'weekendSurchargePercent':
          weekendSurchargePercent,
      'holidaySurchargePercent':
          holidaySurchargePercent,
      'calendarSurchargeAmount':
          calendarSurchargeAmount,
      'pricingBreakdown': pricingBreakdown,
      'totalAmount': totalAmount,
      'status': BookingStatus.normalize(status),
      'paymentMethod': paymentMethod.trim(),
      'paymentStatus':
          PaymentStatus.normalize(paymentStatus),
      'paymentReference': paymentReference.trim(),
      'paymentDeadline': paymentDeadline == null
          ? null
          : Timestamp.fromDate(paymentDeadline!),
      'paymentSubmittedAt':
          paymentSubmittedAt == null
          ? null
          : Timestamp.fromDate(paymentSubmittedAt!),
      'paymentConfirmedAt':
          paymentConfirmedAt == null
          ? null
          : Timestamp.fromDate(paymentConfirmedAt!),
      'receiverBankBin': receiverBankBin.trim(),
      'receiverBankName': receiverBankName.trim(),
      'receiverAccountNumber':
          receiverAccountNumber.trim(),
      'receiverAccountName':
          receiverAccountName.trim(),
      'commissionRate': commissionRate,
      'commissionAmount': effectiveCommissionAmount,
    };
  }
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