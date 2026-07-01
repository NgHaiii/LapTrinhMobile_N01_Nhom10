import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/booking.dart';
import '../model/provider_payment_profile.dart';
import '../model/vietqr_bank.dart';
import 'vietqr_service.dart';

class ProviderPaymentService {
  ProviderPaymentService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    VietQrService? vietQrService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _vietQrService = vietQrService ?? VietQrService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final VietQrService _vietQrService;

  String get currentUserId {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    return uid;
  }

  Stream<ProviderPaymentProfile?> watchMyProfile() {
    final uid = currentUserId;

    return _firestore
        .collection('providerPaymentProfiles')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();

          if (data == null) return null;

          return ProviderPaymentProfile.fromMap(
            data,
            snapshot.id,
          );
        });
  }

  Future<List<VietQrBank>> getBanks({
    bool forceRefresh = false,
  }) {
    return _vietQrService.getBanks(
      forceRefresh: forceRefresh,
    );
  }

  Future<void> submitPaymentProfile({
    required VietQrBank bank,
    required String accountNumber,
    required String accountName,
  }) async {
    final user = await _requireProvider();

    final normalizedAccount = accountNumber
        .replaceAll(RegExp(r'\s+'), '');

    final normalizedName = accountName
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toUpperCase();

    if (!bank.isValid) {
      throw StateError('Ngân hàng đã chọn không hợp lệ.');
    }

    if (!RegExp(r'^[0-9]{6,19}$').hasMatch(normalizedAccount)) {
      throw StateError(
        'Số tài khoản phải gồm từ 6 đến 19 chữ số.',
      );
    }

    if (normalizedName.length < 2) {
      throw StateError('Tên chủ tài khoản không hợp lệ.');
    }

    final providerSnapshot = await _firestore
        .collection('providers')
        .doc(user.uid)
        .get();

    final providerData = providerSnapshot.data();

    if (providerData == null) {
      throw StateError('Không tìm thấy hồ sơ nhà cung cấp.');
    }

    final businessName =
        providerData['businessName']?.toString().trim() ?? '';

    await _firestore
        .collection('providerPaymentProfiles')
        .doc(user.uid)
        .set({
          'providerId': user.uid,
          'businessName': businessName,
          'bankBin': bank.bin,
          'bankCode': bank.code,
          'bankName': bank.name,
          'accountNumber': normalizedAccount,
          'accountName': normalizedName,
          'isVerified': false,
          'verificationStatus': PaymentProfileStatus.pending,
          'rejectionReason': '',
          'verifiedBy': '',
          'verifiedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  String createBookingQrUrl(BookingModel booking) {
    if (!booking.hasReceiverAccount) {
      throw StateError(
        'Đơn chưa có thông tin tài khoản nhận tiền.',
      );
    }

    if (booking.totalAmount <= 0) {
      throw StateError('Tổng tiền booking không hợp lệ.');
    }

    return VietQrService.createQrUrl(
      bankBin: booking.receiverBankBin,
      accountNumber: booking.receiverAccountNumber,
      accountName: booking.receiverAccountName,
      totalAmount: booking.totalAmount,
      paymentReference: booking.paymentReference,
    );
  }

  Future<ProviderPaymentProfile> getVerifiedProfile(
    String providerId,
  ) async {
    final snapshot = await _firestore
        .collection('providerPaymentProfiles')
        .doc(providerId)
        .get();

    final data = snapshot.data();

    if (data == null) {
      throw StateError(
        'Nhà cung cấp chưa cập nhật tài khoản nhận tiền.',
      );
    }

    final profile = ProviderPaymentProfile.fromMap(
      data,
      snapshot.id,
    );

    if (!profile.canReceivePayments) {
      throw StateError(
        'Tài khoản ngân hàng chưa được admin xác minh.',
      );
    }

    return profile;
  }

  Future<User> _requireProvider() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final data = snapshot.data();

    if (data?['role'] != 'provider' ||
        data?['providerStatus'] != 'approved') {
      throw StateError(
        'Tài khoản chưa được cấp quyền nhà cung cấp.',
      );
    }

    return user;
  }

  void dispose() {
    _vietQrService.dispose();
  }
}