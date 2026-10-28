import 'package:bookswaphub/core/utils/firestore_utils.dart';

enum SwapStatus { pending, accepted, rejected, inProgress, completed, cancelled }

SwapStatus parseSwapStatus(String? s) {
  for (final v in SwapStatus.values) {
    if (v.name == s) return v;
  }
  return SwapStatus.pending;
}

class SwapRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String requesterAvatar;
  final String ownerId;
  final String ownerName;
  final String ownerAvatar;
  final String bookId;
  final String bookTitle;
  final String bookCover;
  final String? offeredBookId;
  final String? offeredBookTitle;
  final String? offeredBookCover;
  final SwapStatus status;
  final String message;
  final List<String> confirmedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SwapRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterAvatar,
    required this.ownerId,
    required this.ownerName,
    required this.ownerAvatar,
    required this.bookId,
    required this.bookTitle,
    required this.bookCover,
    this.offeredBookId,
    this.offeredBookTitle,
    this.offeredBookCover,
    required this.status,
    required this.message,
    this.confirmedBy = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory SwapRequest.fromMap(String id, Map<String, dynamic> d) {
    return SwapRequest(
      id: id,
      requesterId: readString(d['requesterId']),
      requesterName: readString(d['requesterName']),
      requesterAvatar: readString(d['requesterAvatar']),
      ownerId: readString(d['ownerId']),
      ownerName: readString(d['ownerName']),
      ownerAvatar: readString(d['ownerAvatar']),
      bookId: readString(d['bookId']),
      bookTitle: readString(d['bookTitle']),
      bookCover: readString(d['bookCover']),
      offeredBookId: d['offeredBookId'] as String?,
      offeredBookTitle: d['offeredBookTitle'] as String?,
      offeredBookCover: d['offeredBookCover'] as String?,
      status: parseSwapStatus(d['status'] as String?),
      message: readString(d['message']),
      confirmedBy: readStringList(d['confirmedBy']),
      createdAt: readDate(d['createdAt']),
      updatedAt: readDate(d['updatedAt']),
    );
  }

  SwapRequest copyWith({SwapStatus? status, List<String>? confirmedBy}) {
    return SwapRequest(
      id: id,
      requesterId: requesterId,
      requesterName: requesterName,
      requesterAvatar: requesterAvatar,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerAvatar: ownerAvatar,
      bookId: bookId,
      bookTitle: bookTitle,
      bookCover: bookCover,
      offeredBookId: offeredBookId,
      offeredBookTitle: offeredBookTitle,
      offeredBookCover: offeredBookCover,
      status: status ?? this.status,
      message: message,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
