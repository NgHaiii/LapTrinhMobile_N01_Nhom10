import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class CommissionStatus {
  static const unpaid = 'unpaid';
  static const paymentReview = 'payment_review';
  static const paid = 'paid';
  static const overdue = 'overdue';
  static const rejected = 'rejected';

  static const values = {
    unpaid,
    paymentReview,
    paid,
    overdue,
    rejected,
  };

  static String normalize(dynamic value) {
    final status = value?.toString().trim().toLowerCase();

    if (status != null && values.contains(status)) {
      return status;
    }

    return unpaid;
  }

  static String label(String value) {
    return switch (normalize(value)) {
      paymentReview => 'Đang kiểm tra thanh toán',
      paid => 'Đã thanh toán',
      overdue => 'Quá hạn',
      rejected => 'Thanh toán bị từ chối',
      _ => 'Chưa thanh toán',
    };
  }
}

class CommissionInvoice {
  const CommissionInvoice({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.month,
    required this.year,
    required this.grossRevenue,
    required this.commissionRate,
    required this.commissionAmount,
    required this.bookingIds,
    required this.status,
    required this.paymentReference,
    this.sequenceNumber = 1,
    this.periodStart,
    this.periodEnd,
    this.penaltyAmount = 0,
    this.violationRecordIds = const [],
    this.rejectionReason = '',
    this.dueDate,
    this.paymentSubmittedAt,
    this.confirmedAt,
    this.confirmedBy = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String providerId;
  final String providerName;

  final int month;
  final int year;

  /// Đợt lập hóa đơn trong cùng tháng.
  /// Ví dụ tháng 7 có thể có đợt 1, đợt 2, đợt 3.
  final int sequenceNumber;

  /// Khoảng dữ liệu thực tế được tính trong hóa đơn này.
  /// Có thể nhỏ hơn cả tháng nếu tháng đó đã lập hóa đơn trước đó.
  final DateTime? periodStart;
  final DateTime? periodEnd;

  final double grossRevenue;
  final double commissionRate;

  /// Hoa hồng cơ bản, chưa bao gồm phụ thu vi phạm.
  final double commissionAmount;

  /// Tổng khoản phụ thu từ các biên bản vi phạm.
  final double penaltyAmount;

  /// Danh sách booking đã được tính trong hóa đơn này.
  /// Service sẽ dùng danh sách này để tránh tính trùng ở lần lập sau.
  final List<String> bookingIds;

  /// Danh sách biên bản vi phạm đã được tính phạt trong hóa đơn này.
  final List<String> violationRecordIds;

  final String status;
  final String paymentReference;
  final String rejectionReason;

  final DateTime? dueDate;
  final DateTime? paymentSubmittedAt;
  final DateTime? confirmedAt;
  final String confirmedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get periodLabel {
    return 'Tháng ${month.toString().padLeft(2, '0')}/$year';
  }

  String get sequenceLabel {
    return 'Đợt $sequenceNumber';
  }

  String get fullPeriodLabel {
    return '$periodLabel - $sequenceLabel';
  }

  String get statusLabel {
    return CommissionStatus.label(status);
  }

  bool get isPaid {
    return status == CommissionStatus.paid;
  }

  bool get hasRevenue {
    return grossRevenue > 0 && bookingIds.isNotEmpty;
  }

  bool get hasPenalty {
    return effectivePenaltyAmount > 0 && violationRecordIds.isNotEmpty;
  }

  bool get canSubmitPayment {
    return status == CommissionStatus.unpaid ||
        status == CommissionStatus.overdue ||
        status == CommissionStatus.rejected;
  }

  bool get isPastDue {
    return !isPaid && dueDate != null && DateTime.now().isAfter(dueDate!);
  }

  double get effectiveBaseCommissionAmount {
    if (commissionAmount > 0) return commissionAmount;
    return grossRevenue * commissionRate;
  }

  double get effectivePenaltyAmount {
    return penaltyAmount < 0 ? 0 : penaltyAmount;
  }

  /// Giữ getter cũ để các màn hình hiện tại vẫn hoạt động.
  /// Giá trị trả về đã bao gồm phụ thu vi phạm.
  double get effectiveCommissionAmount {
    return effectiveBaseCommissionAmount + effectivePenaltyAmount;
  }

  double get totalPayableAmount {
    return effectiveCommissionAmount;
  }

  factory CommissionInvoice.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    final grossRevenue = _asDouble(data['grossRevenue']);

    final commissionRate = _normalizeRate(
      _asDouble(
        data['commissionRate'],
        fallback: 0.10,
      ),
    );

    final sequenceNumber = _safeSequenceNumber(data['sequenceNumber']);

    return CommissionInvoice(
      id: id,
      providerId: _asString(data['providerId']),
      providerName: _asString(
        data['providerName'],
        fallback: 'Nhà cung cấp',
      ),
      month: _asInt(
        data['month'],
        fallback: DateTime.now().month,
      ),
      year: _asInt(
        data['year'],
        fallback: DateTime.now().year,
      ),
      sequenceNumber: sequenceNumber,
      periodStart: _asDateTime(data['periodStart']),
      periodEnd: _asDateTime(data['periodEnd']),
      grossRevenue: grossRevenue,
      commissionRate: commissionRate,
      commissionAmount: _asDouble(
        data['commissionAmount'],
        fallback: grossRevenue * commissionRate,
      ),
      penaltyAmount: _asDouble(data['penaltyAmount']),
      bookingIds: _readStringList(data['bookingIds']),
      violationRecordIds: _readStringList(data['violationRecordIds']),
      status: CommissionStatus.normalize(data['status']),
      paymentReference: _asString(data['paymentReference']),
      rejectionReason: _asString(data['rejectionReason']),
      dueDate: _asDateTime(data['dueDate']),
      paymentSubmittedAt: _asDateTime(data['paymentSubmittedAt']),
      confirmedAt: _asDateTime(data['confirmedAt']),
      confirmedBy: _asString(data['confirmedBy']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId.trim(),
      'providerName': providerName.trim(),
      'month': month,
      'year': year,
      'sequenceNumber': sequenceNumber < 1 ? 1 : sequenceNumber,
      'periodStart': _timestamp(periodStart),
      'periodEnd': _timestamp(periodEnd),
      'grossRevenue': grossRevenue,
      'commissionRate': commissionRate,
      'commissionAmount': effectiveBaseCommissionAmount,
      'penaltyAmount': effectivePenaltyAmount,
      'totalPayableAmount': totalPayableAmount,
      'bookingIds': _uniqueStringList(bookingIds),
      'violationRecordIds': _uniqueStringList(violationRecordIds),
      'status': CommissionStatus.normalize(status),
      'paymentReference': paymentReference.trim(),
      'rejectionReason': rejectionReason.trim(),
      'dueDate': _timestamp(dueDate),
      'paymentSubmittedAt': _timestamp(paymentSubmittedAt),
      'confirmedAt': _timestamp(confirmedAt),
      'confirmedBy': confirmedBy.trim(),
      'createdAt': _timestamp(createdAt),
      'updatedAt': _timestamp(updatedAt),
    };
  }

  CommissionInvoice copyWith({
    String? id,
    String? providerId,
    String? providerName,
    int? month,
    int? year,
    int? sequenceNumber,
    DateTime? periodStart,
    DateTime? periodEnd,
    double? grossRevenue,
    double? commissionRate,
    double? commissionAmount,
    double? penaltyAmount,
    List<String>? bookingIds,
    List<String>? violationRecordIds,
    String? status,
    String? paymentReference,
    String? rejectionReason,
    DateTime? dueDate,
    DateTime? paymentSubmittedAt,
    DateTime? confirmedAt,
    String? confirmedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommissionInvoice(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      month: month ?? this.month,
      year: year ?? this.year,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      grossRevenue: grossRevenue ?? this.grossRevenue,
      commissionRate: commissionRate ?? this.commissionRate,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      penaltyAmount: penaltyAmount ?? this.penaltyAmount,
      bookingIds: bookingIds ?? this.bookingIds,
      violationRecordIds: violationRecordIds ?? this.violationRecordIds,
      status: status ?? this.status,
      paymentReference: paymentReference ?? this.paymentReference,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      dueDate: dueDate ?? this.dueDate,
      paymentSubmittedAt: paymentSubmittedAt ?? this.paymentSubmittedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

List<String> _readStringList(dynamic value) {
  if (value is! Iterable) return const [];

  return _uniqueStringList(
    value.map((item) => item.toString()).toList(),
  );
}

List<String> _uniqueStringList(Iterable<String> value) {
  final result = <String>[];
  final seen = <String>{};

  for (final item in value) {
    final normalized = item.trim();

    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }

    seen.add(normalized);
    result.add(normalized);
  }

  return List.unmodifiable(result);
}

String _asString(
  dynamic value, {
  String fallback = '',
}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

double _asDouble(
  dynamic value, {
  double fallback = 0,
}) {
  if (value is num) return value.toDouble();

  return double.tryParse(value?.toString().trim() ?? '') ?? fallback;
}

int _asInt(
  dynamic value, {
  int fallback = 0,
}) {
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
}

int _safeSequenceNumber(dynamic value) {
  final result = _asInt(value, fallback: 1);
  return result < 1 ? 1 : result;
}

double _normalizeRate(double value) {
  if (value > 1) return value / 100;
  if (value < 0) return 0;
  return value;
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}

Timestamp? _timestamp(DateTime? value) {
  if (value == null) return null;
  return Timestamp.fromDate(value);
}