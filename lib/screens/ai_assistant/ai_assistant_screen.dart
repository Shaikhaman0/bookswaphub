import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/data/repositories/ai_repository.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/routing/app_navigation_helper.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<AiListing> listings;
  final bool isError;

  ChatMessage({required this.text, required this.isUser, this.listings = const [], this.isError = false});
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(text: 'Hi! I\'m your BookSwap Assistant. How can I help you today?', isUser: false),
  ];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  void _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Send the last turns to the backend (it adds real listings and keeps the API key secret).
    final history = _messages
        .where((m) => !m.isError)
        .skip(1) // skip the local greeting
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();
    final recent = history.length > 10 ? history.sublist(history.length - 10) : history;

    ChatMessage reply;
    try {
      final r = await ref.read(aiRepositoryProvider).ask(recent);
      reply = ChatMessage(text: r.text, isUser: false, listings: r.listings);
    } catch (e) {
      reply = ChatMessage(text: friendlyError(e), isUser: false, isError: true);
    }

    if (mounted) {
      setState(() {
        _messages.add(reply);
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(text: 'Hi! I\'m your BookSwap Assistant. How can I help you today?', isUser: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✨ BookSwap Assistant'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => AppNavigationHelper.handleBack(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
            tooltip: 'Clear conversation',
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              _buildSuggestions(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppDimensions.m),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _buildTypingIndicator();
                    }
                    final msg = _messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      'Find programming books',
      'Recommend fiction books',
      'Help me list a book',
      'How does swapping work?',
      'Show popular books',
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.s),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.m),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.s),
            child: ActionChip(
              label: Text(suggestions[index]),
              onPressed: () => _sendMessage(suggestions[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.m),
        padding: const EdgeInsets.all(AppDimensions.m),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: message.isUser ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: message.isUser ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: !message.isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser) ...[
              const Icon(Icons.smart_toy, size: 20, color: Colors.black54),
              const SizedBox(width: AppDimensions.s),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : (message.isError ? Colors.red.shade800 : Colors.black87),
                    ),
                  ),
                  if (message.listings.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.s),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.listings
                          .map((l) => ActionChip(
                                avatar: const Icon(Icons.menu_book, size: 16),
                                label: Text(l.title, overflow: TextOverflow.ellipsis),
                                onPressed: () => context.go('/book/${l.id}'),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.m),
        padding: const EdgeInsets.all(AppDimensions.m),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.smart_toy, size: 20, color: Colors.black54),
            SizedBox(width: AppDimensions.s),
            Text('...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.m),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.m, vertical: AppDimensions.s),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: AppDimensions.s),
            IconButton(
              icon: const Icon(Icons.send),
              color: Theme.of(context).primaryColor,
              onPressed: () => _sendMessage(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}
