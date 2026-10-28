import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookswaphub/data/models/conversation.dart';
import 'package:bookswaphub/data/models/message.dart';
import 'package:bookswaphub/data/repositories/user_repository.dart';

class ChatRepository {
  final FirebaseFirestore _db;
  final UserRepository _users;
  ChatRepository(this._db, this._users);

  static String conversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<List<Conversation>> watchConversations(String myUid) {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: myUid)
        .snapshots()
        .asyncMap((snap) async {
      final out = <Conversation>[];
      for (final d in snap.docs) {
        final data = d.data();
        final rawIds = data['participantIds'];
        final ids = rawIds is List ? rawIds.map((e) => e.toString()).toList() : <String>[];
        final otherId = ids.firstWhere((e) => e != myUid, orElse: () => '');
        final other = otherId.isNotEmpty ? await _users.getProfile(otherId) : null;
        
        String lastMsg = (data['lastMessage'] as String?) ?? '';
        DateTime? lastMsgAt = (data['lastMessageAt'] as Timestamp?)?.toDate()
            ?? (data['createdAt'] as Timestamp?)?.toDate();

        // If lastMessage is empty, check latest message in messages subcollection
        if (lastMsg.isEmpty) {
          try {
            final latestMsgSnap = await _db
                .collection('conversations/${d.id}/messages')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();
            if (latestMsgSnap.docs.isNotEmpty) {
              final mData = latestMsgSnap.docs.first.data();
              lastMsg = (mData['text'] as String?) ?? '';
              final mTime = (mData['createdAt'] as Timestamp?)?.toDate();
              if (mTime != null) lastMsgAt = mTime;
            }
          } catch (_) {}
        }

        final unread = data['unread'];
        final unreadCount = unread is Map ? (unread[myUid] as num?)?.toInt() ?? 0 : 0;

        out.add(Conversation(
          id: d.id,
          participantId: otherId,
          participantName: other != null && other.name.isNotEmpty ? other.name : 'Book Owner',
          participantAvatar: other?.avatarUrl ?? '',
          lastMessage: lastMsg.isNotEmpty ? lastMsg : 'No messages yet',
          lastMessageTime: lastMsgAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          unreadCount: unreadCount,
        ));
      }
      out.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return out;
    });
  }

  /// Opens (or creates) the one conversation between two people.
  Future<String> getOrCreate(String myUid, String otherUid) async {
    final id = conversationId(myUid, otherUid);
    final ref = _db.doc('conversations/$id');
    final snap = await ref.get();
    if (!snap.exists) {
      final ids = [myUid, otherUid]..sort();
      await ref.set({
        'participantIds': ids,
        'unread': <String, dynamic>{},
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return id;
  }

  /// Newest [limit] messages, oldest first. Increase [limit] to "load earlier".
  Stream<List<Message>> watchMessages(String conversationId, String myUid, {int limit = 30}) {
    return _db
        .collection('conversations/$conversationId/messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((s) => s.docs
            .map((d) => Message.fromMap(d.id, conversationId, d.data(),
                myUid: myUid, isPending: d.metadata.hasPendingWrites))
            .toList()
            .reversed
            .toList());
  }

  /// senderId is always the signed-in user (rules reject anything else).
  Future<void> send(String conversationId, String myUid, String text) async {
    final trimmed = text.trim();
    await _db.collection('conversations/$conversationId/messages').add({
      'senderId': myUid,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await _db.doc('conversations/$conversationId').set({
        'lastMessage': trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': myUid,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> markRead(String conversationId, String myUid) {
    return _db.doc('conversations/$conversationId').update({'unread.$myUid': 0});
  }
}
