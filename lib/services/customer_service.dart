import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/booking.dart';
import '../model/hotel.dart';
import '../model/pricing_quote.dart';
import '../model/room.dart';
import '../model/room_rate_plan.dart';
import '../model/room_reservation.dart';
import '../model/user_voucher.dart';
import '../model/voucher.dart';
import 'holiday_service.dart';
import 'hourly_pricing_service.dart';

class CustomerService {
  CustomerService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    HolidayService? holidayService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _holidayService = holidayService ?? HolidayService.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final HolidayService _holidayService;

  String get customerId {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw StateError('Bạn cần đăng nhập để thực hiện chức năng này.');
    }

    return uid;
  }

  Stream<List<HotelModel>> watchHotels() {
    return _firestore.collection('hotels').snapshots().map((snapshot) {
      final hotels = <HotelModel>[];

      for (final document in snapshot.docs) {
        try {
          final hotel = HotelModel.fromMap(document.data(), document.id);

          if (hotel.isVisible) {
            hotels.add(hotel);
          }
        } catch (error, stackTrace) {
          developer.log(
            'Khách sạn ${document.id} không hợp lệ.',
            name: 'CustomerService.watchHotels',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      hotels.sort(_compareHotelsForCustomer);
      return hotels;
    });
  }

  Stream<List<HotelModel>> watchHotelsByProvince(String province) {
    return watchHotelsByLocation(province: province);
  }

  Stream<List<HotelModel>> watchHotelsByLocation({
    String province = '',
    String district = '',
    String keyword = '',
  }) {
    final expectedProvince = _normalizeLocation(province);
    final expectedDistrict = _normalizeLocation(district);
    final expectedKeyword = _normalizeLocation(keyword);

    if (expectedProvince.isEmpty &&
        expectedDistrict.isEmpty &&
        expectedKeyword.isEmpty) {
      return watchHotels();
    }

    return watchHotels().map((hotels) {
      final filtered = hotels.where((hotel) {
        final hotelProvince = _normalizeLocation(hotel.province);
        final hotelDistrict = _normalizeLocation(hotel.district);
        final hotelAddress = _normalizeLocation(hotel.address);
        final hotelFullAddress = _normalizeLocation(hotel.fullAddress);
        final hotelName = _normalizeLocation(hotel.name);
        final hotelDescription = _normalizeLocation(hotel.description);

        final source = [
          hotelProvince,
          hotelDistrict,
          hotelAddress,
          hotelFullAddress,
          hotelName,
          hotelDescription,
        ].where((item) => item.isNotEmpty).join(' ');

        final matchProvince = expectedProvince.isEmpty ||
            hotelProvince == expectedProvince ||
            source.contains(expectedProvince);

        final matchDistrict = expectedDistrict.isEmpty ||
            hotelDistrict == expectedDistrict ||
            source.contains(expectedDistrict);

        final matchKeyword =
            expectedKeyword.isEmpty || source.contains(expectedKeyword);

        return matchProvince && matchDistrict && matchKeyword;
      }).toList();

      filtered.sort(_compareHotelsForCustomer);
      return filtered;
    });
  }

  Stream<HotelModel?> watchHotel(String hotelId) {
    final normalizedId = hotelId.trim();

    if (normalizedId.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection('hotels')
        .doc(normalizedId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();

      if (data == null) return null;

      try {
        return HotelModel.fromMap(data, snapshot.id);
      } catch (error, stackTrace) {
        developer.log(
          'Khách sạn ${snapshot.id} không hợp lệ.',
          name: 'CustomerService.watchHotel',
          error: error,
          stackTrace: stackTrace,
        );

        return null;
      }
    });
  }

  Stream<List<RoomModel>> watchRooms({
    required String hotelId,
    String hotelName = '',
  }) {
    final expectedId = hotelId.trim();
    final expectedName = _normalize(hotelName);

    if (expectedId.isEmpty) {
      return Stream.value(const []);
    }

    return _firestore.collection('rooms').snapshots().map((snapshot) {
      final rooms = <RoomModel>[];

      for (final document in snapshot.docs) {
        try {
          final room = RoomModel.fromMap(document.data(), document.id);

          final matchesId = room.hotelId == expectedId;

          final matchesLegacyName = room.hotelId.isEmpty &&
              expectedName.isNotEmpty &&
              _normalize(room.hotelName) == expectedName;

          if (matchesId || matchesLegacyName) {
            rooms.add(room);
          }
        } catch (error, stackTrace) {
          developer.log(
            'Phòng ${document.id} không hợp lệ.',
            name: 'CustomerService.watchRooms',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      rooms.sort(
        (first, second) => _compareRoomNumbers(
          first.roomNumber,
          second.roomNumber,
        ),
      );

      return rooms;
    });
  }

  Stream<List<RoomReservation>> watchRoomReservations({
    required String roomId,
    DateTime? from,
    DateTime? to,
  }) {
    final normalizedRoomId = roomId.trim();

    if (normalizedRoomId.isEmpty) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('roomSchedules')
        .where('roomId', isEqualTo: normalizedRoomId)
        .snapshots()
        .map((snapshot) {
      final reservations = <String, RoomReservation>{};

      for (final document in snapshot.docs) {
        final values = _readReservations(document.data()['reservations']);

        for (final entry in values.entries) {
          if (entry.value is! Map) continue;

          try {
            final reservation = RoomReservation.fromMap(
              Map<String, dynamic>.from(entry.value as Map),
              fallbackId: entry.key,
            );

            if (!reservation.active) continue;

            if (from != null && !reservation.checkOut.isAfter(from)) {
              continue;
            }

            if (to != null && !reservation.checkIn.isBefore(to)) {
              continue;
            }

            reservations[reservation.bookingId] = reservation;
          } catch (error, stackTrace) {
            developer.log(
              'Lịch phòng ${entry.key} không hợp lệ.',
              name: 'CustomerService.watchRoomReservations',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
      }

      final result = reservations.values.toList()
        ..sort((first, second) => first.checkIn.compareTo(second.checkIn));

      return result;
    });
  }

  Stream<List<BookingModel>> watchMyBookings() {
    return _firestore
        .collection('bookings')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final bookings = <BookingModel>[];

      for (final document in snapshot.docs) {
        try {
          bookings.add(BookingModel.fromMap(document.data(), document.id));
        } catch (error, stackTrace) {
          developer.log(
            'Booking ${document.id} không hợp lệ.',
            name: 'CustomerService.watchMyBookings',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      bookings.sort((first, second) {
        final firstDate = first.createdAt ?? first.checkIn;
        final secondDate = second.createdAt ?? second.checkIn;
        return secondDate.compareTo(firstDate);
      });

      return bookings;
    });
  }

  Stream<BookingModel?> watchBooking(String bookingId) {
    final normalizedId = bookingId.trim();

    if (normalizedId.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection('bookings')
        .doc(normalizedId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();

      if (data == null) return null;

      final booking = BookingModel.fromMap(data, snapshot.id);

      if (booking.customerId != customerId) {
        throw StateError('Bạn không có quyền xem đơn này.');
      }

      return booking;
    });
  }

  Future<PricingQuote> calculatePrice({
    required RoomModel room,
    required DateTime checkIn,
    required DateTime checkOut,
    String ratePlanId = '',
    RoomRatePlan? ratePlan,
  }) async {
    _validateBookingTime(checkIn, checkOut);

    final selectedPlan = ratePlan ?? _findRatePlan(room, ratePlanId);

    final holidays = await _holidayService.getHolidaysForRange(
      checkIn: checkIn,
      checkOut: checkOut,
    );

    return HourlyPricingService(holidays: holidays).calculate(
      checkIn: checkIn,
      checkOut: checkOut,
      firstHourPrice: room.effectiveFirstHourPrice,
      additionalHourPrice: room.effectiveAdditionalHourPrice,
      weekendSurchargePercent: room.weekendSurchargePercent,
      holidaySurchargePercent: room.holidaySurchargePercent,
      ratePlan: selectedPlan,
    );
  }

  Future<List<PricingQuote>> calculateAvailablePrices({
    required RoomModel room,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    _validateBookingTime(checkIn, checkOut);

    final holidays = await _holidayService.getHolidaysForRange(
      checkIn: checkIn,
      checkOut: checkOut,
    );

    return HourlyPricingService(holidays: holidays).calculateAvailableQuotes(
      checkIn: checkIn,
      checkOut: checkOut,
      firstHourPrice: room.effectiveFirstHourPrice,
      additionalHourPrice: room.effectiveAdditionalHourPrice,
      weekendSurchargePercent: room.weekendSurchargePercent,
      holidaySurchargePercent: room.holidaySurchargePercent,
      ratePlans: room.enabledRatePlans,
    );
  }

  Future<String> createBooking({
    required HotelModel hotel,
    required RoomModel room,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    String customerName = '',
    String customerEmail = '',
    String customerPhone = '',
    String specialRequests = '',
    String ratePlanId = '',
    String userVoucherId = '',
  }) async {
    final user = _requireUser();

    _validateBookingTime(checkIn, checkOut);

    if (hotel.id.trim().isEmpty || room.id.trim().isEmpty) {
      throw StateError('Khách sạn hoặc phòng không hợp lệ.');
    }

    final results = await Future.wait([
      _firestore.collection('hotels').doc(hotel.id).get(),
      _firestore.collection('rooms').doc(room.id).get(),
    ]);

    final hotelData = results[0].data();
    final roomData = results[1].data();

    if (hotelData == null || roomData == null) {
      throw StateError('Khách sạn hoặc phòng không còn tồn tại.');
    }

    final currentHotel = HotelModel.fromMap(hotelData, results[0].id);
    final currentRoom = RoomModel.fromMap(roomData, results[1].id);

    if (!currentHotel.isVisible) {
      throw StateError('Khách sạn hiện không nhận đặt phòng.');
    }

    if (!currentRoom.isAvailable) {
      throw StateError('Phòng hiện đang tạm đóng.');
    }

    final belongsToHotel = currentRoom.hotelId == currentHotel.id ||
        (currentRoom.hotelId.isEmpty &&
            _normalize(currentRoom.hotelName) == _normalize(currentHotel.name));

    if (!belongsToHotel) {
      throw StateError('Phòng không thuộc khách sạn đã chọn.');
    }

    if (guests <= 0 || guests > currentRoom.maxGuests) {
      throw StateError('Phòng phù hợp tối đa ${currentRoom.maxGuests} khách.');
    }

    final providerId = currentRoom.providerId.isNotEmpty
        ? currentRoom.providerId
        : currentHotel.providerId;

    if (providerId.isEmpty) {
      throw StateError('Phòng chưa liên kết với nhà cung cấp.');
    }

    final name = customerName.trim().isNotEmpty
        ? customerName.trim()
        : user.displayName?.trim() ?? '';

    final email = customerEmail.trim().isNotEmpty
        ? customerEmail.trim().toLowerCase()
        : user.email?.trim().toLowerCase() ?? '';

    final phone = customerPhone.trim().isNotEmpty
        ? customerPhone.trim()
        : user.phoneNumber?.trim() ?? '';

    if (name.length < 2) {
      throw StateError('Vui lòng nhập họ tên người nhận phòng.');
    }

    if (!_isValidEmail(email)) {
      throw StateError('Email không hợp lệ.');
    }

    if (!_isValidPhone(phone)) {
      throw StateError('Số điện thoại không hợp lệ.');
    }

    final selectedPlan = _findRatePlan(currentRoom, ratePlanId);

    final quote = await calculatePrice(
      room: currentRoom,
      checkIn: checkIn,
      checkOut: checkOut,
      ratePlan: selectedPlan,
    );

    final bookingReference = _firestore.collection('bookings').doc();

    final scheduleIds = _scheduleIds(
      currentRoom.id,
      checkIn,
      checkOut,
    );

    final nights = (quote.durationMinutes / 1440).ceil();

    final booking = BookingModel(
      id: bookingReference.id,
      customerId: user.uid,
      customerName: name,
      customerEmail: email,
      customerPhone: phone,
      specialRequests: specialRequests.trim(),
      providerId: providerId,
      hotelId: currentHotel.id,
      hotelName: currentHotel.name,
      roomId: currentRoom.id,
      roomNumber: currentRoom.roomNumber,
      roomType: currentRoom.type,
      checkIn: checkIn,
      checkOut: checkOut,
      guests: guests,
      pricePerNight: currentRoom.price,
      nights: nights < 1 ? 1 : nights,
      baseHourlyPrice: currentRoom.effectiveFirstHourPrice,
      firstHourPrice: quote.effectiveFirstHourPrice,
      additionalHourPrice: quote.effectiveAdditionalHourPrice,
      durationMinutes: quote.durationMinutes,
      ratePlanId: quote.ratePlanId,
      ratePlanName: quote.ratePlanName,
      ratePlanType: quote.ratePlanType,
      ratePlanPrice: quote.ratePlanPrice,
      overtimeAmount: quote.overtimeAmount,
      weekendSurchargePercent: quote.weekendSurchargePercent,
      holidaySurchargePercent: quote.holidaySurchargePercent,
      calendarSurchargeAmount: quote.calendarSurchargeAmount,
      pricingBreakdown: quote.breakdown,
      subtotalAmount: quote.totalAmount,
      totalAmount: quote.totalAmount,
      status: BookingStatus.pendingProvider,
      paymentMethod: PaymentMethod.vietQr,
      paymentStatus: PaymentStatus.unpaid,
      paymentReference: _paymentReference(bookingReference.id),
      commissionRate: 0.10,
      commissionAmount: _roundToThousand(quote.totalAmount * 0.10),
    );

    await _createBookingTransaction(
      reference: bookingReference,
      booking: booking,
      scheduleIds: scheduleIds,
      userVoucherId: userVoucherId,
      additionalData: {
        'pricingRules': quote.appliedRules,
        'billedMinutes': quote.billedMinutes,
        'pricingSubtotal': quote.subtotal,
      },
    );

    return bookingReference.id;
  }

  Future<void> _createBookingTransaction({
    required DocumentReference<Map<String, dynamic>> reference,
    required BookingModel booking,
    required List<String> scheduleIds,
    required Map<String, dynamic> additionalData,
    String userVoucherId = '',
  }) async {
    final scheduleReferences = scheduleIds
        .map((id) => _firestore.collection('roomSchedules').doc(id))
        .toList();

    await _firestore.runTransaction((transaction) async {
      final scheduleSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final scheduleReference in scheduleReferences) {
        scheduleSnapshots.add(await transaction.get(scheduleReference));
      }

      final normalizedUserVoucherId = userVoucherId.trim();
      DocumentReference<Map<String, dynamic>>? userVoucherRef;
      DocumentReference<Map<String, dynamic>>? voucherRef;
      UserVoucherModel? userVoucher;
      VoucherModel? voucher;

      if (normalizedUserVoucherId.isNotEmpty) {
        userVoucherRef =
            _firestore.collection('userVouchers').doc(normalizedUserVoucherId);

        final userVoucherSnapshot = await transaction.get(userVoucherRef);

        if (!userVoucherSnapshot.exists) {
          throw StateError('Không tìm thấy voucher của bạn.');
        }

        userVoucher = UserVoucherModel.fromDoc(userVoucherSnapshot);

        if (userVoucher.userId != booking.customerId) {
          throw StateError('Bạn không có quyền dùng voucher này.');
        }

        if (!userVoucher.canUse) {
          throw StateError('Voucher không còn khả dụng.');
        }

        voucherRef = _firestore.collection('vouchers').doc(userVoucher.voucherId);

        final voucherSnapshot = await transaction.get(voucherRef);

        if (!voucherSnapshot.exists) {
          throw StateError('Voucher gốc không còn tồn tại.');
        }

        voucher = VoucherModel.fromDoc(voucherSnapshot);

        if (!voucher.canUse) {
          throw StateError('Voucher không còn khả dụng.');
        }

        if (voucher.target != VoucherTarget.all &&
            voucher.target != VoucherTarget.booking) {
          throw StateError('Voucher này không áp dụng cho đặt phòng.');
        }
      }

      final reservationMaps = <Map<String, dynamic>>[];

      for (final snapshot in scheduleSnapshots) {
        final reservations = _readReservations(snapshot.data()?['reservations']);

        for (final entry in reservations.entries) {
          if (entry.value is! Map) continue;

          final reservation = RoomReservation.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
            fallbackId: entry.key,
          );

          if (reservation.overlaps(booking.checkIn, booking.checkOut)) {
            throw StateError(
              'Phòng đã được đặt trong khung giờ này. Vui lòng chọn thời gian khác.',
            );
          }
        }

        reservationMaps.add(reservations);
      }

      var finalBooking = booking;

      if (userVoucher != null &&
          voucher != null &&
          userVoucherRef != null &&
          voucherRef != null) {
        final discount = voucher
            .calculateDiscount(booking.totalAmount)
            .clamp(0, booking.totalAmount)
            .toDouble();

        if (discount <= 0) {
          throw StateError('Voucher không đủ điều kiện áp dụng cho đơn này.');
        }

        final payable = (booking.totalAmount - discount).clamp(0, double.infinity);

        finalBooking = booking.copyWith(
          subtotalAmount: booking.totalAmount,
          totalAmount: payable.toDouble(),
          voucherId: voucher.id,
          userVoucherId: userVoucher.id,
          voucherCode: userVoucher.code,
          voucherTitle: userVoucher.title,
          voucherDiscountAmount: discount,
          commissionAmount: _roundToThousand(
            payable.toDouble() * booking.effectiveCommissionRate,
          ),
        );

        transaction.update(userVoucherRef, {
          'status': UserVoucherStatus.reserved.name,
          'bookingId': finalBooking.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(reference, {
        ...finalBooking.toMap(),
        ...additionalData,
        'scheduleIds': scheduleIds,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (var index = 0; index < scheduleReferences.length; index++) {
        final reservations = reservationMaps[index];

        reservations[finalBooking.id] = RoomReservation(
          bookingId: finalBooking.id,
          roomId: finalBooking.roomId,
          providerId: finalBooking.providerId,
          checkIn: finalBooking.checkIn,
          checkOut: finalBooking.checkOut,
          active: true,
        ).toMap();

        transaction.set(
          scheduleReferences[index],
          {
            'roomId': finalBooking.roomId,
            'yearMonth': scheduleIds[index].split('_').last,
            'reservations': reservations,
            'lastBookingId': finalBooking.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  Future<void> submitPayment(String bookingId) async {
    final user = _requireUser();

    final reference = _firestore.collection('bookings').doc(bookingId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();

      if (data == null) {
        throw StateError('Không tìm thấy đơn đặt phòng.');
      }

      final booking = BookingModel.fromMap(data, snapshot.id);

      if (booking.customerId != user.uid) {
        throw StateError('Bạn không có quyền thanh toán đơn này.');
      }

      if (!booking.canCustomerPay) {
        throw StateError('Đơn chưa thể thanh toán hoặc đã quá hạn.');
      }

      if (!booking.hasReceiverAccount) {
        throw StateError('Nhà cung cấp chưa có tài khoản nhận tiền.');
      }

      transaction.update(reference, {
        'status': BookingStatus.paymentReview,
        'paymentStatus': PaymentStatus.submitted,
        'paymentSubmittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelBooking(BookingModel booking) async {
    final user = _requireUser();
    final reference = _firestore.collection('bookings').doc(booking.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();

      if (data == null) {
        throw StateError('Không tìm thấy đơn đặt phòng.');
      }

      final current = BookingModel.fromMap(data, snapshot.id);

      if (current.customerId != user.uid) {
        throw StateError('Bạn không có quyền hủy đơn này.');
      }

      if (!current.canCustomerCancel) {
        throw StateError('Đơn này không còn được phép hủy.');
      }

      final scheduleIds = _readScheduleIds(data, current);

      final scheduleReferences = scheduleIds
          .map((id) => _firestore.collection('roomSchedules').doc(id))
          .toList();

      final scheduleSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final scheduleReference in scheduleReferences) {
        scheduleSnapshots.add(await transaction.get(scheduleReference));
      }

      DocumentSnapshot<Map<String, dynamic>>? userVoucherSnapshot;
      DocumentReference<Map<String, dynamic>>? userVoucherRef;

      if (current.userVoucherId.trim().isNotEmpty) {
        userVoucherRef =
            _firestore.collection('userVouchers').doc(current.userVoucherId);
        userVoucherSnapshot = await transaction.get(userVoucherRef);
      }

      transaction.update(reference, {
        'status': BookingStatus.cancelled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (userVoucherRef != null &&
          userVoucherSnapshot != null &&
          userVoucherSnapshot.exists) {
        final userVoucher = UserVoucherModel.fromDoc(userVoucherSnapshot);

        if (userVoucher.status == UserVoucherStatus.reserved &&
            userVoucher.bookingId == current.id) {
          transaction.update(userVoucherRef, {
            'status': UserVoucherStatus.available.name,
            'bookingId': '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      for (var index = 0; index < scheduleReferences.length; index++) {
        final schedule = scheduleSnapshots[index];

        if (!schedule.exists) continue;

        final reservations = _readReservations(schedule.data()?['reservations']);
        final oldValue = reservations[current.id];

        if (oldValue is! Map) continue;

        reservations[current.id] = {
          ...Map<String, dynamic>.from(oldValue),
          'active': false,
        };

        transaction.update(
          scheduleReferences[index],
          {
            'reservations': reservations,
            'lastBookingId': current.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    });
  }

  RoomRatePlan? _findRatePlan(RoomModel room, String ratePlanId) {
    final normalized = ratePlanId.trim();

    if (normalized.isEmpty) return null;

    for (final plan in room.enabledRatePlans) {
      if (plan.id == normalized) {
        return plan;
      }
    }

    throw StateError('Combo không tồn tại hoặc đã ngừng áp dụng.');
  }

  List<String> _scheduleIds(
    String roomId,
    DateTime checkIn,
    DateTime checkOut,
  ) {
    final ids = <String>[];

    var cursor = DateTime(checkIn.year, checkIn.month);

    final lastMoment = checkOut.subtract(const Duration(microseconds: 1));
    final lastMonth = DateTime(lastMoment.year, lastMoment.month);

    while (!cursor.isAfter(lastMonth)) {
      final month = cursor.month.toString().padLeft(2, '0');
      ids.add('${roomId}_${cursor.year}$month');
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return ids;
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

    return _scheduleIds(booking.roomId, booking.checkIn, booking.checkOut);
  }

  Map<String, dynamic> _readReservations(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  void _validateBookingTime(DateTime checkIn, DateTime checkOut) {
    if (!_isWholeHour(checkIn) || !_isWholeHour(checkOut)) {
      throw StateError('Giờ nhận và trả phòng phải là giờ tròn.');
    }

    if (checkIn.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      throw StateError('Thời gian nhận phòng không được ở quá khứ.');
    }

    if (!checkOut.isAfter(checkIn)) {
      throw StateError('Giờ trả phòng phải sau giờ nhận phòng.');
    }

    final duration = checkOut.difference(checkIn);

    if (duration.inMinutes % 60 != 0) {
      throw StateError('Thời gian thuê phải tăng theo bước 1 giờ.');
    }

    if (duration < const Duration(hours: 1)) {
      throw StateError('Thời gian thuê tối thiểu là 1 giờ.');
    }

    if (duration > const Duration(days: 30)) {
      throw StateError('Mỗi đơn chỉ được đặt tối đa 30 ngày.');
    }
  }

  bool _isWholeHour(DateTime value) {
    return value.minute == 0 &&
        value.second == 0 &&
        value.millisecond == 0 &&
        value.microsecond == 0;
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn cần đăng nhập để đặt phòng.');
    }

    return user;
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }

  bool _isValidPhone(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[\s.-]'), '');
    return RegExp(r'^(?:0[0-9]{9}|\+84[0-9]{9})$').hasMatch(normalized);
  }

  String _paymentReference(String bookingId) {
    final value = bookingId
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();

    final shortId = value.length > 12 ? value.substring(0, 12) : value;
    return 'BOOKING_$shortId';
  }

  int _compareRoomNumbers(String first, String second) {
    final firstNumber = int.tryParse(first.trim());
    final secondNumber = int.tryParse(second.trim());

    if (firstNumber != null && secondNumber != null) {
      return firstNumber.compareTo(secondNumber);
    }

    return first.toLowerCase().compareTo(second.toLowerCase());
  }

  int _compareHotelsForCustomer(HotelModel first, HotelModel second) {
    final firstScore = _hotelCustomerScore(first);
    final secondScore = _hotelCustomerScore(second);

    final scoreCompare = secondScore.compareTo(firstScore);
    if (scoreCompare != 0) return scoreCompare;

    return first.name.toLowerCase().compareTo(second.name.toLowerCase());
  }

  double _hotelCustomerScore(HotelModel hotel) {
    var score = 0.0;

    if (hotel.images.isNotEmpty || hotel.imageUrl.trim().isNotEmpty) {
      score += 10;
    }

    if (hotel.effectiveMinFirstHourPrice > 0) {
      score += 10;
    }

    if (hotel.hasReviews) {
      score += hotel.rating * 12;
      score += hotel.reviewCount.clamp(0, 500) * 0.04;
    }

    if (hotel.hasContactInformation) {
      score += 4;
    }

    if (hotel.description.trim().isNotEmpty) {
      score += 3;
    }

    return score;
  }

  double _roundToThousand(double value) {
    return (value / 1000).round() * 1000;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  String _normalizeLocation(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('tỉnh ', '')
        .replaceAll('thành phố ', '')
        .replaceAll('tp. ', '')
        .replaceAll('tp ', '')
        .replaceAll('quận ', '')
        .replaceAll('huyện ', '')
        .replaceAll('thị xã ', '')
        .replaceAll('phường ', '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}