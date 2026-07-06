import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/booking.dart';
import '../model/commission_invoice.dart';
import '../model/violation_record.dart';
import 'vietqr_service.dart';

class CommissionService {
  CommissionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const double defaultCommissionRate = 0.10;

  CollectionReference<Map<String, dynamic>> get _invoices {
    return _firestore.collection('commissionInvoices');
  }

  CollectionReference<Map<String, dynamic>> get _violations {
    return _firestore.collection('violationRecords');
  }

  Stream<List<CommissionInvoice>> watchMyInvoices() {
    final uid = _requireUser().uid;

    return _invoices
        .where('providerId', isEqualTo: uid)
        .snapshots()
        .map(_parseInvoices);
  }

  Stream<List<CommissionInvoice>> watchAllInvoices({
    String status = 'all',
  }) {
    Query<Map<String, dynamic>> query = _invoices;

    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map(_parseInvoices);
  }

  Future<CommissionInvoice> createMonthlyInvoice({
    required String providerId,
    required int month,
    required int year,
  }) async {
    await _requireAdmin();

    final normalizedProviderId = providerId.trim();

    if (normalizedProviderId.isEmpty) {
      throw StateError('Mã nhà cung cấp không hợp lệ.');
    }

    if (month < 1 || month > 12 || year < 2020) {
      throw StateError('Tháng lập hóa đơn không hợp lệ.');
    }

    final invoiceId =
        '${normalizedProviderId}_${year}_${month.toString().padLeft(2, '0')}';

    final invoiceReference = _invoices.doc(invoiceId);
    final periodStart = DateTime(year, month);
    final periodEnd = DateTime(year, month + 1);

    final providerSnapshot = await _firestore
        .collection('providers')
        .doc(normalizedProviderId)
        .get();

    var providerName = providerSnapshot.data()?['businessName']
            ?.toString()
            .trim() ??
        '';

    if (providerName.isEmpty) {
      final userSnapshot = await _firestore
          .collection('users')
          .doc(normalizedProviderId)
          .get();

      providerName = userSnapshot.data()?['fullName']
              ?.toString()
              .trim() ??
          'Nhà cung cấp';
    }

    final bookingSnapshot = await _firestore
        .collection('bookings')
        .where(
          'providerId',
          isEqualTo: normalizedProviderId,
        )
        .get();

    final eligibleBookings = <BookingModel>[];

    for (final document in bookingSnapshot.docs) {
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

    final violationSnapshot = await _violations
        .where(
          'providerId',
          isEqualTo: normalizedProviderId,
        )
        .get();

    final candidateViolationIds = <String>[];

    for (final document in violationSnapshot.docs) {
      final data = document.data();
      final status = data['status']?.toString();
      final confirmedAt = _date(data['confirmedAt']);

      if (status != ViolationStatus.confirmed ||
          data['commissionApplied'] == true ||
          confirmedAt == null) {
        continue;
      }

      if (!confirmedAt.isBefore(periodStart) &&
          confirmedAt.isBefore(periodEnd)) {
        candidateViolationIds.add(document.id);
      }
    }

    final grossRevenue = eligibleBookings.fold<double>(
      0,
      (total, booking) => total + booking.totalAmount,
    );

    final baseCommissionAmount =
        eligibleBookings.fold<double>(
      0,
      (total, booking) {
        return total + booking.effectiveCommissionAmount;
      },
    );

    CommissionInvoice? createdInvoice;

    await _firestore.runTransaction((transaction) async {
      final existingInvoice =
          await transaction.get(invoiceReference);

      if (existingInvoice.exists) {
        throw StateError(
          'Hóa đơn hoa hồng của tháng này đã tồn tại.',
        );
      }

      final validViolations = <ViolationRecord>[];

      // Firestore yêu cầu hoàn thành toàn bộ thao tác đọc
      // trước khi bắt đầu ghi.
      for (final violationId in candidateViolationIds) {
        final snapshot = await transaction.get(
          _violations.doc(violationId),
        );

        if (!snapshot.exists) continue;

        final violation =
            ViolationRecord.fromFirestore(snapshot);

        if (violation.providerId != normalizedProviderId ||
            violation.status != ViolationStatus.confirmed ||
            violation.commissionApplied ||
            violation.confirmedAt == null) {
          continue;
        }

        final confirmedAt = violation.confirmedAt!;

        if (!confirmedAt.isBefore(periodStart) &&
            confirmedAt.isBefore(periodEnd)) {
          validViolations.add(violation);
        }
      }

      if (eligibleBookings.isEmpty &&
          validViolations.isEmpty) {
        throw StateError(
          'Không có booking đã thanh toán hoặc khoản phạt '
          'được xác nhận trong tháng này.',
        );
      }

      final penaltyAmount = validViolations.fold<double>(
        0,
        (total, violation) {
          return total + violation.penaltyAmount;
        },
      );

      final paymentReference = _paymentReference(
        providerId: normalizedProviderId,
        month: month,
        year: year,
      );

      final invoice = CommissionInvoice(
        id: invoiceId,
        providerId: normalizedProviderId,
        providerName: providerName,
        month: month,
        year: year,
        grossRevenue: grossRevenue,
        commissionRate: defaultCommissionRate,
        commissionAmount: baseCommissionAmount,
        penaltyAmount: penaltyAmount,
        bookingIds: eligibleBookings
            .map((booking) => booking.id)
            .toSet()
            .toList(),
        violationRecordIds: validViolations
            .map((violation) => violation.id)
            .toSet()
            .toList(),
        status: CommissionStatus.unpaid,
        paymentReference: paymentReference,
        dueDate: DateTime(
          year,
          month + 1,
          5,
          23,
          59,
        ),
      );

      transaction.set(invoiceReference, {
        ...invoice.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (final violation in validViolations) {
        transaction.update(
          _violations.doc(violation.id),
          {
            'commissionApplied': true,
            'commissionInvoiceId': invoiceId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      createdInvoice = invoice;
    });

    return createdInvoice!;
  }

  Future<String> createCommissionQrUrl(
    CommissionInvoice invoice,
  ) async {
    final user = _requireUser();

    if (user.uid != invoice.providerId) {
      final isAdmin = await _isAdmin(user.uid);

      if (!isAdmin) {
        throw StateError(
          'Bạn không có quyền xem QR hóa đơn này.',
        );
      }
    }

    if (invoice.totalPayableAmount <= 0) {
      throw StateError(
        'Tổng tiền hóa đơn không hợp lệ.',
      );
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

    final bankBin =
        settings['bankBin']?.toString().trim() ?? '';

    final accountNumber =
        settings['accountNumber']?.toString().trim() ?? '';

    final accountName =
        settings['accountName']?.toString().trim() ?? '';

    if (bankBin.isEmpty ||
        accountNumber.isEmpty ||
        accountName.isEmpty) {
      throw StateError(
        'Thông tin tài khoản nhận hoa hồng chưa đầy đủ.',
      );
    }

    return VietQrService.createQrUrl(
      bankBin: bankBin,
      accountNumber: accountNumber,
      accountName: accountName,
      totalAmount: invoice.totalPayableAmount,
      paymentReference: invoice.paymentReference,
    );
  }

  Future<void> submitCommissionPayment(
    String invoiceId,
  ) async {
    final user = _requireUser();
    final reference = _invoices.doc(invoiceId.trim());

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();

      if (data == null) {
        throw StateError(
          'Không tìm thấy hóa đơn hoa hồng.',
        );
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
        'paymentSubmittedAt':
            FieldValue.serverTimestamp(),
        'rejectionReason': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> confirmCommissionPayment(
    String invoiceId,
  ) async {
    final admin = await _requireAdmin();
    final reference = _invoices.doc(invoiceId.trim());

    await _firestore.runTransaction((transaction) async {
      final invoiceSnapshot =
          await transaction.get(reference);

      if (!invoiceSnapshot.exists) {
        throw StateError('Không tìm thấy hóa đơn.');
      }

      final invoice = CommissionInvoice.fromMap(
        invoiceSnapshot.data()!,
        invoiceSnapshot.id,
      );

      if (invoice.status !=
          CommissionStatus.paymentReview) {
        throw StateError(
          'Nhà cung cấp chưa gửi xác nhận thanh toán.',
        );
      }

      final violationSnapshots =
          <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final violationId
          in invoice.violationRecordIds) {
        final snapshot = await transaction.get(
          _violations.doc(violationId),
        );

        violationSnapshots.add(snapshot);
      }

      final now = FieldValue.serverTimestamp();

      transaction.update(reference, {
        'status': CommissionStatus.paid,
        'confirmedBy': admin.uid,
        'confirmedAt': now,
        'updatedAt': now,
      });

      for (final snapshot in violationSnapshots) {
        if (!snapshot.exists) continue;

        final data = snapshot.data()!;

        if (data['commissionInvoiceId'] != invoice.id) {
          continue;
        }

        transaction.update(snapshot.reference, {
          'status': ViolationStatus.paid,
          'resolvedAt': now,
          'updatedAt': now,
        });
      }
    });
  }

  Future<void> rejectCommissionPayment({
    required String invoiceId,
    required String reason,
  }) async {
    await _requireAdmin();

    final normalizedReason = reason.trim();

    if (normalizedReason.length < 5) {
      throw StateError(
        'Vui lòng nhập lý do từ chối rõ ràng.',
      );
    }

    await _invoices.doc(invoiceId.trim()).update({
      'status': CommissionStatus.rejected,
      'rejectionReason': normalizedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<CommissionInvoice> _parseInvoices(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final invoices = snapshot.docs.map((document) {
      return CommissionInvoice.fromMap(
        document.data(),
        document.id,
      );
    }).toList();

    invoices.sort((first, second) {
      final firstPeriod = first.year * 100 + first.month;
      final secondPeriod = second.year * 100 + second.month;

      return secondPeriod.compareTo(firstPeriod);
    });

    return invoices;
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
      throw StateError(
        'Bạn không có quyền quản trị.',
      );
    }

    return user;
  }

  Future<bool> _isAdmin(String uid) async {
    final snapshot =
        await _firestore.collection('users').doc(uid).get();

    return snapshot.data()?['role'] == 'admin';
  }
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}