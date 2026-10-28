import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookswaphub/data/models/notification_item.dart';

class NotificationRepository {
  final FirebaseFirestore _db;
  NotificationRepository(this._db);

  Stream<List<NotificationItem>> watch(String uid, {int limit = 50}) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => NotificationItem.fromMap(d.id, d.data())).toList());
  }

  Future<void> markRead(String id) => _db.doc('notifications/$id').update({'isRead': true});

  Future<void> markAllRead(List<String> ids) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_db.doc('notifications/$id'), {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> delete(String id) => _db.doc('notifications/$id').delete();
}
