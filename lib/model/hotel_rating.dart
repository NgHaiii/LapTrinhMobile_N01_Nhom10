import 'hotel.dart';
import 'review.dart';
import 'room.dart';

class RoomRating {
  const RoomRating({
    required this.roomId,
    required this.hotelId,
    required this.averageRating,
    required this.reviewCount,
    required this.recommendationScore,
    required this.positiveReviewCount,
    required this.ratingDistribution,
  });

  final String roomId;
  final String hotelId;
  final double averageRating;
  final int reviewCount;
  final double recommendationScore;
  final int positiveReviewCount;
  final Map<int, int> ratingDistribution;

  bool get hasReviews => reviewCount > 0;

  double get positiveRatio {
    if (reviewCount == 0) return 0;
    return positiveReviewCount / reviewCount;
  }

  int countForRating(int rating) {
    return ratingDistribution[rating] ?? 0;
  }

  factory RoomRating.calculate({
    required String roomId,
    required String hotelId,
    required Iterable<ReviewModel> reviews,
    double globalAverage = 3.5,
    int minimumReviewWeight = 5,
  }) {
    final validReviews = reviews.where((review) {
      return review.isPublished &&
          review.roomId == roomId &&
          review.rating >= 1 &&
          review.rating <= 5;
    }).toList();

    final summary = _calculateSummary(
      reviews: validReviews,
      globalAverage: globalAverage,
      minimumReviewWeight: minimumReviewWeight,
    );

    return RoomRating(
      roomId: roomId,
      hotelId: hotelId,
      averageRating: summary.averageRating,
      reviewCount: summary.reviewCount,
      recommendationScore: summary.recommendationScore,
      positiveReviewCount: summary.positiveReviewCount,
      ratingDistribution: summary.ratingDistribution,
    );
  }

  static RoomRating empty({
    required String roomId,
    required String hotelId,
  }) {
    return RoomRating(
      roomId: roomId,
      hotelId: hotelId,
      averageRating: 0,
      reviewCount: 0,
      recommendationScore: 0,
      positiveReviewCount: 0,
      ratingDistribution: const {
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
      },
    );
  }
}

class HotelRating {
  const HotelRating({
    required this.hotelId,
    required this.averageRating,
    required this.reviewCount,
    required this.recommendationScore,
    required this.positiveReviewCount,
    required this.reviewedRoomCount,
    required this.ratingDistribution,
    required this.roomRatings,
  });

  final String hotelId;

  // Tổng hợp từ tất cả review phòng thuộc khách sạn.
  final double averageRating;
  final int reviewCount;
  final double recommendationScore;
  final int positiveReviewCount;
  final int reviewedRoomCount;

  final Map<int, int> ratingDistribution;
  final Map<String, RoomRating> roomRatings;

  bool get hasReviews => reviewCount > 0;

  double get positiveRatio {
    if (reviewCount == 0) return 0;
    return positiveReviewCount / reviewCount;
  }

  RoomRating ratingForRoom(String roomId) {
    return roomRatings[roomId] ??
        RoomRating.empty(
          roomId: roomId,
          hotelId: hotelId,
        );
  }

  factory HotelRating.calculate({
    required String hotelId,
    required Iterable<ReviewModel> reviews,
    Iterable<RoomModel> rooms = const [],
    double globalAverage = 3.5,
    int minimumReviewWeight = 5,
  }) {
    final hotelReviews = reviews.where((review) {
      return review.isPublished &&
          review.hotelId == hotelId &&
          review.roomId.isNotEmpty &&
          review.rating >= 1 &&
          review.rating <= 5;
    }).toList();

    final roomIds = <String>{
      ...rooms
          .where((room) => room.hotelId == hotelId)
          .map((room) => room.id),
      ...hotelReviews.map((review) => review.roomId),
    };

    final roomRatings = <String, RoomRating>{};

    for (final roomId in roomIds) {
      roomRatings[roomId] = RoomRating.calculate(
        roomId: roomId,
        hotelId: hotelId,
        reviews: hotelReviews,
        globalAverage: globalAverage,
        minimumReviewWeight: minimumReviewWeight,
      );
    }

    final summary = _calculateSummary(
      reviews: hotelReviews,
      globalAverage: globalAverage,
      minimumReviewWeight: minimumReviewWeight,
    );

    return HotelRating(
      hotelId: hotelId,
      averageRating: summary.averageRating,
      reviewCount: summary.reviewCount,
      recommendationScore: summary.recommendationScore,
      positiveReviewCount: summary.positiveReviewCount,
      reviewedRoomCount: roomRatings.values
          .where((rating) => rating.hasReviews)
          .length,
      ratingDistribution: summary.ratingDistribution,
      roomRatings: Map.unmodifiable(roomRatings),
    );
  }

  static HotelRating empty(String hotelId) {
    return HotelRating(
      hotelId: hotelId,
      averageRating: 0,
      reviewCount: 0,
      recommendationScore: 0,
      positiveReviewCount: 0,
      reviewedRoomCount: 0,
      ratingDistribution: const {
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
      },
      roomRatings: const {},
    );
  }
}

class HotelRecommendation {
  const HotelRecommendation({
    required this.hotel,
    required this.rating,
  });

  final HotelModel hotel;
  final HotelRating rating;

  double get score => rating.recommendationScore;
}

class RoomRecommendation {
  const RoomRecommendation({
    required this.room,
    required this.rating,
  });

  final RoomModel room;
  final RoomRating rating;

  double get score => rating.recommendationScore;
}

class _RatingSummary {
  const _RatingSummary({
    required this.averageRating,
    required this.reviewCount,
    required this.recommendationScore,
    required this.positiveReviewCount,
    required this.ratingDistribution,
  });

  final double averageRating;
  final int reviewCount;
  final double recommendationScore;
  final int positiveReviewCount;
  final Map<int, int> ratingDistribution;
}

_RatingSummary _calculateSummary({
  required List<ReviewModel> reviews,
  required double globalAverage,
  required int minimumReviewWeight,
}) {
  final distribution = <int, int>{
    1: 0,
    2: 0,
    3: 0,
    4: 0,
    5: 0,
  };

  if (reviews.isEmpty) {
    return _RatingSummary(
      averageRating: 0,
      reviewCount: 0,
      recommendationScore: 0,
      positiveReviewCount: 0,
      ratingDistribution: Map.unmodifiable(distribution),
    );
  }

  var total = 0;
  var positive = 0;

  for (final review in reviews) {
    total += review.rating;
    distribution[review.rating] =
        (distribution[review.rating] ?? 0) + 1;

    if (review.rating >= 4) {
      positive++;
    }
  }

  final count = reviews.length;
  final average = total / count;
  final weight = minimumReviewWeight < 1
      ? 1
      : minimumReviewWeight;

  final weightedScore =
      (count / (count + weight)) * average +
      (weight / (count + weight)) * globalAverage;

  return _RatingSummary(
    averageRating: average,
    reviewCount: count,
    recommendationScore: weightedScore,
    positiveReviewCount: positive,
    ratingDistribution: Map.unmodifiable(distribution),
  );
}