import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bookswaphub/data/models/user.dart';

class UserRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final Map<String, User> _cache = {};
  UserRepository(this._db, this._storage);

  Stream<User> watchProfile(String uid, {String email = ''}) {
    return _db.doc('users/$uid').snapshots().map((s) {
      final d = s.data();
      return d == null ? User.deleted(uid) : User.fromMap(uid, d, email: email);
    });
  }

  /// Cached lookup for names/avatars (chat, reviews).
  Future<User> getProfile(String uid) async {
    final hit = _cache[uid];
    if (hit != null) return hit;
    final s = await _db.doc('users/$uid').get();
    final d = s.data();
    final u = d == null ? User.deleted(uid) : User.fromMap(uid, d);
    _cache[uid] = u;
    return u;
  }

  Future<void> updateProfile(String uid, {required String name, required String bio, required String location}) async {
    await _db.doc('users/$uid').update({
      'name': name.trim(),
      'bio': bio.trim(),
      'location': location.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _cache.remove(uid);
  }

  Future<void> uploadAvatar(String uid, XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      throw Exception('Profile photo must be smaller than 2 MB.');
    }
    final name = file.name.toLowerCase();
    final type = name.endsWith('.png') ? 'image/png' : name.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
    final ref = _storage.ref('avatars/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}');
    await ref.putData(bytes, SettableMetadata(contentType: type));
    final url = await ref.getDownloadURL();
    await _db.doc('users/$uid').update({'avatarUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
    _cache.remove(uid);
  }

  /// Saves this phone/browser's push token so Cloud Functions can notify the user.
  Future<void> saveDeviceToken(String uid, String token, String platform) {
    return _db.doc('users/$uid/devices/$token').set({
      'platform': platform,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeDeviceToken(String uid, String token) =>
      _db.doc('users/$uid/devices/$token').delete();

  // Admin reads (allowed to everyone signed-in by rules, but only used on the admin screen).
  Future<List<User>> recentUsers({int limit = 100}) async {
    try {
      final s = await _db.collection('users').orderBy('createdAt', descending: true).limit(limit).get();
      return s.docs.map((d) => User.fromMap(d.id, d.data())).toList();
    } catch (_) {
      final s = await _db.collection('users').limit(limit).get();
      return s.docs.map((d) => User.fromMap(d.id, d.data())).toList();
    }
  }
}
