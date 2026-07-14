import 'package:cloud_firestore/cloud_firestore.dart';

enum TravelSuggestionType {
  place,
  itinerary,
  hotel,
  food,
  activity;

  String get label {
    return switch (this) {
      TravelSuggestionType.place => 'Địa điểm',
      TravelSuggestionType.itinerary => 'Lịch trình',
      TravelSuggestionType.hotel => 'Khách sạn',
      TravelSuggestionType.food => 'Ẩm thực',
      TravelSuggestionType.activity => 'Hoạt động',
    };
  }

  static TravelSuggestionType fromValue(String? value) {
    return TravelSuggestionType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => TravelSuggestionType.place,
    );
  }
}

class TravelSuggestionModel {
  const TravelSuggestionModel({
    required this.id,
    required this.title,
    required this.description,
    this.type = TravelSuggestionType.place,
    this.placeId = '',
    this.hotelId = '',
    this.imageUrl = '',
    this.province = '',
    this.district = '',
    this.estimatedCost = 0,
    this.durationText = '',
    this.reasons = const [],
    this.tags = const [],
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final TravelSuggestionType type;
  final String placeId;
  final String hotelId;
  final String imageUrl;
  final String province;
  final String district;
  final double estimatedCost;
  final String durationText;
  final List<String> reasons;
  final List<String> tags;
  final DateTime? createdAt;

  String get locationLabel {
    return [
      district,
      province,
    ].where((item) => item.trim().isNotEmpty).join(', ');
  }

  factory TravelSuggestionModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return TravelSuggestionModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory TravelSuggestionModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return TravelSuggestionModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: TravelSuggestionType.fromValue(data['type'] as String?),
      placeId: data['placeId'] as String? ?? '',
      hotelId: data['hotelId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      province: data['province'] as String? ?? '',
      district: data['district'] as String? ?? '',
      estimatedCost: _doubleValue(data['estimatedCost']),
      durationText: data['durationText'] as String? ?? '',
      reasons: _stringList(data['reasons']),
      tags: _stringList(data['tags']),
      createdAt: _dateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'placeId': placeId,
      'hotelId': hotelId,
      'imageUrl': imageUrl,
      'province': province,
      'district': district,
      'estimatedCost': estimatedCost,
      'durationText': durationText,
      'reasons': reasons,
      'tags': tags,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : createdAt,
    };
  }

  TravelSuggestionModel copyWith({
    String? id,
    String? title,
    String? description,
    TravelSuggestionType? type,
    String? placeId,
    String? hotelId,
    String? imageUrl,
    String? province,
    String? district,
    double? estimatedCost,
    String? durationText,
    List<String>? reasons,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return TravelSuggestionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      placeId: placeId ?? this.placeId,
      hotelId: hotelId ?? this.hotelId,
      imageUrl: imageUrl ?? this.imageUrl,
      province: province ?? this.province,
      district: district ?? this.district,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      durationText: durationText ?? this.durationText,
      reasons: reasons ?? this.reasons,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.whereType<String>().toList();
  return const [];
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