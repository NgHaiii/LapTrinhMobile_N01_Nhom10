import 'package:cloud_firestore/cloud_firestore.dart';

class TravelChatSessionModel {
  const TravelChatSessionModel({
    required this.id,
    required this.userId,
    required this.title,
    this.lastMessage = '',
    this.messageCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String lastMessage;
  final int messageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TravelChatSessionModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return TravelChatSessionModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory TravelChatSessionModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TravelChatSessionModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Đoạn chat du lịch',
      lastMessage: data['lastMessage'] as String? ?? '',
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'lastMessage': lastMessage,
      'messageCount': messageCount,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
    };
  }

  TravelChatSessionModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? lastMessage,
    int? messageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TravelChatSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      messageCount: messageCount ?? this.messageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}