import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../model/chat_message.dart';
import '../model/travel_chat_session.dart';

class AiTravelService {
  AiTravelService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? client,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  static const String _apiUrl =
      'https://appdulich-ai-backend.vercel.app/api/travel-ai';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _client;
  final Set<String> _newSessionIds = <String>{};

  CollectionReference<Map<String, dynamic>> get _messagesRef {
    return _firestore.collection('travelChatMessages');
  }

  CollectionReference<Map<String, dynamic>> get _sessionsRef {
    return _firestore.collection('travelChatSessions');
  }

  CollectionReference<Map<String, dynamic>> get _placesRef {
    return _firestore.collection('travelPlaces');
  }

  String get currentUserId {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw Exception('Bạn cần đăng nhập để dùng AI du lịch.');
    }

    return uid;
  }

  Stream<List<TravelChatSessionModel>> watchSessions() {
    final uid = currentUserId;

    return _sessionsRef
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final sessions =
          snapshot.docs.map(TravelChatSessionModel.fromDoc).toList();

      sessions.sort((a, b) {
        final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        return bTime.compareTo(aTime);
      });

      return sessions;
    });
  }

  Stream<List<ChatMessageModel>> watchMessages(String sessionId) {
    final uid = currentUserId;

    return _messagesRef
        .where('userId', isEqualTo: uid)
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map(ChatMessageModel.fromDoc).toList();

      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        return aTime.compareTo(bTime);
      });

      return messages;
    });
  }

  String createSessionId() {
    final sessionId = _sessionsRef.doc().id;
    _newSessionIds.add(sessionId);
    return sessionId;
  }

  Future<void> deleteSession(String sessionId) async {
    final uid = currentUserId;
    final sessionDoc = await _sessionsRef.doc(sessionId).get();

    if (!sessionDoc.exists) return;

    final data = sessionDoc.data() ?? {};
    if (data['userId'] != uid) {
      throw Exception('Bạn không có quyền xóa đoạn chat này.');
    }

    final messages = await _messagesRef
        .where('userId', isEqualTo: uid)
        .where('sessionId', isEqualTo: sessionId)
        .get();

    final batch = _firestore.batch();

    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_sessionsRef.doc(sessionId));
    await batch.commit();
  }

  Future<String> ask({
    required String sessionId,
    required String message,
  }) async {
    final uid = currentUserId;
    final cleanMessage = message.trim();

    if (cleanMessage.length < 2) {
      throw Exception('Vui lòng nhập câu hỏi rõ hơn.');
    }

    try {
      final history = await _loadRecentHistory(
        sessionId: sessionId,
        userId: uid,
      );

      await _ensureSession(
        sessionId: sessionId,
        userId: uid,
        firstMessage: cleanMessage,
      );

      await _messagesRef.add({
        'sessionId': sessionId,
        'userId': uid,
        'sender': ChatSender.user.name,
        'type': ChatMessageType.text.name,
        'content': cleanMessage,
        'suggestionIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _updateSessionAfterMessage(
        sessionId: sessionId,
        lastMessage: cleanMessage,
        increment: 1,
      );

      final places = await _loadTravelPlaces();

      final response = await _client
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'sessionId': sessionId,
              'message': cleanMessage,
              'history': history,
              'places': places,
            }),
          )
          .timeout(const Duration(seconds: 28));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_parseError(response.body));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final answer = data['answer'] as String? ?? '';

      if (answer.trim().isEmpty) {
        throw Exception('AI chưa trả về nội dung phù hợp.');
      }

      await _messagesRef.add({
        'sessionId': sessionId,
        'userId': uid,
        'sender': ChatSender.ai.name,
        'type': ChatMessageType.text.name,
        'content': answer.trim(),
        'suggestionIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _updateSessionAfterMessage(
        sessionId: sessionId,
        lastMessage: answer.trim(),
        increment: 1,
      );

      return answer.trim();
    } catch (error, stackTrace) {
      developer.log(
        'AI travel error',
        name: 'AiTravelService',
        error: error,
        stackTrace: stackTrace,
      );

      final errorMessage = error.toString().replaceFirst('Exception: ', '');

      await _saveAiError(
        sessionId: sessionId,
        userId: uid,
        message: errorMessage,
      );

      await _updateSessionAfterMessage(
        sessionId: sessionId,
        lastMessage: errorMessage,
        increment: 1,
      );

      throw Exception(errorMessage);
    }
  }

  Future<void> _ensureSession({
    required String sessionId,
    required String userId,
    required String firstMessage,
  }) async {
    final doc = _sessionsRef.doc(sessionId);
    final sessionData = <String, dynamic>{
      'userId': userId,
      'title': _buildSessionTitle(firstMessage),
      'lastMessage': firstMessage,
      'messageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_newSessionIds.contains(sessionId)) {
      await doc.set(sessionData);
      _newSessionIds.remove(sessionId);
      return;
    }

    final snapshot = await doc.get();
    if (snapshot.exists) return;

    await doc.set(sessionData);
  }

  Future<void> _updateSessionAfterMessage({
    required String sessionId,
    required String lastMessage,
    required int increment,
  }) async {
    await _sessionsRef.doc(sessionId).set({
      'lastMessage': _shortText(lastMessage, 140),
      'messageCount': FieldValue.increment(increment),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, String>>> _loadRecentHistory({
    required String sessionId,
    required String userId,
  }) async {
    final snapshot = await _messagesRef
        .where('userId', isEqualTo: userId)
        .where('sessionId', isEqualTo: sessionId)
        .get();

    final docs = snapshot.docs.toList();

    docs.sort((a, b) {
      final aTime = _dateTime(a.data()['createdAt']);
      final bTime = _dateTime(b.data()['createdAt']);

      return aTime.compareTo(bTime);
    });

    return docs
        .where((doc) {
          final data = doc.data();
          final sender = data['sender'] as String? ?? '';
          final type = data['type'] as String? ?? 'text';
          final content = data['content'] as String? ?? '';

          return type == ChatMessageType.text.name &&
              content.trim().isNotEmpty &&
              (sender == ChatSender.user.name || sender == ChatSender.ai.name);
        })
        .map((doc) {
          final data = doc.data();
          final sender = data['sender'] as String? ?? ChatSender.user.name;
          final content = data['content'] as String? ?? '';

          return {
            'role': sender == ChatSender.ai.name ? 'assistant' : 'user',
            'content': content.trim(),
          };
        })
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadTravelPlaces() async {
    final snapshot =
        await _placesRef.where('isActive', isEqualTo: true).limit(20).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'province': data['province'] ?? '',
        'district': data['district'] ?? '',
        'address': data['address'] ?? '',
        'category': data['category'] ?? '',
        'description': data['description'] ?? '',
        'ticketPrice': data['ticketPrice'] ?? 0,
        'rating': data['rating'] ?? 0,
        'tags': data['tags'] ?? <String>[],
      };
    }).toList();
  }

  Future<void> _saveAiError({
    required String sessionId,
    required String userId,
    required String message,
  }) async {
    await _ensureSession(
      sessionId: sessionId,
      userId: userId,
      firstMessage: 'Đoạn chat du lịch',
    );

    await _messagesRef.add({
      'sessionId': sessionId,
      'userId': userId,
      'sender': ChatSender.ai.name,
      'type': ChatMessageType.error.name,
      'content': message,
      'suggestionIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _parseError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;

      return data['error'] as String? ??
          data['message'] as String? ??
          'AI đang tạm thời không phản hồi.';
    } catch (_) {
      return 'AI đang tạm thời không phản hồi.';
    }
  }

  String _buildSessionTitle(String message) {
    final text = _shortText(message, 42);

    if (text.isEmpty) return 'Đoạn chat du lịch';

    return text;
  }

  String _shortText(String value, int maxLength) {
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (text.length <= maxLength) return text;

    return '${text.substring(0, maxLength).trim()}...';
  }

  DateTime _dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void dispose() {
    _client.close();
  }
}
