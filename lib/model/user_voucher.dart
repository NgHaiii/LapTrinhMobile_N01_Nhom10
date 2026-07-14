import 'package:cloud_firestore/cloud_firestore.dart';

enum UserVoucherStatus {
  available,
  used,
  expired;

  static UserVoucherStatus fromValue(String? value) {
    return UserVoucherStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => UserVoucherStatus.available,
    );
  }

  String get label {
    return switch (this) {
      UserVoucherStatus.available => 'Khả dụng',
      UserVoucherStatus.used => 'Đã dùng',
      UserVoucherStatus.expired => 'Hết hạn',
    };
  }
}

class UserVoucherModel {
  const UserVoucherModel({
    required this.id,
    required this.userId,
    required this.voucherId,
    required this.code,
    required this.title,
    this.status = UserVoucherStatus.available,
    this.redeemedByPoints = false,
    this.pointsSpent = 0,
    this.bookingId = '',
    this.usedAt,
    this.expiredAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String voucherId;
  final String code;
  final String title;
  final UserVoucherStatus status;
  final bool redeemedByPoints;
  final int pointsSpent;
  final String bookingId;
  final DateTime? usedAt;
  final DateTime? expiredAt;
  final DateTime? createdAt;

  bool get isExpired {
    if (status == UserVoucherStatus.expired) return true;
    if (expiredAt == null) return false;

    return expiredAt!.isBefore(DateTime.now());
  }

  bool get canUse {
    return status == UserVoucherStatus.available && !isExpired;
  }

  String get statusLabel {
    if (status == UserVoucherStatus.available && isExpired) {
      return UserVoucherStatus.expired.label;
    }

    return status.label;
  }

  factory UserVoucherModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return UserVoucherModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory UserVoucherModel.fromMap(String id, Map<String, dynamic> data) {
    return UserVoucherModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      voucherId: data['voucherId'] as String? ?? '',
      code: data['code'] as String? ?? '',
      title: data['title'] as String? ?? '',
      status: UserVoucherStatus.fromValue(data['status'] as String?),
      redeemedByPoints: data['redeemedByPoints'] as bool? ?? false,
      pointsSpent: (data['pointsSpent'] as num?)?.toInt() ?? 0,
      bookingId: data['bookingId'] as String? ?? '',
      usedAt: _dateTime(data['usedAt']),
      expiredAt: _dateTime(data['expiredAt']),
      createdAt: _dateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'voucherId': voucherId,
      'code': code,
      'title': title,
      'status': isExpired ? UserVoucherStatus.expired.name : status.name,
      'redeemedByPoints': redeemedByPoints,
      'pointsSpent': pointsSpent,
      'bookingId': bookingId,
      'usedAt': usedAt == null ? null : Timestamp.fromDate(usedAt!),
      'expiredAt': expiredAt == null ? null : Timestamp.fromDate(expiredAt!),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  UserVoucherModel copyWith({
    String? id,
    String? userId,
    String? voucherId,
    String? code,
    String? title,
    UserVoucherStatus? status,
    bool? redeemedByPoints,
    int? pointsSpent,
    String? bookingId,
    DateTime? usedAt,
    DateTime? expiredAt,
    DateTime? createdAt,
  }) {
    return UserVoucherModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      voucherId: voucherId ?? this.voucherId,
      code: code ?? this.code,
      title: title ?? this.title,
      status: status ?? this.status,
      redeemedByPoints: redeemedByPoints ?? this.redeemedByPoints,
      pointsSpent: pointsSpent ?? this.pointsSpent,
      bookingId: bookingId ?? this.bookingId,
      usedAt: usedAt ?? this.usedAt,
      expiredAt: expiredAt ?? this.expiredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _dateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);

    return null;
  }
}