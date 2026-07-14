import 'dart:developer' as developer;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/chat_message.dart';
import '../model/travel_place.dart';
import '../model/travel_suggestion.dart';

class AiTravelService {
  AiTravelService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _messagesRef {
    return _firestore.collection('travelChatMessages');
  }

  CollectionReference<Map<String, dynamic>> get _suggestionsRef {
    return _firestore.collection('travelSuggestions');
  }

  CollectionReference<Map<String, dynamic>> get _placesRef {
    return _firestore.collection('travelPlaces');
  }

  String get currentSessionId {
    final userId = _auth.currentUser?.uid ?? 'guest';
    final now = DateTime.now();
    return '${userId}_${now.year}_${now.month}_${now.day}';
  }

  Stream<List<ChatMessageModel>> watchMessages({
    String? sessionId,
  }) {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Stream.value(const []);
    }

    final effectiveSessionId = sessionId ?? currentSessionId;

    return _messagesRef
        .where('userId', isEqualTo: userId)
        .where('sessionId', isEqualTo: effectiveSessionId)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map(ChatMessageModel.fromDoc).toList();

      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

      return messages;
    }).handleError((error, stackTrace) {
      developer.log(
        'watchMessages failed',
        name: 'AiTravelService',
        error: error,
        stackTrace: stackTrace,
      );
      throw error;
    });
  }

  Stream<List<TravelSuggestionModel>> watchSuggestions({
    String province = '',
    TravelSuggestionType? type,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _suggestionsRef;

    if (province.trim().isNotEmpty) {
      query = query.where('province', isEqualTo: province.trim());
    }

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      final suggestions =
          snapshot.docs.map(TravelSuggestionModel.fromDoc).toList();

      suggestions.sort((a, b) => a.title.compareTo(b.title));

      return suggestions;
    });
  }

  Future<ChatMessageModel> sendMessage({
    required String content,
    String? sessionId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Bạn cần đăng nhập để dùng trợ lý du lịch.');
    }

    final question = content.trim();

    if (question.isEmpty) {
      throw Exception('Vui lòng nhập câu hỏi.');
    }

    final effectiveSessionId = sessionId ?? currentSessionId;

    final userMessageDoc = _messagesRef.doc();
    final userMessage = ChatMessageModel.user(
      sessionId: effectiveSessionId,
      userId: user.uid,
      content: question,
    );

    await userMessageDoc.set(userMessage.toMap());

    final aiResponse = await _buildLocalAiResponse(
      userId: user.uid,
      sessionId: effectiveSessionId,
      question: question,
    );

    final aiMessageDoc = _messagesRef.doc();

    final aiMessage = ChatMessageModel.ai(
      sessionId: effectiveSessionId,
      userId: user.uid,
      content: aiResponse.content,
      suggestionIds: aiResponse.suggestionIds,
    );

    await aiMessageDoc.set(aiMessage.toMap());

    return aiMessage.copyWith(id: aiMessageDoc.id);
  }

  Future<_AiResponse> _buildLocalAiResponse({
    required String userId,
    required String sessionId,
    required String question,
  }) async {
    final places = await _loadPlacesForQuestion(question);

    if (places.isEmpty) {
      return const _AiResponse(
        content:
            'Mình chưa tìm thấy địa điểm phù hợp trong dữ liệu hiện tại. Bạn có thể thử hỏi theo tỉnh/thành phố, ví dụ: "Gợi ý địa điểm ở Đà Nẵng" hoặc "Đi biển ở đâu đẹp?".',
      );
    }

    final selected = places.take(3).toList();
    final suggestionIds = <String>[];

    for (final place in selected) {
      final suggestionDoc = _suggestionsRef.doc();

      final suggestion = TravelSuggestionModel(
        id: suggestionDoc.id,
        title: place.name,
        description: place.description.isEmpty
            ? 'Địa điểm phù hợp với nhu cầu bạn vừa hỏi.'
            : place.description,
        type: TravelSuggestionType.place,
        placeId: place.id,
        imageUrl: place.primaryImage,
        province: place.province,
        district: place.district,
        estimatedCost: place.ticketPrice,
        durationText: 'Nửa ngày - 1 ngày',
        reasons: _buildReasons(place, question),
        tags: place.tags,
      );

      await suggestionDoc.set(suggestion.toMap());
      suggestionIds.add(suggestionDoc.id);
    }

    final placeLines = selected.map((place) {
      final location = [
        place.district,
        place.province,
      ].where((item) => item.trim().isNotEmpty).join(', ');

      final locationText = location.isEmpty ? '' : ' - $location';
      return '• ${place.name}$locationText';
    }).join('\n');

    return _AiResponse(
      content:
          'Mình gợi ý cho bạn một vài địa điểm phù hợp:\n$placeLines\n\nBạn có thể hỏi thêm kiểu: "Lập lịch trình 2 ngày", "Có địa điểm nào gần biển không?", hoặc "Gợi ý nơi đi cùng gia đình".',
      suggestionIds: suggestionIds,
    );
  }

  Future<List<TravelPlaceModel>> _loadPlacesForQuestion(String question) async {
    final normalizedQuestion = _normalize(question);

    final snapshot = await _placesRef
        .where('isActive', isEqualTo: true)
        .limit(80)
        .get();

    final places = snapshot.docs.map(TravelPlaceModel.fromDoc).toList();

    places.sort((a, b) {
      final scoreCompare =
          _scorePlace(b, normalizedQuestion).compareTo(_scorePlace(a, normalizedQuestion));

      if (scoreCompare != 0) return scoreCompare;

      final ratingCompare = b.rating.compareTo(a.rating);
      if (ratingCompare != 0) return ratingCompare;

      return b.reviewCount.compareTo(a.reviewCount);
    });

    return places.where((place) {
      return _scorePlace(place, normalizedQuestion) > 0 ||
          normalizedQuestion.contains('gợi ý') ||
          normalizedQuestion.contains('du lịch') ||
          normalizedQuestion.contains('địa điểm');
    }).toList();
  }

  int _scorePlace(TravelPlaceModel place, String question) {
    final source = _normalize(
      '${place.name} ${place.description} ${place.province} '
      '${place.district} ${place.category.label} ${place.tags.join(' ')}',
    );

    var score = 0;

    for (final token in question.split(RegExp(r'\s+'))) {
      if (token.length < 2) continue;
      if (source.contains(token)) score += 2;
    }

    if (question.contains('biển') &&
        place.category == TravelPlaceCategory.beach) {
      score += 8;
    }

    if ((question.contains('núi') || question.contains('rừng')) &&
        place.category == TravelPlaceCategory.mountain) {
      score += 8;
    }

    if ((question.contains('văn hóa') || question.contains('lịch sử')) &&
        place.category == TravelPlaceCategory.culture) {
      score += 8;
    }

    if ((question.contains('ăn') || question.contains('ẩm thực')) &&
        place.category == TravelPlaceCategory.food) {
      score += 8;
    }

    if (place.isFeatured) score += 2;
    score += min(place.rating.round(), 5);

    return score;
  }

  List<String> _buildReasons(TravelPlaceModel place, String question) {
    final reasons = <String>[];

    if (place.rating >= 4.5) {
      reasons.add('Được đánh giá cao');
    }

    if (place.isFeatured) {
      reasons.add('Địa điểm nổi bật');
    }

    if (place.category != TravelPlaceCategory.other) {
      reasons.add('Phù hợp nhóm ${place.category.label}');
    }

    if (question.contains(_normalize(place.province))) {
      reasons.add('Đúng khu vực bạn quan tâm');
    }

    if (reasons.isEmpty) {
      reasons.add('Phù hợp với câu hỏi của bạn');
    }

    return reasons;
  }
}

class _AiResponse {
  const _AiResponse({
    required this.content,
    this.suggestionIds = const [],
  });

  final String content;
  final List<String> suggestionIds;
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}