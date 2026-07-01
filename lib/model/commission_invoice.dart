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

    if (status != null && values.contains(status)) return status;
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

  /// Tổng doanh thu booking đã được thanh toán.
  final double grossRevenue;

  /// Tỷ lệ hoa hồng, ví dụ 0.10 tương ứng 10%.
  final double commissionRate;

  final double commissionAmount;
  final List<String> bookingIds;

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

  String get statusLabel => CommissionStatus.label(status);

  bool get isPaid => status == CommissionStatus.paid;

  bool get canSubmitPayment {
    return status == CommissionStatus.unpaid ||
        status == CommissionStatus.overdue ||
        status == CommissionStatus.rejected;
  }

  bool get isPastDue {
    return !isPaid &&
        dueDate != null &&
        DateTime.now().isAfter(dueDate!);
  }

  double get effectiveCommissionAmount {
    if (commissionAmount > 0) return commissionAmount;
    return grossRevenue * commissionRate;
  }

  factory CommissionInvoice.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    final grossRevenue = _asDouble(data['grossRevenue']);
    final commissionRate = _asDouble(
      data['commissionRate'],
      fallback: 0.10,
    );

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
      grossRevenue: grossRevenue,
      commissionRate: commissionRate,
      commissionAmount: _asDouble(
        data['commissionAmount'],
        fallback: grossRevenue * commissionRate,
      ),
      bookingIds: _readStringList(data['bookingIds']),
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
      'grossRevenue': grossRevenue,
      'commissionRate': commissionRate,
      'commissionAmount': effectiveCommissionAmount,
      'bookingIds': bookingIds.toSet().toList(),
      'status': CommissionStatus.normalize(status),
      'paymentReference': paymentReference.trim(),
      'rejectionReason': rejectionReason.trim(),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'paymentSubmittedAt': paymentSubmittedAt == null
          ? null
          : Timestamp.fromDate(paymentSubmittedAt!),
      'confirmedAt': confirmedAt == null
          ? null
          : Timestamp.fromDate(confirmedAt!),
      'confirmedBy': confirmedBy.trim(),
    };
  }

  CommissionInvoice copyWith({
    String? id,
    String? providerId,
    String? providerName,
    int? month,
    int? year,
    double? grossRevenue,
    double? commissionRate,
    double? commissionAmount,
    List<String>? bookingIds,
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
      grossRevenue: grossRevenue ?? this.grossRevenue,
      commissionRate: commissionRate ?? this.commissionRate,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      bookingIds: bookingIds ?? this.bookingIds,
      status: status ?? this.status,
      paymentReference: paymentReference ?? this.paymentReference,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      dueDate: dueDate ?? this.dueDate,
      paymentSubmittedAt:
          paymentSubmittedAt ?? this.paymentSubmittedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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