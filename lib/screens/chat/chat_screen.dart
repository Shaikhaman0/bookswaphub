import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/conversation.dart';
import 'package:bookswaphub/data/models/message.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/widgets/empty_state.dart';
import 'package:bookswaphub/widgets/error_state.dart';

/// The conversation currently open on screen.
class _ChatTarget {
  final String conversationId;
  final String otherId;
  final String name;
  final String avatar;
  const _ChatTarget(this.conversationId, this.otherId, this.name, this.avatar);
}

class ChatScreen extends ConsumerStatefulWidget {
  /// When set (/chat?with=<uid>), opens or creates the conversation with that person.
  final String? initialUserId;
  const ChatScreen({super.key, this.initialUserId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  _ChatTarget? _target;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _limit = 30;
  String _search = '';
  bool _openingInitial = false;
  bool _markingRead = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUserId != null) _openWithUser(widget.initialUserId!);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUserId != oldWidget.initialUserId) {
      if (widget.initialUserId != null) {
        _openWithUser(widget.initialUserId!);
      } else {
        setState(() => _target = null);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toast(Object e) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is String ? e : friendlyError(e))));

  Future<void> _openWithUser(String otherId) async {
    final me = ref.read(currentUidProvider);
    if (me == null || otherId == me) return;
    setState(() => _openingInitial = true);
    try {
      final id = await ref.read(chatRepositoryProvider).getOrCreate(me, otherId);
      final other = await ref.read(userRepositoryProvider).getProfile(otherId);
      if (!mounted) return;
      setState(() {
        _target = _ChatTarget(id, otherId, other.name, other.avatarUrl);
        _limit = 30;
      });
    } catch (e) {
      if (mounted) _toast(e);
    } finally {
      if (mounted) setState(() => _openingInitial = false);
    }
  }

  void _select(Conversation c) {
    setState(() {
      _target = _ChatTarget(c.id, c.participantId, c.participantName, c.participantAvatar);
      _limit = 30;
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    final target = _target;
    final me = ref.read(currentUidProvider);
    if (text.isEmpty || target == null || me == null) return;
    _messageController.clear();
    try {
      // Works offline too: Firestore queues the message and sends it when you reconnect.
      await ref.read(chatRepositoryProvider).send(target.conversationId, me, text);
    } catch (e) {
      if (mounted) {
        _messageController.text = text; // give the text back so nothing is lost
        _toast(e);
      }
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

  /// Resets MY unread counter when I'm looking at a conversation that has unread messages.
  void _markReadIfNeeded(List<Conversation> conversations) {
    final target = _target;
    final me = ref.read(currentUidProvider);
    if (target == null || me == null || _markingRead) return;
    final match = conversations.where((c) => c.id == target.conversationId);
    if (match.isEmpty || match.first.unreadCount == 0) return;
    _markingRead = true;
    ref.read(chatRepositoryProvider).markRead(target.conversationId, me).catchError((_) {}).whenComplete(() {
      _markingRead = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    conversations.whenData((list) => WidgetsBinding.instance.addPostFrameCallback((_) => _markReadIfNeeded(list)));

    final target = _target;
    final AsyncValue<List<Message>>? messagesAsync;
    if (target != null) {
      messagesAsync = ref.watch(messagesProvider((conversationId: target.conversationId, limit: _limit)));
      ref.listen(messagesProvider((conversationId: target.conversationId, limit: _limit)), (prev, next) {
        next.whenData((_) => _scrollToBottom());
      });
    } else {
      messagesAsync = null;
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= AppDimensions.tabletBreakpoint;

          if (isDesktop) {
            return Row(
              children: [
                SizedBox(width: 300, child: _buildConversationList(conversations)),
                const VerticalDivider(width: 1, color: AppColors.divider),
                Expanded(
                  child: _openingInitial
                      ? const Center(child: CircularProgressIndicator())
                      : target == null
                          ? const EmptyState(
                              icon: Icons.chat,
                              title: 'Your Messages',
                              description: 'Select a conversation to start chatting',
                            )
                          : _buildChatArea(messagesAsync!),
                ),
              ],
            );
          }

          if (_openingInitial) return const Center(child: CircularProgressIndicator());
          return target == null
              ? _buildConversationList(conversations)
              : _buildChatArea(messagesAsync!, isMobile: true);
        },
      ),
    );
  }

  Widget _avatar(String url, String name, {double radius = 20}) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: url.isEmpty ? null : NetworkImage(url),
      child: url.isEmpty ? Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase()) : null,
    );
  }

  Widget _buildConversationList(AsyncValue<List<Conversation>> async) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search messages...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(conversationsProvider)),
            data: (all) {
              final list = _search.isEmpty
                  ? all
                  : all
                      .where((c) =>
                          c.participantName.toLowerCase().contains(_search) ||
                          c.lastMessage.toLowerCase().contains(_search))
                      .toList();
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: _search.isEmpty ? 'No conversations' : 'No results found',
                  description: _search.isEmpty
                      ? 'Open a book and tap "Message owner" to start one.'
                      : 'No conversations matching "$_search".',
                );
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final conversation = list[index];
                  final isSelected = _target?.conversationId == conversation.id;
                  final time = conversation.lastMessageTime;
                  String timeStr = '';
                  if (time.year > 1970) {
                    final now = DateTime.now();
                    final isToday = now.year == time.year && now.month == time.month && now.day == time.day;
                    if (isToday) {
                      timeStr = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
                    } else {
                      timeStr = '${time.day}/${time.month}';
                    }
                  }
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppColors.primaryLight.withValues(alpha: 0.1),
                    leading: _avatar(conversation.participantAvatar, conversation.participantName),
                    title: Text(conversation.participantName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      conversation.lastMessage.isEmpty ? 'No messages yet' : conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        if (conversation.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _select(conversation),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatArea(AsyncValue<List<Message>> messagesAsync, {bool isMobile = false}) {
    final target = _target!;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _target = null),
                ),
              _avatar(target.avatar, target.name),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(target.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(
              message: friendlyError(e),
              onRetry: () => ref.invalidate(messagesProvider((conversationId: target.conversationId, limit: _limit))),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'Say hello',
                  description: 'Send the first message.',
                );
              }
              final canLoadMore = messages.length >= _limit;
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppDimensions.md),
                itemCount: messages.length + (canLoadMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (canLoadMore && index == 0) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(() => _limit += 30),
                        child: const Text('Load earlier messages'),
                      ),
                    );
                  }
                  final message = messages[index - (canLoadMore ? 1 : 0)];
                  return _buildMessageBubble(context, message);
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              const IconButton(
                icon: Icon(Icons.attach_file, color: AppColors.textSecondary),
                tooltip: 'Attachments are not supported yet',
                onPressed: null,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLength: 2000,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.md,
                      vertical: AppDimensions.sm,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.md),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: message.isMe ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg).copyWith(
                  bottomRight: message.isMe ? Radius.zero : null,
                  bottomLeft: !message.isMe ? Radius.zero : null,
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(color: message.isMe ? Colors.white : AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.isPending
                  ? 'Sending...'
                  : '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
