import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/routing/app_navigation_helper.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/widgets/book_card.dart';
import 'package:bookswaphub/widgets/empty_state.dart';
import 'package:bookswaphub/widgets/error_state.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  Future<void> _remove(BuildContext context, WidgetRef ref, Book book) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(wishlistRepositoryProvider);
    try {
      await repo.remove(uid, book.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${book.title} removed from wishlist'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.add(uid, book.id),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistBooksProvider);
    final count = wishlist.when(data: (b) => b.length, loading: () => 0, error: (_, __) => 0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Wishlist'),
            Text(
              '$count books',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => AppNavigationHelper.handleBack(context),
        ),
      ),
      body: wishlist.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(wishlistBooksProvider)),
        data: (books) {
          if (books.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: '💝 Your wishlist is empty',
              description: 'Start adding books you love',
              buttonText: 'Explore Books',
              onPressed: () => context.go('/discover'),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 2;
              if (constraints.maxWidth >= AppDimensions.tabletBreakpoint) {
                crossAxisCount = 4;
              } else if (constraints.maxWidth >= AppDimensions.mobileBreakpoint) {
                crossAxisCount = 3;
              }
              return GridView.builder(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.45,
                  crossAxisSpacing: AppDimensions.paddingMd,
                  mainAxisSpacing: AppDimensions.paddingMd,
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return Stack(
                    children: [
                      BookCard(book: book),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: IconButton.filledTonal(
                          tooltip: 'Remove from wishlist',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _remove(context, ref, book),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
