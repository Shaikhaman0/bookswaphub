import 'package:bookswaphub/core/utils/firestore_utils.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final bool isMe;
  final bool isPending; // still being sent (offline queue)

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName = '',
    this.senderAvatar = '',
    required this.content,
    required this.timestamp,
    this.isRead = false,
    required this.isMe,
    this.isPending = false,
  });

  factory Message.fromMap(
    String id,
    String conversationId,
    Map<String, dynamic> d, {
    required String myUid,
    bool isPending = false,
  }) {
    final sender = readString(d['senderId']);
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: sender,
      content: readString(d['text']),
      timestamp: readDate(d['createdAt']),
      isMe: sender == myUid,
      isPending: isPending,
    );
  }
}
