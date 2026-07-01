class RatePlanType {
  static const daytime = 'daytime';
  static const overnight = 'overnight';
  static const dayNight = 'dayNight';

  static const values = {
    daytime,
    overnight,
    dayNight,
  };

  static String normalize(dynamic value) {
    final type = value?.toString().trim();

    if (type != null && values.contains(type)) {
      return type;
    }

    return daytime;
  }

  static String label(String type) {
    return switch (normalize(type)) {
      overnight => 'Combo qua đêm',
      dayNight => 'Combo ngày đêm',
      _ => 'Combo ban ngày',
    };
  }
}

class RoomRatePlan {
  const RoomRatePlan({
    required this.id,
    required this.name,
    required this.type,
    required this.startHour,
    required this.endHour,
    required this.price,
    required this.enabled,
  });

  final String id;
  final String name;
  final String type;

  /// Giờ bắt đầu từ 0 đến 23.
  final int startHour;

  /// Giờ kết thúc từ 0 đến 23.
  ///
  /// Nếu nhỏ hơn hoặc bằng startHour thì kết thúc vào hôm sau.
  final int endHour;

  final double price;
  final bool enabled;

  bool get spansMidnight => endHour <= startHour;

  int get durationHours {
    if (endHour > startHour) {
      return endHour - startHour;
    }

    return 24 - startHour + endHour;
  }

  String get typeLabel => RatePlanType.label(type);

  String get timeLabel {
    final start = '${startHour.toString().padLeft(2, '0')}:00';
    final end = '${endHour.toString().padLeft(2, '0')}:00';

    return '$start - $end${spansMidnight ? ' hôm sau' : ''}';
  }

  bool get isValid {
    return id.trim().isNotEmpty &&
        name.trim().isNotEmpty &&
        RatePlanType.values.contains(type) &&
        startHour >= 0 &&
        startHour <= 23 &&
        endHour >= 0 &&
        endHour <= 23 &&
        startHour != endHour &&
        price > 0;
  }

  DateTime expectedCheckOut(DateTime checkIn) {
    final start = DateTime(
      checkIn.year,
      checkIn.month,
      checkIn.day,
      startHour,
    );

    return start.add(Duration(hours: durationHours));
  }

  bool isEligible({
    required DateTime checkIn,
    required DateTime checkOut,
  }) {
    if (!enabled || !isValid) return false;

    if (checkIn.minute != 0 ||
        checkIn.second != 0 ||
        checkIn.millisecond != 0 ||
        checkIn.hour != startHour) {
      return false;
    }

    return expectedCheckOut(checkIn).isAtSameMomentAs(checkOut);
  }

  factory RoomRatePlan.fromMap(Map<String, dynamic> data) {
    return RoomRatePlan(
      id: _asString(data['id']),
      name: _asString(
        data['name'],
        fallback: RatePlanType.label(
          RatePlanType.normalize(data['type']),
        ),
      ),
      type: RatePlanType.normalize(data['type']),
      startHour: _asInt(data['startHour'], fallback: 8),
      endHour: _asInt(data['endHour'], fallback: 18),
      price: _asDouble(data['price']),
      enabled: _asBool(data['enabled'], fallback: true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.trim(),
      'name': name.trim(),
      'type': RatePlanType.normalize(type),
      'startHour': startHour,
      'endHour': endHour,
      'durationHours': durationHours,
      'price': price,
      'enabled': enabled,
    };
  }

  RoomRatePlan copyWith({
    String? id,
    String? name,
    String? type,
    int? startHour,
    int? endHour,
    double? price,
    bool? enabled,
  }) {
    return RoomRatePlan(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      price: price ?? this.price,
      enabled: enabled ?? this.enabled,
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;

  final result = value.toString().trim();
  return result.isEmpty ? fallback : result;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();

  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }

  return fallback;
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