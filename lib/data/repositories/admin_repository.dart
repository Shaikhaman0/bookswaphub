import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/models/swap_request.dart';

class AdminReport {
  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String details;
  final String status;
  final DateTime? createdAt;
  const AdminReport(this.id, this.targetType, this.targetId, this.reason, this.details, this.status, {this.createdAt});
}

/// Admin management repository. Supports both Cloud Functions and direct Firestore operations.
class AdminRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;
  AdminRepository(this._functions, this._db);

  Future<Map<String, int>> stats() async {
    try {
      final res = await _functions.httpsCallable('adminStats').call<Map<String, dynamic>>();
      return res.data.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      // Direct Firestore fallback
      final usersSnap = await _db.collection('users').count().get();
      final booksSnap = await _db.collection('books').where('status', isEqualTo: 'available').count().get();
      final pendingSnap = await _db.collection('swapRequests').where('status', isEqualTo: 'pending').count().get();
      final activeSnap = await _db.collection('swapRequests').where('status', whereIn: ['accepted', 'inProgress']).count().get();
      final completedSnap = await _db.collection('swapRequests').where('status', isEqualTo: 'completed').count().get();
      final reportsSnap = await _db.collection('reports').where('status', isEqualTo: 'open').count().get();
      int paidOrders = 0;
      try {
        final ordersSnap = await _db.collection('orders').where('status', isEqualTo: 'paid').count().get();
        paidOrders = ordersSnap.count ?? 0;
      } catch (_) {}
      return {
        'users': usersSnap.count ?? 0,
        'availableBooks': booksSnap.count ?? 0,
        'swapsPending': pendingSnap.count ?? 0,
        'swapsActive': activeSnap.count ?? 0,
        'swapsCompleted': completedSnap.count ?? 0,
        'openReports': reportsSnap.count ?? 0,
        'paidOrders': paidOrders,
      };
    }
  }

  Stream<List<AdminReport>> watchReports({String? status}) {
    Query query = _db.collection('reports');
    if (status != null && status.isNotEmpty && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final m = d.data() as Map<String, dynamic>;
              return AdminReport(
                d.id,
                '${m['targetType'] ?? 'item'}',
                '${m['targetId'] ?? ''}',
                '${m['reason'] ?? ''}',
                '${m['details'] ?? ''}',
                '${m['status'] ?? 'open'}',
                createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
              );
            }).toList());
  }

  Future<void> updateReport(String id, String status, {String note = ''}) async {
    try {
      await _functions.httpsCallable('adminUpdateReport').call({'reportId': id, 'status': status, 'note': note});
    } catch (_) {
      await _db.doc('reports/$id').set({
        'status': status,
        'adminNote': note,
        'reviewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteReport(String id) async {
    await _db.doc('reports/$id').delete();
  }

  Future<void> moderateBook(String bookId, String action) async {
    try {
      await _functions.httpsCallable('adminModerateBook').call({'bookId': bookId, 'action': action});
    } catch (_) {
      await _db.doc('books/$bookId').update({
        'status': action == 'remove' ? 'removed' : 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateBookStatus(String bookId, String status) async {
    await _db.doc('books/$bookId').update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBook(String bookId) async {
    await _db.doc('books/$bookId').delete();
  }

  Future<void> setUserDisabled(String uid, bool disabled) async {
    try {
      await _functions.httpsCallable('adminSetUserDisabled').call({'uid': uid, 'disabled': disabled});
    } catch (_) {
      await _db.doc('users/$uid').set({'disabled': disabled}, SetOptions(merge: true));
    }
  }

  Future<void> setUserAdmin(String uid, bool isAdmin) async {
    await _db.doc('users/$uid').set({
      'isAdmin': isAdmin,
      'role': isAdmin ? 'admin' : 'user',
    }, SetOptions(merge: true));
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _functions.httpsCallable('adminDeleteUser').call({'uid': uid});
    } catch (_) {
      await _db.doc('users/$uid').delete();
    }
  }

  Future<List<Book>> recentBooks({int limit = 100}) async {
    final s = await _db.collection('books').orderBy('createdAt', descending: true).limit(limit).get();
    return s.docs.map((d) => Book.fromMap(d.id, d.data())).toList();
  }

  Future<List<SwapRequest>> recentSwaps({int limit = 100}) async {
    final s = await _db.collection('swapRequests').orderBy('createdAt', descending: true).limit(limit).get();
    return s.docs.map((d) => SwapRequest.fromMap(d.id, d.data())).toList();
  }

  Future<void> manageSwap(String swapId, String action) async {
    try {
      await _functions.httpsCallable('adminManageSwap').call({'swapId': swapId, 'action': action});
    } catch (_) {
      final ref = _db.doc('swapRequests/$swapId');
      final snap = await ref.get();
      if (!snap.exists) return;

      if (action == 'delete') {
        await ref.delete();
        return;
      }

      String newStatus = action;
      if (action == 'complete' || action == 'forceComplete') newStatus = 'completed';
      if (action == 'cancel' || action == 'forceCancel') newStatus = 'cancelled';
      if (action == 'accept') newStatus = 'accepted';
      if (action == 'reject') newStatus = 'rejected';

      await ref.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final data = snap.data()!;
      final bookId = data['bookId'] as String?;
      final offeredBookId = data['offeredBookId'] as String?;

      if (action == 'cancel' || action == 'reject' || action == 'forceCancel') {
        if (bookId != null && bookId.isNotEmpty) {
          await _db.doc('books/$bookId').update({'status': 'available'}).catchError((_) {});
        }
        if (offeredBookId != null && offeredBookId.isNotEmpty) {
          await _db.doc('books/$offeredBookId').update({'status': 'available'}).catchError((_) {});
        }
      } else if (action == 'complete' || action == 'forceComplete') {
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
    }
  }

  Future<int> sendBroadcastNotification({required String title, required String body}) async {
    try {
      final res = await _functions.httpsCallable('adminBroadcast').call({
        'title': title,
        'body': body,
      });
      final count = (res.data is Map ? (res.data as Map)['count'] as num? : null)?.toInt();
      return count ?? 0;
    } catch (_) {
      // Direct Firestore fallback
      final usersSnap = await _db.collection('users').get();
      final docs = usersSnap.docs;
      for (var i = 0; i < docs.length; i += 400) {
        final chunk = docs.sublist(i, i + 400 > docs.length ? docs.length : i + 400);
        final batch = _db.batch();
        for (final doc in chunk) {
          final notifRef = _db.collection('notifications').doc();
          batch.set(notifRef, {
            'userId': doc.id,
            'title': title,
            'body': body,
            'type': 'system',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
      return docs.length;
    }
  }
}
