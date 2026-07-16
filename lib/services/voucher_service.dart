import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/user_voucher.dart';
import '../model/voucher.dart';
import 'loyalty_service.dart';

class VoucherService {
  VoucherService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LoyaltyService? loyaltyService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _loyaltyService = loyaltyService ?? LoyaltyService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LoyaltyService _loyaltyService;

  CollectionReference<Map<String, dynamic>> get _vouchersRef {
    return _firestore.collection('vouchers');
  }

  CollectionReference<Map<String, dynamic>> get _userVouchersRef {
    return _firestore.collection('userVouchers');
  }

  CollectionReference<Map<String, dynamic>> get _usersRef {
    return _firestore.collection('users');
  }

  /// Theo dõi số voucher mới khách hàng chưa xem.
  ///
  /// Hàm đọc trực tiếp dữ liệu Firestore thay vì tạo VoucherModel
  /// để một voucher chưa hoàn chỉnh không làm lỗi toàn bộ giao diện.
  Stream<int> watchNewVoucherCount() {
    return _watchNewVoucherCount().asBroadcastStream();
  }

  Stream<int> _watchNewVoucherCount() async* {
    final user = _auth.currentUser;

    if (user == null) {
      yield 0;
      return;
    }

    DateTime? lastSeenVoucherAt;

    try {
      final userSnapshot = await _usersRef.doc(user.uid).get();
      final userData =
          userSnapshot.data() ?? const <String, dynamic>{};

      if (!_promotionsEnabled(userData)) {
        yield 0;
        return;
      }

      lastSeenVoucherAt = _dateTime(
        userData['lastSeenVoucherAt'],
      );
    } catch (error, stackTrace) {
      developer.log(
        'Không thể đọc trạng thái voucher đã xem',
        name: 'VoucherService',
        error: error,
        stackTrace: stackTrace,
      );

      // Không để lỗi đọc trạng thái làm đỏ giao diện.
      yield 0;
      return;
    }

    yield* _vouchersRef
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      var count = 0;

      for (final document in snapshot.docs) {
        try {
          final data = document.data();

          if (data['isActive'] != true) {
            continue;
          }

          final createdAt = _dateTime(data['createdAt']);

          // serverTimestamp có thể chưa hoàn tất trong một thời gian ngắn.
          // Khi đó chỉ bỏ qua document, không làm sập giao diện.
          if (createdAt == null) {
            continue;
          }

          final endAt = _dateTime(data['endAt']);

          if (endAt != null && now.isAfter(endAt)) {
            continue;
          }

          final quantity = _safeInt(data['quantity']);
          final usedCount = _safeInt(data['usedCount']);

          if (quantity > 0 && usedCount >= quantity) {
            continue;
          }

          final isNew = lastSeenVoucherAt == null ||
              createdAt.isAfter(lastSeenVoucherAt);

          if (isNew) {
            count++;
          }
        } catch (error, stackTrace) {
          // Một voucher lỗi dữ liệu chỉ bị bỏ qua.
          developer.log(
            'Không thể kiểm tra voucher ${document.id}',
            name: 'VoucherService',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      return count;
    }).handleError((error, stackTrace) {
      developer.log(
        'Theo dõi voucher mới thất bại',
        name: 'VoucherService',
        error: error,
        stackTrace: stackTrace,
      );

      // Không throw lại lỗi vì stream này chỉ dùng hiển thị badge.
    });
  }

  /// Đánh dấu tất cả voucher hiện tại là đã xem.
  Future<void> markVouchersAsSeen() async {
    final user = _requireUser();

    await _usersRef.doc(user.uid).update({
      'lastSeenVoucherAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Theo dõi voucher được phép hiển thị và nhận/đổi.
  ///
  /// Voucher chưa đến ngày áp dụng vẫn được hiển thị.
  Stream<List<VoucherModel>> watchActiveVouchers({
    VoucherTarget? target,
    bool includePointVouchers = true,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _vouchersRef.where(
      'isActive',
      isEqualTo: true,
    );

    if (target != null && target != VoucherTarget.all) {
      query = query.where(
        'target',
        whereIn: [
          target.name,
          VoucherTarget.all.name,
        ],
      );
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      final vouchers = <VoucherModel>[];

      for (final document in snapshot.docs) {
        try {
          final voucher = VoucherModel.fromDoc(document);

          if (!includePointVouchers &&
              voucher.requiredPoints > 0) {
            continue;
          }

          // canClaim cho phép hiển thị trước ngày áp dụng.
          if (!voucher.canClaim) {
            continue;
          }

          vouchers.add(voucher);
        } catch (error, stackTrace) {
          // Bỏ qua document bị lỗi thay vì làm hỏng trang Ưu đãi.
          developer.log(
            'Không thể đọc voucher ${document.id}',
            name: 'VoucherService',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      vouchers.sort((a, b) {
        final pointCompare =
            a.requiredPoints.compareTo(b.requiredPoints);

        if (pointCompare != 0) {
          return pointCompare;
        }

        final aEnd = a.endAt ?? DateTime(2999);
        final bEnd = b.endAt ?? DateTime(2999);

        return aEnd.compareTo(bEnd);
      });

      return vouchers;
    }).handleError((error, stackTrace) {
      developer.log(
        'watchActiveVouchers failed',
        name: 'VoucherService',
        error: error,
        stackTrace: stackTrace,
      );

      throw error;
    });
  }

  Stream<List<UserVoucherModel>> watchMyVouchers({
    UserVoucherStatus? status,
  }) {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Stream.value(const []);
    }

    Query<Map<String, dynamic>> query = _userVouchersRef.where(
      'userId',
      isEqualTo: userId,
    );

    if (status != null) {
      query = query.where(
        'status',
        isEqualTo: status.name,
      );
    }

    return query.snapshots().map((snapshot) {
      final vouchers = <UserVoucherModel>[];

      for (final document in snapshot.docs) {
        try {
          vouchers.add(
            UserVoucherModel.fromDoc(document),
          );
        } catch (error, stackTrace) {
          developer.log(
            'Không thể đọc userVoucher ${document.id}',
            name: 'VoucherService',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      vouchers.sort((a, b) {
        final aTime =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        return bTime.compareTo(aTime);
      });

      return vouchers;
    });
  }

  /// Chỉ trả về voucher thực sự dùng được.
  ///
  /// Voucher đã đổi trước ngày áp dụng chưa xuất hiện trong danh sách
  /// chọn voucher khi đặt phòng.
  Stream<List<UserVoucherModel>> watchMyUsableVouchers({
    VoucherTarget target = VoucherTarget.booking,
    double orderAmount = 0,
  }) {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Stream.value(const []);
    }

    return _userVouchersRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .where(
          'status',
          isEqualTo: UserVoucherStatus.available.name,
        )
        .snapshots()
        .asyncMap((snapshot) async {
      final result = <UserVoucherModel>[];

      for (final document in snapshot.docs) {
        try {
          final userVoucher =
              UserVoucherModel.fromDoc(document);

          if (!userVoucher.canUse) {
            continue;
          }

          final voucher = await getVoucher(
            userVoucher.voucherId,
          );

          // Giữ canUse để voucher chưa đến ngày
          // không được áp dụng vào đơn.
          if (voucher == null || !voucher.canUse) {
            continue;
          }

          if (voucher.target != VoucherTarget.all &&
              voucher.target != target) {
            continue;
          }

          if (orderAmount > 0 &&
              voucher.calculateDiscount(orderAmount) <= 0) {
            continue;
          }

          result.add(userVoucher);
        } catch (error, stackTrace) {
          developer.log(
            'Không thể kiểm tra userVoucher ${document.id}',
            name: 'VoucherService',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      result.sort((a, b) {
        final aTime = a.expiredAt ?? DateTime(2999);
        final bTime = b.expiredAt ?? DateTime(2999);

        return aTime.compareTo(bTime);
      });

      return result;
    });
  }

  Stream<UserVoucherModel?> watchUserVoucher(
    String userVoucherId,
  ) {
    final normalizedId = userVoucherId.trim();

    if (normalizedId.isEmpty) {
      return Stream.value(null);
    }

    return _userVouchersRef
        .doc(normalizedId)
        .snapshots()
        .map((document) {
      if (!document.exists) {
        return null;
      }

      try {
        return UserVoucherModel.fromDoc(document);
      } catch (error, stackTrace) {
        developer.log(
          'Không thể đọc userVoucher $normalizedId',
          name: 'VoucherService',
          error: error,
          stackTrace: stackTrace,
        );

        return null;
      }
    });
  }

  Future<VoucherModel?> getVoucher(
    String voucherId,
  ) async {
    final normalizedId = voucherId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final document =
        await _vouchersRef.doc(normalizedId).get();

    if (!document.exists) {
      return null;
    }

    try {
      return VoucherModel.fromDoc(document);
    } catch (error, stackTrace) {
      developer.log(
        'Không thể đọc voucher $normalizedId',
        name: 'VoucherService',
        error: error,
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  Future<UserVoucherModel?> getUserVoucher(
    String userVoucherId,
  ) async {
    final normalizedId = userVoucherId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final document =
        await _userVouchersRef.doc(normalizedId).get();

    if (!document.exists) {
      return null;
    }

    try {
      return UserVoucherModel.fromDoc(document);
    } catch (error, stackTrace) {
      developer.log(
        'Không thể đọc userVoucher $normalizedId',
        name: 'VoucherService',
        error: error,
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  /// Đổi voucher bằng điểm.
  ///
  /// Khách được đổi trước ngày áp dụng nhưng chưa được dùng ngay.
  Future<void> redeemVoucherByPoints(
    VoucherModel voucher,
  ) async {
    final user = _requireUser();

    if (!voucher.canClaim) {
      throw Exception(
        'Voucher không còn khả dụng để đổi.',
      );
    }

    if (voucher.requiredPoints <= 0) {
      throw Exception(
        'Voucher này không cần đổi bằng điểm.',
      );
    }

    final userVoucherId = '${user.uid}_${voucher.id}';

    await _firestore.runTransaction((transaction) async {
      final userVoucherDocument =
          _userVouchersRef.doc(userVoucherId);

      final existingUserVoucher =
          await transaction.get(userVoucherDocument);

      if (existingUserVoucher.exists) {
        throw Exception(
          'Bạn đã đổi voucher này rồi.',
        );
      }

      final voucherDocument =
          _vouchersRef.doc(voucher.id);

      final voucherSnapshot =
          await transaction.get(voucherDocument);

      if (!voucherSnapshot.exists) {
        throw Exception(
          'Không tìm thấy voucher.',
        );
      }

      final latestVoucher =
          VoucherModel.fromDoc(voucherSnapshot);

      if (!latestVoucher.canClaim) {
        throw Exception(
          'Voucher không còn khả dụng để đổi.',
        );
      }

      if (latestVoucher.requiredPoints <= 0) {
        throw Exception(
          'Voucher này không cần đổi bằng điểm.',
        );
      }

      await _loyaltyService.spendPointsInTransaction(
        transaction: transaction,
        userId: user.uid,
        points: latestVoucher.requiredPoints,
        title: 'Đổi voucher ${latestVoucher.code}',
        description: latestVoucher.title,
        referenceId: latestVoucher.id,
      );

      final userVoucher = UserVoucherModel(
        id: userVoucherId,
        userId: user.uid,
        voucherId: latestVoucher.id,
        code: latestVoucher.code,
        title: latestVoucher.title,
        redeemedByPoints: true,
        pointsSpent: latestVoucher.requiredPoints,
        expiredAt: latestVoucher.endAt,
      );

      transaction.set(
        userVoucherDocument,
        userVoucher.toMap(),
      );
    });
  }

  /// Nhận voucher miễn phí.
  ///
  /// Voucher miễn phí được nhận trước ngày áp dụng.
  Future<void> claimFreeVoucher(
    VoucherModel voucher,
  ) async {
    final user = _requireUser();

    if (!voucher.canClaim) {
      throw Exception(
        'Voucher không còn khả dụng để nhận.',
      );
    }

    if (voucher.requiredPoints > 0) {
      throw Exception(
        'Voucher này cần ${voucher.requiredPoints} điểm để đổi.',
      );
    }

    final userVoucherId = '${user.uid}_${voucher.id}';

    await _firestore.runTransaction((transaction) async {
      final userVoucherDocument =
          _userVouchersRef.doc(userVoucherId);

      final existing =
          await transaction.get(userVoucherDocument);

      if (existing.exists) {
        throw Exception(
          'Bạn đã nhận voucher này rồi.',
        );
      }

      final voucherDocument =
          _vouchersRef.doc(voucher.id);

      final voucherSnapshot =
          await transaction.get(voucherDocument);

      if (!voucherSnapshot.exists) {
        throw Exception(
          'Không tìm thấy voucher.',
        );
      }

      final latestVoucher =
          VoucherModel.fromDoc(voucherSnapshot);

      if (!latestVoucher.canClaim) {
        throw Exception(
          'Voucher không còn khả dụng để nhận.',
        );
      }

      // Ngăn gọi nhầm luồng miễn phí cho voucher cần điểm.
      if (latestVoucher.requiredPoints > 0) {
        throw Exception(
          'Voucher này cần '
          '${latestVoucher.requiredPoints} điểm để đổi.',
        );
      }

      final userVoucher = UserVoucherModel(
        id: userVoucherId,
        userId: user.uid,
        voucherId: latestVoucher.id,
        code: latestVoucher.code,
        title: latestVoucher.title,
        redeemedByPoints: false,
        pointsSpent: 0,
        expiredAt: latestVoucher.endAt,
      );

      transaction.set(
        userVoucherDocument,
        userVoucher.toMap(),
      );
    });
  }

  /// Tính số tiền giảm của voucher khách sở hữu.
  ///
  /// Giữ canUse để voucher chưa đến ngày trả về 0.
  Future<double> calculateUserVoucherDiscount({
    required String userVoucherId,
    required double orderAmount,
    VoucherTarget target = VoucherTarget.booking,
  }) async {
    final user = _requireUser();

    final userVoucher = await getUserVoucher(
      userVoucherId,
    );

    if (userVoucher == null ||
        userVoucher.userId != user.uid ||
        !userVoucher.canUse) {
      return 0;
    }

    final voucher = await getVoucher(
      userVoucher.voucherId,
    );

    if (voucher == null || !voucher.canUse) {
      return 0;
    }

    if (voucher.target != VoucherTarget.all &&
        voucher.target != target) {
      return 0;
    }

    return voucher
        .calculateDiscount(orderAmount)
        .clamp(0, orderAmount)
        .toDouble();
  }

  /// Giữ voucher cho đơn đặt phòng.
  ///
  /// Kiểm tra voucher gốc đã tới thời gian áp dụng.
  Future<void> reserveVoucherForBooking({
    required String userVoucherId,
    required String bookingId,
  }) async {
    final user = _requireUser();

    final normalizedUserVoucherId =
        userVoucherId.trim();
    final normalizedBookingId = bookingId.trim();

    if (normalizedUserVoucherId.isEmpty) {
      throw Exception(
        'Mã voucher của khách hàng không hợp lệ.',
      );
    }

    if (normalizedBookingId.isEmpty) {
      throw Exception(
        'Mã đơn đặt phòng không hợp lệ.',
      );
    }

    await _firestore.runTransaction((transaction) async {
      final userVoucherDocument =
          _userVouchersRef.doc(normalizedUserVoucherId);

      final userVoucherSnapshot =
          await transaction.get(userVoucherDocument);

      if (!userVoucherSnapshot.exists) {
        throw Exception(
          'Không tìm thấy voucher của bạn.',
        );
      }

      final userVoucher =
          UserVoucherModel.fromDoc(userVoucherSnapshot);

      if (userVoucher.userId != user.uid) {
        throw Exception(
          'Bạn không có quyền dùng voucher này.',
        );
      }

      if (!userVoucher.canUse) {
        throw Exception(
          'Voucher không còn khả dụng.',
        );
      }

      final voucherDocument =
          _vouchersRef.doc(userVoucher.voucherId);

      final voucherSnapshot =
          await transaction.get(voucherDocument);

      if (!voucherSnapshot.exists) {
        throw Exception(
          'Voucher gốc không còn tồn tại.',
        );
      }

      final voucher =
          VoucherModel.fromDoc(voucherSnapshot);

      if (voucher.isNotStarted) {
        throw Exception(
          'Voucher chưa đến thời gian áp dụng.',
        );
      }

      if (!voucher.canUse) {
        throw Exception(
          'Voucher không còn khả dụng.',
        );
      }

      transaction.update(userVoucherDocument, {
        'status': UserVoucherStatus.reserved.name,
        'bookingId': normalizedBookingId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> releaseReservedVoucher({
    required String userVoucherId,
    required String bookingId,
  }) async {
    final user = _requireUser();

    final normalizedUserVoucherId =
        userVoucherId.trim();
    final normalizedBookingId = bookingId.trim();

    if (normalizedUserVoucherId.isEmpty) {
      return;
    }

    await _firestore.runTransaction((transaction) async {
      final userVoucherDocument =
          _userVouchersRef.doc(normalizedUserVoucherId);

      final snapshot =
          await transaction.get(userVoucherDocument);

      if (!snapshot.exists) {
        return;
      }

      final userVoucher =
          UserVoucherModel.fromDoc(snapshot);

      if (userVoucher.userId != user.uid) {
        throw Exception(
          'Bạn không có quyền thao tác voucher này.',
        );
      }

      if (userVoucher.status !=
              UserVoucherStatus.reserved ||
          userVoucher.bookingId != normalizedBookingId) {
        return;
      }

      transaction.update(userVoucherDocument, {
        'status': UserVoucherStatus.available.name,
        'bookingId': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markVoucherUsed({
    required String userVoucherId,
    required String bookingId,
  }) async {
    final user = _requireUser();

    final normalizedUserVoucherId =
        userVoucherId.trim();
    final normalizedBookingId = bookingId.trim();

    if (normalizedUserVoucherId.isEmpty ||
        normalizedBookingId.isEmpty) {
      throw Exception(
        'Thông tin sử dụng voucher không hợp lệ.',
      );
    }

    await _firestore.runTransaction((transaction) async {
      final userVoucherDocument =
          _userVouchersRef.doc(normalizedUserVoucherId);

      final snapshot =
          await transaction.get(userVoucherDocument);

      if (!snapshot.exists) {
        throw Exception(
          'Không tìm thấy voucher của bạn.',
        );
      }

      final userVoucher =
          UserVoucherModel.fromDoc(snapshot);

      if (userVoucher.userId != user.uid) {
        throw Exception(
          'Bạn không có quyền dùng voucher này.',
        );
      }

      final canMarkUsed = userVoucher.canUse ||
          (userVoucher.status ==
                  UserVoucherStatus.reserved &&
              userVoucher.bookingId ==
                  normalizedBookingId);

      if (!canMarkUsed) {
        throw Exception(
          'Voucher không còn khả dụng.',
        );
      }

      transaction.update(userVoucherDocument, {
        'status': UserVoucherStatus.used.name,
        'bookingId': normalizedBookingId,
        'usedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(
        _vouchersRef.doc(userVoucher.voucherId),
        {
          'usedCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Bạn cần đăng nhập.',
      );
    }

    return user;
  }
}

bool _promotionsEnabled(
  Map<String, dynamic> userData,
) {
  final settings = userData['notificationSettings'];

  if (settings is Map) {
    return settings['promotions'] != false;
  }

  // Khách chưa cấu hình thì mặc định bật.
  return true;
}

int _safeInt(dynamic value) {
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
