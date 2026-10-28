import 'package:cloud_firestore/cloud_firestore.dart';

class WishlistRepository {
  final FirebaseFirestore _db;
  WishlistRepository(this._db);

  /// Newest first. Each entry is a book id.
  Stream<List<String>> watchBookIds(String uid) {
    return _db
        .collection('wishlists')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => (d.data()['bookId'] ?? '').toString()).where((e) => e.isNotEmpty).toList());
  }

  Future<void> add(String uid, String bookId) {
    // doc id = uid_bookId, so the same book can never be added twice.
    return _db.doc('wishlists/${uid}_$bookId').set({
      'userId': uid,
      'bookId': bookId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String uid, String bookId) => _db.doc('wishlists/${uid}_$bookId').delete();
}
