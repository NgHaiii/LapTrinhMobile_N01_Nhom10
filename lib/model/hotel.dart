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
    this.images = const [],
    this.rating = 0,
    this.minPrice = 0,
    this.createdAt,
  });

  final String id;
  final String providerId;
  final String name;
  final String address;
  final String province;
  final String district;
  final String description;

  /// Ảnh bìa, giữ lại để tương thích dữ liệu cũ.
  final String imageUrl;
  final List<String> images;

  final String category;
  final String status;
  final double rating;
  final double minPrice;
  final DateTime? createdAt;

  String get coverImage {
    if (images.isNotEmpty) return images.first;
    return imageUrl;
  }

  String get fullAddress {
    final parts = <String>[
      address.trim(),
      district.trim(),
      province.trim(),
    ].where((value) => value.isNotEmpty).toSet();

    return parts.join(', ');
  }

  bool get isVisible {
    final normalizedStatus = status.trim().toLowerCase();

    return normalizedStatus.isEmpty ||
        normalizedStatus == 'approved' ||
        normalizedStatus == 'active';
  }

  factory HotelModel.fromMap(Map<String, dynamic> data, String id) {
    final address = _asString(data['address']);
    final images = _readImages(data);

    var province = _asString(data['province'] ?? data['city']);

    var district = _asString(data['district'] ?? data['wardDistrict']);

    if (province.isEmpty || district.isEmpty) {
      final legacyLocation = _inferLocationFromAddress(address);

      if (province.isEmpty) {
        province = legacyLocation.province;
      }

      if (district.isEmpty) {
        district = legacyLocation.district;
      }
    }

    return HotelModel(
      id: id,
      providerId: _asString(data['providerId']),
      name: _asString(data['name'], fallback: 'Khách sạn'),
      address: address,
      province: province,
      district: district,
      description: _asString(data['description']),
      imageUrl: images.isNotEmpty ? images.first : _asString(data['imageUrl']),
      images: images,
      category: _asString(data['category'], fallback: 'Khách sạn'),
      status: _asString(data['status'], fallback: 'approved').toLowerCase(),
      rating: _asDouble(data['rating']),
      minPrice: _asDouble(data['minPrice']),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedImages = images
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    final cover = normalizedImages.isNotEmpty
        ? normalizedImages.first
        : imageUrl.trim();

    return {
      'providerId': providerId.trim(),
      'name': name.trim(),
      'address': address.trim(),
      'province': province.trim(),
      'district': district.trim(),
      'description': description.trim(),
      'imageUrl': cover,
      'images': normalizedImages,
      'category': category.trim(),
      'status': status.trim().toLowerCase(),
      'rating': rating,
      'minPrice': minPrice,
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
    String? category,
    String? status,
    double? rating,
    double? minPrice,
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
      category: category ?? this.category,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      minPrice: minPrice ?? this.minPrice,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class _LegacyLocation {
  const _LegacyLocation({this.province = '', this.district = ''});

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
    district: parts.length >= 3 ? parts[parts.length - 2] : '',
  );
}

List<String> _readImages(Map<String, dynamic> data) {
  final value = data['images'];

  final images = value is List
      ? value
            .whereType<String>()
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toSet()
            .toList()
      : <String>[];

  final oldImageUrl = _asString(data['imageUrl']);

  if (oldImageUrl.isNotEmpty && !images.contains(oldImageUrl)) {
    images.insert(0, oldImageUrl);
  }

  return images;
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
