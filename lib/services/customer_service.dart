import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/booking.dart';
import '../model/hotel.dart';
import '../model/room.dart';

class CustomerService {
  CustomerService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get customerId {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw StateError('Bạn cần đăng nhập để thực hiện chức năng này.');
    }

    return uid;
  }

  /// Theo dõi những khách sạn được phép hiển thị.
  ///
  /// Không lọc status trực tiếp trong câu truy vấn để dữ liệu cũ
  /// chưa có field status vẫn được đọc.
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
            'Hotel document ${document.id} bị lỗi dữ liệu.',
            name: 'CustomerService.watchHotels',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      hotels.sort((first, second) {
        return first.name.toLowerCase().compareTo(second.name.toLowerCase());
      });

      return hotels;
    });
  }

  /// Theo dõi phòng thuộc một khách sạn.
  ///
  /// Có hỗ trợ dữ liệu cũ dùng hotelID, hotel_id hoặc hotelName
  /// thông qua RoomModel.fromMap().
  Stream<List<RoomModel>> watchRooms({
    required String hotelId,
    String hotelName = '',
  }) {
    final normalizedHotelId = hotelId.trim();
    final normalizedHotelName = _normalize(hotelName);

    if (normalizedHotelId.isEmpty) {
      return Stream.value(const <RoomModel>[]);
    }

    return _firestore.collection('rooms').snapshots().map((snapshot) {
      final rooms = <RoomModel>[];

      for (final document in snapshot.docs) {
        try {
          final room = RoomModel.fromMap(document.data(), document.id);

          final matchesId = room.hotelId.trim() == normalizedHotelId;

          final matchesLegacyName =
              room.hotelId.trim().isEmpty &&
              normalizedHotelName.isNotEmpty &&
              _normalize(room.hotelName) == normalizedHotelName;

          if (matchesId || matchesLegacyName) {
            rooms.add(room);
          }
        } catch (error, stackTrace) {
          developer.log(
            'Room document ${document.id} bị lỗi dữ liệu.',
            name: 'CustomerService.watchRooms',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      rooms.sort((first, second) {
        return _compareRoomNumbers(first.roomNumber, second.roomNumber);
      });

      return rooms;
    });
  }

  /// Theo dõi đơn đặt phòng của tài khoản hiện tại.
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
            'Booking document ${document.id} bị lỗi dữ liệu.',
            name: 'CustomerService.watchMyBookings',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      bookings.sort((first, second) {
        final firstTime = first.createdAt?.millisecondsSinceEpoch ?? 0;
        final secondTime = second.createdAt?.millisecondsSinceEpoch ?? 0;

        return secondTime.compareTo(firstTime);
      });

      return bookings;
    });
  }

  /// Tạo đơn đặt phòng ở trạng thái chờ nhà cung cấp xác nhận.
  ///
  /// Giá tiền và thông tin phòng được đọc lại từ Firestore,
  /// không tin dữ liệu giá gửi trực tiếp từ giao diện.
  Future<String> createBooking({
    required HotelModel hotel,
    required RoomModel room,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn cần đăng nhập để đặt phòng.');
    }

    final normalizedCheckIn = _dateOnly(checkIn);
    final normalizedCheckOut = _dateOnly(checkOut);
    final today = _dateOnly(DateTime.now());

    if (normalizedCheckIn.isBefore(today)) {
      throw StateError('Ngày nhận phòng không được nhỏ hơn ngày hiện tại.');
    }

    if (!normalizedCheckOut.isAfter(normalizedCheckIn)) {
      throw StateError('Ngày trả phòng phải sau ngày nhận phòng.');
    }

    if (guests <= 0) {
      throw StateError('Số lượng khách phải lớn hơn 0.');
    }

    final results = await Future.wait([
      _firestore.collection('hotels').doc(hotel.id).get(),
      _firestore.collection('rooms').doc(room.id).get(),
    ]);

    final hotelSnapshot = results[0];
    final roomSnapshot = results[1];

    if (!hotelSnapshot.exists) {
      throw StateError('Khách sạn không còn tồn tại.');
    }

    if (!roomSnapshot.exists) {
      throw StateError('Phòng không còn tồn tại.');
    }

    final hotelData = hotelSnapshot.data();
    final roomData = roomSnapshot.data();

    if (hotelData == null || roomData == null) {
      throw StateError('Không thể đọc dữ liệu khách sạn hoặc phòng.');
    }

    final currentHotel = HotelModel.fromMap(hotelData, hotelSnapshot.id);
    final currentRoom = RoomModel.fromMap(roomData, roomSnapshot.id);

    if (!currentHotel.isVisible) {
      throw StateError('Khách sạn hiện không nhận đặt phòng.');
    }

    final belongsToHotel =
        currentRoom.hotelId == currentHotel.id ||
        (currentRoom.hotelId.isEmpty &&
            _normalize(currentRoom.hotelName) == _normalize(currentHotel.name));

    if (!belongsToHotel) {
      throw StateError('Phòng không thuộc khách sạn đã chọn.');
    }

    if (!currentRoom.isAvailable) {
      throw StateError('Phòng hiện đang tạm đóng.');
    }

    if (guests > currentRoom.maxGuests) {
      throw StateError(
        'Phòng chỉ phù hợp tối đa ${currentRoom.maxGuests} khách.',
      );
    }

    if (currentRoom.price <= 0) {
      throw StateError('Phòng chưa có giá hợp lệ.');
    }

    final nights = normalizedCheckOut.difference(normalizedCheckIn).inDays;

    if (nights <= 0) {
      throw StateError('Số đêm lưu trú không hợp lệ.');
    }

    await _ensureNoCustomerDuplicate(
      roomId: currentRoom.id,
      checkIn: normalizedCheckIn,
      checkOut: normalizedCheckOut,
    );

    final totalAmount = currentRoom.price * nights;
    final bookingReference = _firestore.collection('bookings').doc();

    final booking = BookingModel(
      id: bookingReference.id,
      customerId: user.uid,
      customerName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email ?? 'Khách hàng',
      customerEmail: user.email ?? '',
      providerId: currentRoom.providerId.isNotEmpty
          ? currentRoom.providerId
          : currentHotel.providerId,
      hotelId: currentHotel.id,
      hotelName: currentHotel.name,
      roomId: currentRoom.id,
      roomNumber: currentRoom.roomNumber,
      roomType: currentRoom.type,
      checkIn: normalizedCheckIn,
      checkOut: normalizedCheckOut,
      guests: guests,
      pricePerNight: currentRoom.price,
      nights: nights,
      totalAmount: totalAmount,
      status: BookingStatus.pending,
    );

    await bookingReference.set({
      ...booking.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return bookingReference.id;
  }

  /// Hủy đơn của chính khách hàng khi đơn còn chờ xác nhận.
  Future<void> cancelBooking(BookingModel booking) async {
    final uid = customerId;
    final reference = _firestore.collection('bookings').doc(booking.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('Không tìm thấy đơn đặt phòng.');
      }

      final currentBooking = BookingModel.fromMap(data, snapshot.id);

      if (currentBooking.customerId != uid) {
        throw StateError('Bạn không có quyền hủy đơn này.');
      }

      if (!currentBooking.canCustomerCancel) {
        throw StateError('Chỉ có thể hủy đơn đang chờ xác nhận.');
      }

      transaction.update(reference, {
        'status': BookingStatus.cancelled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Ngăn khách hàng tự tạo nhiều đơn trùng phòng và trùng ngày.
  ///
  /// Nhà cung cấp vẫn cần xác nhận đơn để xử lý trường hợp
  /// nhiều khách hàng khác nhau đặt cùng một phòng.
  Future<void> _ensureNoCustomerDuplicate({
    required String roomId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('customerId', isEqualTo: customerId)
        .get();

    for (final document in snapshot.docs) {
      final booking = BookingModel.fromMap(document.data(), document.id);

      if (booking.roomId != roomId) continue;

      if (booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.rejected ||
          booking.status == BookingStatus.completed) {
        continue;
      }

      final overlaps =
          checkIn.isBefore(booking.checkOut) && checkOut.isAfter(booking.checkIn);

      if (overlaps) {
        throw StateError(
          'Bạn đã có một đơn đặt phòng này trong thời gian đã chọn.',
        );
      }
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _compareRoomNumbers(String first, String second) {
    final firstNumber = int.tryParse(first.trim());
    final secondNumber = int.tryParse(second.trim());

    if (firstNumber != null && secondNumber != null) {
      return firstNumber.compareTo(secondNumber);
    }

    return first.toLowerCase().compareTo(second.toLowerCase());
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}