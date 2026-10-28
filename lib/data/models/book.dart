import 'package:bookswaphub/core/utils/firestore_utils.dart';

/// A book listing (Firestore: books/{id}).
/// `status`: available | unavailable | reserved | swapped | sold | removed
/// `listingType`: swap | sale | both
class Book {
  final String id;
  final String title;
  final String author;
  final String description;
  final String category; // display name
  final String categoryId;
  final String genre;
  final String condition; // 'Like New', 'Good', 'Fair', 'Worn'
  final String language;
  final String edition;
  final String ownerId;
  final String ownerName;
  final String ownerAvatar;
  final String location;
  final double rating;
  final int ratingCount;
  final String status;
  final String listingType;
  final double? price;
  final String currency;
  final List<String> imageUrls;
  final DateTime createdAt;
  final bool isWishlisted; // UI hint only; real state comes from the wishlist provider

  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.description = '',
    this.category = '',
    this.categoryId = '',
    this.genre = '',
    this.condition = 'Good',
    this.language = 'English',
    this.edition = '',
    required this.ownerId,
    this.ownerName = '',
    this.ownerAvatar = '',
    this.location = '',
    this.rating = 0,
    this.ratingCount = 0,
    this.status = 'available',
    this.listingType = 'swap',
    this.price,
    this.currency = 'inr',
    this.imageUrls = const [],
    required this.createdAt,
    this.isWishlisted = false,
  });

  bool get isAvailable => status == 'available';
  bool get canSwap => listingType == 'swap' || listingType == 'both';
  bool get canBuy => listingType == 'sale' || listingType == 'both';

  factory Book.fromMap(String id, Map<String, dynamic> d) {
    return Book(
      id: id,
      title: readString(d['title']),
      author: readString(d['author']),
      description: readString(d['description']),
      category: readString(d['category']),
      categoryId: readString(d['categoryId']),
      genre: readString(d['genre']),
      condition: readString(d['condition'], 'Good'),
      language: readString(d['language'], 'English'),
      edition: readString(d['edition']),
      ownerId: readString(d['ownerId']),
      ownerName: readString(d['ownerName']),
      ownerAvatar: readString(d['ownerAvatar']),
      location: readString(d['location']),
      rating: readDouble(d['rating']),
      ratingCount: readInt(d['ratingCount']),
      status: readString(d['status'], 'available'),
      listingType: readString(d['listingType'], 'swap'),
      price: d['price'] is num ? (d['price'] as num).toDouble() : null,
      currency: readString(d['currency'], 'inr'),
      imageUrls: readStringList(d['imageUrls']),
      createdAt: readDate(d['createdAt']),
    );
  }

  Book copyWith({
    String? title,
    String? author,
    String? description,
    String? category,
    String? categoryId,
    String? condition,
    String? language,
    String? location,
    String? status,
    String? listingType,
    double? price,
    List<String>? imageUrls,
    bool? isWishlisted,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      genre: genre,
      condition: condition ?? this.condition,
      language: language ?? this.language,
      edition: edition,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerAvatar: ownerAvatar,
      location: location ?? this.location,
      rating: rating,
      ratingCount: ratingCount,
      status: status ?? this.status,
      listingType: listingType ?? this.listingType,
      price: price ?? this.price,
      currency: currency,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt,
      isWishlisted: isWishlisted ?? this.isWishlisted,
    );
  }
}
