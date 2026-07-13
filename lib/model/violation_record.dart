import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class ViolationStatus {
  static const String draft = 'draft';
  static const String waitingProvider = 'waitingProvider';
  static const String investigating = 'investigating';
  static const String confirmed = 'confirmed';
  static const String noPenalty = 'noPenalty';
  static const String appealed = 'appealed';
  static const String cancelled = 'cancelled';
  static const String paid = 'paid';

  static const List<String> values = [
    draft,
    waitingProvider,
    investigating,
    confirmed,
    noPenalty,
    appealed,
    cancelled,
    paid,
  ];

  static String normalize(dynamic value) {
    final status = value?.toString().trim() ?? '';

    if (values.contains(status)) {
      return status;
    }

    return draft;
  }

  static String label(String value) {
    return switch (normalize(value)) {
      draft => 'Bản nháp',
      waitingProvider => 'Chờ nhà cung cấp giải trình',
      investigating => 'Chờ quản trị viên quyết định',
      confirmed => 'Quyết định phạt 5%',
      noPenalty => 'Không áp dụng phạt',
      appealed => 'Nhà cung cấp khiếu nại',
      cancelled => 'Đã hủy',
      paid => 'Đã thanh toán',
      _ => 'Không xác định',
    };
  }
}

abstract final class ViolationType {
  static const String serviceQuality = 'serviceQuality';
  static const String incorrectInformation = 'incorrectInformation';
  static const String hygiene = 'hygiene';
  static const String customerSafety = 'customerSafety';
  static const String paymentDispute = 'paymentDispute';
  static const String providerBehavior = 'providerBehavior';
  static const String bookingViolation = 'bookingViolation';
  static const String other = 'other';

  static const List<String> values = [
    serviceQuality,
    incorrectInformation,
    hygiene,
    customerSafety,
    paymentDispute,
    providerBehavior,
    bookingViolation,
    other,
  ];

  static String normalize(dynamic value) {
    final type = value?.toString().trim() ?? '';

    if (values.contains(type)) {
      return type;
    }

    return other;
  }

  static String label(String value) {
    return switch (normalize(value)) {
      serviceQuality => 'Chất lượng dịch vụ',
      incorrectInformation => 'Thông tin không chính xác',
      hygiene => 'Vệ sinh phòng',
      customerSafety => 'An toàn khách hàng',
      paymentDispute => 'Tranh chấp thanh toán',
      providerBehavior => 'Thái độ nhà cung cấp',
      bookingViolation => 'Vi phạm đặt phòng',
      other => 'Vi phạm khác',
      _ => 'Không xác định',
    };
  }
}

class ViolationRecord {
  const ViolationRecord({
    required this.id,
    required this.reviewId,
    required this.bookingId,
    required this.hotelId,
    required this.roomId,
    required this.providerId,
    required this.customerId,
    required this.hotelName,
    required this.roomNumber,
    required this.customerName,
    required this.severity,
    required this.violationType,
    required this.title,
    required this.description,
    required this.evidenceUrls,
    required this.bookingAmount,
    required this.baseCommissionRate,
    required this.penaltyRate,
    required this.penaltyAmount,
    required this.status,
    required this.providerExplanation,
    required this.appealNote,
    required this.adminNote,
    required this.createdBy,
    required this.commissionApplied,
    this.commissionInvoiceId,
    this.createdAt,
    this.updatedAt,
    this.issuedAt,
    this.confirmedAt,
    this.resolvedAt,
  });

  final String id;
  final String reviewId;
  final String bookingId;
  final String hotelId;
  final String roomId;
  final String providerId;
  final String customerId;

  final String hotelName;
  final String roomNumber;
  final String customerName;

  final String severity;
  final String violationType;
  final String title;
  final String description;
  final List<String> evidenceUrls;

  final double bookingAmount;
  final double baseCommissionRate;
  final double penaltyRate;
  final double penaltyAmount;

  final String status;
  final String providerExplanation;
  final String appealNote;
  final String adminNote;
  final String createdBy;

  final bool commissionApplied;
  final String? commissionInvoiceId;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? issuedAt;
  final DateTime? confirmedAt;
  final DateTime? resolvedAt;

  bool get isDraft => status == ViolationStatus.draft;

  bool get hasProviderExplanation {
    return providerExplanation.trim().isNotEmpty;
  }

  bool get hasAppeal {
    return appealNote.trim().isNotEmpty;
  }

  bool get isConfirmed {
    return status == ViolationStatus.confirmed;
  }

  bool get isPaid {
    return status == ViolationStatus.paid;
  }

  bool get isNoPenalty {
    return status == ViolationStatus.noPenalty;
  }

  bool get hasPenalty {
    return status == ViolationStatus.confirmed ||
        status == ViolationStatus.paid;
  }

  bool get canBeIncludedInCommissionInvoice {
    return status == ViolationStatus.confirmed &&
        !commissionApplied &&
        (commissionInvoiceId == null ||
            commissionInvoiceId!.trim().isEmpty) &&
        confirmedAt != null;
  }

  double get effectivePenaltyAmount {
    return hasPenalty ? penaltyAmount : 0;
  }

  bool get isClosed {
    return status == ViolationStatus.noPenalty ||
        status == ViolationStatus.cancelled ||
        status == ViolationStatus.paid;
  }

  bool get canProviderExplain {
    return status == ViolationStatus.waitingProvider ||
        status == ViolationStatus.investigating;
  }

  bool get canProviderAppeal {
    return status == ViolationStatus.confirmed &&
        !commissionApplied;
  }

  bool get canProviderRespond {
    return canProviderExplain || canProviderAppeal;
  }

  factory ViolationRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ViolationRecord.fromMap(
      snapshot.id,
      snapshot.data() ?? const <String, dynamic>{},
    );
  }

  factory ViolationRecord.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return ViolationRecord(
      id: id,
      reviewId: _string(map['reviewId']),
      bookingId: _string(map['bookingId']),
      hotelId: _string(map['hotelId']),
      roomId: _string(map['roomId']),
      providerId: _string(map['providerId']),
      customerId: _string(map['customerId']),
      hotelName: _string(map['hotelName']),
      roomNumber: _string(map['roomNumber']),
      customerName: _string(map['customerName']),
      severity: _string(
        map['severity'],
        fallback: 'critical',
      ),
      violationType: ViolationType.normalize(
        map['violationType'],
      ),
      title: _string(map['title']),
      description: _string(map['description']),
      evidenceUrls: _stringList(map['evidenceUrls']),
      bookingAmount: _double(map['bookingAmount']),
      baseCommissionRate: _normalizeRate(
        _double(
          map['baseCommissionRate'],
          fallback: 0.10,
        ),
      ),
      penaltyRate: _normalizeRate(
        _double(
          map['penaltyRate'],
          fallback: 0.05,
        ),
      ),
      penaltyAmount: _double(map['penaltyAmount']),
      status: ViolationStatus.normalize(map['status']),
      providerExplanation: _string(
        map['providerExplanation'],
      ),
      appealNote: _string(map['appealNote']),
      adminNote: _string(map['adminNote']),
      createdBy: _string(map['createdBy']),
      commissionApplied: map['commissionApplied'] == true,
      commissionInvoiceId: _nullableString(
        map['commissionInvoiceId'],
      ),
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      issuedAt: _date(map['issuedAt']),
      confirmedAt: _date(map['confirmedAt']),
      resolvedAt: _date(map['resolvedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewId': reviewId.trim(),
      'bookingId': bookingId.trim(),
      'hotelId': hotelId.trim(),
      'roomId': roomId.trim(),
      'providerId': providerId.trim(),
      'customerId': customerId.trim(),
      'hotelName': hotelName.trim(),
      'roomNumber': roomNumber.trim(),
      'customerName': customerName.trim(),
      'severity': severity.trim(),
      'violationType': ViolationType.normalize(violationType),
      'title': title.trim(),
      'description': description.trim(),
      'evidenceUrls': _uniqueStringList(evidenceUrls),
      'bookingAmount': bookingAmount,
      'baseCommissionRate': baseCommissionRate,
      'penaltyRate': penaltyRate,
      'penaltyAmount': penaltyAmount,
      'status': ViolationStatus.normalize(status),
      'providerExplanation': providerExplanation.trim(),
      'appealNote': appealNote.trim(),
      'adminNote': adminNote.trim(),
      'createdBy': createdBy.trim(),
      'commissionApplied': commissionApplied,
      'commissionInvoiceId': commissionInvoiceId,
      'createdAt': _timestamp(createdAt),
      'updatedAt': _timestamp(updatedAt),
      'issuedAt': _timestamp(issuedAt),
      'confirmedAt': _timestamp(confirmedAt),
      'resolvedAt': _timestamp(resolvedAt),
    };
  }

  ViolationRecord copyWith({
    String? id,
    String? reviewId,
    String? bookingId,
    String? hotelId,
    String? roomId,
    String? providerId,
    String? customerId,
    String? hotelName,
    String? roomNumber,
    String? customerName,
    String? severity,
    String? violationType,
    String? title,
    String? description,
    List<String>? evidenceUrls,
    double? bookingAmount,
    double? baseCommissionRate,
    double? penaltyRate,
    double? penaltyAmount,
    String? status,
    String? providerExplanation,
    String? appealNote,
    String? adminNote,
    String? createdBy,
    bool? commissionApplied,
    String? commissionInvoiceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? issuedAt,
    DateTime? confirmedAt,
    DateTime? resolvedAt,
  }) {
    return ViolationRecord(
      id: id ?? this.id,
      reviewId: reviewId ?? this.reviewId,
      bookingId: bookingId ?? this.bookingId,
      hotelId: hotelId ?? this.hotelId,
      roomId: roomId ?? this.roomId,
      providerId: providerId ?? this.providerId,
      customerId: customerId ?? this.customerId,
      hotelName: hotelName ?? this.hotelName,
      roomNumber: roomNumber ?? this.roomNumber,
      customerName: customerName ?? this.customerName,
      severity: severity ?? this.severity,
      violationType: violationType ?? this.violationType,
      title: title ?? this.title,
      description: description ?? this.description,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      bookingAmount: bookingAmount ?? this.bookingAmount,
      baseCommissionRate:
          baseCommissionRate ?? this.baseCommissionRate,
      penaltyRate: penaltyRate ?? this.penaltyRate,
      penaltyAmount: penaltyAmount ?? this.penaltyAmount,
      status: status ?? this.status,
      providerExplanation:
          providerExplanation ?? this.providerExplanation,
      appealNote: appealNote ?? this.appealNote,
      adminNote: adminNote ?? this.adminNote,
      createdBy: createdBy ?? this.createdBy,
      commissionApplied:
          commissionApplied ?? this.commissionApplied,
      commissionInvoiceId:
          commissionInvoiceId ?? this.commissionInvoiceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      issuedAt: issuedAt ?? this.issuedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

String _string(
  Object? value, {
  String fallback = '',
}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double _double(
  Object? value, {
  double fallback = 0,
}) {
  if (value is num) return value.toDouble();

  return double.tryParse(value?.toString() ?? '') ??
      fallback;
}

double _normalizeRate(double value) {
  if (value > 1) return value / 100;
  if (value < 0) return 0;
  return value;
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) return const [];

  return _uniqueStringList(
    value.map((item) => item.toString()),
  );
}

List<String> _uniqueStringList(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};

  for (final value in values) {
    final normalized = value.trim();

    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }

    seen.add(normalized);
    result.add(normalized);
  }

  return List.unmodifiable(result);
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) return DateTime.tryParse(value);

  return null;
}

Timestamp? _timestamp(DateTime? value) {
  return value == null ? null : Timestamp.fromDate(value);
}