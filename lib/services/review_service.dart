import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/booking.dart';
import '../model/review.dart';

class ReviewService {
  ReviewService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore =
           firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>
  get _reviews => _firestore.collection('reviews');

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để thực hiện thao tác này.',
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

    if (id.isEmpty) return Stream.value(const []);

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

    if (id.isEmpty) return Stream.value(const []);

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

  Stream<List<ReviewModel>>
  watchAllReviewsForAdmin() {
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

    final userReference = _firestore
        .collection('users')
        .doc(user.uid);

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

      final data = bookingSnapshot.data()!;

      if (data['customerId'] != user.uid) {
        throw StateError(
          'Bạn không có quyền đánh giá đơn này.',
        );
      }

      if (data['status'] != BookingStatus.completed) {
        throw StateError(
          'Chỉ đơn đã hoàn thành mới được đánh giá.',
        );
      }

      if (existingReview.exists) {
        throw StateError(
          'Đơn này đã được đánh giá.',
        );
      }

      final providerId =
          data['providerId']?.toString().trim() ?? '';

      final hotelId =
          data['hotelId']?.toString().trim() ?? '';

      final hotelName =
          data['hotelName']?.toString().trim() ?? '';

      final roomId =
          data['roomId']?.toString().trim() ?? '';

      final roomNumber =
          data['roomNumber']?.toString().trim() ?? '';

      final roomType =
          data['roomType']?.toString().trim() ?? '';

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

      final customerName =
          userSnapshot.data()?['fullName']
              ?.toString()
              .trim() ??
          '';

      final severity =
          ReviewSeverity.fromRating(validRating);

      final moderationStatus =
          ReviewModerationStatus.fromRating(
        validRating,
      );

      transaction.set(reviewReference, {
        'targetType': 'room',
        'bookingId': booking.id,
        'customerId': user.uid,
        'customerName': customerName.isEmpty
            ? 'Khách hàng'
            : customerName,
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
            validRating <= 2,
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

    await _firestore.runTransaction((transaction) async {
      final reference = _reviews.doc(id);
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Không tìm thấy đánh giá.');
      }

      if (snapshot.data()?['customerId'] != user.uid) {
        throw StateError(
          'Bạn không có quyền sửa đánh giá này.',
        );
      }

      transaction.update(reference, {
        'rating': validRating,
        'comment': _validateComment(comment),
        'severity':
            ReviewSeverity.fromRating(validRating),
        'moderationStatus':
            ReviewModerationStatus.fromRating(
          validRating,
        ),
        'adminNote': '',
        'assignedAdminId': '',
        'providerActionRequired':
            validRating <= 2,
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
    final reference = _reviews.doc(
      _requireId(reviewId),
    );

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Không tìm thấy đánh giá.');
      }

      if (snapshot.data()?['providerId'] != user.uid) {
        throw StateError(
          'Bạn không có quyền phản hồi đánh giá này.',
        );
      }

      transaction.update(reference, {
        'providerReply': _validateReply(reply),
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
        throw StateError('Không tìm thấy đánh giá.');
      }

      if (snapshot.data()?['providerId'] != user.uid) {
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
    final admin = _requireUser();
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

    await _reviews.doc(id).update({
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
  }

  Future<void> setReviewVisibility({
    required String reviewId,
    required bool visible,
  }) async {
    _requireUser();

    await _reviews.doc(
      _requireId(reviewId),
    ).update({
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

    if (result.length < 5 ||
        result.length > 1500) {
      throw StateError(
        'Nội dung đánh giá phải từ 5 đến 1500 ký tự.',
      );
    }

    return result;
  }

  String _validateReply(String value) {
    final result = value.trim();

    if (result.length < 2 ||
        result.length > 1000) {
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
  final firstDate =
      first.updatedAt ??
      first.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final secondDate =
      second.updatedAt ??
      second.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  return secondDate.compareTo(firstDate);
}