import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/booking.dart';
import '../model/commission_invoice.dart';
import 'vietqr_service.dart';

class CommissionService {
  CommissionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const double defaultCommissionRate = 0.10;

  Stream<List<CommissionInvoice>> watchMyInvoices() {
    final uid = _requireUser().uid;

    return _firestore
        .collection('commissionInvoices')
        .where('providerId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final invoices = snapshot.docs
              .map(
                (document) => CommissionInvoice.fromMap(
                  document.data(),
                  document.id,
                ),
              )
              .toList();

          invoices.sort((first, second) {
            final firstPeriod = first.year * 100 + first.month;
            final secondPeriod = second.year * 100 + second.month;

            return secondPeriod.compareTo(firstPeriod);
          });

          return invoices;
        });
  }

  Stream<List<CommissionInvoice>> watchAllInvoices({
    String status = 'all',
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      'commissionInvoices',
    );

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      final invoices = snapshot.docs
          .map(
            (document) => CommissionInvoice.fromMap(
              document.data(),
              document.id,
            ),
          )
          .toList();

      invoices.sort((first, second) {
        final firstPeriod = first.year * 100 + first.month;
        final secondPeriod = second.year * 100 + second.month;

        return secondPeriod.compareTo(firstPeriod);
      });

      return invoices;
    });
  }

  Future<CommissionInvoice> createMonthlyInvoice({
    required String providerId,
    required int month,
    required int year,
  }) async {
    await _requireAdmin();

    if (providerId.trim().isEmpty) {
      throw StateError('Mã nhà cung cấp không hợp lệ.');
    }

    if (month < 1 || month > 12 || year < 2020) {
      throw StateError('Tháng lập hóa đơn không hợp lệ.');
    }

    final invoiceId =
        '${providerId}_${year}_${month.toString().padLeft(2, '0')}';

    final invoiceReference = _firestore
        .collection('commissionInvoices')
        .doc(invoiceId);

    final existingInvoice = await invoiceReference.get();

    if (existingInvoice.exists) {
      throw StateError(
        'Hóa đơn hoa hồng của tháng này đã tồn tại.',
      );
    }

    final providerSnapshot = await _firestore
        .collection('providers')
        .doc(providerId)
        .get();

    final providerData = providerSnapshot.data();

    if (providerData == null) {
      throw StateError('Không tìm thấy nhà cung cấp.');
    }

    final periodStart = DateTime(year, month);
    final periodEnd = DateTime(year, month + 1);

    final bookingsSnapshot = await _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .get();

    final eligibleBookings = <BookingModel>[];

    for (final document in bookingsSnapshot.docs) {
      final booking = BookingModel.fromMap(
        document.data(),
        document.id,
      );

      final paidAt = booking.paymentConfirmedAt;

      if (booking.paymentStatus != PaymentStatus.paid ||
          paidAt == null) {
        continue;
      }

      if (!paidAt.isBefore(periodStart) &&
          paidAt.isBefore(periodEnd)) {
        eligibleBookings.add(booking);
      }
    }

    if (eligibleBookings.isEmpty) {
      throw StateError(
        'Không có booking đã thanh toán trong tháng này.',
      );
    }

    final grossRevenue = eligibleBookings.fold<double>(
      0,
      (total, booking) => total + booking.totalAmount,
    );

    final commissionAmount = eligibleBookings.fold<double>(
      0,
      (total, booking) =>
          total + booking.effectiveCommissionAmount,
    );

    final paymentReference = _paymentReference(
      providerId: providerId,
      month: month,
      year: year,
    );

    final invoice = CommissionInvoice(
      id: invoiceId,
      providerId: providerId,
      providerName:
          providerData['businessName']?.toString() ??
          'Nhà cung cấp',
      month: month,
      year: year,
      grossRevenue: grossRevenue,
      commissionRate: defaultCommissionRate,
      commissionAmount: commissionAmount,
      bookingIds: eligibleBookings
          .map((booking) => booking.id)
          .toList(),
      status: CommissionStatus.unpaid,
      paymentReference: paymentReference,
      dueDate: DateTime(year, month + 1, 5, 23, 59),
    );

    await invoiceReference.set({
      ...invoice.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return invoice;
  }

  Future<String> createCommissionQrUrl(
    CommissionInvoice invoice,
  ) async {
    final user = _requireUser();

    if (user.uid != invoice.providerId) {
      final isAdmin = await _isAdmin(user.uid);

      if (!isAdmin) {
        throw StateError('Bạn không có quyền xem QR hóa đơn này.');
      }
    }

    if (invoice.effectiveCommissionAmount <= 0) {
      throw StateError('Số tiền hoa hồng không hợp lệ.');
    }

    final settingsSnapshot = await _firestore
        .collection('appSettings')
        .doc('payment')
        .get();

    final settings = settingsSnapshot.data();

    if (settings == null || settings['isActive'] != true) {
      throw StateError(
        'Admin chưa cấu hình tài khoản nhận hoa hồng.',
      );
    }

    final bankBin = settings['bankBin']?.toString() ?? '';
    final accountNumber =
        settings['accountNumber']?.toString() ?? '';
    final accountName =
        settings['accountName']?.toString() ?? '';

    return VietQrService.createQrUrl(
      bankBin: bankBin,
      accountNumber: accountNumber,
      accountName: accountName,
      totalAmount: invoice.effectiveCommissionAmount,
      paymentReference: invoice.paymentReference,
    );
  }

  Future<void> submitCommissionPayment(String invoiceId) async {
    final user = _requireUser();

    final reference = _firestore
        .collection('commissionInvoices')
        .doc(invoiceId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();

      if (data == null) {
        throw StateError('Không tìm thấy hóa đơn hoa hồng.');
      }

      final invoice = CommissionInvoice.fromMap(
        data,
        snapshot.id,
      );

      if (invoice.providerId != user.uid) {
        throw StateError(
          'Bạn không có quyền thanh toán hóa đơn này.',
        );
      }

      if (!invoice.canSubmitPayment) {
        throw StateError(
          'Hóa đơn không ở trạng thái cho phép thanh toán.',
        );
      }

      transaction.update(reference, {
        'status': CommissionStatus.paymentReview,
        'paymentSubmittedAt': FieldValue.serverTimestamp(),
        'rejectionReason': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> confirmCommissionPayment(
    String invoiceId,
  ) async {
    final admin = await _requireAdmin();
    final reference = _firestore
        .collection('commissionInvoices')
        .doc(invoiceId);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (data == null) {
      throw StateError('Không tìm thấy hóa đơn.');
    }

    final invoice = CommissionInvoice.fromMap(data, snapshot.id);

    if (invoice.status != CommissionStatus.paymentReview) {
      throw StateError(
        'Nhà cung cấp chưa gửi xác nhận thanh toán.',
      );
    }

    await reference.update({
      'status': CommissionStatus.paid,
      'confirmedBy': admin.uid,
      'confirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectCommissionPayment({
    required String invoiceId,
    required String reason,
  }) async {
    await _requireAdmin();

    final normalizedReason = reason.trim();

    if (normalizedReason.length < 5) {
      throw StateError('Vui lòng nhập lý do từ chối rõ ràng.');
    }

    await _firestore
        .collection('commissionInvoices')
        .doc(invoiceId)
        .update({
          'status': CommissionStatus.rejected,
          'rejectionReason': normalizedReason,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  String _paymentReference({
    required String providerId,
    required int month,
    required int year,
  }) {
    final shortProviderId = providerId.length > 8
        ? providerId.substring(0, 8)
        : providerId;

    return 'HH${month.toString().padLeft(2, '0')}'
            '$year$shortProviderId'
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    return user;
  }

  Future<User> _requireAdmin() async {
    final user = _requireUser();

    if (!await _isAdmin(user.uid)) {
      throw StateError('Bạn không có quyền quản trị.');
    }

    return user;
  }

  Future<bool> _isAdmin(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .get();

    return snapshot.data()?['role'] == 'admin';
  }
}