import 'package:bookswaphub/core/utils/firestore_utils.dart';

class Review {
  final String id;
  final String reviewerId;
  final String reviewerName;
  final String reviewerAvatar;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerAvatar,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromMap(String id, Map<String, dynamic> d) {
    return Review(
      id: id,
      reviewerId: readString(d['reviewerId']),
      reviewerName: readString(d['reviewerName'], 'Reader'),
      reviewerAvatar: readString(d['reviewerAvatar']),
      rating: readDouble(d['rating']),
      comment: readString(d['comment']),
      createdAt: readDate(d['createdAt']),
    );
  }
}
