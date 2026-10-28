import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/models/conversation.dart';
import 'package:bookswaphub/data/models/message.dart';
import 'package:bookswaphub/data/models/notification_item.dart';
import 'package:bookswaphub/data/models/review.dart';
import 'package:bookswaphub/data/models/swap_request.dart';
import 'package:bookswaphub/data/models/user.dart';
import 'package:bookswaphub/data/repositories/admin_repository.dart';
import 'package:bookswaphub/data/repositories/ai_repository.dart';
import 'package:bookswaphub/data/repositories/auth_repository.dart';
import 'package:bookswaphub/data/repositories/book_repository.dart';
import 'package:bookswaphub/data/repositories/chat_repository.dart';
import 'package:bookswaphub/data/repositories/notification_repository.dart';
import 'package:bookswaphub/data/repositories/payment_repository.dart';
import 'package:bookswaphub/data/repositories/review_repository.dart';
import 'package:bookswaphub/data/repositories/swap_repository.dart';
import 'package:bookswaphub/data/repositories/user_repository.dart';
import 'package:bookswaphub/data/repositories/wishlist_repository.dart';

// ---------------------------------------------------------------- Firebase instances
final firebaseAuthProvider = Provider<fb.FirebaseAuth>((ref) => fb.FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final storageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);
final functionsProvider = Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instance);

// ---------------------------------------------------------------- Repositories
final authRepositoryProvider = Provider<AuthRepository>(
    (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider), ref.watch(functionsProvider)));
final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository(ref.watch(firestoreProvider), ref.watch(storageProvider)));
final bookRepositoryProvider =
    Provider<BookRepository>((ref) => BookRepository(ref.watch(firestoreProvider), ref.watch(storageProvider)));
final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) => WishlistRepository(ref.watch(firestoreProvider)));
final swapRepositoryProvider =
    Provider<SwapRepository>((ref) => SwapRepository(ref.watch(firestoreProvider), ref.watch(functionsProvider)));
final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(firestoreProvider), ref.watch(userRepositoryProvider)));
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository(ref.watch(firestoreProvider)));
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) => ReviewRepository(ref.watch(firestoreProvider)));
final paymentRepositoryProvider =
    Provider<PaymentRepository>((ref) => PaymentRepository(ref.watch(functionsProvider), ref.watch(firestoreProvider)));
final aiRepositoryProvider = Provider<AiRepository>((ref) => AiRepository(ref.watch(functionsProvider)));
final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository(ref.watch(functionsProvider), ref.watch(firestoreProvider)));

// ---------------------------------------------------------------- Auth state
final authStateProvider = StreamProvider<fb.User?>((ref) => ref.watch(authRepositoryProvider).userChanges);

/// The signed-in user's id, or null (also null while the first auth check is loading).
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).when(
        data: (u) => u?.uid,
        loading: () => null,
        error: (_, __) => null,
      );
});

final currentEmailProvider = Provider<String>((ref) {
  return ref.watch(authStateProvider).when(
        data: (u) => u?.email ?? '',
        loading: () => '',
        error: (_, __) => '',
      );
});

/// True only if the server-issued token carries the admin claim. UI hiding is NOT security;
/// every admin function re-checks on the server.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  return ref.read(authRepositoryProvider).isAdmin();
});

// ---------------------------------------------------------------- Profiles
final myProfileProvider = StreamProvider<User?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  final email = ref.watch(currentEmailProvider);
  return ref.watch(userRepositoryProvider).watchProfile(uid, email: email);
});

final profileProvider = FutureProvider.family<User, String>(
    (ref, uid) => ref.watch(userRepositoryProvider).getProfile(uid));

// ---------------------------------------------------------------- Books
final myBooksProvider = StreamProvider<List<Book>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <Book>[]);
  return ref.watch(bookRepositoryProvider).watchMyBooks(uid);
});

final bookProvider = StreamProvider.family<Book?, String>(
    (ref, id) => ref.watch(bookRepositoryProvider).watchBook(id));

typedef RelatedKey = ({String id, String categoryId});

final relatedBooksProvider = FutureProvider.family<List<Book>, RelatedKey>((ref, key) async {
  if (key.categoryId.isEmpty) return const <Book>[];
  final page = await ref.watch(bookRepositoryProvider).fetchPage(categoryId: key.categoryId, limit: 7);
  return page.books.where((b) => b.id != key.id).take(6).toList();
});

// ---------------------------------------------------------------- Wishlist
final wishlistBookIdsProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <String>[]);
  return ref.watch(wishlistRepositoryProvider).watchBookIds(uid);
});

final wishlistIdSetProvider = Provider<Set<String>>((ref) {
  return ref.watch(wishlistBookIdsProvider).when(
        data: (ids) => ids.toSet(),
        loading: () => <String>{},
        error: (_, __) => <String>{},
      );
});

/// Books in the wishlist. A book that was deleted simply does not come back, and is cleaned up.
final wishlistBooksProvider = FutureProvider<List<Book>>((ref) async {
  final ids = await ref.watch(wishlistBookIdsProvider.future);
  final books = await ref.watch(bookRepositoryProvider).getBooksByIds(ids);
  final byId = {for (final b in books) b.id: b};
  return [for (final id in ids) if (byId[id] != null) byId[id]!];
});

// ---------------------------------------------------------------- Swaps / chat / notifications / reviews
final swapsProvider = StreamProvider<List<SwapRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <SwapRequest>[]);
  return ref.watch(swapRepositoryProvider).watchMySwaps(uid);
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <Conversation>[]);
  return ref.watch(chatRepositoryProvider).watchConversations(uid);
});

typedef MessagesKey = ({String conversationId, int limit});

final messagesProvider = StreamProvider.family<List<Message>, MessagesKey>((ref, key) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <Message>[]);
  return ref.watch(chatRepositoryProvider).watchMessages(key.conversationId, uid, limit: key.limit);
});

final notificationsProvider = StreamProvider<List<NotificationItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <NotificationItem>[]);
  return ref.watch(notificationRepositoryProvider).watch(uid);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).when(
        data: (list) => list.where((n) => !n.isRead).length,
        loading: () => 0,
        error: (_, __) => 0,
      );
});

final reviewsProvider = StreamProvider.family<List<Review>, String>(
    (ref, uid) => ref.watch(reviewRepositoryProvider).watchForUser(uid));

// ---------------------------------------------------------------- Home sections
final homeFeaturedProvider = FutureProvider<List<Book>>((ref) async =>
    (await ref.watch(bookRepositoryProvider).fetchPage(sort: BookSort.rating, limit: 8)).books);

final homeRecentProvider = FutureProvider<List<Book>>((ref) async =>
    (await ref.watch(bookRepositoryProvider).fetchPage(sort: BookSort.recent, limit: 8)).books);

/// "Recommended": more books from the category of your most recent wishlist item (else newest).
final homeRecommendedProvider = FutureProvider<List<Book>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  final wished = await ref.watch(wishlistBooksProvider.future);
  if (wished.isNotEmpty && wished.first.categoryId.isNotEmpty) {
    final page = await repo.fetchPage(categoryId: wished.first.categoryId, limit: 7);
    final list = page.books.where((b) => !wished.any((w) => w.id == b.id)).take(6).toList();
    if (list.isNotEmpty) return list;
  }
  return (await repo.fetchPage(sort: BookSort.recent, limit: 6)).books;
});

final homeNearbyProvider = FutureProvider<List<Book>>((ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  final city = profile?.location ?? '';
  if (city.isEmpty) return const <Book>[];
  return (await ref.watch(bookRepositoryProvider).fetchPage(location: city, limit: 8)).books;
});

// ---------------------------------------------------------------- Discover (search + filters + paging)
class DiscoverState {
  final List<Book> books;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;
  final String query;
  final String? categoryId;
  final BookSort sort;
  final Set<String> conditions;

  const DiscoverState({
    this.books = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
    this.query = '',
    this.categoryId,
    this.sort = BookSort.recent,
    this.conditions = const {},
  });

  List<Book> get visible =>
      conditions.isEmpty ? books : books.where((b) => conditions.contains(b.condition)).toList();

  DiscoverState copyWith({
    List<Book>? books,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
    String? query,
    String? categoryId,
    bool clearCategory = false,
    BookSort? sort,
    Set<String>? conditions,
  }) {
    return DiscoverState(
      books: books ?? this.books,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      sort: sort ?? this.sort,
      conditions: conditions ?? this.conditions,
    );
  }
}

class DiscoverController extends Notifier<DiscoverState> {
  DocumentSnapshot<Map<String, dynamic>>? _last;
  int _generation = 0;

  @override
  DiscoverState build() => const DiscoverState(loading: true);

  /// Condition is a quick on-screen filter (no reload needed).
  void setConditions(Set<String> conditions) {
    state = state.copyWith(conditions: conditions);
  }

  /// Set filters and reload from the first page.
  Future<void> apply({String? query, String? categoryId, bool clearCategory = false, BookSort? sort, Set<String>? conditions}) {
    state = state.copyWith(
      query: query,
      categoryId: categoryId,
      clearCategory: clearCategory,
      sort: sort,
      conditions: conditions,
    );
    return refresh();
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    _last = null;
    state = state.copyWith(loading: true, loadingMore: false, books: const [], clearError: true);
    try {
      final page = await ref.read(bookRepositoryProvider).fetchPage(
            categoryId: state.categoryId,
            query: state.query,
            sort: state.sort,
          );
      if (gen != _generation) return; // a newer search replaced this one
      _last = page.lastDoc;
      state = state.copyWith(books: page.books, loading: false, hasMore: page.hasMore);
    } catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await ref.read(bookRepositoryProvider).fetchPage(
            categoryId: state.categoryId,
            query: state.query,
            sort: state.sort,
            startAfter: _last,
          );
      if (gen != _generation) return;
      _last = page.lastDoc;
      state = state.copyWith(books: [...state.books, ...page.books], loadingMore: false, hasMore: page.hasMore);
    } catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loadingMore: false, error: friendlyError(e));
    }
  }
}

final discoverProvider = NotifierProvider<DiscoverController, DiscoverState>(DiscoverController.new);
