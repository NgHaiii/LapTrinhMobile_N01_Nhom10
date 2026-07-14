import 'package:flutter/material.dart';

import '../../../model/chat_message.dart';
import '../../../services/ai_travel_service.dart';
import 'widgets/chat_message_bubble.dart';

class AiTravelChatPage extends StatefulWidget {
  const AiTravelChatPage({
    super.key,
    this.service,
  });

  final AiTravelService? service;

  @override
  State<AiTravelChatPage> createState() => _AiTravelChatPageState();
}

class _AiTravelChatPageState extends State<AiTravelChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  late final AiTravelService _service;
  late final String _sessionId;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AiTravelService();
    _sessionId = _service.currentSessionId;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();
    _messageController.clear();
    setState(() => _sending = true);

    try {
      await _service.sendMessage(
        content: text,
        sessionId: _sessionId,
      );

      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 140,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _quickAsk(String text) {
    _messageController.text = text;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      appBar: AppBar(
        title: const Text('AI gợi ý du lịch'),
        backgroundColor: const Color(0xFFF4FAF9),
      ),
      body: Column(
        children: [
          _SuggestionChips(onTap: _quickAsk),
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _service.watchMessages(sessionId: _sessionId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (snapshot.connectionState == ConnectionState.waiting &&
                    messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Không thể tải đoạn chat',
                    message: _cleanError(snapshot.error),
                  );
                }

                if (messages.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Bạn muốn đi đâu?',
                    message:
                        'Hỏi TravelHub AI để nhận gợi ý địa điểm, lịch trình và hoạt động du lịch.',
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return ChatMessageBubble(message: messages[index]);
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Hỏi về địa điểm, lịch trình, chi phí...',
                        prefixIcon: Icon(Icons.travel_explore_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Gửi',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      'Gợi ý địa điểm đi biển',
      'Đi đâu ở Đà Nẵng?',
      'Lập lịch trình 2 ngày',
      'Địa điểm phù hợp gia đình',
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];

          return ActionChip(
            avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: Text(suggestion),
            onPressed: () => onTap(suggestion),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: const Color(0xFF087F8C)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF102326),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF647A7D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}