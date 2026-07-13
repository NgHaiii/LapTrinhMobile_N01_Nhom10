import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/hotel.dart';
import '../model/hotel_rating.dart';
import '../model/review.dart';
import '../model/room.dart';

class RecommendationService {
  RecommendationService({
    FirebaseFirestore? firestore,
  }) : _firestore =
           firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<HotelRecommendation>>
  watchRecommendedHotels({
    String province = '',
    String district = '',
    int limit = 10,
  }) {
    late StreamController<List<HotelRecommendation>>
    controller;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    hotelsSubscription;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    roomsSubscription;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    reviewsSubscription;

    List<HotelModel> hotels = const [];
    List<RoomModel> rooms = const [];
    List<ReviewModel> reviews = const [];

    var hotelsLoaded = false;
    var roomsLoaded = false;
    var reviewsLoaded = false;

    void emit() {
      if (!hotelsLoaded ||
          !roomsLoaded ||
          !reviewsLoaded ||
          controller.isClosed) {
        return;
      }

      final provinceFilter = province.trim().toLowerCase();
      final districtFilter = district.trim().toLowerCase();

      final globalAverage = _globalAverage(reviews);
      final recommendations = <HotelRecommendation>[];

      for (final hotel in hotels) {
        if (!hotel.isVisible) continue;

        if (provinceFilter.isNotEmpty &&
            hotel.province.trim().toLowerCase() !=
                provinceFilter) {
          continue;
        }

        if (districtFilter.isNotEmpty &&
            hotel.district.trim().toLowerCase() !=
                districtFilter) {
          continue;
        }

        final hotelRooms = rooms.where((room) {
          return room.hotelId == hotel.id &&
              room.isAvailable;
        }).toList();

        if (hotelRooms.isEmpty) continue;

        final rating = HotelRating.calculate(
          hotelId: hotel.id,
          rooms: hotelRooms,
          reviews: reviews,
          globalAverage: globalAverage,
        );

        recommendations.add(
          HotelRecommendation(
            hotel: hotel.copyWith(
              rating: rating.averageRating,
              reviewCount: rating.reviewCount,
              reviewedRoomCount: rating.reviewedRoomCount,
              recommendationScore: rating.recommendationScore,
            ),
            rating: rating,
          ),
        );
      }

      recommendations.sort(_compareHotels);

      final safeLimit =
          limit <= 0 ? recommendations.length : limit;

      controller.add(
        recommendations.take(safeLimit).toList(),
      );
    }

    controller =
        StreamController<List<HotelRecommendation>>(
      onListen: () {
        hotelsSubscription = _firestore
            .collection('hotels')
            .snapshots()
            .listen(
              (snapshot) {
                hotels = _readHotels(snapshot);
                hotelsLoaded = true;
                emit();
              },
              onError: controller.addError,
            );

        roomsSubscription = _firestore
            .collection('rooms')
            .snapshots()
            .listen(
              (snapshot) {
                rooms = _readRooms(snapshot);
                roomsLoaded = true;
                emit();
              },
              onError: controller.addError,
            );

        reviewsSubscription = _firestore
            .collection('reviews')
            .where(
              'status',
              isEqualTo: ReviewStatus.published,
            )
            .snapshots()
            .listen(
              (snapshot) {
                reviews = _readReviews(snapshot);
                reviewsLoaded = true;
                emit();
              },
              onError: controller.addError,
            );
      },
      onCancel: () async {
        await hotelsSubscription?.cancel();
        await roomsSubscription?.cancel();
        await reviewsSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<List<RoomRecommendation>>
  watchRecommendedRooms({
    required String hotelId,
    int guests = 1,
    int limit = 20,
  }) {
    final normalizedHotelId = hotelId.trim();

    if (normalizedHotelId.isEmpty) {
      return Stream.value(const []);
    }

    late StreamController<List<RoomRecommendation>>
    controller;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    roomsSubscription;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    reviewsSubscription;

    List<RoomModel> rooms = const [];
    List<ReviewModel> reviews = const [];

    var roomsLoaded = false;
    var reviewsLoaded = false;

    void emit() {
      if (!roomsLoaded ||
          !reviewsLoaded ||
          controller.isClosed) {
        return;
      }

      final globalAverage = _globalAverage(reviews);
      final result = <RoomRecommendation>[];

      for (final room in rooms) {
        if (!room.isAvailable) continue;
        if (guests > 0 && room.maxGuests < guests) continue;

        final rating = RoomRating.calculate(
          roomId: room.id,
          hotelId: room.hotelId,
          reviews: reviews,
          globalAverage: globalAverage,
        );

        result.add(
          RoomRecommendation(
            room: room,
            rating: rating,
          ),
        );
      }

      result.sort(_compareRooms);

      final safeLimit = limit <= 0 ? result.length : limit;
      controller.add(result.take(safeLimit).toList());
    }

    controller = StreamController<List<RoomRecommendation>>(
      onListen: () {
        roomsSubscription = _firestore
            .collection('rooms')
            .where(
              'hotelId',
              isEqualTo: normalizedHotelId,
            )
            .snapshots()
            .listen(
              (snapshot) {
                rooms = _readRooms(snapshot);
                roomsLoaded = true;
                emit();
              },
              onError: controller.addError,
            );

        reviewsSubscription = _firestore
            .collection('reviews')
            .where(
              'hotelId',
              isEqualTo: normalizedHotelId,
            )
            .where(
              'status',
              isEqualTo: ReviewStatus.published,
            )
            .snapshots()
            .listen(
              (snapshot) {
                reviews = _readReviews(snapshot);
                reviewsLoaded = true;
                emit();
              },
              onError: controller.addError,
            );
      },
      onCancel: () async {
        await roomsSubscription?.cancel();
        await reviewsSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<RoomRating> watchRoomRating({
    required String roomId,
    required String hotelId,
  }) {
    final normalizedRoomId = roomId.trim();

    if (normalizedRoomId.isEmpty) {
      return Stream.value(
        RoomRating.empty(
          roomId: '',
          hotelId: hotelId,
        ),
      );
    }

    return _firestore
        .collection('reviews')
        .where('roomId', isEqualTo: normalizedRoomId)
        .where(
          'status',
          isEqualTo: ReviewStatus.published,
        )
        .snapshots()
        .map((snapshot) {
          final reviews = _readReviews(snapshot);

          return RoomRating.calculate(
            roomId: normalizedRoomId,
            hotelId: hotelId,
            reviews: reviews,
            globalAverage: _globalAverage(reviews),
          );
        });
  }

  List<HotelModel> _readHotels(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final result = <HotelModel>[];

    for (final document in snapshot.docs) {
      try {
        result.add(
          HotelModel.fromMap(
            document.data(),
            document.id,
          ),
        );
      } catch (error, stackTrace) {
        developer.log(
          'Khách sạn ${document.id} không hợp lệ.',
          name: 'RecommendationService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return result;
  }

  List<RoomModel> _readRooms(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final result = <RoomModel>[];

    for (final document in snapshot.docs) {
      try {
        result.add(
          RoomModel.fromMap(
            document.data(),
            document.id,
          ),
        );
      } catch (error, stackTrace) {
        developer.log(
          'Phòng ${document.id} không hợp lệ.',
          name: 'RecommendationService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return result;
  }

  List<ReviewModel> _readReviews(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final result = <ReviewModel>[];

    for (final document in snapshot.docs) {
      try {
        result.add(
          ReviewModel.fromMap(
            document.data(),
            document.id,
          ),
        );
      } catch (error, stackTrace) {
        developer.log(
          'Đánh giá ${document.id} không hợp lệ.',
          name: 'RecommendationService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return result;
  }

  double _globalAverage(List<ReviewModel> reviews) {
    final published = reviews
        .where((review) => review.isPublished)
        .toList();

    if (published.isEmpty) return 3.5;

    final total = published.fold<int>(
      0,
      (sum, review) => sum + review.rating,
    );

    return total / published.length;
  }
}

int _compareHotels(
  HotelRecommendation first,
  HotelRecommendation second,
) {
  final score = second.rating.recommendationScore
      .compareTo(first.rating.recommendationScore);

  if (score != 0) return score;

  final reviews = second.rating.reviewCount
      .compareTo(first.rating.reviewCount);

  if (reviews != 0) return reviews;

  return second.rating.averageRating.compareTo(
    first.rating.averageRating,
  );
}

int _compareRooms(
  RoomRecommendation first,
  RoomRecommendation second,
) {
  final reviewedComparison =
      (second.rating.hasReviews ? 1 : 0).compareTo(
    first.rating.hasReviews ? 1 : 0,
  );

  if (reviewedComparison != 0) {
    return reviewedComparison;
  }

  final score = second.rating.recommendationScore
      .compareTo(first.rating.recommendationScore);

  if (score != 0) return score;

  final reviews = second.rating.reviewCount
      .compareTo(first.rating.reviewCount);

  if (reviews != 0) return reviews;

  return first.room.roomNumber.compareTo(
    second.room.roomNumber,
  );
}