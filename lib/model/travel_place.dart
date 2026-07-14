import 'package:cloud_firestore/cloud_firestore.dart';

enum TravelPlaceCategory {
  beach,
  mountain,
  culture,
  food,
  entertainment,
  shopping,
  nature,
  other;

  String get label {
    return switch (this) {
      TravelPlaceCategory.beach => 'Biển đảo',
      TravelPlaceCategory.mountain => 'Núi rừng',
      TravelPlaceCategory.culture => 'Văn hóa',
      TravelPlaceCategory.food => 'Ẩm thực',
      TravelPlaceCategory.entertainment => 'Vui chơi',
      TravelPlaceCategory.shopping => 'Mua sắm',
      TravelPlaceCategory.nature => 'Thiên nhiên',
      TravelPlaceCategory.other => 'Khác',
    };
  }

  static TravelPlaceCategory fromValue(String? value) {
    return TravelPlaceCategory.values.firstWhere(
      (item) => item.name == value,
      orElse: () => TravelPlaceCategory.other,
    );
  }
}

class TravelPlaceModel {
  const TravelPlaceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.province,
    required this.district,
    required this.address,
    this.category = TravelPlaceCategory.other,
    this.images = const [],
    this.openingHours = '',
    this.ticketPrice = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.latitude,
    this.longitude,
    this.isFeatured = false,
    this.isActive = true,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String province;
  final String district;
  final String address;
  final TravelPlaceCategory category;
  final List<String> images;
  final String openingHours;
  final double ticketPrice;
  final double rating;
  final int reviewCount;
  final double? latitude;
  final double? longitude;
  final bool isFeatured;
  final bool isActive;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullAddress {
    return [
      address,
      district,
      province,
    ].where((item) => item.trim().isNotEmpty).join(', ');
  }

  String get primaryImage {
    return images.isEmpty ? '' : images.first;
  }

  bool get hasLocation {
    return latitude != null && longitude != null;
  }

  factory TravelPlaceModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return TravelPlaceModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory TravelPlaceModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return TravelPlaceModel(
      id: id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      province: data['province'] as String? ?? '',
      district: data['district'] as String? ?? '',
      address: data['address'] as String? ?? '',
      category: TravelPlaceCategory.fromValue(data['category'] as String?),
      images: _stringList(data['images']),
      openingHours: data['openingHours'] as String? ?? '',
      ticketPrice: _doubleValue(data['ticketPrice']),
      rating: _doubleValue(data['rating']),
      reviewCount: _intValue(data['reviewCount']),
      latitude: data['latitude'] == null ? null : _doubleValue(data['latitude']),
      longitude:
          data['longitude'] == null ? null : _doubleValue(data['longitude']),
      isFeatured: data['isFeatured'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      tags: _stringList(data['tags']),
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'province': province,
      'district': district,
      'address': address,
      'category': category.name,
      'images': images,
      'openingHours': openingHours,
      'ticketPrice': ticketPrice,
      'rating': rating,
      'reviewCount': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      'isFeatured': isFeatured,
      'isActive': isActive,
      'tags': tags,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TravelPlaceModel copyWith({
    String? id,
    String? name,
    String? description,
    String? province,
    String? district,
    String? address,
    TravelPlaceCategory? category,
    List<String>? images,
    String? openingHours,
    double? ticketPrice,
    double? rating,
    int? reviewCount,
    double? latitude,
    double? longitude,
    bool? isFeatured,
    bool? isActive,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TravelPlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      province: province ?? this.province,
      district: district ?? this.district,
      address: address ?? this.address,
      category: category ?? this.category,
      images: images ?? this.images,
      openingHours: openingHours ?? this.openingHours,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return const [];
}

double _doubleValue(dynamic value) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return 0;
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

DateTime? _dateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}