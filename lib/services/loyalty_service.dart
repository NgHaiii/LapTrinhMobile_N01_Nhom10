import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/loyalty_point.dart';
import '../model/point_transaction.dart';

class LoyaltyService {
  LoyaltyService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _pointsRef {
    return _firestore.collection('loyaltyPoints');
  }

  CollectionReference<Map<String, dynamic>> get _transactionsRef {
    return _firestore.collection('pointTransactions');
  }

  Stream<LoyaltyPointModel> watchMyPoints() {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Stream.value(LoyaltyPointModel.empty(''));
    }

    return _pointsRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        return LoyaltyPointModel.empty(userId);
      }

      return LoyaltyPointModel.fromDoc(doc);
    }).handleError((error, stackTrace) {
      developer.log(
        'watchMyPoints failed',
        name: 'LoyaltyService',
        error: error,
        stackTrace: stackTrace,
      );
      throw error;
    });
  }

  Stream<List<PointTransactionModel>> watchMyTransactions({
    int limit = 50,
  }) {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Stream.value(const []);
    }

    return _transactionsRef
        .where('userId', isEqualTo: userId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final transactions =
          snapshot.docs.map(PointTransactionModel.fromDoc).toList();

      transactions.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return transactions;
    });
  }

  Future<LoyaltyPointModel> getMyPoints() async {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      throw Exception('Bạn cần đăng nhập.');
    }

    final doc = await _pointsRef.doc(userId).get();

    if (!doc.exists) {
      return LoyaltyPointModel.empty(userId);
    }

    return LoyaltyPointModel.fromDoc(doc);
  }

  Future<void> earnPointsFromBooking({
    required String bookingId,
    required double paidAmount,
    int pointPerAmount = 10000,
  }) async {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      throw Exception('Bạn cần đăng nhập để tích điểm.');
    }

    final points = (paidAmount / pointPerAmount).floor();

    if (points <= 0) return;

    await addPoints(
      userId: userId,
      points: points,
      title: 'Tích điểm đặt phòng',
      description: 'Tích $points điểm từ đơn đặt phòng.',
      source: PointTransactionSource.booking,
      referenceId: bookingId,
    );
  }

  Future<void> addPoints({
    required String userId,
    required int points,
    required String title,
    required String description,
    PointTransactionSource source = PointTransactionSource.system,
    String referenceId = '',
  }) async {
    if (points <= 0) return;

    await _firestore.runTransaction((transaction) async {
      final pointsDoc = _pointsRef.doc(userId);
      final snapshot = await transaction.get(pointsDoc);

      final current = snapshot.exists
          ? LoyaltyPointModel.fromDoc(snapshot)
          : LoyaltyPointModel.empty(userId);

      final newTotal = current.totalPoints + points;
      final newAvailable = current.availablePoints + points;
      final newTier = LoyaltyTier.fromPoints(newTotal);

      transaction.set(
        pointsDoc,
        current
            .copyWith(
              totalPoints: newTotal,
              availablePoints: newAvailable,
              tier: newTier,
            )
            .toMap(),
        SetOptions(merge: true),
      );

      final transactionDoc = _transactionsRef.doc();

      transaction.set(
        transactionDoc,
        PointTransactionModel(
          id: transactionDoc.id,
          userId: userId,
          points: points,
          type: PointTransactionType.earn,
          source: source,
          title: title,
          description: description,
          referenceId: referenceId,
        ).toMap(),
      );
    });
  }

  Future<void> spendPoints({
    required String userId,
    required int points,
    required String title,
    required String description,
    PointTransactionSource source = PointTransactionSource.voucher,
    String referenceId = '',
  }) async {
    await _firestore.runTransaction((transaction) async {
      await spendPointsInTransaction(
        transaction: transaction,
        userId: userId,
        points: points,
        title: title,
        description: description,
        source: source,
        referenceId: referenceId,
      );
    });
  }

  Future<void> spendPointsInTransaction({
    required Transaction transaction,
    required String userId,
    required int points,
    required String title,
    required String description,
    PointTransactionSource source = PointTransactionSource.voucher,
    String referenceId = '',
  }) async {
    if (points <= 0) return;

    final pointsDoc = _pointsRef.doc(userId);
    final snapshot = await transaction.get(pointsDoc);

    final current = snapshot.exists
        ? LoyaltyPointModel.fromDoc(snapshot)
        : LoyaltyPointModel.empty(userId);

    if (current.availablePoints < points) {
      throw Exception('Bạn không đủ điểm để thực hiện thao tác này.');
    }

    final newAvailable = current.availablePoints - points;
    final newUsed = current.usedPoints + points;

    transaction.set(
      pointsDoc,
      current
          .copyWith(
            availablePoints: newAvailable,
            usedPoints: newUsed,
          )
          .toMap(),
      SetOptions(merge: true),
    );

    final transactionDoc = _transactionsRef.doc();

    transaction.set(
      transactionDoc,
      PointTransactionModel(
        id: transactionDoc.id,
        userId: userId,
        points: -points,
        type: PointTransactionType.redeem,
        source: source,
        title: title,
        description: description,
        referenceId: referenceId,
      ).toMap(),
    );
  }

  Future<void> adjustPointsByAdmin({
    required String userId,
    required int points,
    required String reason,
  }) async {
    if (points == 0) return;

    await _firestore.runTransaction((transaction) async {
      final pointsDoc = _pointsRef.doc(userId);
      final snapshot = await transaction.get(pointsDoc);

      final current = snapshot.exists
          ? LoyaltyPointModel.fromDoc(snapshot)
          : LoyaltyPointModel.empty(userId);

      final newTotal = (current.totalPoints + points).clamp(0, 1 << 31);
      final newAvailable =
          (current.availablePoints + points).clamp(0, 1 << 31);
      final newTier = LoyaltyTier.fromPoints(newTotal);

      transaction.set(
        pointsDoc,
        current
            .copyWith(
              totalPoints: newTotal,
              availablePoints: newAvailable,
              tier: newTier,
            )
            .toMap(),
        SetOptions(merge: true),
      );

      final transactionDoc = _transactionsRef.doc();

      transaction.set(
        transactionDoc,
        PointTransactionModel(
          id: transactionDoc.id,
          userId: userId,
          points: points,
          type: PointTransactionType.adjust,
          source: PointTransactionSource.admin,
          title: 'Điều chỉnh điểm',
          description: reason,
        ).toMap(),
      );
    });
  }
}