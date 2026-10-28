import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Turns low-level Firebase errors into short messages a user can understand.
class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);
  @override
  String toString() => message;
}

String friendlyError(Object error) {
  if (error is AppFailure) return error.message;
  if (error is fb.FirebaseAuthException) return friendlyAuthCode(error.code);
  if (error is FirebaseFunctionsException) {
    return error.message ?? 'The server could not complete that request.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You are not allowed to do that.';
      case 'unavailable':
        return 'No connection. Please check your internet and try again.';
      case 'not-found':
        return 'That item no longer exists.';
      case 'failed-precondition':
        return 'This query needs a database index. See docs/FIREBASE_SETUP.md (deploy indexes).';
    }
    return error.message ?? 'Something went wrong.';
  }
  return 'Something went wrong. Please try again.';
}

String friendlyAuthCode(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address is not valid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'weak-password':
      return 'Please choose a stronger password (at least 6 characters).';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a bit and try again.';
    case 'network-request-failed':
      return 'No connection. Please check your internet and try again.';
    case 'requires-recent-login':
      return 'Please log in again to do this.';
  }
  return 'Authentication failed ($code).';
}

/// Form validators shared by login/register.
String? validateEmail(String? v) {
  final value = (v ?? '').trim();
  if (value.isEmpty) return 'Email is required';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Enter a valid email';
  return null;
}

String? validatePassword(String? v) {
  final value = v ?? '';
  if (value.isEmpty) return 'Password is required';
  if (value.length < 8) return 'Use at least 8 characters';
  return null;
}
