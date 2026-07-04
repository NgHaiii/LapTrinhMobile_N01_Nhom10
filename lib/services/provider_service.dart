import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/booking.dart';
import '../model/hotel.dart';
import '../model/room.dart';
import '../model/room_rate_plan.dart';

class ProviderStats {
  const ProviderStats({
    required this.hotels,
    required this.rooms,
    required this.pendingBookings,
    required this.revenue,
    this.awaitingPayments = 0,
  });

  final int hotels;
  final int rooms;
  final int pendingBookings;
  final int awaitingPayments;
  final double revenue;
}

class ProviderService {
  ProviderService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore =
           firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get providerId {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    return uid;
  }

  Stream<List<HotelModel>> watchHotels() {
    return _firestore
        .collection('hotels')
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
          final hotels = snapshot.docs
              .map(
                (document) => HotelModel.fromMap(
                  document.data(),
                  document.id,
                ),
              )
              .toList();

          hotels.sort(
            (a, b) => a.name.compareTo(b.name),
          );

          return hotels;
        });
  }

  Stream<List<RoomModel>> watchRooms({
    String? hotelId,
  }) {
    return _firestore
        .collection('rooms')
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
          var rooms = snapshot.docs
              .map(
                (document) => RoomModel.fromMap(
                  document.data(),
                  document.id,
                ),
              )
              .toList();

          if (hotelId?.trim().isNotEmpty == true) {
            rooms = rooms
                .where(
                  (room) =>
                      room.hotelId == hotelId!.trim(),
                )
                .toList();
          }

          rooms.sort(
            (a, b) =>
                a.roomNumber.compareTo(b.roomNumber),
          );

          return rooms;
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
  watchBookings({
    String status = 'all',
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId);

    if (status != 'all') {
      query = query.where(
        'status',
        isEqualTo: status,
      );
    }

    return query.snapshots();
  }

  Stream<List<BookingModel>> watchBookingModels() {
    return watchBookings().map((snapshot) {
      final bookings = snapshot.docs
          .map(
            (document) => BookingModel.fromMap(
              document.data(),
              document.id,
            ),
          )
          .toList();

      bookings.sort((a, b) {
        final first = a.createdAt ?? a.checkIn;
        final second = b.createdAt ?? b.checkIn;

        return second.compareTo(first);
      });

      return bookings;
    });
  }

  Future<ProviderStats> loadStats() async {
    final results = await Future.wait([
      _firestore
          .collection('hotels')
          .where('providerId', isEqualTo: providerId)
          .get(),
      _firestore
          .collection('rooms')
          .where('providerId', isEqualTo: providerId)
          .get(),
      _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .get(),
    ]);

    var pending = 0;
    var awaitingPayment = 0;
    var revenue = 0.0;

    for (final document in results[2].docs) {
      final booking = BookingModel.fromMap(
        document.data(),
        document.id,
      );

      if (booking.status ==
              BookingStatus.pendingProvider ||
          booking.status == BookingStatus.pending) {
        pending++;
      }

      if (booking.status ==
              BookingStatus.awaitingPayment ||
          booking.status ==
              BookingStatus.paymentReview) {
        awaitingPayment++;
      }

      if (booking.paymentStatus ==
          PaymentStatus.paid) {
        revenue += booking.totalAmount;
      }
    }

    return ProviderStats(
      hotels: results[0].docs.length,
      rooms: results[1].docs.length,
      pendingBookings: pending,
      awaitingPayments: awaitingPayment,
      revenue: revenue,
    );
  }

  Future<void> addHotel({
    required String name,
    required String address,
    required String province,
    required String district,
    required String description,
    required List<String> images,
    required String category,
    required String contactPhone,
    String contactEmail = '',
    String zaloPhone = '',
    String facebookUrl = '',
    List<String> amenities = const [],
  }) async {
    final normalizedImages = _normalizeList(images);

    if (name.trim().length < 2) {
      throw StateError(
        'Tên khách sạn không hợp lệ.',
      );
    }

    if (province.trim().isEmpty) {
      throw StateError(
        'Vui lòng nhập tỉnh hoặc thành phố.',
      );
    }

    if (district.trim().isEmpty) {
      throw StateError(
        'Vui lòng nhập quận hoặc huyện.',
      );
    }

    if (address.trim().isEmpty) {
      throw StateError(
        'Vui lòng nhập địa chỉ khách sạn.',
      );
    }

    if (normalizedImages.isEmpty) {
      throw StateError(
        'Khách sạn phải có ít nhất một ảnh.',
      );
    }

    _validateHotelContact(
      phone: contactPhone,
      email: contactEmail,
      zalo: zaloPhone,
      facebook: facebookUrl,
    );

    await _firestore.collection('hotels').add({
      'providerId': providerId,
      'name': name.trim(),
      'address': address.trim(),
      'province': province.trim(),
      'district': district.trim(),
      'description': description.trim(),
      'imageUrl': normalizedImages.first,
      'images': normalizedImages,
      'amenities': _normalizeList(amenities),
      'category': category.trim(),
      'status': 'approved',
      'rating': 0.0,
      'contactPhone':
          _normalizePhone(contactPhone),
      'contactEmail':
          contactEmail.trim().toLowerCase(),
      'zaloPhone': _normalizePhone(zaloPhone),
      'facebookUrl':
          _normalizeFacebookUrl(facebookUrl),
      'minPrice': 0.0,
      'minHourlyPrice': 0.0,
      'minFirstHourPrice': 0.0,
      'minAdditionalHourPrice': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateHotel(
    HotelModel hotel,
  ) async {
    _ensureOwnership(hotel.providerId);

    if (hotel.id.trim().isEmpty) {
      throw StateError(
        'Mã khách sạn không hợp lệ.',
      );
    }

    if (hotel.name.trim().length < 2) {
      throw StateError(
        'Tên khách sạn không hợp lệ.',
      );
    }

    if (hotel.images.isEmpty &&
        hotel.imageUrl.trim().isEmpty) {
      throw StateError(
        'Khách sạn phải có ít nhất một ảnh.',
      );
    }

    _validateHotelContact(
      phone: hotel.contactPhone,
      email: hotel.contactEmail,
      zalo: hotel.zaloPhone,
      facebook: hotel.facebookUrl,
    );

    await _firestore
        .collection('hotels')
        .doc(hotel.id)
        .update({
          ...hotel.toMap(),
          'providerId': providerId,
          'contactPhone':
              _normalizePhone(hotel.contactPhone),
          'contactEmail':
              hotel.contactEmail.trim().toLowerCase(),
          'zaloPhone':
              _normalizePhone(hotel.zaloPhone),
          'facebookUrl': _normalizeFacebookUrl(
            hotel.facebookUrl,
          ),
          'updatedAt':
              FieldValue.serverTimestamp(),
        });
  }

  Future<void> deleteHotel(
    HotelModel hotel,
  ) async {
    _ensureOwnership(hotel.providerId);

    final activeBookings = await _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .get();

    for (final document in activeBookings.docs) {
      final booking = BookingModel.fromMap(
        document.data(),
        document.id,
      );

      if (booking.hotelId == hotel.id &&
          !booking.isFinished) {
        throw StateError(
          'Khách sạn đang có đơn đặt phòng hoạt động.',
        );
      }
    }

    final rooms = await _firestore
        .collection('rooms')
        .where('hotelId', isEqualTo: hotel.id)
        .get();

    final batch = _firestore.batch();

    for (final room in rooms.docs) {
      if (room.data()['providerId'] == providerId) {
        batch.delete(room.reference);
      }
    }

    batch.delete(
      _firestore.collection('hotels').doc(hotel.id),
    );

    await batch.commit();
  }

  Future<void> addRoom({
    required String hotelId,
    required String roomNumber,
    required String type,
    required double price,
    required int maxGuests,
    required String description,
    required bool isAvailable,
    double hourlyPrice = 0,
    double firstHourPrice = 0,
    double additionalHourPrice = 0,
    double weekendSurchargePercent = 20,
    double holidaySurchargePercent = 35,
    double area = 0,
    int bedCount = 1,
    String bedType = '',
    List<String> images = const [],
    List<String> amenities = const [],
    List<RoomRatePlan> ratePlans = const [],
  }) async {
    await _ensureHotelOwnership(hotelId);

    final firstPrice = firstHourPrice > 0
        ? firstHourPrice
        : hourlyPrice > 0
        ? hourlyPrice
        : price / 24;

    final nextPrice = additionalHourPrice > 0
        ? additionalHourPrice
        : firstPrice;

    _validateRoomData(
      roomNumber: roomNumber,
      firstHourPrice: firstPrice,
      additionalHourPrice: nextPrice,
      maxGuests: maxGuests,
      weekendPercent: weekendSurchargePercent,
      holidayPercent: holidaySurchargePercent,
      ratePlans: ratePlans,
    );

    await _ensureRoomNumberAvailable(
      hotelId: hotelId,
      roomNumber: roomNumber,
    );

    final normalizedImages = _normalizeList(images);

    await _firestore.collection('rooms').add({
      'hotelId': hotelId.trim(),
      'providerId': providerId,
      'roomNumber': roomNumber.trim(),
      'type': type.trim(),
      'price': price,
      'hourlyPrice': firstPrice,
      'firstHourPrice': firstPrice,
      'additionalHourPrice': nextPrice,
      'weekendSurchargePercent':
          weekendSurchargePercent.clamp(0, 100),
      'holidaySurchargePercent':
          holidaySurchargePercent.clamp(0, 100),
      'maxGuests': maxGuests,
      'description': description.trim(),
      'isAvailable': isAvailable,
      'area': area,
      'bedCount': bedCount,
      'bedType': bedType.trim(),
      'imageUrl': normalizedImages.isEmpty
          ? ''
          : normalizedImages.first,
      'images': normalizedImages,
      'amenities': _normalizeList(amenities),
      'ratePlans': _normalizeRatePlans(ratePlans)
          .map((plan) => plan.toMap())
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _synchronizeMinimumPrices(hotelId);
  }

  Future<void> updateRoom(
    RoomModel room,
  ) async {
    _ensureOwnership(room.providerId);
    await _ensureHotelOwnership(room.hotelId);

    _validateRoomData(
      roomNumber: room.roomNumber,
      firstHourPrice:
          room.effectiveFirstHourPrice,
      additionalHourPrice:
          room.effectiveAdditionalHourPrice,
      maxGuests: room.maxGuests,
      weekendPercent:
          room.weekendSurchargePercent,
      holidayPercent:
          room.holidaySurchargePercent,
      ratePlans: room.ratePlans,
    );

    await _ensureRoomNumberAvailable(
      hotelId: room.hotelId,
      roomNumber: room.roomNumber,
      excludedRoomId: room.id,
    );

    await _firestore
        .collection('rooms')
        .doc(room.id)
        .update({
          ...room.toMap(),
          'providerId': providerId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    await _synchronizeMinimumPrices(room.hotelId);
  }

  Future<void> deleteRoom(
    RoomModel room,
  ) async {
    _ensureOwnership(room.providerId);

    final bookings = await _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .get();

    for (final document in bookings.docs) {
      final booking = BookingModel.fromMap(
        document.data(),
        document.id,
      );

      if (booking.roomId == room.id &&
          !booking.isFinished) {
        throw StateError(
          'Phòng đang có đơn đặt phòng hoạt động.',
        );
      }
    }

    await _firestore
        .collection('rooms')
        .doc(room.id)
        .delete();

    await _synchronizeMinimumPrices(room.hotelId);
  }

  Future<void> approveBooking(
    String bookingId,
  ) async {
    final booking =
        await _getOwnedBooking(bookingId);

    if (booking.status != BookingStatus.pending &&
        booking.status !=
            BookingStatus.pendingProvider) {
      throw StateError(
        'Đơn không còn ở trạng thái chờ duyệt.',
      );
    }

    final profile = await _firestore
        .collection('providerPaymentProfiles')
        .doc(providerId)
        .get();

    final paymentData = profile.data();

    if (paymentData == null ||
        paymentData['isVerified'] != true ||
        paymentData['verificationStatus'] !=
            'approved') {
      throw StateError(
        'Tài khoản ngân hàng chưa được admin xác minh.',
      );
    }

    await _ensureNoLegacyOverlap(booking);

    await _firestore
        .collection('bookings')
        .doc(bookingId)
        .update({
          'status': BookingStatus.awaitingPayment,
          'paymentStatus': PaymentStatus.unpaid,
          'paymentDeadline': Timestamp.fromDate(
            DateTime.now().add(
              const Duration(hours: 2),
            ),
          ),
          'receiverBankBin':
              paymentData['bankBin']?.toString() ?? '',
          'receiverBankName':
              paymentData['bankName']?.toString() ?? '',
          'receiverAccountNumber':
              paymentData['accountNumber']?.toString() ??
              '',
          'receiverAccountName':
              paymentData['accountName']?.toString() ??
              '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> rejectBooking(
    String bookingId,
  ) async {
    final booking =
        await _getOwnedBooking(bookingId);

    if (booking.status != BookingStatus.pending &&
        booking.status !=
            BookingStatus.pendingProvider) {
      throw StateError(
        'Đơn không còn ở trạng thái chờ duyệt.',
      );
    }

    await _closeBooking(
      bookingId,
      BookingStatus.rejected,
    );
  }

  Future<void> confirmPayment(
    String bookingId,
  ) async {
    final booking =
        await _getOwnedBooking(bookingId);

    if (booking.status !=
            BookingStatus.paymentReview ||
        booking.paymentStatus !=
            PaymentStatus.submitted) {
      throw StateError(
        'Khách chưa gửi xác nhận thanh toán.',
      );
    }

    await _firestore
        .collection('bookings')
        .doc(bookingId)
        .update({
          'status': BookingStatus.confirmed,
          'paymentStatus': PaymentStatus.paid,
          'paymentConfirmedAt':
              FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> rejectPayment(
    String bookingId,
  ) async {
    final booking =
        await _getOwnedBooking(bookingId);

    if (booking.status !=
        BookingStatus.paymentReview) {
      throw StateError(
        'Đơn không ở trạng thái kiểm tra tiền.',
      );
    }

    await _firestore
        .collection('bookings')
        .doc(bookingId)
        .update({
          'status': BookingStatus.awaitingPayment,
          'paymentStatus': PaymentStatus.rejected,
          'paymentDeadline': Timestamp.fromDate(
            DateTime.now().add(
              const Duration(hours: 1),
            ),
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> completeBooking(
    String bookingId,
  ) async {
    final booking =
        await _getOwnedBooking(bookingId);

    if (booking.status != BookingStatus.confirmed) {
      throw StateError(
        'Chỉ đơn đã xác nhận mới được hoàn thành.',
      );
    }

    await _closeBooking(
      bookingId,
      BookingStatus.completed,
    );
  }

  Future<void> cancelBooking(
    String bookingId,
  ) async {
    final booking =
        await _getOwnedBooking(bookingId);

    if (booking.isFinished) {
      throw StateError('Đơn đã kết thúc.');
    }

    await _closeBooking(
      bookingId,
      BookingStatus.cancelled,
    );
  }

  Future<void> updateBookingStatus(
    String bookingId,
    String status,
  ) {
    return switch (status) {
      BookingStatus.confirmed =>
        approveBooking(bookingId),
      BookingStatus.rejected =>
        rejectBooking(bookingId),
      BookingStatus.completed =>
        completeBooking(bookingId),
      BookingStatus.cancelled =>
        cancelBooking(bookingId),
      _ => Future.error(
        ArgumentError('Trạng thái không hợp lệ.'),
      ),
    };
  }

  Future<void> _closeBooking(
    String bookingId,
    String finalStatus,
  ) async {
    final bookingReference = _firestore
        .collection('bookings')
        .doc(bookingId);

    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot =
          await transaction.get(bookingReference);

      final data = bookingSnapshot.data();

      if (data == null) {
        throw StateError(
          'Không tìm thấy đơn đặt phòng.',
        );
      }

      final booking = BookingModel.fromMap(
        data,
        bookingSnapshot.id,
      );

      _ensureOwnership(booking.providerId);

      final scheduleIds =
          _readScheduleIds(data, booking);

      final scheduleReferences = scheduleIds
          .map(
            (id) => _firestore
                .collection('roomSchedules')
                .doc(id),
          )
          .toList();

      final scheduleSnapshots =
          <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final reference in scheduleReferences) {
        scheduleSnapshots.add(
          await transaction.get(reference),
        );
      }

      transaction.update(bookingReference, {
        'status': finalStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (var index = 0;
          index < scheduleReferences.length;
          index++) {
        final snapshot = scheduleSnapshots[index];

        if (!snapshot.exists) continue;

        final reservations = _readReservations(
          snapshot.data()?['reservations'],
        );

        final oldValue = reservations[booking.id];

        if (oldValue is! Map) continue;

        reservations[booking.id] = {
          ...Map<String, dynamic>.from(oldValue),
          'active': false,
        };

        transaction.update(
          scheduleReferences[index],
          {
            'reservations': reservations,
            'lastBookingId': booking.id,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      }
    });
  }

  Future<BookingModel> _getOwnedBooking(
    String bookingId,
  ) async {
    final snapshot = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();

    final data = snapshot.data();

    if (data == null) {
      throw StateError(
        'Không tìm thấy đơn đặt phòng.',
      );
    }

    final booking = BookingModel.fromMap(
      data,
      snapshot.id,
    );

    _ensureOwnership(booking.providerId);
    return booking;
  }

  Future<void> _ensureNoLegacyOverlap(
    BookingModel current,
  ) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .get();

    for (final document in snapshot.docs) {
      if (document.id == current.id) continue;

      final booking = BookingModel.fromMap(
        document.data(),
        document.id,
      );

      if (booking.roomId != current.roomId) {
        continue;
      }

      if (booking.isFinished) continue;

      final overlaps =
          current.checkIn.isBefore(booking.checkOut) &&
          current.checkOut.isAfter(booking.checkIn);

      if (overlaps) {
        throw StateError(
          'Phòng đã có đơn khác trong thời gian này.',
        );
      }
    }
  }

  Future<void> _ensureHotelOwnership(
    String hotelId,
  ) async {
    final snapshot = await _firestore
        .collection('hotels')
        .doc(hotelId)
        .get();

    if (!snapshot.exists ||
        snapshot.data()?['providerId'] != providerId) {
      throw StateError(
        'Bạn không có quyền quản lý khách sạn này.',
      );
    }
  }

  Future<void> _ensureRoomNumberAvailable({
    required String hotelId,
    required String roomNumber,
    String excludedRoomId = '',
  }) async {
    final snapshot = await _firestore
        .collection('rooms')
        .where('hotelId', isEqualTo: hotelId)
        .where(
          'roomNumber',
          isEqualTo: roomNumber.trim(),
        )
        .get();

    final duplicated = snapshot.docs.any(
      (document) =>
          document.id != excludedRoomId,
    );

    if (duplicated) {
      throw StateError('Số phòng đã tồn tại.');
    }
  }

  void _validateHotelContact({
    required String phone,
    required String email,
    required String zalo,
    required String facebook,
  }) {
    final normalizedPhone = _normalizePhone(phone);

    if (!_isValidVietnamesePhone(
      normalizedPhone,
    )) {
      throw StateError(
        'Số điện thoại liên hệ không hợp lệ.',
      );
    }

    final normalizedEmail =
        email.trim().toLowerCase();

    if (normalizedEmail.isNotEmpty &&
        !RegExp(
          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
        ).hasMatch(normalizedEmail)) {
      throw StateError(
        'Email liên hệ không hợp lệ.',
      );
    }

    final normalizedZalo = _normalizePhone(zalo);

    if (normalizedZalo.isNotEmpty &&
        !_isValidVietnamesePhone(
          normalizedZalo,
        )) {
      throw StateError(
        'Số điện thoại Zalo không hợp lệ.',
      );
    }

    if (facebook.trim().isNotEmpty) {
      final normalizedUrl =
          _normalizeFacebookUrl(facebook);

      final uri = Uri.tryParse(normalizedUrl);
      final host = uri?.host.toLowerCase() ?? '';

      final validHost =
          host == 'facebook.com' ||
          host.endsWith('.facebook.com');

      if (uri == null ||
          !uri.hasScheme ||
          !validHost) {
        throw StateError(
          'Đường dẫn Facebook không hợp lệ.',
        );
      }
    }
  }

  bool _isValidVietnamesePhone(String value) {
    return RegExp(
      r'^(?:0[0-9]{9}|\+84[0-9]{9})$',
    ).hasMatch(value);
  }

  String _normalizePhone(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\s.-]'), '');
  }

  String _normalizeFacebookUrl(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) return '';

    if (normalized.startsWith('http://') ||
        normalized.startsWith('https://')) {
      return normalized;
    }

    return 'https://$normalized';
  }

  void _validateRoomData({
    required String roomNumber,
    required double firstHourPrice,
    required double additionalHourPrice,
    required int maxGuests,
    required double weekendPercent,
    required double holidayPercent,
    required List<RoomRatePlan> ratePlans,
  }) {
    if (roomNumber.trim().isEmpty) {
      throw StateError(
        'Vui lòng nhập số phòng.',
      );
    }

    if (firstHourPrice <= 0 ||
        additionalHourPrice <= 0) {
      throw StateError(
        'Giá giờ đầu và giá từ giờ thứ hai '
        'phải lớn hơn 0.',
      );
    }

    if (maxGuests <= 0) {
      throw StateError(
        'Số lượng khách tối đa phải lớn hơn 0.',
      );
    }

    if (weekendPercent < 0 ||
        weekendPercent > 100 ||
        holidayPercent < 0 ||
        holidayPercent > 100) {
      throw StateError(
        'Phần trăm phụ thu phải từ 0 đến 100.',
      );
    }

    final ids = <String>{};

    for (final plan in ratePlans) {
      if (!plan.isValid) {
        throw StateError(
          'Thông tin combo '
          '${plan.name} không hợp lệ.',
        );
      }

      if (!ids.add(plan.id)) {
        throw StateError(
          'Mã combo ${plan.id} đang bị trùng.',
        );
      }
    }
  }

  List<RoomRatePlan> _normalizeRatePlans(
    List<RoomRatePlan> plans,
  ) {
    final result = <String, RoomRatePlan>{};

    for (final plan in plans) {
      if (plan.isValid) {
        result[plan.id] = plan;
      }
    }

    return result.values.toList();
  }

  Future<void> _synchronizeMinimumPrices(
    String hotelId,
  ) async {
    final snapshot = await _firestore
        .collection('rooms')
        .where('hotelId', isEqualTo: hotelId)
        .get();

    final rooms = snapshot.docs
        .map(
          (document) => RoomModel.fromMap(
            document.data(),
            document.id,
          ),
        )
        .toList();

    double minimum(
      Iterable<double> source,
    ) {
      final values = source
          .where((value) => value > 0)
          .toList();

      if (values.isEmpty) return 0;

      return values.reduce(
        (a, b) => a < b ? a : b,
      );
    }

    await _firestore
        .collection('hotels')
        .doc(hotelId)
        .update({
          'minPrice': minimum(
            rooms.map((room) => room.price),
          ),
          'minHourlyPrice': minimum(
            rooms.map(
              (room) =>
                  room.effectiveFirstHourPrice,
            ),
          ),
          'minFirstHourPrice': minimum(
            rooms.map(
              (room) =>
                  room.effectiveFirstHourPrice,
            ),
          ),
          'minAdditionalHourPrice': minimum(
            rooms.map(
              (room) =>
                  room.effectiveAdditionalHourPrice,
            ),
          ),
          'updatedAt':
              FieldValue.serverTimestamp(),
        });
  }

  List<String> _readScheduleIds(
    Map<String, dynamic> data,
    BookingModel booking,
  ) {
    final value = data['scheduleIds'];

    if (value is List) {
      final result = value
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList();

      if (result.isNotEmpty) return result;
    }

    return _scheduleIds(
      booking.roomId,
      booking.checkIn,
      booking.checkOut,
    );
  }

  List<String> _scheduleIds(
    String roomId,
    DateTime checkIn,
    DateTime checkOut,
  ) {
    final ids = <String>[];

    var cursor = DateTime(
      checkIn.year,
      checkIn.month,
    );

    final lastMoment = checkOut.subtract(
      const Duration(microseconds: 1),
    );

    final lastMonth = DateTime(
      lastMoment.year,
      lastMoment.month,
    );

    while (!cursor.isAfter(lastMonth)) {
      final month =
          cursor.month.toString().padLeft(2, '0');

      ids.add(
        '${roomId}_${cursor.year}$month',
      );

      cursor = DateTime(
        cursor.year,
        cursor.month + 1,
      );
    }

    return ids;
  }

  Map<String, dynamic> _readReservations(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  List<String> _normalizeList(
    List<String> values,
  ) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  void _ensureOwnership(String ownerId) {
    if (ownerId != providerId) {
      throw StateError(
        'Bạn không có quyền thay đổi dữ liệu này.',
      );
    }
  }
}