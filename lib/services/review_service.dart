import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/booking.dart';
import '../model/review.dart';

class ReviewService {
  ReviewService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reviews {
    return _firestore.collection('reviews');
  }

  CollectionReference<Map<String, dynamic>> get _users {
    return _firestore.collection('users');
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để thực hiện thao tác này.',
      );
    }

    return user;
  }

  Future<User> _requireAdmin() async {
    final user = _requireUser();
    final snapshot = await _users.doc(user.uid).get();

    if (!snapshot.exists ||
        _text(snapshot.data()?['role']) != 'admin') {
      throw StateError(
        'Chỉ quản trị viên được thực hiện thao tác này.',
      );
    }

    return user;
  }

  String _requireId(String value) {
    final result = value.trim();

    if (result.isEmpty) {
      throw StateError('Mã đánh giá không hợp lệ.');
    }

    return result;
  }

  Stream<ReviewModel?> watchBookingReview(
    String bookingId,
  ) {
    final id = bookingId.trim();

    if (id.isEmpty) return Stream.value(null);

    return _reviews.doc(id).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) return null;

      return ReviewModel.fromMap(data, snapshot.id);
    });
  }

  Stream<List<ReviewModel>> watchRoomReviews(
    String roomId,
  ) {
    final id = roomId.trim();

    if (id.isEmpty) {
      return Stream.value(const <ReviewModel>[]);
    }

    return _reviews
        .where('roomId', isEqualTo: id)
        .where(
          'status',
          isEqualTo: ReviewStatus.published,
        )
        .snapshots()
        .map(_publishedReviews);
  }

  Stream<List<ReviewModel>> watchHotelRoomReviews(
    String hotelId,
  ) {
    final id = hotelId.trim();

    if (id.isEmpty) {
      return Stream.value(const <ReviewModel>[]);
    }

    return _reviews
        .where('hotelId', isEqualTo: id)
        .where(
          'status',
          isEqualTo: ReviewStatus.published,
        )
        .snapshots()
        .map(_publishedReviews);
  }

  Stream<List<ReviewModel>> watchMyReviews() {
    final user = _requireUser();

    return _reviews
        .where(
          'customerId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(_allReviews);
  }

  Stream<List<ReviewModel>> watchProviderReviews() {
    final user = _requireUser();

    return _reviews
        .where(
          'providerId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(_allReviews);
  }

  Stream<List<ReviewModel>> watchAllReviewsForAdmin() {
    _requireUser();

    return _reviews.snapshots().map(_allReviews);
  }

  Future<void> createReview({
    required BookingModel booking,
    required int rating,
    required String comment,
  }) async {
    final user = _requireUser();
    final validRating = _validateRating(rating);
    final validComment = _validateComment(comment);

    final bookingReference = _firestore
        .collection('bookings')
        .doc(booking.id);

    final reviewReference = _reviews.doc(booking.id);
    final userReference = _users.doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(
        bookingReference,
      );

      final existingReview = await transaction.get(
        reviewReference,
      );

      final userSnapshot = await transaction.get(
        userReference,
      );

      if (!bookingSnapshot.exists) {
        throw StateError(
          'Không tìm thấy đơn đặt phòng.',
        );
      }

      final bookingData = bookingSnapshot.data()!;

      if (_text(bookingData['customerId']) != user.uid) {
        throw StateError(
          'Bạn không có quyền đánh giá đơn này.',
        );
      }

      if (_text(bookingData['status']) !=
          BookingStatus.completed) {
        throw StateError(
          'Chỉ đơn đã hoàn thành mới được đánh giá.',
        );
      }

      if (existingReview.exists) {
        throw StateError(
          'Đơn này đã được đánh giá.',
        );
      }

      final providerId = _text(
        bookingData['providerId'],
      );

      final hotelId = _text(
        bookingData['hotelId'],
      );

      final hotelName = _text(
        bookingData['hotelName'],
      );

      final roomId = _text(
        bookingData['roomId'],
      );

      final roomNumber = _text(
        bookingData['roomNumber'],
      );

      final roomType = _text(
        bookingData['roomType'],
      );

      if (providerId.isEmpty ||
          hotelId.isEmpty ||
          hotelName.isEmpty ||
          roomId.isEmpty ||
          roomNumber.isEmpty ||
          roomType.isEmpty) {
        throw StateError(
          'Đơn không có đầy đủ thông tin phòng.',
        );
      }

      final customerName = _text(
        userSnapshot.data()?['fullName'],
        fallback: 'Khách hàng',
      );

      final severity = ReviewSeverity.fromContent(
        validRating,
        validComment,
      );

      final moderationStatus =
          ReviewModerationStatus.fromSeverity(
        severity,
      );

      final providerActionRequired =
          severity == ReviewSeverity.critical ||
              severity == ReviewSeverity.high;

      transaction.set(reviewReference, {
        'targetType': 'room',
        'bookingId': booking.id,
        'customerId': user.uid,
        'customerName': customerName,
        'providerId': providerId,
        'hotelId': hotelId,
        'hotelName': hotelName,
        'roomId': roomId,
        'roomNumber': roomNumber,
        'roomType': roomType,
        'rating': validRating,
        'comment': validComment,
        'providerReply': '',
        'status': ReviewStatus.published,
        'severity': severity,
        'moderationStatus': moderationStatus,
        'adminNote': '',
        'assignedAdminId': '',
        'providerActionRequired':
            providerActionRequired,
        'violationRecordId': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'repliedAt': null,
        'reviewedAt': null,
        'resolvedAt': null,
      });
    });
  }

  Future<void> updateReview({
    required String reviewId,
    required int rating,
    required String comment,
  }) async {
    final user = _requireUser();
    final id = _requireId(reviewId);
    final validRating = _validateRating(rating);
    final validComment = _validateComment(comment);

    await _firestore.runTransaction((transaction) async {
      final reference = _reviews.doc(id);
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError(
          'Không tìm thấy đánh giá.',
        );
      }

      final data = snapshot.data()!;

      if (_text(data['customerId']) != user.uid) {
        throw StateError(
          'Bạn không có quyền sửa đánh giá này.',
        );
      }

      if (_text(data['violationRecordId']).isNotEmpty) {
        throw StateError(
          'Không thể sửa đánh giá đang có biên bản xử lý.',
        );
      }

      final severity = ReviewSeverity.fromContent(
        validRating,
        validComment,
      );

      final moderationStatus =
          ReviewModerationStatus.fromSeverity(
        severity,
      );

      final providerActionRequired =
          severity == ReviewSeverity.critical ||
              severity == ReviewSeverity.high;

      transaction.update(reference, {
        'rating': validRating,
        'comment': validComment,
        'severity': severity,
        'moderationStatus': moderationStatus,
        'adminNote': '',
        'assignedAdminId': '',
        'providerActionRequired':
            providerActionRequired,
        'reviewedAt': null,
        'resolvedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    final user = _requireUser();
    final validReply = _validateReply(reply);

    final reference = _reviews.doc(
      _requireId(reviewId),
    );

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError(
          'Không tìm thấy đánh giá.',
        );
      }

      final data = snapshot.data()!;

      if (_text(data['providerId']) != user.uid) {
        throw StateError(
          'Bạn không có quyền phản hồi đánh giá này.',
        );
      }

      transaction.update(reference, {
        'providerReply': validReply,
        'repliedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> removeProviderReply(
    String reviewId,
  ) async {
    final user = _requireUser();

    final reference = _reviews.doc(
      _requireId(reviewId),
    );

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError(
          'Không tìm thấy đánh giá.',
        );
      }

      final data = snapshot.data()!;

      if (_text(data['providerId']) != user.uid) {
        throw StateError(
          'Bạn không có quyền xóa phản hồi này.',
        );
      }

      transaction.update(reference, {
        'providerReply': '',
        'repliedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> moderateReview({
    required String reviewId,
    required String moderationStatus,
    required String adminNote,
    required bool providerActionRequired,
  }) async {
    final admin = await _requireAdmin();
    final id = _requireId(reviewId);

    if (!ReviewModerationStatus.values.contains(
      moderationStatus,
    )) {
      throw StateError(
        'Trạng thái xử lý không hợp lệ.',
      );
    }

    final note = adminNote.trim();

    if (note.length < 3 || note.length > 1500) {
      throw StateError(
        'Ghi chú phải từ 3 đến 1500 ký tự.',
      );
    }

    final closed =
        moderationStatus ==
                ReviewModerationStatus.resolved ||
            moderationStatus ==
                ReviewModerationStatus.dismissed;

    await _firestore.runTransaction((transaction) async {
      final reference = _reviews.doc(id);
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError(
          'Không tìm thấy đánh giá.',
        );
      }

      final data = snapshot.data()!;

      if (_text(data['violationRecordId']).isNotEmpty &&
          moderationStatus ==
              ReviewModerationStatus.dismissed) {
        throw StateError(
          'Đánh giá đã có biên bản. Hãy hủy biên bản '
          'trước khi kết luận không vi phạm.',
        );
      }

      transaction.update(reference, {
        'moderationStatus': moderationStatus,
        'adminNote': note,
        'assignedAdminId': admin.uid,
        'providerActionRequired':
            providerActionRequired,
        'reviewedAt': FieldValue.serverTimestamp(),
        'resolvedAt': closed
            ? FieldValue.serverTimestamp()
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setReviewVisibility({
    required String reviewId,
    required bool visible,
  }) async {
    await _requireAdmin();

    final id = _requireId(reviewId);

    await _reviews.doc(id).update({
      'status': visible
          ? ReviewStatus.published
          : ReviewStatus.hidden,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<ReviewModel> _publishedReviews(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _parseReviews(
      snapshot,
      publishedOnly: true,
    );
  }

  List<ReviewModel> _allReviews(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _parseReviews(
      snapshot,
      publishedOnly: false,
    );
  }

  List<ReviewModel> _parseReviews(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool publishedOnly,
  }) {
    final reviews = <ReviewModel>[];

    for (final document in snapshot.docs) {
      try {
        final review = ReviewModel.fromMap(
          document.data(),
          document.id,
        );

        if (!publishedOnly || review.isPublished) {
          reviews.add(review);
        }
      } catch (error, stackTrace) {
        developer.log(
          'Đánh giá ${document.id} không hợp lệ.',
          name: 'ReviewService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    reviews.sort(_newestFirst);
    return reviews;
  }

  int _validateRating(int rating) {
    if (rating < 1 || rating > 5) {
      throw StateError(
        'Điểm đánh giá phải từ 1 đến 5.',
      );
    }

    return rating;
  }

  String _validateComment(String value) {
    final result = value.trim();

    if (result.length < 5 || result.length > 1500) {
      throw StateError(
        'Nội dung đánh giá phải từ 5 đến 1500 ký tự.',
      );
    }

    return result;
  }

  String _validateReply(String value) {
    final result = value.trim();

    if (result.length < 2 || result.length > 1000) {
      throw StateError(
        'Phản hồi phải từ 2 đến 1000 ký tự.',
      );
    }

    return result;
  }
}

int _newestFirst(
  ReviewModel first,
  ReviewModel second,
) {
  final firstDate = first.updatedAt ??
      first.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final secondDate = second.updatedAt ??
      second.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  return secondDate.compareTo(firstDate);
}

String _text(
  Object? value, {
  String fallback = '',
}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}