import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class BookingStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const rejected = 'rejected';

  static const values = {pending, confirmed, completed, cancelled, rejected};

  static String normalize(dynamic value) {
    final status = value?.toString().trim().toLowerCase();

    if (status != null && values.contains(status)) {
      return status;
    }

    return pending;
  }
}

class BookingModel {
  const BookingModel({
    required this.id,
    required this.customerId,
    required this.providerId,
    required this.hotelId,
    required this.hotelName,
    required this.roomId,
    required this.roomNumber,
    required this.roomType,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.pricePerNight,
    required this.nights,
    required this.totalAmount,
    required this.status,
    this.customerName = '',
    this.customerEmail = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  final String customerId;
  final String customerName;
  final String customerEmail;

  final String providerId;

  final String hotelId;
  final String hotelName;

  final String roomId;
  final String roomNumber;
  final String roomType;

  final DateTime checkIn;
  final DateTime checkOut;

  final int guests;
  final double pricePerNight;
  final int nights;
  final double totalAmount;

  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canCustomerCancel {
    return status == BookingStatus.pending;
  }

  bool get isFinished {
    return status == BookingStatus.completed ||
        status == BookingStatus.cancelled ||
        status == BookingStatus.rejected;
  }

  String get statusLabel {
    return switch (status) {
      BookingStatus.confirmed => 'Đã xác nhận',
      BookingStatus.completed => 'Hoàn thành',
      BookingStatus.cancelled => 'Đã hủy',
      BookingStatus.rejected => 'Bị từ chối',
      _ => 'Chờ xác nhận',
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> data, String id) {
    final checkIn = _asDateTime(data['checkIn']) ?? DateTime.now();

    final checkOut =
        _asDateTime(data['checkOut']) ?? checkIn.add(const Duration(days: 1));

    final calculatedNights = checkOut.difference(checkIn).inDays;

    final pricePerNight = _asDouble(data['pricePerNight']);

    final nights = _asInt(
      data['nights'],
      fallback: calculatedNights > 0 ? calculatedNights : 1,
    );

    final storedTotal = _asDouble(data['totalAmount']);

    return BookingModel(
      id: id,
      customerId: _asString(data['customerId']),
      customerName: _asString(data['customerName']),
      customerEmail: _asString(data['customerEmail']),
      providerId: _asString(data['providerId']),
      hotelId: _asString(data['hotelId']),
      hotelName: _asString(data['hotelName'], fallback: 'Khách sạn'),
      roomId: _asString(data['roomId']),
      roomNumber: _asString(data['roomNumber']),
      roomType: _asString(data['roomType'], fallback: 'Phòng'),
      checkIn: checkIn,
      checkOut: checkOut,
      guests: _asInt(data['guests'], fallback: 1),
      pricePerNight: pricePerNight,
      nights: nights,
      totalAmount: storedTotal > 0 ? storedTotal : pricePerNight * nights,
      status: BookingStatus.normalize(data['status']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId.trim(),
      'customerName': customerName.trim(),
      'customerEmail': customerEmail.trim(),
      'providerId': providerId.trim(),
      'hotelId': hotelId.trim(),
      'hotelName': hotelName.trim(),
      'roomId': roomId.trim(),
      'roomNumber': roomNumber.trim(),
      'roomType': roomType.trim(),
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': Timestamp.fromDate(checkOut),
      'guests': guests,
      'pricePerNight': pricePerNight,
      'nights': nights,
      'totalAmount': totalAmount,
      'status': BookingStatus.normalize(status),
    };
  }

  BookingModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerEmail,
    String? providerId,
    String? hotelId,
    String? hotelName,
    String? roomId,
    String? roomNumber,
    String? roomType,
    DateTime? checkIn,
    DateTime? checkOut,
    int? guests,
    double? pricePerNight,
    int? nights,
    double? totalAmount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      providerId: providerId ?? this.providerId,
      hotelId: hotelId ?? this.hotelId,
      hotelName: hotelName ?? this.hotelName,
      roomId: roomId ?? this.roomId,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      guests: guests ?? this.guests,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      nights: nights ?? this.nights,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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
