import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/vietqr_bank.dart';

class VietQrService {
  VietQrService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _banksUrl = 'https://api.vietqr.io/v2/banks';

  List<VietQrBank>? _cachedBanks;

  Future<List<VietQrBank>> getBanks({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedBanks != null) {
      return List.unmodifiable(_cachedBanks!);
    }

    final response = await _client
        .get(Uri.parse(_banksUrl))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Không thể tải danh sách ngân hàng '
        '(${response.statusCode}).',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw StateError('VietQR trả về dữ liệu không hợp lệ.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw StateError('VietQR trả về dữ liệu không hợp lệ.');
    }

    final rawBanks = decoded['data'];

    if (rawBanks is! List) {
      throw StateError('Không tìm thấy danh sách ngân hàng.');
    }

    final banks = rawBanks
        .whereType<Map>()
        .map(
          (data) => VietQrBank.fromMap(
            Map<String, dynamic>.from(data),
          ),
        )
        .where((bank) => bank.isValid)
        .toList();

    banks.sort(
      (first, second) =>
          first.shortName.toLowerCase().compareTo(
            second.shortName.toLowerCase(),
          ),
    );

    _cachedBanks = banks;
    return List.unmodifiable(banks);
  }

  Future<VietQrBank?> findBankByBin(String bankBin) async {
    final expectedBin = bankBin.trim();
    final banks = await getBanks();

    for (final bank in banks) {
      if (bank.bin == expectedBin) return bank;
    }

    return null;
  }

  static String createQrUrl({
    required String bankBin,
    required String accountNumber,
    required String accountName,
    required double totalAmount,
    required String paymentReference,
    String template = 'compact2',
  }) {
    final normalizedBin = bankBin.trim();
    final normalizedAccount = accountNumber
        .replaceAll(RegExp(r'\s+'), '');
    final normalizedName = accountName.trim();
    final normalizedReference = _normalizeReference(paymentReference);
    final amount = totalAmount.round();

    if (normalizedBin.isEmpty) {
      throw StateError('Chưa có mã BIN ngân hàng.');
    }

    if (!RegExp(r'^[0-9]{6,19}$').hasMatch(normalizedAccount)) {
      throw StateError('Số tài khoản ngân hàng không hợp lệ.');
    }

    if (normalizedName.length < 2) {
      throw StateError('Tên chủ tài khoản không hợp lệ.');
    }

    if (amount <= 0) {
      throw StateError('Số tiền thanh toán phải lớn hơn 0.');
    }

    if (normalizedReference.isEmpty) {
      throw StateError('Mã nội dung chuyển khoản không hợp lệ.');
    }

    final safeTemplate = const {
      'compact',
      'compact2',
      'qr_only',
      'print',
    }.contains(template)
        ? template
        : 'compact2';

    return Uri.https(
      'img.vietqr.io',
      '/image/$normalizedBin-$normalizedAccount-$safeTemplate.png',
      {
        'amount': amount.toString(),
        'addInfo': normalizedReference,
        'accountName': normalizedName,
      },
    ).toString();
  }

  static String _normalizeReference(String value) {
    final normalized = value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9_]'), '');

    if (normalized.length <= 25) return normalized;
    return normalized.substring(0, 25);
  }

  void dispose() {
    _client.close();
  }
}