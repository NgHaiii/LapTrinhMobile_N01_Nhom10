import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.images = const [],
    this.createdAt,
  });

  final String id;
  final String hotelId;
  final String hotelName;
  final String providerId;
  final String roomNumber;
  final String type;
  final double price;
  final String description;
  final int maxGuests;
  final bool isAvailable;
  final List<String> images;
  final DateTime? createdAt;

  String get coverImage {
    return images.isEmpty ? '' : images.first;
  }

  bool canAccommodate(int guests) {
    return isAvailable && guests > 0 && maxGuests >= guests;
  }

  factory RoomModel.fromMap(Map<String, dynamic> data, String id) {
    return RoomModel(
      id: id,
      hotelId: _asString(
        data['hotelId'] ?? data['hotelID'] ?? data['hotel_id'],
      ),
      hotelName: _asString(data['hotelName']),
      providerId: _asString(data['providerId']),
      roomNumber: _asString(data['roomNumber']),
      type: _asString(data['type'], fallback: 'Phòng'),
      price: _asDouble(data['price']),
      description: _asString(data['description']),
      maxGuests: _asInt(data['maxGuests'], fallback: 1),
      isAvailable: _asBool(data['isAvailable'], fallback: true),
      images: _readImages(data),
      createdAt: _asDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedImages = images
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    return {
      'hotelId': hotelId.trim(),
      'hotelName': hotelName.trim(),
      'providerId': providerId.trim(),
      'roomNumber': roomNumber.trim(),
      'type': type.trim(),
      'price': price,
      'description': description.trim(),
      'maxGuests': maxGuests,
      'isAvailable': isAvailable,
      'imageUrl': normalizedImages.isNotEmpty ? normalizedImages.first : '',
      'images': normalizedImages,
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
    String? description,
    int? maxGuests,
    bool? isAvailable,
    List<String>? images,
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
      description: description ?? this.description,
      maxGuests: maxGuests ?? this.maxGuests,
      isAvailable: isAvailable ?? this.isAvailable,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
    );
  }
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

    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }

    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
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

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}
