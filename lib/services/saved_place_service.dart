import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/hotel.dart';
import '../model/saved_place.dart';
import '../model/travel_place.dart';

class SavedPlaceService {
  SavedPlaceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _savedPlacesRef {
    return _firestore.collection('savedPlaces');
  }

  String? get currentUserId {
    return _auth.currentUser?.uid;
  }

  Stream<List<SavedPlaceModel>> watchMySavedPlaces({
    SavedPlaceType? type,
  }) {
    final userId = currentUserId;

    if (userId == null) {
      return Stream.value(const []);
    }

    Query<Map<String, dynamic>> query =
        _savedPlacesRef.where('userId', isEqualTo: userId);

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs.map(SavedPlaceModel.fromDoc).toList();

      items.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return items;
    }).handleError((error, stackTrace) {
      developer.log(
        'watchMySavedPlaces failed',
        name: 'SavedPlaceService',
        error: error,
        stackTrace: stackTrace,
      );
      throw error;
    });
  }

  Future<bool> isSaved({
    required String placeId,
    required SavedPlaceType type,
  }) async {
    final userId = currentUserId;

    if (userId == null || placeId.trim().isEmpty) return false;

    final doc = await _savedPlacesRef
        .doc(_savedPlaceId(userId, placeId, type))
        .get();

    return doc.exists;
  }

  Future<void> saveTravelPlace({
    required TravelPlaceModel place,
    String note = '',
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('Bạn cần đăng nhập để lưu địa điểm.');
    }

    final savedPlace = SavedPlaceModel(
      id: _savedPlaceId(userId, place.id, SavedPlaceType.travelPlace),
      userId: userId,
      placeId: place.id,
      name: place.name,
      type: SavedPlaceType.travelPlace,
      imageUrl: place.primaryImage,
      address: place.address,
      province: place.province,
      district: place.district,
      rating: place.rating,
      note: note.trim(),
    );

    await _savedPlacesRef.doc(savedPlace.id).set(savedPlace.toMap());
  }

  Future<void> saveHotel({
    required HotelModel hotel,
    String note = '',
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('Bạn cần đăng nhập để lưu khách sạn.');
    }

    final savedPlace = SavedPlaceModel(
      id: _savedPlaceId(userId, hotel.id, SavedPlaceType.hotel),
      userId: userId,
      placeId: hotel.id,
      name: hotel.name,
      type: SavedPlaceType.hotel,
      imageUrl: _hotelImageUrl(hotel),
      address: hotel.address,
      province: hotel.province,
      district: hotel.district,
      rating: hotel.rating,
      note: note.trim(),
    );

    await _savedPlacesRef.doc(savedPlace.id).set(savedPlace.toMap());
  }

  Future<void> removeSavedPlace({
    required String placeId,
    required SavedPlaceType type,
  }) async {
    final userId = currentUserId;

    if (userId == null || placeId.trim().isEmpty) return;

    await _savedPlacesRef.doc(_savedPlaceId(userId, placeId, type)).delete();
  }

  Future<bool> toggleTravelPlace(TravelPlaceModel place) async {
    final saved = await isSaved(
      placeId: place.id,
      type: SavedPlaceType.travelPlace,
    );

    if (saved) {
      await removeSavedPlace(
        placeId: place.id,
        type: SavedPlaceType.travelPlace,
      );
      return false;
    }

    await saveTravelPlace(place: place);
    return true;
  }

  Future<bool> toggleHotel(HotelModel hotel) async {
    final saved = await isSaved(
      placeId: hotel.id,
      type: SavedPlaceType.hotel,
    );

    if (saved) {
      await removeSavedPlace(
        placeId: hotel.id,
        type: SavedPlaceType.hotel,
      );
      return false;
    }

    await saveHotel(hotel: hotel);
    return true;
  }

  Future<void> updateNote({
    required String savedPlaceId,
    required String note,
  }) async {
    if (savedPlaceId.trim().isEmpty) return;

    await _savedPlacesRef.doc(savedPlaceId).update({
      'note': note.trim(),
    });
  }

  String _savedPlaceId(
    String userId,
    String placeId,
    SavedPlaceType type,
  ) {
    return '${userId}_${type.name}_$placeId';
  }

  String _hotelImageUrl(HotelModel hotel) {
    return hotel.images.isEmpty ? '' : hotel.images.first;
  }
}