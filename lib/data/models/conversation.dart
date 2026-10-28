import 'package:bookswaphub/core/utils/firestore_utils.dart';

/// A chat between two people (Firestore: conversations/{uidA_uidB}).
/// The other person's name/avatar are looked up from their profile, not stored here.
class Conversation {
  final String id;
  final String participantId;
  final String participantName;
  final String participantAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  const Conversation({
    required this.id,
    required this.participantId,
    required this.participantName,
    required this.participantAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.isOnline = false,
  });

  factory Conversation.fromMap(
    String id,
    Map<String, dynamic> d, {
    required String myUid,
    required String otherName,
    required String otherAvatar,
  }) {
    final ids = readStringList(d['participantIds']);
    final other = ids.firstWhere((e) => e != myUid, orElse: () => '');
    final unread = d['unread'];
    return Conversation(
      id: id,
      participantId: other,
      participantName: otherName,
      participantAvatar: otherAvatar,
      lastMessage: readString(d['lastMessage']),
      lastMessageTime: readDate(d['lastMessageAt']),
      unreadCount: unread is Map ? readInt(unread[myUid]) : 0,
    );
  }
}
