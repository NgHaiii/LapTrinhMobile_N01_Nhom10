import 'package:cloud_firestore/cloud_firestore.dart';

class RoomReservation {
  const RoomReservation({
    required this.bookingId,
    required this.roomId,
    required this.providerId,
    required this.checkIn,
    required this.checkOut,
    required this.active,
  });

  final String bookingId;
  final String roomId;
  final String providerId;
  final DateTime checkIn;
  final DateTime checkOut;
  final bool active;

  bool overlaps(DateTime start, DateTime end) {
    if (!active || !end.isAfter(start)) return false;

    return start.isBefore(checkOut) &&
        end.isAfter(checkIn);
  }

  bool occupiesHour(DateTime hour) {
    return overlaps(
      hour,
      hour.add(const Duration(hours: 1)),
    );
  }

  factory RoomReservation.fromMap(
    Map<String, dynamic> data, {
    String fallbackId = '',
  }) {
    final checkIn =
        _asDateTime(data['checkIn']) ?? DateTime.now();

    final checkOut =
        _asDateTime(data['checkOut']) ??
        checkIn.add(const Duration(hours: 1));

    return RoomReservation(
      bookingId: _asString(
        data['bookingId'],
        fallback: fallbackId,
      ),
      roomId: _asString(data['roomId']),
      providerId: _asString(data['providerId']),
      checkIn: checkIn,
      checkOut: checkOut,
      active: _asBool(data['active'], fallback: true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId.trim(),
      'roomId': roomId.trim(),
      'providerId': providerId.trim(),
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': Timestamp.fromDate(checkOut),
      'active': active,
    };
  }

  RoomReservation copyWith({
    String? bookingId,
    String? roomId,
    String? providerId,
    DateTime? checkIn,
    DateTime? checkOut,
    bool? active,
  }) {
    return RoomReservation(
      bookingId: bookingId ?? this.bookingId,
      roomId: roomId ?? this.roomId,
      providerId: providerId ?? this.providerId,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      active: active ?? this.active,
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;

  final result = value.toString().trim();
  return result.isEmpty ? fallback : result;
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