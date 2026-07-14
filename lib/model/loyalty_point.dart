import 'package:cloud_firestore/cloud_firestore.dart';

enum LoyaltyTier {
  bronze,
  silver,
  gold,
  diamond;

  String get label {
    return switch (this) {
      LoyaltyTier.bronze => 'Bronze',
      LoyaltyTier.silver => 'Silver',
      LoyaltyTier.gold => 'Gold',
      LoyaltyTier.diamond => 'Diamond',
    };
  }

  static LoyaltyTier fromValue(String? value) {
    return LoyaltyTier.values.firstWhere(
      (item) => item.name == value,
      orElse: () => LoyaltyTier.bronze,
    );
  }

  static LoyaltyTier fromPoints(int points) {
    if (points >= 10000) return LoyaltyTier.diamond;
    if (points >= 5000) return LoyaltyTier.gold;
    if (points >= 1500) return LoyaltyTier.silver;
    return LoyaltyTier.bronze;
  }
}

class LoyaltyPointModel {
  const LoyaltyPointModel({
    required this.userId,
    this.totalPoints = 0,
    this.availablePoints = 0,
    this.usedPoints = 0,
    this.expiredPoints = 0,
    this.tier = LoyaltyTier.bronze,
    this.updatedAt,
  });

  final String userId;
  final int totalPoints;
  final int availablePoints;
  final int usedPoints;
  final int expiredPoints;
  final LoyaltyTier tier;
  final DateTime? updatedAt;

  int get nextTierPoint {
    return switch (tier) {
      LoyaltyTier.bronze => 1500,
      LoyaltyTier.silver => 5000,
      LoyaltyTier.gold => 10000,
      LoyaltyTier.diamond => totalPoints,
    };
  }

  double get tierProgress {
    if (tier == LoyaltyTier.diamond) return 1;
    if (nextTierPoint <= 0) return 0;
    return (totalPoints / nextTierPoint).clamp(0, 1);
  }

  factory LoyaltyPointModel.empty(String userId) {
    return LoyaltyPointModel(userId: userId);
  }

  factory LoyaltyPointModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return LoyaltyPointModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory LoyaltyPointModel.fromMap(
    Map<String, dynamic> data,
    String userId,
  ) {
    final totalPoints = _intValue(data['totalPoints']);

    return LoyaltyPointModel(
      userId: userId,
      totalPoints: totalPoints,
      availablePoints: _intValue(data['availablePoints']),
      usedPoints: _intValue(data['usedPoints']),
      expiredPoints: _intValue(data['expiredPoints']),
      tier: LoyaltyTier.fromValue(
        data['tier'] as String?,
      ),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'totalPoints': totalPoints,
      'availablePoints': availablePoints,
      'usedPoints': usedPoints,
      'expiredPoints': expiredPoints,
      'tier': tier.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  LoyaltyPointModel copyWith({
    String? userId,
    int? totalPoints,
    int? availablePoints,
    int? usedPoints,
    int? expiredPoints,
    LoyaltyTier? tier,
    DateTime? updatedAt,
  }) {
    return LoyaltyPointModel(
      userId: userId ?? this.userId,
      totalPoints: totalPoints ?? this.totalPoints,
      availablePoints: availablePoints ?? this.availablePoints,
      usedPoints: usedPoints ?? this.usedPoints,
      expiredPoints: expiredPoints ?? this.expiredPoints,
      tier: tier ?? this.tier,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

DateTime? _dateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}