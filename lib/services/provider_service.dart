import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/hotel.dart';
import '../model/room.dart';

class ProviderStats {
  const ProviderStats({
    required this.hotels,
    required this.rooms,
    required this.pendingBookings,
    required this.revenue,
  });

  final int hotels;
  final int rooms;
  final int pendingBookings;
  final double revenue;
}

class ProviderService {
  ProviderService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

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
          final hotels = snapshot.docs.map((document) {
            return HotelModel.fromMap(document.data(), document.id);
          }).toList();

          hotels.sort((a, b) => a.name.compareTo(b.name));
          return hotels;
        });
  }

  Stream<List<RoomModel>> watchRooms({String? hotelId}) {
    return _firestore
        .collection('rooms')
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
          var rooms = snapshot.docs.map((document) {
            return RoomModel.fromMap(document.data(), document.id);
          }).toList();

          if (hotelId != null && hotelId.isNotEmpty) {
            rooms = rooms.where((room) => room.hotelId == hotelId).toList();
          }

          rooms.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
          return rooms;
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBookings({
    String status = 'all',
  }) {
    final collection = _firestore
        .collection('bookings')
        .where('providerId', isEqualTo: providerId);

    if (status == 'all') return collection.snapshots();

    return collection.where('status', isEqualTo: status).snapshots();
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

    final bookings = results[2].docs;
    var pendingBookings = 0;
    var revenue = 0.0;

    for (final document in bookings) {
      final data = document.data();
      final status = data['status'];
      final amount = data['totalAmount'];

      if (status == 'pending') pendingBookings++;

      if ((status == 'confirmed' || status == 'completed') && amount is num) {
        revenue += amount.toDouble();
      }
    }

    return ProviderStats(
      hotels: results[0].docs.length,
      rooms: results[1].docs.length,
      pendingBookings: pendingBookings,
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
  }) async {
    final normalizedImages = images
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedImages.isEmpty) {
      throw StateError('Khách sạn phải có ít nhất một ảnh.');
    }

    if (province.trim().isEmpty || district.trim().isEmpty) {
      throw StateError('Vui lòng nhập tỉnh/thành phố và quận/huyện.');
    }

    final reference = _firestore.collection('hotels').doc();

    await reference.set({
      'providerId': providerId,
      'name': name.trim(),
      'address': address.trim(),
      'province': province.trim(),
      'district': district.trim(),
      'description': description.trim(),
      'imageUrl': normalizedImages.first,
      'images': normalizedImages,
      'category': category.trim(),
      'status': 'approved',
      'rating': 0.0,
      'minPrice': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateHotel(HotelModel hotel) async {
    _ensureOwnership(hotel.providerId);

    await _firestore.collection('hotels').doc(hotel.id).update({
      ...hotel.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteHotel(HotelModel hotel) async {
    _ensureOwnership(hotel.providerId);

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

    batch.delete(_firestore.collection('hotels').doc(hotel.id));

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
    List<String> images = const [],
  }) async {
    await _ensureHotelOwnership(hotelId);

    final duplicate = await _firestore
        .collection('rooms')
        .where('hotelId', isEqualTo: hotelId)
        .where('roomNumber', isEqualTo: roomNumber.trim())
        .get();

    if (duplicate.docs.isNotEmpty) {
      throw StateError('Số phòng đã tồn tại trong khách sạn.');
    }

    await _firestore.collection('rooms').add({
      'hotelId': hotelId,
      'providerId': providerId,
      'roomNumber': roomNumber.trim(),
      'type': type.trim(),
      'price': price,
      'maxGuests': maxGuests,
      'description': description.trim(),
      'isAvailable': isAvailable,
      'images': images,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _synchronizeMinimumPrice(hotelId);
  }

  Future<void> updateRoom(RoomModel room) async {
    _ensureOwnership(room.providerId);
    await _ensureHotelOwnership(room.hotelId);

    await _firestore.collection('rooms').doc(room.id).update({
      ...room.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _synchronizeMinimumPrice(room.hotelId);
  }

  Future<void> deleteRoom(RoomModel room) async {
    _ensureOwnership(room.providerId);

    await _firestore.collection('rooms').doc(room.id).delete();
    await _synchronizeMinimumPrice(room.hotelId);
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    const allowedStatuses = {'confirmed', 'rejected', 'completed', 'cancelled'};

    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('Trạng thái đơn không hợp lệ.');
    }

    final reference = _firestore.collection('bookings').doc(bookingId);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (data == null) {
      throw StateError('Không tìm thấy đơn đặt phòng.');
    }

    _ensureOwnership(data['providerId'] as String? ?? '');

    await reference.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureHotelOwnership(String hotelId) async {
    final snapshot = await _firestore.collection('hotels').doc(hotelId).get();

    final ownerId = snapshot.data()?['providerId'];

    if (!snapshot.exists || ownerId != providerId) {
      throw StateError('Bạn không có quyền quản lý khách sạn này.');
    }
  }

  Future<void> _synchronizeMinimumPrice(String hotelId) async {
    final rooms = await _firestore
        .collection('rooms')
        .where('hotelId', isEqualTo: hotelId)
        .get();

    final prices = rooms.docs
        .map((document) => document.data()['price'])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();

    final minimumPrice = prices.isEmpty
        ? 0.0
        : prices.reduce((a, b) => a < b ? a : b);

    await _firestore.collection('hotels').doc(hotelId).update({
      'minPrice': minimumPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _ensureOwnership(String ownerId) {
    if (ownerId != providerId) {
      throw StateError('Bạn không có quyền thay đổi dữ liệu này.');
    }
  }
}
