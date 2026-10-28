import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookswaphub/data/models/review.dart';

class ReviewRepository {
  final FirebaseFirestore _db;
  ReviewRepository(this._db);

  Stream<List<Review>> watchForUser(String uid) {
    return _db
        .collection('reviews')
        .where('revieweeId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => Review.fromMap(d.id, d.data())).toList());
  }

  /// Files a report. Status is always "open"; only admins (through a Cloud Function) can change it.
  Future<void> report({
    required String reporterId,
    required String targetType, // book | user
    required String targetId,
    required String reason, // spam | inappropriate | fake | scam | other
    String details = '',
  }) {
    return _db.collection('reports').add({
      'reporterId': reporterId,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'details': details.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
