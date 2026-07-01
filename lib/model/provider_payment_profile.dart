import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class PaymentProfileStatus {
  static const notSubmitted = 'not_submitted';
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';

  static const values = {
    notSubmitted,
    pending,
    approved,
    rejected,
  };

  static String normalize(dynamic value) {
    final status = value?.toString().trim().toLowerCase();

    if (status != null && values.contains(status)) return status;
    return notSubmitted;
  }

  static String label(String status) {
    return switch (normalize(status)) {
      pending => 'Đang chờ xác minh',
      approved => 'Đã xác minh',
      rejected => 'Bị từ chối',
      _ => 'Chưa cung cấp',
    };
  }
}

class ProviderPaymentProfile {
  const ProviderPaymentProfile({
    required this.providerId,
    required this.businessName,
    required this.bankBin,
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.isVerified,
    required this.verificationStatus,
    this.rejectionReason = '',
    this.verifiedBy = '',
    this.createdAt,
    this.updatedAt,
    this.verifiedAt,
  });

  final String providerId;
  final String businessName;

  /// BIN ngân hàng dùng để tạo VietQR.
  final String bankBin;
  final String bankCode;
  final String bankName;

  final String accountNumber;
  final String accountName;

  final bool isVerified;
  final String verificationStatus;
  final String rejectionReason;
  final String verifiedBy;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? verifiedAt;

  bool get hasBankInformation {
    return bankBin.trim().isNotEmpty &&
        bankName.trim().isNotEmpty &&
        accountNumber.trim().isNotEmpty &&
        accountName.trim().isNotEmpty;
  }

  bool get canReceivePayments {
    return hasBankInformation &&
        isVerified &&
        verificationStatus == PaymentProfileStatus.approved;
  }

  String get statusLabel {
    return PaymentProfileStatus.label(verificationStatus);
  }

  String get maskedAccountNumber {
    final value = accountNumber.trim();

    if (value.length <= 4) return value;
    return '${'*' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  factory ProviderPaymentProfile.empty({
    required String providerId,
    String businessName = '',
  }) {
    return ProviderPaymentProfile(
      providerId: providerId,
      businessName: businessName,
      bankBin: '',
      bankCode: '',
      bankName: '',
      accountNumber: '',
      accountName: '',
      isVerified: false,
      verificationStatus: PaymentProfileStatus.notSubmitted,
    );
  }

  factory ProviderPaymentProfile.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return ProviderPaymentProfile(
      providerId: _asString(
        data['providerId'],
        fallback: id,
      ),
      businessName: _asString(data['businessName']),
      bankBin: _asString(data['bankBin']),
      bankCode: _asString(data['bankCode']).toUpperCase(),
      bankName: _asString(data['bankName']),
      accountNumber: _asString(data['accountNumber']),
      accountName: _asString(data['accountName']).toUpperCase(),
      isVerified: _asBool(data['isVerified']),
      verificationStatus: PaymentProfileStatus.normalize(
        data['verificationStatus'],
      ),
      rejectionReason: _asString(data['rejectionReason']),
      verifiedBy: _asString(data['verifiedBy']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
      verifiedAt: _asDateTime(data['verifiedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId.trim(),
      'businessName': businessName.trim(),
      'bankBin': bankBin.trim(),
      'bankCode': bankCode.trim().toUpperCase(),
      'bankName': bankName.trim(),
      'accountNumber': accountNumber.trim(),
      'accountName': accountName.trim().toUpperCase(),
      'isVerified': isVerified,
      'verificationStatus': PaymentProfileStatus.normalize(
        verificationStatus,
      ),
      'rejectionReason': rejectionReason.trim(),
      'verifiedBy': verifiedBy.trim(),
    };
  }

  ProviderPaymentProfile copyWith({
    String? providerId,
    String? businessName,
    String? bankBin,
    String? bankCode,
    String? bankName,
    String? accountNumber,
    String? accountName,
    bool? isVerified,
    String? verificationStatus,
    String? rejectionReason,
    String? verifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? verifiedAt,
  }) {
    return ProviderPaymentProfile(
      providerId: providerId ?? this.providerId,
      businessName: businessName ?? this.businessName,
      bankBin: bankBin ?? this.bankBin,
      bankCode: bankCode ?? this.bankCode,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus:
          verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;

  final result = value.toString().trim();
  return result.isEmpty ? fallback : result;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  if (value is String) {
    final normalized = value.trim().toLowerCase();

    if (const {'true', '1', 'yes'}.contains(normalized)) return true;
    if (const {'false', '0', 'no'}.contains(normalized)) return false;
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