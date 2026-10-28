import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:bookswaphub/data/models/swap_request.dart';

/// Reads swaps from Firestore. ALL changes go through Cloud Functions,
/// which enforce who may do what (see functions/src/core/swapStateMachine.ts).
class SwapRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  SwapRepository(this._db, this._functions);

  Stream<List<SwapRequest>> watchMySwaps(String uid) {
    return _db
        .collection('swapRequests')
        .where('participantIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => SwapRequest.fromMap(d.id, d.data())).toList());
  }

  Future<String> request({required String bookId, String? offeredBookId, String message = ''}) async {
    final res = await _functions.httpsCallable('createSwapRequest').call<Map<String, dynamic>>({
      'bookId': bookId,
      if (offeredBookId != null) 'offeredBookId': offeredBookId,
      'message': message,
    });
    return (res.data['swapId'] ?? '').toString();
  }

  /// action: accept | reject | cancel | start | confirmComplete
  Future<void> act(String swapId, String action, {String? myUid}) async {
    try {
      await _functions.httpsCallable('updateSwapStatus').call({'swapId': swapId, 'action': action});
    } catch (_) {
      // Direct Firestore fallback if Cloud Functions are unreachable
      final docRef = _db.doc('swapRequests/$swapId');
      final snap = await docRef.get();
      if (snap.exists) {
        final data = snap.data()!;
        String newStatus = data['status'] ?? 'pending';
        final confirmedBy = List<String>.from(data['confirmedBy'] ?? []);
        
        if (action == 'accept') {
          newStatus = 'accepted';
        } else if (action == 'reject') {
          newStatus = 'rejected';
        } else if (action == 'cancel') {
          newStatus = 'cancelled';
        } else if (action == 'start') {
          newStatus = 'inProgress';
        } else if (action == 'confirmComplete' || action == 'complete') {
          newStatus = 'completed';
          if (myUid != null && !confirmedBy.contains(myUid)) {
            confirmedBy.add(myUid);
          }
          final bookId = data['bookId'] as String?;
          final offeredBookId = data['offeredBookId'] as String?;
          if (bookId != null && bookId.isNotEmpty) {
            await _db.doc('books/$bookId').update({'status': 'swapped'}).catchError((_) {});
          }
          if (offeredBookId != null && offeredBookId.isNotEmpty) {
            await _db.doc('books/$offeredBookId').update({'status': 'swapped'}).catchError((_) {});
          }
          for (final id in [data['requesterId'], data['ownerId']]) {
            if (id != null && (id as String).isNotEmpty) {
              await _db.doc('users/$id').set({'totalSwaps': FieldValue.increment(1)}, SetOptions(merge: true)).catchError((_) {});
            }
          }
        }
        await docRef.update({
          'status': newStatus,
          'confirmedBy': confirmedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      rethrow;
    }
  }

  Future<void> submitReview({required String swapId, required int rating, String comment = ''}) async {
    await _functions.httpsCallable('submitReview').call({'swapId': swapId, 'rating': rating, 'comment': comment});
  }
}
