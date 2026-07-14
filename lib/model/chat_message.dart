import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatSender {
  user,
  ai,
  system;

  String get label {
    return switch (this) {
      ChatSender.user => 'Bạn',
      ChatSender.ai => 'TravelHub AI',
      ChatSender.system => 'Hệ thống',
    };
  }

  static ChatSender fromValue(String? value) {
    return ChatSender.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ChatSender.user,
    );
  }
}

enum ChatMessageType {
  text,
  suggestion,
  error;

  String get label {
    return switch (this) {
      ChatMessageType.text => 'Tin nhắn',
      ChatMessageType.suggestion => 'Gợi ý',
      ChatMessageType.error => 'Lỗi',
    };
  }

  static ChatMessageType fromValue(String? value) {
    return ChatMessageType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ChatMessageType.text,
    );
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.content,
    required this.sender,
    this.type = ChatMessageType.text,
    this.suggestionIds = const [],
    this.createdAt,
  });

  final String id;
  final String sessionId;
  final String userId;
  final String content;
  final ChatSender sender;
  final ChatMessageType type;
  final List<String> suggestionIds;
  final DateTime? createdAt;

  bool get isUser {
    return sender == ChatSender.user;
  }

  bool get isAi {
    return sender == ChatSender.ai;
  }

  factory ChatMessageModel.user({
    required String sessionId,
    required String userId,
    required String content,
  }) {
    return ChatMessageModel(
      id: '',
      sessionId: sessionId,
      userId: userId,
      content: content,
      sender: ChatSender.user,
    );
  }

  factory ChatMessageModel.ai({
    required String sessionId,
    required String userId,
    required String content,
    List<String> suggestionIds = const [],
  }) {
    return ChatMessageModel(
      id: '',
      sessionId: sessionId,
      userId: userId,
      content: content,
      sender: ChatSender.ai,
      type: suggestionIds.isEmpty
          ? ChatMessageType.text
          : ChatMessageType.suggestion,
      suggestionIds: suggestionIds,
    );
  }

  factory ChatMessageModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ChatMessageModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory ChatMessageModel.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    return ChatMessageModel(
      id: id,
      sessionId: data['sessionId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      sender: ChatSender.fromValue(data['sender'] as String?),
      type: ChatMessageType.fromValue(data['type'] as String?),
      suggestionIds: _stringList(data['suggestionIds']),
      createdAt: _dateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'content': content,
      'sender': sender.name,
      'type': type.name,
      'suggestionIds': suggestionIds,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : createdAt,
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? sessionId,
    String? userId,
    String? content,
    ChatSender? sender,
    ChatMessageType? type,
    List<String>? suggestionIds,
    DateTime? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      suggestionIds: suggestionIds ?? this.suggestionIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.whereType<String>().toList();
  return const [];
}

DateTime? _dateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}