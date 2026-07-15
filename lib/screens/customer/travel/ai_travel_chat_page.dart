import 'package:flutter/material.dart';

import '../../../model/chat_message.dart';
import '../../../services/ai_travel_service.dart';
import 'travel_chat_history_page.dart';
import 'widgets/chat_message_bubble.dart';

class AiTravelChatPage extends StatefulWidget {
  const AiTravelChatPage({
    super.key,
    this.sessionId,
  });

  final String? sessionId;

  @override
  State<AiTravelChatPage> createState() => _AiTravelChatPageState();
}

class _AiTravelChatPageState extends State<AiTravelChatPage> {
  final AiTravelService _service = AiTravelService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String _sessionId;

  bool _sending = false;

  static const _quickPrompts = [
    'Gợi ý địa điểm đi biển',
    'Đi đâu ở Đà Nẵng 3 ngày?',
    'Lịch trình Hà Nội cuối tuần',
    'Du lịch tiết kiệm cho 2 người',
    'Tiếp tục gợi ý này',
  ];

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId ?? _service.createSessionId();
  }

  void _newChat() {
    if (_sending) return;

    setState(() {
      _sessionId = _service.createSessionId();
    });

    _controller.clear();
  }

  Future<void> _openHistory() async {
    final selectedSessionId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const TravelChatHistoryPage(),
      ),
    );

    if (!mounted || selectedSessionId == null || selectedSessionId.isEmpty) {
      return;
    }

    setState(() {
      _sessionId = selectedSessionId;
    });

    _scrollToBottom();
  }

  Future<void> _send([String? text]) async {
    final message = (text ?? _controller.text).trim();

    if (message.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();
    _controller.clear();

    setState(() => _sending = true);
    _scrollToBottom();

    try {
      await _service.ask(
        sessionId: _sessionId,
        message: message,
      );

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_cleanError(error)),
          ),
        );

      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;

      _scrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _service.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF3FAF8),
      appBar: AppBar(
        title: const Text('AI gợi ý du lịch'),
        backgroundColor: const Color(0xFFF3FAF8),
        actions: [
          IconButton(
            tooltip: 'Lịch sử chat',
            onPressed: _sending ? null : _openHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Đoạn chat mới',
            onPressed: _sending ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _QuickPromptBar(
            prompts: _quickPrompts,
            sending: _sending,
            onPromptTap: _send,
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              key: ValueKey(_sessionId),
              stream: _service.watchMessages(_sessionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ScrollableState(
                    child: _EmptyState(
                      title: 'Không thể tải đoạn chat',
                      message: _cleanError(snapshot.error),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty && !_sending) {
                  return const _ScrollableState(
                    child: _WelcomeState(),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                  itemCount: messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_sending && index == messages.length) {
                      return const _TypingBubble();
                    }

                    return ChatMessageBubble(message: messages[index]);
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.outlineVariant),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !_sending,
                      decoration: InputDecoration(
                        hintText: 'Hỏi tiếp về lịch trình, chi phí...',
                        prefixIcon: const Icon(Icons.travel_explore_rounded),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Xóa',
                                onPressed: _sending
                                    ? null
                                    : () {
                                        _controller.clear();
                                        setState(() {});
                                      },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox.square(
                    dimension: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _sending ? null : () => _send(),
                      child: _sending
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
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

class _QuickPromptBar extends StatelessWidget {
  const _QuickPromptBar({
    required this.prompts,
    required this.sending,
    required this.onPromptTap,
  });

  final List<String> prompts;
  final bool sending;
  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 54,
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];

          return ActionChip(
            avatar: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: colors.primary,
            ),
            label: Text(
              prompt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: sending ? null : () => onPromptTap(prompt),
          );
        },
      ),
    );
  }
}

class _ScrollableState extends StatelessWidget {
  const _ScrollableState({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _WelcomeState extends StatelessWidget {
  const _WelcomeState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: const Icon(Icons.auto_awesome_rounded, size: 38),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bạn muốn đi đâu hôm nay?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hỏi AI về lịch trình, địa điểm, chi phí, ăn uống hoặc mở lại lịch sử chat để tiếp tục.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'TravelHub AI đang suy nghĩ...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 58, color: colors.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
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