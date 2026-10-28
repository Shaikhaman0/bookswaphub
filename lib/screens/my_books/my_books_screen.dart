import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/widgets/empty_state.dart';
import 'package:bookswaphub/widgets/error_state.dart';

class MyBooksScreen extends ConsumerWidget {
  const MyBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(myBooksProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Books'),
          backgroundColor: AppColors.surface,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/add-book'),
                icon: const Icon(Icons.add),
                label: const Text('Add New Book'),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All Books'),
              Tab(text: 'Available'),
              Tab(text: 'Reserved'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
          ),
        ),
        body: booksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(myBooksProvider)),
          data: (books) => TabBarView(
            children: [
              _list(context, ref, books, 'No books in your account yet. Tap "Add New Book" to list one.'),
              _list(context, ref, books.where((b) => b.status == 'available').toList(), 'No available books.'),
              _list(context, ref, books.where((b) => b.status == 'reserved').toList(), 'No reserved books.'),
            ],
          ),
        ),
        floatingActionButton: MediaQuery.of(context).size.width < AppDimensions.mobileBreakpoint
            ? FloatingActionButton(
                onPressed: () => context.go('/add-book'),
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, List<Book> books, String emptyText) {
    if (books.isEmpty) {
      return EmptyState(icon: Icons.menu_book_outlined, title: 'No Books Found', description: emptyText);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final locked = book.status == 'reserved' || book.status == 'swapped' || book.status == 'sold';
        return Card(
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingMd),
          child: ListTile(
            contentPadding: const EdgeInsets.all(AppDimensions.paddingMd),
            leading: SizedBox(
              width: 50,
              child: book.imageUrls.isNotEmpty
                  ? Image.network(book.imageUrls.first, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.book, color: AppColors.primary))
                  : Container(color: AppColors.primaryLight, child: const Icon(Icons.book, color: AppColors.primary)),
            ),
            title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.author),
                const SizedBox(height: AppDimensions.paddingXs),
                Chip(
                  label: Text(_statusLabel(book.status), style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  backgroundColor: book.isAvailable ? Colors.green.shade100 : Colors.orange.shade100,
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye, color: AppColors.textSecondary),
                  onPressed: () => context.go('/book/${book.id}'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () => context.go('/edit-book/${book.id}'),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: locked ? Colors.grey : AppColors.accent),
                  tooltip: locked ? 'Cannot delete while reserved, swapped or sold' : 'Delete',
                  onPressed: locked ? null : () => _confirmDelete(context, ref, book),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'available':
        return 'Available';
      case 'unavailable':
        return 'Unavailable';
      case 'reserved':
        return 'Reserved (swap accepted)';
      case 'swapped':
        return 'Swapped';
      case 'sold':
        return 'Sold';
    }
    return s;
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Book book) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Delete "${book.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(bookRepositoryProvider).deleteBook(book);
                messenger.showSnackBar(const SnackBar(content: Text('Book deleted')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}
