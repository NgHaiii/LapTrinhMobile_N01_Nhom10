import 'package:cloud_firestore/cloud_firestore.dart';

import 'room_rate_plan.dart';

class RoomModel {
  const RoomModel({
    required this.id,
    required this.hotelId,
    required this.providerId,
    required this.roomNumber,
    required this.type,
    required this.price,
    required this.description,
    required this.maxGuests,
    required this.isAvailable,
    this.hotelName = '',
    this.hourlyPrice = 0,
    this.firstHourPrice = 0,
    this.additionalHourPrice = 0,
    this.weekendSurchargePercent = 20,
    this.holidaySurchargePercent = 35,
    this.area = 0,
    this.bedCount = 1,
    this.bedType = '',
    this.images = const [],
    this.amenities = const [],
    this.ratePlans = const [],
    this.createdAt,
  });

  final String id;
  final String hotelId;
  final String hotelName;
  final String providerId;
  final String roomNumber;
  final String type;

  /// Giá theo đêm, giữ tương thích dữ liệu cũ.
  final double price;

  /// Giá giờ cũ, giữ tương thích.
  final double hourlyPrice;

  final double firstHourPrice;
  final double additionalHourPrice;

  final double weekendSurchargePercent;
  final double holidaySurchargePercent;

  final String description;
  final int maxGuests;
  final bool isAvailable;
  final double area;
  final int bedCount;
  final String bedType;
  final List<String> images;
  final List<String> amenities;
  final List<RoomRatePlan> ratePlans;
  final DateTime? createdAt;

  String get coverImage {
    return images.isEmpty ? '' : images.first;
  }

  double get _legacyHourlyPrice {
    if (hourlyPrice > 0) return hourlyPrice;
    return price > 0 ? price / 24 : 0;
  }

  double get effectiveFirstHourPrice {
    if (firstHourPrice > 0) return firstHourPrice;
    return _legacyHourlyPrice;
  }

  double get effectiveAdditionalHourPrice {
    if (additionalHourPrice > 0) {
      return additionalHourPrice;
    }

    return _legacyHourlyPrice;
  }

  /// Giữ tương thích với giao diện/service cũ.
  double get effectiveHourlyPrice {
    return effectiveFirstHourPrice;
  }

  List<RoomRatePlan> get enabledRatePlans {
    return ratePlans
        .where((plan) => plan.enabled && plan.isValid)
        .toList();
  }

  bool canAccommodate(int guests) {
    return isAvailable &&
        guests > 0 &&
        maxGuests >= guests &&
        effectiveFirstHourPrice > 0 &&
        effectiveAdditionalHourPrice > 0;
  }

  factory RoomModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    final price = _asDouble(
      data['price'] ??
          data['pricePerNight'] ??
          data['nightlyPrice'],
    );

    final legacyHourly = _asDouble(
      data['hourlyPrice'] ?? data['pricePerHour'],
      fallback: price > 0 ? price / 24 : 0,
    );

    return RoomModel(
      id: id,
      hotelId: _asString(
        data['hotelId'] ??
            data['hotelID'] ??
            data['hotel_id'],
      ),
      hotelName: _asString(data['hotelName']),
      providerId: _asString(data['providerId']),
      roomNumber: _asString(data['roomNumber']),
      type: _asString(
        data['type'],
        fallback: 'Phòng',
      ),
      price: price,
      hourlyPrice: legacyHourly,
      firstHourPrice: _asDouble(
        data['firstHourPrice'],
        fallback: legacyHourly,
      ),
      additionalHourPrice: _asDouble(
        data['additionalHourPrice'],
        fallback: legacyHourly,
      ),
      weekendSurchargePercent: _asPercent(
        data['weekendSurchargePercent'],
        fallback: 20,
      ),
      holidaySurchargePercent: _asPercent(
        data['holidaySurchargePercent'],
        fallback: 35,
      ),
      description: _asString(data['description']),
      maxGuests: _asInt(
        data['maxGuests'],
        fallback: 1,
      ),
      isAvailable: _asBool(
        data['isAvailable'],
        fallback: true,
      ),
      area: _asDouble(data['area']),
      bedCount: _asInt(
        data['bedCount'],
        fallback: 1,
      ),
      bedType: _asString(data['bedType']),
      images: _readImages(data),
      amenities: _readStringList(data['amenities']),
      ratePlans: _readRatePlans(data['ratePlans']),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedImages = images
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    final normalizedAmenities = amenities
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    final normalizedPlans = <String, RoomRatePlan>{};

    for (final plan in ratePlans) {
      if (plan.isValid) {
        normalizedPlans[plan.id] = plan;
      }
    }

    return {
      'hotelId': hotelId.trim(),
      'hotelName': hotelName.trim(),
      'providerId': providerId.trim(),
      'roomNumber': roomNumber.trim(),
      'type': type.trim(),
      'price': price,
      'hourlyPrice': effectiveFirstHourPrice,
      'firstHourPrice': effectiveFirstHourPrice,
      'additionalHourPrice': effectiveAdditionalHourPrice,
      'weekendSurchargePercent':
          weekendSurchargePercent.clamp(0, 100),
      'holidaySurchargePercent':
          holidaySurchargePercent.clamp(0, 100),
      'description': description.trim(),
      'maxGuests': maxGuests,
      'isAvailable': isAvailable,
      'area': area,
      'bedCount': bedCount,
      'bedType': bedType.trim(),
      'imageUrl': normalizedImages.isNotEmpty
          ? normalizedImages.first
          : '',
      'images': normalizedImages,
      'amenities': normalizedAmenities,
      'ratePlans': normalizedPlans.values
          .map((plan) => plan.toMap())
          .toList(),
    };
  }

  RoomModel copyWith({
    String? id,
    String? hotelId,
    String? hotelName,
    String? providerId,
    String? roomNumber,
    String? type,
    double? price,
    double? hourlyPrice,
    double? firstHourPrice,
    double? additionalHourPrice,
    double? weekendSurchargePercent,
    double? holidaySurchargePercent,
    String? description,
    int? maxGuests,
    bool? isAvailable,
    double? area,
    int? bedCount,
    String? bedType,
    List<String>? images,
    List<String>? amenities,
    List<RoomRatePlan>? ratePlans,
    DateTime? createdAt,
  }) {
    return RoomModel(
      id: id ?? this.id,
      hotelId: hotelId ?? this.hotelId,
      hotelName: hotelName ?? this.hotelName,
      providerId: providerId ?? this.providerId,
      roomNumber: roomNumber ?? this.roomNumber,
      type: type ?? this.type,
      price: price ?? this.price,
      hourlyPrice: hourlyPrice ?? this.hourlyPrice,
      firstHourPrice:
          firstHourPrice ?? this.firstHourPrice,
      additionalHourPrice:
          additionalHourPrice ?? this.additionalHourPrice,
      weekendSurchargePercent:
          weekendSurchargePercent ??
          this.weekendSurchargePercent,
      holidaySurchargePercent:
          holidaySurchargePercent ??
          this.holidaySurchargePercent,
      description: description ?? this.description,
      maxGuests: maxGuests ?? this.maxGuests,
      isAvailable: isAvailable ?? this.isAvailable,
      area: area ?? this.area,
      bedCount: bedCount ?? this.bedCount,
      bedType: bedType ?? this.bedType,
      images: images ?? this.images,
      amenities: amenities ?? this.amenities,
      ratePlans: ratePlans ?? this.ratePlans,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

List<RoomRatePlan> _readRatePlans(dynamic value) {
  if (value is! List) return [];

  final plans = <String, RoomRatePlan>{};

  for (final item in value) {
    if (item is! Map) continue;

    final plan = RoomRatePlan.fromMap(
      Map<String, dynamic>.from(item),
    );

    if (plan.isValid) {
      plans[plan.id] = plan;
    }
  }

  return plans.values.toList();
}

List<String> _readImages(Map<String, dynamic> data) {
  final images = _readStringList(data['images']);
  final legacyImage = _asString(data['imageUrl']);

  if (legacyImage.isNotEmpty &&
      !images.contains(legacyImage)) {
    images.insert(0, legacyImage);
  }

  return images;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) return [];

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;

  final result = value.toString().trim();
  return result.isEmpty ? fallback : result;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();

  if (value is String) {
    final normalized = value
        .replaceAll('đ', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    return double.tryParse(normalized) ?? fallback;
  }

  return fallback;
}

double _asPercent(dynamic value, {double fallback = 0}) {
  return _asDouble(
    value,
    fallback: fallback,
  ).clamp(0, 100).toDouble();
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();

  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }

  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  if (value is String) {
    final normalized = value.trim().toLowerCase();

    if (const {'true', '1', 'yes'}.contains(normalized)) {
      return true;
    }

    if (const {'false', '0', 'no'}.contains(normalized)) {
      return false;
    }
  }

  return fallback;
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) return DateTime.tryParse(value);

  return null;
}