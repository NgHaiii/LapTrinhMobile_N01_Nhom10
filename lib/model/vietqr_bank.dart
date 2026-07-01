class VietQrBank {
  const VietQrBank({
    required this.id,
    required this.name,
    required this.code,
    required this.bin,
    required this.shortName,
    required this.logo,
    this.transferSupported = true,
    this.lookupSupported = false,
  });

  final int id;

  /// Tên đầy đủ của ngân hàng.
  final String name;

  /// Mã ngân hàng, ví dụ VCB, MB, TCB.
  final String code;

  /// Mã BIN dùng để tạo VietQR.
  final String bin;

  final String shortName;
  final String logo;
  final bool transferSupported;
  final bool lookupSupported;

  String get displayName {
    if (shortName.isNotEmpty) return '$shortName - $name';
    if (code.isNotEmpty) return '$code - $name';
    return name;
  }

  bool get isValid {
    return bin.trim().isNotEmpty &&
        name.trim().isNotEmpty &&
        transferSupported;
  }

  factory VietQrBank.fromMap(Map<String, dynamic> data) {
    return VietQrBank(
      id: _asInt(data['id']),
      name: _asString(data['name']),
      code: _asString(data['code']).toUpperCase(),
      bin: _asString(data['bin']),
      shortName: _asString(
        data['shortName'] ?? data['short_name'],
      ),
      logo: _asString(data['logo']),
      transferSupported: _asBool(
        data['transferSupported'],
        fallback: true,
      ),
      lookupSupported: _asBool(data['lookupSupported']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'bin': bin.trim(),
      'shortName': shortName.trim(),
      'logo': logo.trim(),
      'transferSupported': transferSupported,
      'lookupSupported': lookupSupported,
    };
  }

  VietQrBank copyWith({
    int? id,
    String? name,
    String? code,
    String? bin,
    String? shortName,
    String? logo,
    bool? transferSupported,
    bool? lookupSupported,
  }) {
    return VietQrBank(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      bin: bin ?? this.bin,
      shortName: shortName ?? this.shortName,
      logo: logo ?? this.logo,
      transferSupported: transferSupported ?? this.transferSupported,
      lookupSupported: lookupSupported ?? this.lookupSupported,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VietQrBank && other.bin == bin;
  }

  @override
  int get hashCode => bin.hashCode;
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

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  if (value is String) {
    final normalized = value.trim().toLowerCase();

    if (const {'true', '1', 'yes'}.contains(normalized)) return true;
    if (const {'false', '0', 'no'}.contains(normalized)) return false;
  }

  return fallback;
}