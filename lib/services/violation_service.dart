import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/review.dart';
import '../model/violation_record.dart';

class BookingFinancials {
  const BookingFinancials({
    required this.bookingAmount,
    required this.baseCommissionRate,
  });

  final double bookingAmount;
  final double baseCommissionRate;

  double get penaltyAmount => bookingAmount * 0.05;
}

class ViolationService {
  ViolationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>
      get _violations {
    return _firestore.collection('violationRecords');
  }

  CollectionReference<Map<String, dynamic>> get _reviews {
    return _firestore.collection('reviews');
  }

  CollectionReference<Map<String, dynamic>> get _bookings {
    return _firestore.collection('bookings');
  }

  Stream<List<ViolationRecord>> watchAllViolations() {
    return _violations
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(ViolationRecord.fromFirestore)
          .toList(growable: false);
    });
  }

  Stream<List<ViolationRecord>> watchProviderViolations(
    String providerId,
  ) {
    return _violations
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(ViolationRecord.fromFirestore)
          .toList(growable: false);
    });
  }

  Stream<ViolationRecord?> watchViolation(
    String violationId,
  ) {
    return _violations
        .doc(violationId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return ViolationRecord.fromFirestore(snapshot);
    });
  }

  Future<BookingFinancials> getBookingFinancials(
    String bookingId,
  ) async {
    if (bookingId.trim().isEmpty) {
      throw StateError(
        'Đánh giá chưa liên kết với đơn đặt phòng.',
      );
    }

    final snapshot = await _bookings.doc(bookingId).get();

    if (!snapshot.exists) {
      throw StateError('Không tìm thấy đơn đặt phòng.');
    }

    final data =
        snapshot.data() ?? const <String, dynamic>{};

    final amount = _number(
      data['totalAmount'] ??
          data['totalPrice'] ??
          data['finalAmount'],
    );

    if (amount <= 0) {
      throw StateError(
        'Đơn đặt phòng chưa có tổng tiền hợp lệ.',
      );
    }

    final commissionRate = _normalizeRate(
      _number(
        data['commissionRate'],
        fallback: 0.10,
      ),
    );

    return BookingFinancials(
      bookingAmount: amount,
      baseCommissionRate: commissionRate,
    );
  }

  Future<String> createFromReview({
    required String reviewId,
    required String violationType,
    required String title,
    required String description,
    required List<String> evidenceUrls,
    required bool issueNow,
  }) async {
    final adminId = await _requireAdmin();

    final cleanTitle = title.trim();
    final cleanDescription = description.trim();

    if (!ViolationType.values.contains(violationType)) {
      throw StateError('Loại vi phạm không hợp lệ.');
    }

    if (cleanTitle.length < 5) {
      throw StateError(
        'Tiêu đề phải có ít nhất 5 ký tự.',
      );
    }

    if (cleanDescription.length < 20) {
      throw StateError(
        'Nội dung biên bản phải có ít nhất 20 ký tự.',
      );
    }

    final recordReference = _violations.doc();
    final reviewReference = _reviews.doc(reviewId);

    await _firestore.runTransaction((transaction) async {
      final reviewSnapshot =
          await transaction.get(reviewReference);

      if (!reviewSnapshot.exists) {
        throw StateError('Không tìm thấy đánh giá.');
      }

      final review = reviewSnapshot.data() ??
          const <String, dynamic>{};

      final existingViolationId =
          _text(review['violationRecordId']);

      if (existingViolationId.isNotEmpty) {
        throw StateError(
          'Đánh giá này đã có biên bản vi phạm.',
        );
      }

      final bookingId = _text(review['bookingId']);

      if (bookingId.isEmpty) {
        throw StateError(
          'Đánh giá chưa liên kết với đơn đặt phòng.',
        );
      }

      final bookingReference = _bookings.doc(bookingId);
      final bookingSnapshot =
          await transaction.get(bookingReference);

      if (!bookingSnapshot.exists) {
        throw StateError(
          'Không tìm thấy đơn đặt phòng.',
        );
      }

      final booking = bookingSnapshot.data() ??
          const <String, dynamic>{};

      final bookingAmount = _number(
        booking['totalAmount'] ??
            booking['totalPrice'] ??
            booking['finalAmount'],
      );

      if (bookingAmount <= 0) {
        throw StateError(
          'Tổng tiền đơn đặt phòng không hợp lệ.',
        );
      }

      final baseCommissionRate = _normalizeRate(
        _number(
          booking['commissionRate'],
          fallback: 0.10,
        ),
      );

      const penaltyRate = 0.05;
      final penaltyAmount =
          bookingAmount * penaltyRate;

      final now = FieldValue.serverTimestamp();

      transaction.set(recordReference, {
        'reviewId': reviewId,
        'bookingId': bookingId,
        'hotelId': _text(review['hotelId']),
        'roomId': _text(review['roomId']),
        'providerId': _text(review['providerId']),
        'customerId': _text(review['customerId']),
        'hotelName': _text(review['hotelName']),
        'roomNumber': _text(review['roomNumber']),
        'customerName': _text(review['customerName']),
        'severity': _text(
          review['severity'],
          fallback: ReviewSeverity.critical,
        ),
        'violationType': violationType,
        'title': cleanTitle,
        'description': cleanDescription,
        'evidenceUrls': evidenceUrls
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toSet()
            .toList(),
        'bookingAmount': bookingAmount,
        'baseCommissionRate': baseCommissionRate,
        'penaltyRate': penaltyRate,
        'penaltyAmount': penaltyAmount,
        'status': issueNow
            ? ViolationStatus.waitingProvider
            : ViolationStatus.draft,
        'providerExplanation': '',
        'appealNote': '',
        'adminNote': '',
        'createdBy': adminId,
        'commissionApplied': false,
        'commissionInvoiceId': null,
        'createdAt': now,
        'updatedAt': now,
        'issuedAt': issueNow ? now : null,
        'confirmedAt': null,
        'resolvedAt': null,
      });

      transaction.update(reviewReference, {
        'violationRecordId': recordReference.id,
        'moderationStatus': issueNow
            ? ReviewModerationStatus.providerContacted
            : ReviewModerationStatus.investigating,
        'providerActionRequired': issueNow,
        'updatedAt': now,
      });
    });

    return recordReference.id;
  }

  Future<void> issueDraft(String violationId) async {
    await _requireAdmin();

    final reference = _violations.doc(violationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Không tìm thấy biên bản.');
      }

      final data =
          snapshot.data() ?? const <String, dynamic>{};

      if (_text(data['status']) !=
          ViolationStatus.draft) {
        throw StateError(
          'Chỉ có thể ban hành bản nháp.',
        );
      }

      final now = FieldValue.serverTimestamp();

      transaction.update(reference, {
        'status': ViolationStatus.waitingProvider,
        'issuedAt': now,
        'updatedAt': now,
      });

      final reviewId = _text(data['reviewId']);

      if (reviewId.isNotEmpty) {
        transaction.update(_reviews.doc(reviewId), {
          'moderationStatus':
              ReviewModerationStatus.providerContacted,
          'providerActionRequired': true,
          'updatedAt': now,
        });
      }
    });
  }

  Future<void> submitProviderExplanation({
    required String violationId,
    required String explanation,
  }) async {
    final providerId = await _requireSignedIn();
    final cleanExplanation = explanation.trim();

    if (cleanExplanation.length < 10) {
      throw StateError(
        'Nội dung giải trình phải có ít nhất 10 ký tự.',
      );
    }

    final reference = _violations.doc(violationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Không tìm thấy biên bản.');
      }

      final data =
          snapshot.data() ?? const <String, dynamic>{};

      if (_text(data['providerId']) != providerId) {
        throw StateError(
          'Bạn không có quyền giải trình biên bản này.',
        );
      }

      final status = _text(data['status']);

      if (status != ViolationStatus.waitingProvider &&
          status != ViolationStatus.investigating) {
        throw StateError(
          'Biên bản không ở trạng thái nhận giải trình.',
        );
      }

      transaction.update(reference, {
        'providerExplanation': cleanExplanation,
        'status': ViolationStatus.investigating,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitAppeal({
    required String violationId,
    required String appealNote,
  }) async {
    final providerId = await _requireSignedIn();
    final cleanNote = appealNote.trim();

    if (cleanNote.length < 10) {
      throw StateError(
        'Nội dung khiếu nại phải có ít nhất 10 ký tự.',
      );
    }

    final reference = _violations.doc(violationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Không tìm thấy biên bản.');
      }

      final data =
          snapshot.data() ?? const <String, dynamic>{};

      if (_text(data['providerId']) != providerId) {
        throw StateError(
          'Bạn không có quyền khiếu nại biên bản này.',
        );
      }

      if (_text(data['status']) !=
          ViolationStatus.confirmed) {
        throw StateError(
          'Chỉ biên bản đã quyết định phạt mới được khiếu nại.',
        );
      }

      if (data['commissionApplied'] == true) {
        throw StateError(
          'Khoản phạt đã được tính vào hóa đơn.',
        );
      }

      transaction.update(reference, {
        'appealNote': cleanNote,
        'status': ViolationStatus.appealed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> confirmViolation({
    required String violationId,
    required String adminNote,
  }) async {
    await _requireAdmin();

    final cleanNote = adminNote.trim();

    if (cleanNote.length < 5) {
      throw StateError(
        'Admin phải nhập kết luận xác minh.',
      );
    }

    final reference = _violations.doc(violationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Không tìm thấy biên bản.');
      }

      final data =
          snapshot.data() ?? const <String, dynamic>{};

      final status = _text(data['status']);

      if (status != ViolationStatus.investigating &&
          status != ViolationStatus.appealed) {
        throw StateError(
          'Chỉ được quyết định sau khi nhà cung cấp giải trình.',
        );
      }

      if (status == ViolationStatus.investigating &&
          _text(data['providerExplanation']).isEmpty) {
        throw StateError(
          'Nhà cung cấp chưa gửi nội dung giải trình.',
        );
      }

      if (data['commissionApplied'] == true) {
        throw StateError(
          'Khoản phạt đã được tính vào hóa đơn.',
        );
      }

      final now = FieldValue.serverTimestamp();

      transaction.update(reference, {
        'status': ViolationStatus.confirmed,
        'adminNote': cleanNote,
        'confirmedAt': now,
        'resolvedAt': null,
        'updatedAt': now,
      });

      final reviewId = _text(data['reviewId']);

      if (reviewId.isNotEmpty) {
        transaction.update(_reviews.doc(reviewId), {
          'moderationStatus':
              ReviewModerationStatus.resolved,
          'providerActionRequired': false,
          'adminNote': cleanNote,
          'resolvedAt': now,
          'updatedAt': now,
        });
      }
    });
  }

  Future<void> resolveWithoutPenalty({
    required String violationId,
    required String adminNote,
  }) async {
    await _requireAdmin();

    final cleanNote = adminNote.trim();

    if (cleanNote.length < 5) {
      throw StateError(
        'Admin phải nhập kết luận không áp dụng phạt.',
      );
    }

    final reference = _violations.doc(violationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Không tìm thấy biên bản.');
      }

      final data =
          snapshot.data() ?? const <String, dynamic>{};

      final status = _text(data['status']);

      if (status != ViolationStatus.investigating &&
          status != ViolationStatus.appealed) {
        throw StateError(
          'Biên bản chưa thể đưa ra quyết định.',
        );
      }

      if (status == ViolationStatus.investigating &&
          _text(data['providerExplanation']).isEmpty) {
        throw StateError(
          'Nhà cung cấp chưa gửi nội dung giải trình.',
        );
      }

      if (data['commissionApplied'] == true) {
        throw StateError(
          'Khoản phạt đã được tính vào hóa đơn.',
        );
      }

      final now = FieldValue.serverTimestamp();

      transaction.update(reference, {
        'status': ViolationStatus.noPenalty,
        'adminNote': cleanNote,
        'confirmedAt': null,
        'resolvedAt': now,
        'commissionApplied': false,
        'commissionInvoiceId': null,
        'updatedAt': now,
      });

      final reviewId = _text(data['reviewId']);

      if (reviewId.isNotEmpty) {
        transaction.update(_reviews.doc(reviewId), {
          'moderationStatus':
              ReviewModerationStatus.resolved,
          'providerActionRequired': false,
          'adminNote': cleanNote,
          'resolvedAt': now,
          'updatedAt': now,
        });
      }
    });
  }

  Future<void> cancelViolation({
    required String violationId,
    required String reason,
  }) async {
    await _requireAdmin();

    final cleanReason = reason.trim();

    if (cleanReason.length < 5) {
      throw StateError(
        'Vui lòng nhập lý do hủy biên bản.',
      );
    }

    final reference = _violations.doc(violationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Không tìm thấy biên bản.');
      }

      final data =
          snapshot.data() ?? const <String, dynamic>{};

      if (_text(data['status']) !=
          ViolationStatus.draft) {
        throw StateError(
          'Chỉ được hủy biên bản đang ở dạng nháp.',
        );
      }

      if (data['commissionApplied'] == true) {
        throw StateError(
          'Không thể hủy biên bản đã tính vào hóa đơn.',
        );
      }

      final now = FieldValue.serverTimestamp();

      transaction.update(reference, {
        'status': ViolationStatus.cancelled,
        'adminNote': cleanReason,
        'resolvedAt': now,
        'updatedAt': now,
      });

      final reviewId = _text(data['reviewId']);

      if (reviewId.isNotEmpty) {
        transaction.update(_reviews.doc(reviewId), {
          'moderationStatus':
              ReviewModerationStatus.dismissed,
          'providerActionRequired': false,
          'adminNote': cleanReason,
          'updatedAt': now,
        });
      }
    });
  }

  Future<String> _requireAdmin() async {
    final uid = await _requireSignedIn();

    final snapshot =
        await _firestore.collection('users').doc(uid).get();

    if (!snapshot.exists ||
        _text(snapshot.data()?['role']) != 'admin') {
      throw StateError(
        'Chỉ quản trị viên được thực hiện thao tác này.',
      );
    }

    return uid;
  }

  Future<String> _requireSignedIn() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    return user.uid;
  }
}

String _text(
  Object? value, {
  String fallback = '',
}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double _number(
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