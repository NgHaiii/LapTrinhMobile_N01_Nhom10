import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/booking.dart';
import '../model/provider_application.dart';

class AdminStats {
  const AdminStats({
    required this.users,
    required this.providers,
    required this.pendingApplications,
    required this.bookings,
    this.pendingPaymentProfiles = 0,
    this.unpaidCommissionInvoices = 0,
  });

  final int users;
  final int providers;
  final int pendingApplications;
  final int bookings;
  final int pendingPaymentProfiles;
  final int unpaidCommissionInvoices;
}

class AdminService {
  AdminService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchApplications(
    String status,
  ) {
    final collection = _firestore.collection('providerApplications');

    if (status == 'all') return collection.snapshots();

    return collection.where('status', isEqualTo: status).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsers() {
    return _firestore.collection('users').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBookings() {
    return _firestore.collection('bookings').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPaymentProfiles({
    String status = 'all',
  }) {
    final collection = _firestore.collection('providerPaymentProfiles');

    if (status == 'all') return collection.snapshots();

    return collection
        .where('verificationStatus', isEqualTo: status)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCommissionInvoices({
    String status = 'all',
  }) {
    final collection = _firestore.collection('commissionInvoices');

    if (status == 'all') return collection.snapshots();

    return collection.where('status', isEqualTo: status).snapshots();
  }

  Future<AdminStats> loadStats() async {
    await _requireAdmin();

    final results = await Future.wait([
      _firestore.collection('users').get(),
      _firestore
          .collection('users')
          .where('role', isEqualTo: 'provider')
          .get(),
      _firestore
          .collection('providerApplications')
          .where('status', isEqualTo: 'pending')
          .get(),
      _firestore.collection('bookings').get(),
      _firestore
          .collection('providerPaymentProfiles')
          .where('verificationStatus', isEqualTo: 'pending')
          .get(),
      _firestore
          .collection('commissionInvoices')
          .where('status', isEqualTo: 'unpaid')
          .get(),
    ]);

    return AdminStats(
      users: results[0].docs.length,
      providers: results[1].docs.length,
      pendingApplications: results[2].docs.length,
      bookings: results[3].docs.length,
      pendingPaymentProfiles: results[4].docs.length,
      unpaidCommissionInvoices: results[5].docs.length,
    );
  }

  Future<void> approveApplication(
    ProviderApplication application,
  ) async {
    final admin = await _requireAdmin();
    final batch = _firestore.batch();

    final applicationReference = _firestore
        .collection('providerApplications')
        .doc(application.userId);

    final userReference = _firestore
        .collection('users')
        .doc(application.userId);

    final providerReference = _firestore
        .collection('providers')
        .doc(application.userId);

    final paymentProfileReference = _firestore
        .collection('providerPaymentProfiles')
        .doc(application.userId);

    batch.update(applicationReference, {
      'status': 'approved',
      'rejectionReason': '',
      'reviewedBy': admin.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    batch.update(userReference, {
      'role': 'provider',
      'providerStatus': 'approved',
    });

    batch.set(
      providerReference,
      {
        'userId': application.userId,
        'businessName': application.businessName,
        'representativeName': application.representativeName,
        'phoneNumber': application.phoneNumber,
        'address': application.address,
        'identityNumber': application.identityNumber,
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': admin.uid,
      },
      SetOptions(merge: true),
    );

    batch.set(
      paymentProfileReference,
      {
        'providerId': application.userId,
        'businessName': application.businessName,
        'bankBin': '',
        'bankCode': '',
        'bankName': '',
        'accountNumber': '',
        'accountName': '',
        'isVerified': false,
        'verificationStatus': 'not_submitted',
        'rejectionReason': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> rejectApplication(
    ProviderApplication application,
    String reason,
  ) async {
    final admin = await _requireAdmin();
    final normalizedReason = reason.trim();

    if (normalizedReason.length < 5) {
      throw StateError('Vui lòng nhập lý do từ chối rõ ràng.');
    }

    final batch = _firestore.batch();

    batch.update(
      _firestore
          .collection('providerApplications')
          .doc(application.userId),
      {
        'status': 'rejected',
        'rejectionReason': normalizedReason,
        'reviewedBy': admin.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      _firestore.collection('users').doc(application.userId),
      {
        'role': 'customer',
        'providerStatus': 'rejected',
      },
    );

    await batch.commit();
  }

  Future<void> approvePaymentProfile(String providerId) async {
    final admin = await _requireAdmin();
    final reference = _firestore
        .collection('providerPaymentProfiles')
        .doc(providerId);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (data == null) {
      throw StateError('Không tìm thấy thông tin ngân hàng.');
    }

    if ((data['bankBin']?.toString() ?? '').isEmpty ||
        (data['accountNumber']?.toString() ?? '').isEmpty ||
        (data['accountName']?.toString() ?? '').isEmpty) {
      throw StateError('Thông tin tài khoản ngân hàng chưa đầy đủ.');
    }

    await reference.update({
      'isVerified': true,
      'verificationStatus': 'approved',
      'rejectionReason': '',
      'verifiedBy': admin.uid,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectPaymentProfile(
    String providerId,
    String reason,
  ) async {
    final admin = await _requireAdmin();
    final normalizedReason = reason.trim();

    if (normalizedReason.length < 5) {
      throw StateError('Vui lòng nhập lý do từ chối.');
    }

    await _firestore
        .collection('providerPaymentProfiles')
        .doc(providerId)
        .update({
          'isVerified': false,
          'verificationStatus': 'rejected',
          'rejectionReason': normalizedReason,
          'verifiedBy': admin.uid,
          'verifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> confirmCommissionPayment(String invoiceId) async {
    final admin = await _requireAdmin();
    final reference = _firestore
        .collection('commissionInvoices')
        .doc(invoiceId);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (data == null) {
      throw StateError('Không tìm thấy hóa đơn hoa hồng.');
    }

    if (data['status'] != 'payment_review') {
      throw StateError('Nhà cung cấp chưa báo đã thanh toán hóa đơn.');
    }

    await reference.update({
      'status': 'paid',
      'confirmedBy': admin.uid,
      'confirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectCommissionPayment(
    String invoiceId,
    String reason,
  ) async {
    await _requireAdmin();

    await _firestore
        .collection('commissionInvoices')
        .doc(invoiceId)
        .update({
          'status': 'unpaid',
          'rejectionReason': reason.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> setUserActive(
    String userId,
    bool active,
  ) async {
    await _requireAdmin();

    if (userId == _auth.currentUser?.uid) {
      throw StateError('Admin không thể tự khóa tài khoản của mình.');
    }

    await _firestore.collection('users').doc(userId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBookingStatus(
    String bookingId,
    String status,
  ) async {
    await _requireAdmin();

    if (!BookingStatus.values.contains(status)) {
      throw StateError('Trạng thái booking không hợp lệ.');
    }

    await _firestore.collection('bookings').doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<User> _requireAdmin() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (snapshot.data()?['role'] != 'admin') {
      throw StateError('Bạn không có quyền quản trị.');
    }

    return user;
  }
}