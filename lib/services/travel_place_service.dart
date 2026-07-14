import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/saved_place.dart';
import '../model/travel_place.dart';

class TravelPlaceService {
  TravelPlaceService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _placesRef {
    return _firestore.collection('travelPlaces');
  }

  CollectionReference<Map<String, dynamic>> get _savedPlacesRef {
    return _firestore.collection('savedPlaces');
  }

  Stream<List<TravelPlaceModel>> watchFeaturedPlaces({
    int limit = 10,
  }) {
    return _placesRef
        .where('isActive', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final places = snapshot.docs.map(TravelPlaceModel.fromDoc).toList();

      places.sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;
        return b.reviewCount.compareTo(a.reviewCount);
      });

      return places;
    }).handleError((error, stackTrace) {
      developer.log(
        'watchFeaturedPlaces failed',
        name: 'TravelPlaceService',
        error: error,
        stackTrace: stackTrace,
      );
      throw error;
    });
  }

  Stream<List<TravelPlaceModel>> watchPlaces({
    TravelPlaceCategory? category,
    String province = '',
    String district = '',
    String keyword = '',
    bool onlyActive = true,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _placesRef;

    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (category != null && category != TravelPlaceCategory.other) {
      query = query.where('category', isEqualTo: category.name);
    }

    if (province.trim().isNotEmpty) {
      query = query.where('province', isEqualTo: province.trim());
    }

    if (district.trim().isNotEmpty) {
      query = query.where('district', isEqualTo: district.trim());
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      final normalizedKeyword = _normalize(keyword);

      final places = snapshot.docs.map(TravelPlaceModel.fromDoc).where((place) {
        if (normalizedKeyword.isEmpty) return true;

        final source = _normalize(
          '${place.name} ${place.description} ${place.fullAddress} '
          '${place.category.label} ${place.tags.join(' ')}',
        );

        return source.contains(normalizedKeyword);
      }).toList();

      places.sort((a, b) {
        if (a.isFeatured != b.isFeatured) {
          return a.isFeatured ? -1 : 1;
        }

        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;

        return a.name.compareTo(b.name);
      });

      return places;
    }).handleError((error, stackTrace) {
      developer.log(
        'watchPlaces failed',
        name: 'TravelPlaceService',
        error: error,
        stackTrace: stackTrace,
      );
      throw error;
    });
  }

  Stream<TravelPlaceModel?> watchPlace(String placeId) {
    if (placeId.trim().isEmpty) {
      return Stream.value(null);
    }

    return _placesRef.doc(placeId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TravelPlaceModel.fromDoc(doc);
    });
  }

  Future<TravelPlaceModel?> getPlace(String placeId) async {
    if (placeId.trim().isEmpty) return null;

    final doc = await _placesRef.doc(placeId).get();
    if (!doc.exists) return null;

    return TravelPlaceModel.fromDoc(doc);
  }

  Stream<List<SavedPlaceModel>> watchSavedPlaces(String userId) {
    if (userId.trim().isEmpty) {
      return Stream.value(const []);
    }

    return _savedPlacesRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final saved = snapshot.docs.map(SavedPlaceModel.fromDoc).toList();

      saved.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return saved;
    });
  }

  Future<bool> isSaved({
    required String userId,
    required String placeId,
    SavedPlaceType type = SavedPlaceType.travelPlace,
  }) async {
    if (userId.trim().isEmpty || placeId.trim().isEmpty) return false;

    final id = _savedPlaceId(userId, placeId, type);
    final doc = await _savedPlacesRef.doc(id).get();

    return doc.exists;
  }

  Future<void> saveTravelPlace({
    required String userId,
    required TravelPlaceModel place,
    String note = '',
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception('Bạn cần đăng nhập để lưu địa điểm.');
    }

    final saved = SavedPlaceModel(
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

    await _savedPlacesRef.doc(saved.id).set(saved.toMap());
  }

  Future<void> removeSavedPlace({
    required String userId,
    required String placeId,
    SavedPlaceType type = SavedPlaceType.travelPlace,
  }) async {
    if (userId.trim().isEmpty || placeId.trim().isEmpty) return;

    await _savedPlacesRef.doc(_savedPlaceId(userId, placeId, type)).delete();
  }

  Future<void> toggleSavedTravelPlace({
    required String userId,
    required TravelPlaceModel place,
  }) async {
    final currentlySaved = await isSaved(
      userId: userId,
      placeId: place.id,
      type: SavedPlaceType.travelPlace,
    );

    if (currentlySaved) {
      await removeSavedPlace(
        userId: userId,
        placeId: place.id,
        type: SavedPlaceType.travelPlace,
      );
      return;
    }

    await saveTravelPlace(userId: userId, place: place);
  }

  String _savedPlaceId(
    String userId,
    String placeId,
    SavedPlaceType type,
  ) {
    return '${userId}_${type.name}_$placeId';
  }
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}