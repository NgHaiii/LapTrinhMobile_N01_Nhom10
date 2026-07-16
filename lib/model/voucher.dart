import 'package:cloud_firestore/cloud_firestore.dart';

enum VoucherDiscountType {
  fixed,
  percentage;

  String get label {
    return switch (this) {
      VoucherDiscountType.fixed => 'Giảm tiền',
      VoucherDiscountType.percentage => 'Giảm phần trăm',
    };
  }

  static VoucherDiscountType fromValue(String? value) {
    // Hỗ trợ cả tên enum trong model và tên được form admin lưu.
    return switch (value?.trim()) {
      'percentage' || 'percent' => VoucherDiscountType.percentage,
      'fixed' || 'fixedAmount' => VoucherDiscountType.fixed,
      _ => VoucherDiscountType.fixed,
    };
  }
}

enum VoucherTarget {
  booking,
  travelActivity,
  all;

  String get label {
    return switch (this) {
      VoucherTarget.booking => 'Đặt phòng',
      VoucherTarget.travelActivity => 'Hoạt động du lịch',
      VoucherTarget.all => 'Tất cả dịch vụ',
    };
  }

  static VoucherTarget fromValue(String? value) {
    return VoucherTarget.values.firstWhere(
      (item) => item.name == value,
      orElse: () => VoucherTarget.booking,
    );
  }
}

class VoucherModel {
  const VoucherModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    this.discountType = VoucherDiscountType.fixed,
    this.target = VoucherTarget.booking,
    this.discountValue = 0,
    this.maxDiscountAmount = 0,
    this.minOrderAmount = 0,
    this.requiredPoints = 0,
    this.quantity = 0,
    this.usedCount = 0,
    this.startAt,
    this.endAt,
    this.isActive = true,
    this.imageUrl = '',
    this.terms = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String code;
  final String title;
  final String description;
  final VoucherDiscountType discountType;
  final VoucherTarget target;
  final double discountValue;
  final double maxDiscountAmount;
  final double minOrderAmount;
  final int requiredPoints;
  final int quantity;
  final int usedCount;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;
  final String imageUrl;
  final List<String> terms;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isExpired {
    if (endAt == null) return false;
    return DateTime.now().isAfter(endAt!);
  }

  bool get isNotStarted {
    if (startAt == null) return false;
    return DateTime.now().isBefore(startAt!);
  }

  bool get isOutOfStock {
    return quantity > 0 && usedCount >= quantity;
  }

  /// Voucher được phép hiển thị và nhận/đổi.
  ///
  /// Không kiểm tra ngày bắt đầu để khách có thể đổi voucher trước
  /// thời gian áp dụng.
  bool get canClaim {
    return isActive && !isExpired && !isOutOfStock;
  }

  /// Voucher được phép áp dụng vào đơn hàng.
  ///
  /// Khác với [canClaim], voucher chỉ sử dụng được khi đã đến ngày bắt đầu.
  bool get canUse {
    return canClaim && !isNotStarted;
  }

  String get discountLabel {
    if (discountType == VoucherDiscountType.percentage) {
      final value = discountValue.toStringAsFixed(
        discountValue.truncateToDouble() == discountValue ? 0 : 1,
      );

      return 'Giảm $value%';
    }

    return 'Giảm ${discountValue.round()}đ';
  }

  double calculateDiscount(double orderAmount) {
    // Giữ canUse tại đây để voucher chưa đến ngày không thể giảm giá.
    if (!canUse || orderAmount < minOrderAmount) {
      return 0;
    }

    final rawDiscount = discountType == VoucherDiscountType.percentage
        ? orderAmount * discountValue / 100
        : discountValue;

    if (maxDiscountAmount > 0) {
      return rawDiscount > maxDiscountAmount
          ? maxDiscountAmount
          : rawDiscount;
    }

    return rawDiscount;
  }

  factory VoucherModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return VoucherModel.fromMap(
      doc.data() ?? const <String, dynamic>{},
      doc.id,
    );
  }

  factory VoucherModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return VoucherModel(
      id: id,
      code: _stringValue(data['code']),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      discountType: VoucherDiscountType.fromValue(
        data['discountType']?.toString(),
      ),
      target: VoucherTarget.fromValue(
        data['target']?.toString(),
      ),
      discountValue: _doubleValue(data['discountValue']),
      maxDiscountAmount: _doubleValue(data['maxDiscountAmount']),
      minOrderAmount: _doubleValue(data['minOrderAmount']),

      // Form admin đang lưu là pointsRequired.
      // requiredPoints được giữ làm dự phòng cho dữ liệu cũ.
      requiredPoints: _intValue(
        data['pointsRequired'] ?? data['requiredPoints'],
      ),

      quantity: _intValue(data['quantity']),
      usedCount: _intValue(data['usedCount']),
      startAt: _dateTime(data['startAt']),
      endAt: _dateTime(data['endAt']),
      isActive: data['isActive'] is bool
          ? data['isActive'] as bool
          : true,
      imageUrl: _stringValue(data['imageUrl']),
      terms: _stringList(data['terms']),
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'title': title,
      'description': description,
      'discountType': discountType.name,
      'target': target.name,
      'discountValue': discountValue,
      'maxDiscountAmount': maxDiscountAmount,
      'minOrderAmount': minOrderAmount,
      'requiredPoints': requiredPoints,
      'quantity': quantity,
      'usedCount': usedCount,
      'startAt': startAt,
      'endAt': endAt,
      'isActive': isActive,
      'imageUrl': imageUrl,
      'terms': terms,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  VoucherModel copyWith({
    String? id,
    String? code,
    String? title,
    String? description,
    VoucherDiscountType? discountType,
    VoucherTarget? target,
    double? discountValue,
    double? maxDiscountAmount,
    double? minOrderAmount,
    int? requiredPoints,
    int? quantity,
    int? usedCount,
    DateTime? startAt,
    DateTime? endAt,
    bool? isActive,
    String? imageUrl,
    List<String>? terms,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoucherModel(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      target: target ?? this.target,
      discountValue: discountValue ?? this.discountValue,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      requiredPoints: requiredPoints ?? this.requiredPoints,
      quantity: quantity ?? this.quantity,
      usedCount: usedCount ?? this.usedCount,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      terms: terms ?? this.terms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String _stringValue(dynamic value) {
  return value?.toString().trim() ?? '';
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  // Form admin hiện lưu điều khoản dưới dạng một chuỗi.
  if (value is String) {
    return value
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  return const [];
}

double _doubleValue(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value.trim()) ?? 0;
  }

  return 0;
}

int _intValue(dynamic value) {
  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }

  return 0;
}

DateTime? _dateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}