import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/core/utils/search_keywords.dart';
import 'package:bookswaphub/data/models/book.dart';

enum BookSort { recent, rating, titleAZ }

class BookDraft {
  final String title;
  final String author;
  final String categoryId;
  final String categoryName;
  final String description;
  final String condition;
  final String language;
  final String location;
  final String listingType; // swap | sale | both
  final double? price;

  const BookDraft({
    required this.title,
    required this.author,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.condition,
    required this.language,
    required this.location,
    required this.listingType,
    this.price,
  });
}

class BookPage {
  final List<Book> books;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  const BookPage(this.books, this.lastDoc, this.hasMore);
}

class BookRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  BookRepository(this._db, this._storage);

  CollectionReference<Map<String, dynamic>> get _books => _db.collection('books');

  static const int pageSize = 12;

  /// One page of available books. Uses real Firestore queries (see firestore.indexes.json).
  Future<BookPage> fetchPage({
    String? categoryId,
    String query = '',
    BookSort sort = BookSort.recent,
    String? location,
    String? ownerId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> q = _books.where('status', isEqualTo: 'available');
    if (categoryId != null && categoryId.isNotEmpty) {
      q = q.where('categoryId', isEqualTo: categoryId);
    }
    if (location != null && location.isNotEmpty) {
      q = q.where('location', isEqualTo: location);
    }
    if (ownerId != null && ownerId.isNotEmpty) {
      q = q.where('ownerId', isEqualTo: ownerId);
    }
    final keyword = queryKeyword(query);
    if (keyword != null) {
      // Searching: one keyword server-side, newest first; other words are filtered below.
      q = q.where('searchKeywords', arrayContains: keyword).orderBy('createdAt', descending: true);
    } else {
      switch (sort) {
        case BookSort.recent:
          q = q.orderBy('createdAt', descending: true);
          break;
        case BookSort.rating:
          q = q.orderBy('rating', descending: true).orderBy('createdAt', descending: true);
          break;
        case BookSort.titleAZ:
          q = q.orderBy('titleLower');
          break;
      }
    }
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await q.limit(limit).get();
    var books = snap.docs.map((d) => Book.fromMap(d.id, d.data())).toList();
    if (keyword != null) {
      books = books.where((b) => matchesQuery(query, b.title, b.author)).toList();
      if (sort == BookSort.rating) {
        books.sort((a, b) => b.rating.compareTo(a.rating));
      } else if (sort == BookSort.titleAZ) {
        books.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      }
    }
    return BookPage(books, snap.docs.isEmpty ? startAfter : snap.docs.last, snap.docs.length >= limit);
  }

  Stream<Book?> watchBook(String id) => _books.doc(id).snapshots().map((s) {
        final d = s.data();
        return d == null ? null : Book.fromMap(s.id, d);
      });

  Future<Book?> getBook(String id) async {
    final s = await _books.doc(id).get();
    final d = s.data();
    return d == null ? null : Book.fromMap(s.id, d);
  }

  Future<List<Book>> getBooksByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <Book>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await _books.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map((d) => Book.fromMap(d.id, d.data())));
    }
    return results;
  }

  Stream<List<Book>> watchMyBooks(String uid) {
    return _books
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Book.fromMap(d.id, d.data()))
            .where((b) => b.status != 'removed' && b.status != 'swapped')
            .toList());
  }

  // ---------------- write ----------------

  Map<String, dynamic> _fields(BookDraft d) => {
        'title': d.title,
        'titleLower': d.title.toLowerCase(),
        'author': d.author,
        'authorLower': d.author.toLowerCase(),
        'description': d.description,
        'category': d.categoryName,
        'categoryId': d.categoryId,
        'condition': d.condition,
        'language': d.language,
        'location': d.location,
        'listingType': d.listingType,
        if (d.listingType != 'swap' && d.price != null) 'price': d.price,
        if (d.listingType != 'swap') 'currency': 'inr',
        'searchKeywords': buildSearchKeywords(d.title, d.author),
      };

  Future<String> _upload(String uid, String bookId, XFile file, int index) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const AppFailure('Each image must be smaller than 5 MB.');
    }
    final name = file.name.toLowerCase();
    final type = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    final ext = type == 'image/png' ? 'png' : type == 'image/webp' ? 'webp' : 'jpg';
    final ref = _storage.ref('books/$uid/${bookId}_${DateTime.now().millisecondsSinceEpoch}_$index.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: type));
    return ref.getDownloadURL();
  }

  /// Creates a listing. The success value is returned only after Firestore accepted the write.
  Future<String> createBook({
    required String uid,
    required String ownerName,
    required String ownerAvatar,
    required BookDraft draft,
    required List<XFile> images,
  }) async {
    final ref = _books.doc();
    final urls = <String>[];
    try {
      for (var i = 0; i < images.length && i < 5; i++) {
        urls.add(await _upload(uid, ref.id, images[i], i));
      }
      await ref.set({
        ..._fields(draft),
        'ownerId': uid,
        'ownerName': ownerName,
        if (ownerAvatar.isNotEmpty) 'ownerAvatar': ownerAvatar,
        'status': 'available',
        'rating': 0,
        'ratingCount': 0,
        'imageUrls': urls,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      await _deleteUrls(urls); // don't leave orphaned images behind
      rethrow;
    }
  }

  Future<void> updateBook({
    required Book existing,
    required BookDraft draft,
    required List<String> keepUrls,
    required List<XFile> newImages,
    required bool isAvailable,
  }) async {
    final uploaded = <String>[];
    try {
      final room = 5 - keepUrls.length;
      for (var i = 0; i < newImages.length && i < room; i++) {
        uploaded.add(await _upload(existing.ownerId, existing.id, newImages[i], i));
      }
      final patch = <String, dynamic>{
        ..._fields(draft),
        'imageUrls': [...keepUrls, ...uploaded],
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Owners can only toggle available <-> unavailable (rules enforce this too).
      if (existing.status == 'available' || existing.status == 'unavailable') {
        patch['status'] = isAvailable ? 'available' : 'unavailable';
      }
      if (draft.listingType == 'swap') {
        patch['price'] = FieldValue.delete();
        patch['currency'] = FieldValue.delete();
      }
      await _books.doc(existing.id).update(patch);
      final removed = existing.imageUrls.where((u) => !keepUrls.contains(u)).toList();
      await _deleteUrls(removed);
    } catch (e) {
      await _deleteUrls(uploaded);
      rethrow;
    }
  }

  Future<void> setAvailability(String bookId, bool available) {
    return _books.doc(bookId).update({
      'status': available ? 'available' : 'unavailable',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBook(Book book) async {
    await _books.doc(book.id).delete(); // rules: owner only, and only if not reserved/sold
    await _deleteUrls(book.imageUrls);
  }

  Future<void> _deleteUrls(List<String> urls) async {
    for (final u in urls) {
      try {
        await _storage.refFromURL(u).delete();
      } catch (_) {
        // best effort: an already-missing file is fine
      }
    }
  }
}
