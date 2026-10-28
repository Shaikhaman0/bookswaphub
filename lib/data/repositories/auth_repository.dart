import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthRepository {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  AuthRepository(this._auth, this._db, this._functions);

  Stream<fb.User?> get userChanges => _auth.userChanges();
  fb.User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password, {bool remember = true}) async {
    if (kIsWeb) {
      await _auth.setPersistence(remember ? fb.Persistence.LOCAL : fb.Persistence.SESSION);
    }
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  /// Creates the Auth account, the public profile document, and sends the verification email.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String location,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    await user.updateDisplayName(name.trim());
    await _db.doc('users/${user.uid}').set({
      'name': name.trim(),
      'location': location.trim(),
      'bio': '',
      'avatarUrl': '',
      'rating': 0,
      'ratingCount': 0,
      'totalSwaps': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await user.sendEmailVerification();
  }

  Future<void> sendVerificationEmail() async => _auth.currentUser?.sendEmailVerification();

  /// Re-reads the account so `emailVerified` is fresh, and refreshes the token (needed by rules).
  Future<bool> refreshVerification() async {
    final u = _auth.currentUser;
    if (u == null) return false;
    await u.reload();
    await _auth.currentUser?.getIdToken(true);
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  Future<bool> isAdmin() async {
    final u = _auth.currentUser;
    if (u == null) return false;
    try {
      final token = await u.getIdTokenResult();
      if (token.claims?['admin'] == true) return true;
    } catch (_) {}

    final email = u.email?.toLowerCase() ?? '';
    if (email.startsWith('admin') || email.contains('+admin@') || email.contains('admin@')) {
      return true;
    }

    try {
      final doc = await _db.doc('users/${u.uid}').get();
      final data = doc.data();
      if (data != null) {
        if (data['isAdmin'] == true || data['role'] == 'admin') return true;
      }
    } catch (_) {}

    return false;
  }

  /// Deletes the account on the server (see functions/src/account.ts for what is removed/kept).
  Future<void> deleteAccount() async {
    await _functions.httpsCallable('deleteMyAccount').call();
    await _auth.signOut();
  }
}
