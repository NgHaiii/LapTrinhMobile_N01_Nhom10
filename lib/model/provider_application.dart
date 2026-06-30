import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus {
  pending,
  approved,
  rejected;

  static ApplicationStatus parse(String? value) {
    return ApplicationStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ApplicationStatus.pending,
    );
  }
}

class ProviderApplication {
  const ProviderApplication({
    required this.userId,
    required this.businessName,
    required this.representativeName,
    required this.phoneNumber,
    required this.address,
    required this.identityNumber,
    required this.identityFrontUrl,
    required this.identityBackUrl,
    required this.businessLicenseUrl,
    required this.status,
    this.rejectionReason = '',
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy = '',
  });

  final String userId;
  final String businessName;
  final String representativeName;
  final String phoneNumber;
  final String address;
  final String identityNumber;
  final String identityFrontUrl;
  final String identityBackUrl;
  final String businessLicenseUrl;
  final ApplicationStatus status;
  final String rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String reviewedBy;

  factory ProviderApplication.fromMap(Map<String, dynamic> data) {
    return ProviderApplication(
      userId: data['userId'] as String? ?? '',
      businessName: data['businessName'] as String? ?? '',
      representativeName: data['representativeName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      address: data['address'] as String? ?? '',
      identityNumber: data['identityNumber'] as String? ?? '',
      identityFrontUrl: data['identityFrontUrl'] as String? ?? '',
      identityBackUrl: data['identityBackUrl'] as String? ?? '',
      businessLicenseUrl: data['businessLicenseUrl'] as String? ?? '',
      status: ApplicationStatus.parse(data['status'] as String?),
      rejectionReason: data['rejectionReason'] as String? ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String? ?? '',
    );
  }
}
