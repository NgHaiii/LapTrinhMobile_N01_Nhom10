import 'package:cloud_firestore/cloud_firestore.dart';

class HolidayInfo {
  const HolidayInfo({
    required this.date,
    required this.name,
    this.multiplier = 1.35,
    this.source = 'fallback',
  });

  final DateTime date;
  final String name;
  final double multiplier;
  final String source;

  String get dateKey {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  bool matches(DateTime value) {
    return date.year == value.year &&
        date.month == value.month &&
        date.day == value.day;
  }

  factory HolidayInfo.fromNager(Map<String, dynamic> data) {
    final date = DateTime.tryParse(data['date']?.toString() ?? '');

    if (date == null) {
      throw const FormatException('Ngày lễ không hợp lệ.');
    }

    return HolidayInfo(
      date: date,
      name:
          data['localName']?.toString().trim().isNotEmpty == true
          ? data['localName'].toString().trim()
          : data['name']?.toString().trim() ?? 'Ngày lễ',
      source: 'nager',
    );
  }

  factory HolidayInfo.fromMap(Map<String, dynamic> data) {
    return HolidayInfo(
      date: _readDate(data['date']) ?? DateTime.now(),
      name: data['name']?.toString().trim() ?? 'Ngày lễ',
      multiplier: _readMultiplier(data['multiplier']),
      source: data['source']?.toString() ?? 'firestore',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(
        DateTime(date.year, date.month, date.day),
      ),
      'name': name.trim(),
      'multiplier': multiplier,
      'source': source,
    };
  }
}

DateTime? _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);

  return null;
}

double _readMultiplier(dynamic value) {
  if (value is num && value >= 1 && value <= 3) {
    return value.toDouble();
  }

  return 1.35;
}