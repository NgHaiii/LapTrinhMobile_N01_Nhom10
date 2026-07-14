import 'package:cloud_firestore/cloud_firestore.dart';

enum SavedPlaceType {
  hotel,
  travelPlace;

  String get label {
    return switch (this) {
      SavedPlaceType.hotel => 'Khách sạn',
      SavedPlaceType.travelPlace => 'Địa điểm du lịch',
    };
  }

  static SavedPlaceType fromValue(String? value) {
    return SavedPlaceType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SavedPlaceType.travelPlace,
    );
  }
}

class SavedPlaceModel {
  const SavedPlaceModel({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.name,
    required this.type,
    this.imageUrl = '',
    this.address = '',
    this.province = '',
    this.district = '',
    this.rating = 0,
    this.note = '',
    this.createdAt,
  });

  final String id;
  final String userId;
  final String placeId;
  final String name;
  final SavedPlaceType type;
  final String imageUrl;
  final String address;
  final String province;
  final String district;
  final double rating;
  final String note;
  final DateTime? createdAt;

  String get fullAddress {
    return [
      address,
      district,
      province,
    ].where((item) => item.trim().isNotEmpty).join(', ');
  }

  factory SavedPlaceModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SavedPlaceModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory SavedPlaceModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return SavedPlaceModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      placeId: data['placeId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      type: SavedPlaceType.fromValue(data['type'] as String?),
      imageUrl: data['imageUrl'] as String? ?? '',
      address: data['address'] as String? ?? '',
      province: data['province'] as String? ?? '',
      district: data['district'] as String? ?? '',
      rating: _doubleValue(data['rating']),
      note: data['note'] as String? ?? '',
      createdAt: _dateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'placeId': placeId,
      'name': name,
      'type': type.name,
      'imageUrl': imageUrl,
      'address': address,
      'province': province,
      'district': district,
      'rating': rating,
      'note': note,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : createdAt,
    };
  }

  SavedPlaceModel copyWith({
    String? id,
    String? userId,
    String? placeId,
    String? name,
    SavedPlaceType? type,
    String? imageUrl,
    String? address,
    String? province,
    String? district,
    double? rating,
    String? note,
    DateTime? createdAt,
  }) {
    return SavedPlaceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      address: address ?? this.address,
      province: province ?? this.province,
      district: district ?? this.district,
      rating: rating ?? this.rating,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

double _doubleValue(dynamic value) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return 0;
}

DateTime? _dateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}