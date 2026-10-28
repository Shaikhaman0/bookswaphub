import 'package:bookswaphub/core/utils/firestore_utils.dart';

/// Public profile (Firestore: users/{uid}). Email comes from Firebase Auth, not Firestore.
class User {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String bio;
  final String location;
  final double rating;
  final int ratingCount;
  final int totalBooks;
  final int totalSwaps;
  final DateTime joinedDate;
  final bool isOnline;
  final bool disabled;
  final bool isAdmin;

  DateTime get createdAt => joinedDate;

  const User({
    required this.id,
    required this.name,
    this.email = '',
    this.avatarUrl = '',
    this.bio = '',
    this.location = '',
    this.rating = 0,
    this.ratingCount = 0,
    this.totalBooks = 0,
    this.totalSwaps = 0,
    required this.joinedDate,
    this.isOnline = false,
    this.disabled = false,
    this.isAdmin = false,
  });

  factory User.fromMap(String id, Map<String, dynamic> d, {String email = '', int totalBooks = 0}) {
    return User(
      id: id,
      name: readString(d['name'], 'Deleted user'),
      email: email.isNotEmpty ? email : readString(d['email']),
      avatarUrl: readString(d['avatarUrl']),
      bio: readString(d['bio']),
      location: readString(d['location']),
      rating: readDouble(d['rating']),
      ratingCount: readInt(d['ratingCount']),
      totalBooks: totalBooks,
      totalSwaps: readInt(d['totalSwaps']),
      joinedDate: readDate(d['createdAt']),
      disabled: d['disabled'] == true,
      isAdmin: d['isAdmin'] == true || d['role'] == 'admin',
    );
  }

  /// Shown when a profile no longer exists (deleted account).
  factory User.deleted(String id) =>
      User(id: id, name: 'Deleted user', joinedDate: DateTime.fromMillisecondsSinceEpoch(0));
}
