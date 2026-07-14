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

  Stream<List<VoucherModel>> watchActiveVouchers({
    VoucherTarget? target,
    bool includePointVouchers = true,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query =
        _vouchersRef.where('isActive', isEqualTo: true);

    if (target != null && target != VoucherTarget.all) {
      query = query.where('target', whereIn: [target.name, VoucherTarget.all.name]);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      final now = DateTime.now();

      final vouchers = snapshot.docs.map(VoucherModel.fromDoc).where((voucher) {
        if (!includePointVouchers && voucher.requiredPoints > 0) {
          return false;
        }

        if (voucher.startAt != null && now.isBefore(voucher.startAt!)) {
          return false;
        }

        if (voucher.endAt != null && now.isAfter(voucher.endAt!)) {
          return false;
        }

        return voucher.canUse;
      }).toList();

      vouchers.sort((a, b) {
        final pointCompare = a.requiredPoints.compareTo(b.requiredPoints);
        if (pointCompare != 0) return pointCompare;

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

    Query<Map<String, dynamic>> query =
        _userVouchersRef.where('userId', isEqualTo: userId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) {
      final vouchers = snapshot.docs.map(UserVoucherModel.fromDoc).toList();

      vouchers.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return vouchers;
    });
  }

  Stream<UserVoucherModel?> watchUserVoucher(String userVoucherId) {
    if (userVoucherId.trim().isEmpty) {
      return Stream.value(null);
    }

    return _userVouchersRef.doc(userVoucherId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserVoucherModel.fromDoc(doc);
    });
  }

  Future<VoucherModel?> getVoucher(String voucherId) async {
    if (voucherId.trim().isEmpty) return null;

    final doc = await _vouchersRef.doc(voucherId).get();
    if (!doc.exists) return null;

    return VoucherModel.fromDoc(doc);
  }

  Future<UserVoucherModel?> getUserVoucher(String userVoucherId) async {
    if (userVoucherId.trim().isEmpty) return null;

    final doc = await _userVouchersRef.doc(userVoucherId).get();
    if (!doc.exists) return null;

    return UserVoucherModel.fromDoc(doc);
  }

  Future<void> redeemVoucherByPoints(VoucherModel voucher) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Bạn cần đăng nhập để đổi voucher.');
    }

    if (!voucher.canUse) {
      throw Exception('Voucher không còn khả dụng.');
    }

    if (voucher.requiredPoints <= 0) {
      throw Exception('Voucher này không cần đổi bằng điểm.');
    }

    final userVoucherId = '${user.uid}_${voucher.id}';

    await _firestore.runTransaction((transaction) async {
      final userVoucherDoc = _userVouchersRef.doc(userVoucherId);
      final existingUserVoucher = await transaction.get(userVoucherDoc);

      if (existingUserVoucher.exists) {
        throw Exception('Bạn đã đổi voucher này rồi.');
      }

      final voucherDoc = _vouchersRef.doc(voucher.id);
      final voucherSnapshot = await transaction.get(voucherDoc);

      if (!voucherSnapshot.exists) {
        throw Exception('Không tìm thấy voucher.');
      }

      final latestVoucher = VoucherModel.fromDoc(voucherSnapshot);

      if (!latestVoucher.canUse) {
        throw Exception('Voucher không còn khả dụng.');
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

      transaction.set(userVoucherDoc, userVoucher.toMap());
    });
  }

  Future<void> claimFreeVoucher(VoucherModel voucher) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Bạn cần đăng nhập để nhận voucher.');
    }

    if (!voucher.canUse) {
      throw Exception('Voucher không còn khả dụng.');
    }

    if (voucher.requiredPoints > 0) {
      throw Exception('Voucher này cần đổi bằng điểm.');
    }

    final userVoucherId = '${user.uid}_${voucher.id}';

    final userVoucherDoc = _userVouchersRef.doc(userVoucherId);
    final existing = await userVoucherDoc.get();

    if (existing.exists) {
      throw Exception('Bạn đã nhận voucher này rồi.');
    }

    final userVoucher = UserVoucherModel(
      id: userVoucherId,
      userId: user.uid,
      voucherId: voucher.id,
      code: voucher.code,
      title: voucher.title,
      expiredAt: voucher.endAt,
    );

    await userVoucherDoc.set(userVoucher.toMap());
  }

  Future<void> markVoucherUsed({
    required String userVoucherId,
    required String bookingId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Bạn cần đăng nhập.');
    }

    final doc = await _userVouchersRef.doc(userVoucherId).get();

    if (!doc.exists) {
      throw Exception('Không tìm thấy voucher của bạn.');
    }

    final userVoucher = UserVoucherModel.fromDoc(doc);

    if (userVoucher.userId != user.uid) {
      throw Exception('Bạn không có quyền dùng voucher này.');
    }

    if (!userVoucher.canUse) {
      throw Exception('Voucher không còn khả dụng.');
    }

    await _userVouchersRef.doc(userVoucherId).update({
      'status': UserVoucherStatus.used.name,
      'bookingId': bookingId,
      'usedAt': FieldValue.serverTimestamp(),
    });

    await _vouchersRef.doc(userVoucher.voucherId).update({
      'usedCount': FieldValue.increment(1),
    });
  }

  Future<double> calculateUserVoucherDiscount({
    required String userVoucherId,
    required double orderAmount,
    VoucherTarget target = VoucherTarget.booking,
  }) async {
    final userVoucher = await getUserVoucher(userVoucherId);

    if (userVoucher == null || !userVoucher.canUse) {
      return 0;
    }

    final voucher = await getVoucher(userVoucher.voucherId);

    if (voucher == null || !voucher.canUse) {
      return 0;
    }

    if (voucher.target != VoucherTarget.all && voucher.target != target) {
      return 0;
    }

    return voucher.calculateDiscount(orderAmount);
  }
}