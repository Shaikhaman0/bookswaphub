import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/routing/app_navigation_helper.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/models/swap_request.dart';
import 'package:bookswaphub/data/models/user.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/screens/profile/edit_profile_dialog.dart';
import 'package:bookswaphub/widgets/stat_card.dart';
import 'package:bookswaphub/widgets/book_card.dart';
import 'package:bookswaphub/widgets/empty_state.dart';
import 'package:bookswaphub/widgets/error_state.dart';

/// `uid == null` (or equal to the signed-in user) shows YOUR profile with all tabs.
/// Another uid shows that person's public profile: their available books and reviews.
class ProfileScreen extends ConsumerStatefulWidget {
  final String? uid;
  const ProfileScreen({super.key, this.uid});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

/// Books an arbitrary user currently lists (public, available only).
final userBooksProvider = FutureProvider.family<List<Book>, String>((ref, uid) async =>
    (await ref.watch(bookRepositoryProvider).fetchPage(ownerId: uid, limit: 24)).books);

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  TabController? _tabs;
  int _tabCount = 0;

  void _ensureTabs(int n) {
    if (_tabs != null && _tabCount == n) return;
    _tabs?.dispose();
    _tabCount = n;
    _tabs = TabController(length: n, vsync: this);
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUidProvider);
    final targetUid = widget.uid ?? me;
    if (targetUid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isMine = targetUid == me;

    final profile = isMine ? ref.watch(myProfileProvider) : ref.watch(profileProvider(targetUid));
    final isDesktop = MediaQuery.of(context).size.width >= AppDimensions.tabletBreakpoint;
    _ensureTabs(isMine ? 4 : 2);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMine ? 'My Profile' : 'User Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => AppNavigationHelper.handleBack(context),
        ),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: friendlyError(e),
          onRetry: () => isMine ? ref.invalidate(myProfileProvider) : ref.invalidate(profileProvider(targetUid)),
        ),
        data: (user) {
          if (user == null) return const Center(child: Text('Profile not found.'));
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(user, isMine)),
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                    child: TabBar(
                      controller: _tabs,
                      isScrollable: !isDesktop,
                      tabs: isMine
                          ? const [Tab(text: 'My Books'), Tab(text: 'Wishlist'), Tab(text: 'Reviews'), Tab(text: 'Swap History')]
                          : const [Tab(text: 'Books'), Tab(text: 'Reviews')],
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
                    child: TabBarView(
                      controller: _tabs,
                      children: isMine
                          ? [_myBooks(), _wishlist(), _reviews(targetUid), _history(me!)]
                          : [_theirBooks(targetUid), _reviews(targetUid)],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(User user, bool isMine) {
    final initial = user.name.isEmpty ? '?' : user.name.substring(0, 1).toUpperCase();
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                  child: user.avatarUrl.isEmpty ? Text(initial, style: const TextStyle(fontSize: 32)) : null,
                ),
                if (isMine)
                  InkWell(
                    onTap: () => pickAndUploadAvatar(context, ref, user.id),
                    child: const CircleAvatar(radius: 14, child: Icon(Icons.camera_alt, size: 14)),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            Text(user.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppDimensions.xs),
            Text(user.bio.isEmpty ? 'Book Enthusiast' : user.bio,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
            const SizedBox(height: AppDimensions.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: AppDimensions.xs),
                Text(user.location.isEmpty ? 'Unknown' : user.location, style: const TextStyle(color: Colors.grey)),
                const SizedBox(width: AppDimensions.md),
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: AppDimensions.xs),
                Text(user.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatCard(icon: Icons.menu_book, value: '${user.totalBooks}', label: 'Books', color: Colors.blue),
                const SizedBox(width: AppDimensions.md),
                StatCard(icon: Icons.swap_horiz, value: '${user.totalSwaps}', label: 'Swaps', color: Colors.green),
                const SizedBox(width: AppDimensions.md),
                StatCard(icon: Icons.star, value: user.rating.toStringAsFixed(1), label: 'Rating', color: Colors.amber),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),
            if (isMine)
              ElevatedButton.icon(
                onPressed: () => showEditProfileDialog(context, ref, user),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl, vertical: AppDimensions.md)),
              )
            else
              ElevatedButton.icon(
                onPressed: () => context.go('/chat?with=${user.id}'),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Message'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Book> books) => GridView.builder(
        padding: const EdgeInsets.all(AppDimensions.md),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.50,
          crossAxisSpacing: AppDimensions.md,
          mainAxisSpacing: AppDimensions.md,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) => BookCard(book: books[i]),
      );

  Widget _async<T>(AsyncValue<T> v, Widget Function(T) build, VoidCallback retry) => v.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: friendlyError(e), onRetry: retry),
        data: build,
      );

  Widget _myBooks() => _async<List<Book>>(
        ref.watch(myBooksProvider),
        (books) => books.isEmpty
            ? const EmptyState(icon: Icons.menu_book_outlined, title: 'No Books', description: 'You have not listed any books yet.')
            : _grid(books),
        () => ref.invalidate(myBooksProvider),
      );

  Widget _theirBooks(String uid) => _async<List<Book>>(
        ref.watch(userBooksProvider(uid)),
        (books) => books.isEmpty
            ? const EmptyState(icon: Icons.menu_book_outlined, title: 'No Books', description: 'No available books.')
            : _grid(books),
        () => ref.invalidate(userBooksProvider(uid)),
      );

  Widget _wishlist() => _async<List<Book>>(
        ref.watch(wishlistBooksProvider),
        (books) => books.isEmpty
            ? const EmptyState(icon: Icons.favorite_border, title: 'Wishlist Empty', description: 'Your wishlist is empty.')
            : _grid(books),
        () => ref.invalidate(wishlistBooksProvider),
      );

  Widget _reviews(String uid) => _async(
        ref.watch(reviewsProvider(uid)),
        (reviews) {
          if (reviews.isEmpty) {
            return const EmptyState(icon: Icons.rate_review, title: 'No Reviews', description: 'No reviews yet.');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.md),
            itemCount: reviews.length,
            itemBuilder: (context, i) {
              final r = reviews[i];
              return Card(
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: r.reviewerAvatar.isNotEmpty ? NetworkImage(r.reviewerAvatar) : null,
                          child: r.reviewerAvatar.isEmpty
                              ? Text(r.reviewerName.isEmpty ? '?' : r.reviewerName.substring(0, 1).toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.reviewerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(r.createdAt.toString().split(' ')[0],
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ]),
                        ),
                        Row(
                          children: List.generate(
                              5, (s) => Icon(s < r.rating ? Icons.star : Icons.star_border, size: 16, color: Colors.amber)),
                        ),
                      ]),
                      if (r.comment.isNotEmpty) ...[const SizedBox(height: AppDimensions.md), Text(r.comment)],
                    ],
                  ),
                ),
              );
            },
          );
        },
        () => ref.invalidate(reviewsProvider(uid)),
      );

  Widget _history(String me) => _async<List<SwapRequest>>(
        ref.watch(swapsProvider),
        (all) {
          final done = all
              .where((s) => s.status == SwapStatus.completed || s.status == SwapStatus.rejected || s.status == SwapStatus.cancelled)
              .toList();
          if (done.isEmpty) {
            return const EmptyState(icon: Icons.history, title: 'No Swap History', description: 'No past swaps found.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.md),
            itemCount: done.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = done[i];
              final other = s.requesterId == me ? s.ownerName : s.requesterName;
              return ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(s.bookTitle),
                subtitle: Text('With $other · ${s.status.name} · ${s.updatedAt.toString().split(' ')[0]}'),
              );
            },
          );
        },
        () => ref.invalidate(swapsProvider),
      );
}
