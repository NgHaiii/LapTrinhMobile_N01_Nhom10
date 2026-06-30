import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/provider_application.dart';

class AdminStats {
  const AdminStats({
    required this.users,
    required this.providers,
    required this.pendingApplications,
    required this.bookings,
  });

  final int users;
  final int providers;
  final int pendingApplications;
  final int bookings;
}

class AdminService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchApplications(String status) {
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

  Future<AdminStats> loadStats() async {
    final results = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('users').where('role', isEqualTo: 'provider').get(),
      _firestore
          .collection('providerApplications')
          .where('status', isEqualTo: 'pending')
          .get(),
      _firestore.collection('bookings').get(),
    ]);

    return AdminStats(
      users: results[0].docs.length,
      providers: results[1].docs.length,
      pendingApplications: results[2].docs.length,
      bookings: results[3].docs.length,
    );
  }

  Future<void> approveApplication(ProviderApplication application) async {
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

    batch.set(providerReference, {
      'userId': application.userId,
      'businessName': application.businessName,
      'representativeName': application.representativeName,
      'phoneNumber': application.phoneNumber,
      'address': application.address,
      'identityNumber': application.identityNumber,
      'status': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': admin.uid,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> rejectApplication(
    ProviderApplication application,
    String reason,
  ) async {
    final admin = await _requireAdmin();
    final batch = _firestore.batch();

    batch.update(
      _firestore.collection('providerApplications').doc(application.userId),
      {
        'status': 'rejected',
        'rejectionReason': reason.trim(),
        'reviewedBy': admin.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.update(_firestore.collection('users').doc(application.userId), {
      'role': 'customer',
      'providerStatus': 'rejected',
    });

    await batch.commit();
  }

  Future<void> setUserActive(String userId, bool active) async {
    await _requireAdmin();

    if (userId == _auth.currentUser?.uid) {
      throw StateError('Admin không thể tự khóa tài khoản của mình.');
    }

    await _firestore.collection('users').doc(userId).update({
      'isActive': active,
    });
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _requireAdmin();

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

    final snapshot = await _firestore.collection('users').doc(user.uid).get();

    if (snapshot.data()?['role'] != 'admin') {
      throw StateError('Bạn không có quyền quản trị.');
    }

    return user;
  }
}
