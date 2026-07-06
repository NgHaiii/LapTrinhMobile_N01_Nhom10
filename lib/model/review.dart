import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class ReviewStatus {
  static const published = 'published';
  static const hidden = 'hidden';

  static const values = {published, hidden};

  static String normalize(dynamic value) {
    final result = value?.toString().trim().toLowerCase();
    return values.contains(result) ? result! : published;
  }
}

abstract final class ReviewSeverity {
  static const normal = 'normal';
  static const warning = 'warning';
  static const high = 'high';
  static const critical = 'critical';

  static const values = {normal, warning, high, critical};

  static String fromContent(int rating, String comment) {
    if (rating == 1) return critical;

    final normalized = comment.toLowerCase();
    const seriousKeywords = [
      'lừa đảo',
      'đe dọa',
      'hành hung',
      'trộm',
      'mất cắp',
      'mất an toàn',
      'nguy hiểm',
      'quấy rối',
      'không đúng phòng',
      'không có phòng',
    ];

    final hasSeriousContent = seriousKeywords.any(
      normalized.contains,
    );

    if (rating <= 2 && hasSeriousContent) return critical;
    if (rating == 2) return high;
    if (rating == 3) return warning;
    return normal;
  }

  static String normalize(
    dynamic value, {
    required int rating,
    required String comment,
  }) {
    final result = value?.toString().trim().toLowerCase();

    if (result != null && values.contains(result)) {
      return result;
    }

    return fromContent(rating, comment);
  }
}

abstract final class ReviewModerationStatus {
  static const notRequired = 'not_required';
  static const pendingReview = 'pending_review';
  static const investigating = 'investigating';
  static const providerContacted = 'provider_contacted';
  static const resolved = 'resolved';
  static const dismissed = 'dismissed';

  static const values = {
    notRequired,
    pendingReview,
    investigating,
    providerContacted,
    resolved,
    dismissed,
  };

  static String fromSeverity(String severity) {
    return severity == ReviewSeverity.normal
        ? notRequired
        : pendingReview;
  }

  static String normalize(
    dynamic value, {
    required String severity,
  }) {
    final result = value?.toString().trim().toLowerCase();

    if (result != null && values.contains(result)) {
      return result;
    }

    return fromSeverity(severity);
  }
}

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.hotelId,
    required this.roomId,
    required this.rating,
    required this.comment,
    required this.status,
    this.customerName = '',
    this.hotelName = '',
    this.roomNumber = '',
    this.roomType = '',
    this.providerReply = '',
    this.severity = ReviewSeverity.normal,
    this.moderationStatus =
        ReviewModerationStatus.notRequired,
    this.adminNote = '',
    this.assignedAdminId = '',
    this.providerActionRequired = false,
    this.violationRecordId = '',
    this.createdAt,
    this.updatedAt,
    this.repliedAt,
    this.reviewedAt,
    this.resolvedAt,
  });

  final String id;
  final String bookingId;

  final String customerId;
  final String customerName;
  final String providerId;

  final String hotelId;
  final String hotelName;
  final String roomId;
  final String roomNumber;
  final String roomType;

  final int rating;
  final String comment;
  final String providerReply;
  final String status;

  final String severity;
  final String moderationStatus;
  final String adminNote;
  final String assignedAdminId;
  final bool providerActionRequired;

  final String violationRecordId;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? repliedAt;
  final DateTime? reviewedAt;
  final DateTime? resolvedAt;

  bool get isPublished => status == ReviewStatus.published;

  bool get hasProviderReply {
    return providerReply.trim().isNotEmpty;
  }

  bool get hasViolationRecord {
    return violationRecordId.trim().isNotEmpty;
  }

  bool get requiresModeration {
    return moderationStatus !=
            ReviewModerationStatus.notRequired &&
        moderationStatus != ReviewModerationStatus.resolved &&
        moderationStatus != ReviewModerationStatus.dismissed;
  }

  bool get isModerationClosed {
    return moderationStatus ==
            ReviewModerationStatus.resolved ||
        moderationStatus == ReviewModerationStatus.dismissed;
  }

  bool get isCritical {
    return severity == ReviewSeverity.critical;
  }

  factory ReviewModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    final rating = _normalizeRating(data['rating']);
    final comment = _asString(data['comment']);

    final severity = ReviewSeverity.normalize(
      data['severity'],
      rating: rating,
      comment: comment,
    );

    return ReviewModel(
      id: id,
      bookingId: _asString(
        data['bookingId'],
        fallback: id,
      ),
      customerId: _asString(data['customerId']),
      customerName: _asString(
        data['customerName'],
        fallback: 'Khách hàng',
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
      rating: rating,
      comment: comment,
      providerReply: _asString(data['providerReply']),
      status: ReviewStatus.normalize(data['status']),
      severity: severity,
      moderationStatus: ReviewModerationStatus.normalize(
        data['moderationStatus'],
        severity: severity,
      ),
      adminNote: _asString(data['adminNote']),
      assignedAdminId: _asString(data['assignedAdminId']),
      providerActionRequired: _asBool(
        data['providerActionRequired'],
        fallback: severity == ReviewSeverity.critical ||
            severity == ReviewSeverity.high,
      ),
      violationRecordId: _asString(
        data['violationRecordId'],
      ),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
      repliedAt: _asDateTime(data['repliedAt']),
      reviewedAt: _asDateTime(data['reviewedAt']),
      resolvedAt: _asDateTime(data['resolvedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedSeverity = ReviewSeverity.normalize(
      severity,
      rating: rating,
      comment: comment,
    );

    return {
      'targetType': 'room',
      'bookingId': bookingId.trim(),
      'customerId': customerId.trim(),
      'customerName': customerName.trim(),
      'providerId': providerId.trim(),
      'hotelId': hotelId.trim(),
      'hotelName': hotelName.trim(),
      'roomId': roomId.trim(),
      'roomNumber': roomNumber.trim(),
      'roomType': roomType.trim(),
      'rating': rating.clamp(1, 5),
      'comment': comment.trim(),
      'providerReply': providerReply.trim(),
      'status': ReviewStatus.normalize(status),
      'severity': normalizedSeverity,
      'moderationStatus': ReviewModerationStatus.normalize(
        moderationStatus,
        severity: normalizedSeverity,
      ),
      'adminNote': adminNote.trim(),
      'assignedAdminId': assignedAdminId.trim(),
      'providerActionRequired': providerActionRequired,
      'violationRecordId': violationRecordId.trim(),
      'createdAt': _timestamp(createdAt),
      'updatedAt': _timestamp(updatedAt),
      'repliedAt': _timestamp(repliedAt),
      'reviewedAt': _timestamp(reviewedAt),
      'resolvedAt': _timestamp(resolvedAt),
    };
  }

  ReviewModel copyWith({
    int? rating,
    String? comment,
    String? providerReply,
    String? status,
    String? severity,
    String? moderationStatus,
    String? adminNote,
    String? assignedAdminId,
    bool? providerActionRequired,
    String? violationRecordId,
    DateTime? updatedAt,
    DateTime? repliedAt,
    DateTime? reviewedAt,
    DateTime? resolvedAt,
    bool clearReply = false,
    bool clearResolution = false,
    bool clearViolationRecord = false,
  }) {
    return ReviewModel(
      id: id,
      bookingId: bookingId,
      customerId: customerId,
      customerName: customerName,
      providerId: providerId,
      hotelId: hotelId,
      hotelName: hotelName,
      roomId: roomId,
      roomNumber: roomNumber,
      roomType: roomType,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      providerReply: clearReply
          ? ''
          : providerReply ?? this.providerReply,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      moderationStatus:
          moderationStatus ?? this.moderationStatus,
      adminNote: adminNote ?? this.adminNote,
      assignedAdminId:
          assignedAdminId ?? this.assignedAdminId,
      providerActionRequired:
          providerActionRequired ?? this.providerActionRequired,
      violationRecordId: clearViolationRecord
          ? ''
          : violationRecordId ?? this.violationRecordId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      repliedAt:
          clearReply ? null : repliedAt ?? this.repliedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      resolvedAt: clearResolution
          ? null
          : resolvedAt ?? this.resolvedAt,
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

int _normalizeRating(dynamic value) {
  final result = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 1;

  return result.clamp(1, 5);
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
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

Timestamp? _timestamp(DateTime? value) {
  return value == null ? null : Timestamp.fromDate(value);
}