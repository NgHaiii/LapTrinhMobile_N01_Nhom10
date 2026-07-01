import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../model/holiday.dart';

class HolidayService {
  HolidayService({
    FirebaseFirestore? firestore,
    http.Client? client,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _client = client ?? http.Client();

  static final HolidayService instance = HolidayService();

  final FirebaseFirestore _firestore;
  final http.Client _client;

  final Map<int, List<HolidayInfo>> _cache = {};

  Future<List<HolidayInfo>> getHolidays(
    int year, {
    bool forceRefresh = false,
  }) async {
    if (year < 2020 || year > 2100) {
      throw StateError('Năm cần tải không hợp lệ.');
    }

    if (!forceRefresh && _cache.containsKey(year)) {
      return List.unmodifiable(_cache[year]!);
    }

    final result = <String, HolidayInfo>{};

    for (final holiday in _fallbackHolidays(year)) {
      result[holiday.dateKey] = holiday;
    }

    final apiHolidays = await _loadNagerHolidays(year);

    for (final holiday in apiHolidays) {
      result[holiday.dateKey] = holiday;
    }

    final overrides = await _loadFirestoreOverrides(year);

    for (final override in overrides) {
      if (override.enabled) {
        result[override.holiday.dateKey] = override.holiday;
      } else {
        result.remove(override.holiday.dateKey);
      }
    }

    final holidays = result.values.toList()
      ..sort((first, second) => first.date.compareTo(second.date));

    _cache[year] = holidays;

    return List.unmodifiable(holidays);
  }

  Future<List<HolidayInfo>> getHolidaysForRange({
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    if (!checkOut.isAfter(checkIn)) {
      throw StateError('Khoảng thời gian không hợp lệ.');
    }

    final result = <String, HolidayInfo>{};

    for (var year = checkIn.year; year <= checkOut.year; year++) {
      final yearlyHolidays = await getHolidays(year);

      for (final holiday in yearlyHolidays) {
        result[holiday.dateKey] = holiday;
      }
    }

    return result.values.where((holiday) {
      final date = DateTime(
        holiday.date.year,
        holiday.date.month,
        holiday.date.day,
      );

      final start = DateTime(
        checkIn.year,
        checkIn.month,
        checkIn.day,
      );

      final end = DateTime(
        checkOut.year,
        checkOut.month,
        checkOut.day,
      );

      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  Future<List<HolidayInfo>> _loadNagerHolidays(int year) async {
    try {
      final uri = Uri.parse(
        'https://date.nager.at/api/v3/'
        'PublicHolidays/$year/VN',
      );

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return [];
      }

      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is! List) return [];

      final holidays = <HolidayInfo>[];

      for (final item in decoded) {
        if (item is! Map) continue;

        try {
          holidays.add(
            HolidayInfo.fromNager(
              Map<String, dynamic>.from(item),
            ),
          );
        } catch (error, stackTrace) {
          developer.log(
            'Ngày lễ API không hợp lệ.',
            name: 'HolidayService',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      return holidays;
    } catch (error, stackTrace) {
      developer.log(
        'Không tải được Nager.Date, sử dụng dữ liệu dự phòng.',
        name: 'HolidayService',
        error: error,
        stackTrace: stackTrace,
      );

      return [];
    }
  }

  Future<List<_HolidayOverride>> _loadFirestoreOverrides(
    int year,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('holidayCalendars')
          .doc(year.toString())
          .get();

      final rawHolidays = snapshot.data()?['holidays'];

      if (rawHolidays is! List) return [];

      final result = <_HolidayOverride>[];

      for (final item in rawHolidays) {
        if (item is! Map) continue;

        final data = Map<String, dynamic>.from(item);
        final holiday = HolidayInfo.fromMap(data);

        if (holiday.date.year != year) continue;

        result.add(
          _HolidayOverride(
            holiday: holiday,
            enabled: data['enabled'] != false,
          ),
        );
      }

      return result;
    } catch (error, stackTrace) {
      developer.log(
        'Không tải được lịch ghi đè từ Firestore.',
        name: 'HolidayService',
        error: error,
        stackTrace: stackTrace,
      );

      return [];
    }
  }

  List<HolidayInfo> _fallbackHolidays(int year) {
    final holidays = <HolidayInfo>[
      HolidayInfo(
        date: DateTime(year, 1, 1),
        name: 'Tết Dương lịch',
      ),
      HolidayInfo(
        date: DateTime(year, 4, 30),
        name: 'Ngày Chiến thắng 30/04',
      ),
      HolidayInfo(
        date: DateTime(year, 5, 1),
        name: 'Ngày Quốc tế Lao động',
      ),
      HolidayInfo(
        date: DateTime(year, 9, 2),
        name: 'Quốc khánh 02/09',
      ),
    ];

    if (year == 2026) {
      holidays.addAll([
        ..._createRange(
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 4),
          'Tết Dương lịch',
        ),
        ..._createRange(
          DateTime(2026, 2, 14),
          DateTime(2026, 2, 22),
          'Tết Nguyên đán',
        ),
        ..._createRange(
          DateTime(2026, 4, 25),
          DateTime(2026, 4, 27),
          'Giỗ Tổ Hùng Vương',
        ),
        ..._createRange(
          DateTime(2026, 4, 30),
          DateTime(2026, 5, 3),
          'Nghỉ lễ 30/04 - 01/05',
        ),
        ..._createRange(
          DateTime(2026, 8, 29),
          DateTime(2026, 9, 2),
          'Nghỉ lễ Quốc khánh',
        ),
      ]);
    }

    final unique = <String, HolidayInfo>{};

    for (final holiday in holidays) {
      unique[holiday.dateKey] = holiday;
    }

    return unique.values.toList();
  }

  List<HolidayInfo> _createRange(
    DateTime start,
    DateTime end,
    String name,
  ) {
    final result = <HolidayInfo>[];
    var current = start;

    while (!current.isAfter(end)) {
      result.add(
        HolidayInfo(
          date: current,
          name: name,
          source: 'fallback',
        ),
      );

      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  void clearCache([int? year]) {
    if (year == null) {
      _cache.clear();
    } else {
      _cache.remove(year);
    }
  }

  void dispose() {
    _client.close();
  }
}

class _HolidayOverride {
  const _HolidayOverride({
    required this.holiday,
    required this.enabled,
  });

  final HolidayInfo holiday;
  final bool enabled;
}