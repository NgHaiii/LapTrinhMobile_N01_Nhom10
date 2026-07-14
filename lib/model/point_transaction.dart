import 'package:cloud_firestore/cloud_firestore.dart';

enum PointTransactionType {
  earn,
  redeem,
  expire,
  adjust;

  String get label {
    return switch (this) {
      PointTransactionType.earn => 'Tích điểm',
      PointTransactionType.redeem => 'Đổi điểm',
      PointTransactionType.expire => 'Hết hạn',
      PointTransactionType.adjust => 'Điều chỉnh',
    };
  }

  static PointTransactionType fromValue(String? value) {
    return PointTransactionType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PointTransactionType.earn,
    );
  }
}

enum PointTransactionSource {
  booking,
  voucher,
  admin,
  system;

  String get label {
    return switch (this) {
      PointTransactionSource.booking => 'Đặt phòng',
      PointTransactionSource.voucher => 'Voucher',
      PointTransactionSource.admin => 'Quản trị viên',
      PointTransactionSource.system => 'Hệ thống',
    };
  }

  static PointTransactionSource fromValue(String? value) {
    return PointTransactionSource.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PointTransactionSource.system,
    );
  }
}

class PointTransactionModel {
  const PointTransactionModel({
    required this.id,
    required this.userId,
    required this.points,
    required this.type,
    required this.source,
    this.title = '',
    this.description = '',
    this.referenceId = '',
    this.createdAt,
  });

  final String id;
  final String userId;
  final int points;
  final PointTransactionType type;
  final PointTransactionSource source;
  final String title;
  final String description;
  final String referenceId;
  final DateTime? createdAt;

  bool get isPositive {
    return type == PointTransactionType.earn ||
        (type == PointTransactionType.adjust && points > 0);
  }

  String get signedPoints {
    if (points == 0) return '0';
    return isPositive ? '+$points' : '-${points.abs()}';
  }

  factory PointTransactionModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PointTransactionModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory PointTransactionModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return PointTransactionModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      points: _intValue(data['points']),
      type: PointTransactionType.fromValue(data['type'] as String?),
      source: PointTransactionSource.fromValue(data['source'] as String?),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      referenceId: data['referenceId'] as String? ?? '',
      createdAt: _dateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'points': points,
      'type': type.name,
      'source': source.name,
      'title': title,
      'description': description,
      'referenceId': referenceId,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : createdAt,
    };
  }

  PointTransactionModel copyWith({
    String? id,
    String? userId,
    int? points,
    PointTransactionType? type,
    PointTransactionSource? source,
    String? title,
    String? description,
    String? referenceId,
    DateTime? createdAt,
  }) {
    return PointTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      points: points ?? this.points,
      type: type ?? this.type,
      source: source ?? this.source,
      title: title ?? this.title,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

DateTime? _dateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}