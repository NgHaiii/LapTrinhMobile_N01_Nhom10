import 'package:cloud_firestore/cloud_firestore.dart';

class HotelModel {
  const HotelModel({
    required this.id,
    required this.providerId,
    required this.name,
    required this.address,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.status,
    this.province = '',
    this.district = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.zaloPhone = '',
    this.facebookUrl = '',
    this.images = const [],
    this.amenities = const [],
    this.rating = 0,
    this.reviewCount = 0,
    this.reviewedRoomCount = 0,
    this.recommendationScore = 0,
    this.minPrice = 0,
    this.minHourlyPrice = 0,
    this.minFirstHourPrice = 0,
    this.minAdditionalHourPrice = 0,
    this.createdAt,
  });

  final String id;
  final String providerId;
  final String name;
  final String address;
  final String province;
  final String district;
  final String description;
  final String imageUrl;
  final List<String> images;
  final List<String> amenities;
  final String category;
  final String status;

  // Điểm tổng hợp từ các đánh giá phòng thuộc khách sạn.
  final double rating;
  final int reviewCount;
  final int reviewedRoomCount;
  final double recommendationScore;

  final String contactEmail;
  final String contactPhone;
  final String zaloPhone;
  final String facebookUrl;

  final double minPrice;
  final double minHourlyPrice;
  final double minFirstHourPrice;
  final double minAdditionalHourPrice;
  final DateTime? createdAt;

  String get coverImage {
    if (images.isNotEmpty) return images.first;
    return imageUrl;
  }

  String get fullAddress {
    final parts = <String>[];

    void addPart(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty) return;

      final current = parts.join(', ').toLowerCase();

      if (!current.contains(normalized.toLowerCase())) {
        parts.add(normalized);
      }
    }

    addPart(address);
    addPart(district);
    addPart(province);

    return parts.join(', ');
  }

  bool get hasContactInformation {
    return contactEmail.trim().isNotEmpty ||
        contactPhone.trim().isNotEmpty ||
        zaloPhone.trim().isNotEmpty ||
        facebookUrl.trim().isNotEmpty;
  }

  bool get hasReviews => reviewCount > 0 && rating > 0;

  String get ratingLabel {
    if (!hasReviews) return 'Mới';
    return rating.toStringAsFixed(1);
  }

  double get effectiveMinHourlyPrice {
    return effectiveMinFirstHourPrice;
  }

  double get effectiveMinFirstHourPrice {
    if (minFirstHourPrice > 0) return minFirstHourPrice;
    if (minHourlyPrice > 0) return minHourlyPrice;
    return minPrice > 0 ? minPrice / 24 : 0;
  }

  double get effectiveMinAdditionalHourPrice {
    if (minAdditionalHourPrice > 0) {
      return minAdditionalHourPrice;
    }

    if (minHourlyPrice > 0) return minHourlyPrice;
    return minPrice > 0 ? minPrice / 24 : 0;
  }

  bool get isVisible {
    final value = status.trim().toLowerCase();

    return value.isEmpty ||
        value == 'approved' ||
        value == 'active';
  }

  factory HotelModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    final address = _asString(data['address']);
    final images = _readImages(data);
    final minPrice = _asDouble(data['minPrice']);

    final legacyHourlyPrice = _asDouble(
      data['minHourlyPrice'],
      fallback: minPrice > 0 ? minPrice / 24 : 0,
    );

    var province = _asString(
      data['province'] ?? data['city'],
    );

    var district = _asString(
      data['district'] ?? data['wardDistrict'],
    );

    if (province.isEmpty || district.isEmpty) {
      final location = _inferLocationFromAddress(address);

      if (province.isEmpty) {
        province = location.province;
      }

      if (district.isEmpty) {
        district = location.district;
      }
    }

    return HotelModel(
      id: id,
      providerId: _asString(data['providerId']),
      name: _asString(
        data['name'],
        fallback: 'Khách sạn',
      ),
      address: address,
      province: province,
      district: district,
      description: _asString(data['description']),
      imageUrl: images.isNotEmpty
          ? images.first
          : _asString(data['imageUrl']),
      images: images,
      amenities: _readStringList(data['amenities']),
      category: _asString(
        data['category'],
        fallback: 'Khách sạn',
      ),
      status: _asString(
        data['status'],
        fallback: 'approved',
      ).toLowerCase(),
      rating: _asDouble(data['rating']),
      reviewCount: _asInt(data['reviewCount']),
      reviewedRoomCount: _asInt(
        data['reviewedRoomCount'],
      ),
      recommendationScore: _asDouble(
        data['recommendationScore'],
      ),
      contactEmail: _asString(
        data['contactEmail'] ?? data['email'],
      ).toLowerCase(),
      contactPhone: _asString(
        data['contactPhone'] ?? data['phoneNumber'],
      ),
      zaloPhone: _asString(
        data['zaloPhone'] ?? data['zalo'],
      ),
      facebookUrl: _asString(
        data['facebookUrl'] ?? data['facebook'],
      ),
      minPrice: minPrice,
      minHourlyPrice: legacyHourlyPrice,
      minFirstHourPrice: _asDouble(
        data['minFirstHourPrice'],
        fallback: legacyHourlyPrice,
      ),
      minAdditionalHourPrice: _asDouble(
        data['minAdditionalHourPrice'],
        fallback: legacyHourlyPrice,
      ),
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

    return {
      'providerId': providerId.trim(),
      'name': name.trim(),
      'address': address.trim(),
      'province': province.trim(),
      'district': district.trim(),
      'description': description.trim(),
      'imageUrl': normalizedImages.isNotEmpty
          ? normalizedImages.first
          : imageUrl.trim(),
      'images': normalizedImages,
      'amenities': normalizedAmenities,
      'category': category.trim(),
      'status': status.trim().toLowerCase(),

      // Giữ tương thích với rules hiện tại.
      // Điểm thật vẫn được RecommendationService tính từ reviews.
      'rating': rating,

      'contactEmail': contactEmail.trim().toLowerCase(),
      'contactPhone': contactPhone.trim(),
      'zaloPhone': zaloPhone.trim(),
      'facebookUrl': facebookUrl.trim(),
      'minPrice': minPrice,
      'minHourlyPrice': effectiveMinHourlyPrice,
      'minFirstHourPrice': effectiveMinFirstHourPrice,
      'minAdditionalHourPrice':
          effectiveMinAdditionalHourPrice,
    };
  }

  HotelModel copyWith({
    String? id,
    String? providerId,
    String? name,
    String? address,
    String? province,
    String? district,
    String? description,
    String? imageUrl,
    List<String>? images,
    List<String>? amenities,
    String? category,
    String? status,
    double? rating,
    int? reviewCount,
    int? reviewedRoomCount,
    double? recommendationScore,
    String? contactEmail,
    String? contactPhone,
    String? zaloPhone,
    String? facebookUrl,
    double? minPrice,
    double? minHourlyPrice,
    double? minFirstHourPrice,
    double? minAdditionalHourPrice,
    DateTime? createdAt,
  }) {
    return HotelModel(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      address: address ?? this.address,
      province: province ?? this.province,
      district: district ?? this.district,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      amenities: amenities ?? this.amenities,
      category: category ?? this.category,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      reviewedRoomCount:
          reviewedRoomCount ?? this.reviewedRoomCount,
      recommendationScore:
          recommendationScore ?? this.recommendationScore,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      zaloPhone: zaloPhone ?? this.zaloPhone,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      minPrice: minPrice ?? this.minPrice,
      minHourlyPrice:
          minHourlyPrice ?? this.minHourlyPrice,
      minFirstHourPrice:
          minFirstHourPrice ?? this.minFirstHourPrice,
      minAdditionalHourPrice:
          minAdditionalHourPrice ??
          this.minAdditionalHourPrice,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class _LegacyLocation {
  const _LegacyLocation({
    this.province = '',
    this.district = '',
  });

  final String province;
  final String district;
}

_LegacyLocation _inferLocationFromAddress(String address) {
  final parts = address
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.length < 2) {
    return const _LegacyLocation();
  }

  return _LegacyLocation(
    province: parts.last,
    district: parts.length >= 3
        ? parts[parts.length - 2]
        : '',
  );
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

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();

  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }

  return fallback;
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}