import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/routing/app_navigation_helper.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/screens/add_book/book_form.dart';
import 'package:bookswaphub/widgets/error_state.dart';

class EditBookScreen extends ConsumerWidget {
  final String bookId;
  const EditBookScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider(bookId));
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Book'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => AppNavigationHelper.handleBack(context),
        ),
      ),
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: 'Could not load this book.', onRetry: () => ref.invalidate(bookProvider(bookId))),
        data: (book) {
          if (book == null) {
            return const ErrorState(title: 'Book not found', message: 'This book no longer exists.');
          }
          if (book.ownerId != uid) {
            return const ErrorState(title: 'Not allowed', message: 'You can only edit your own books.');
          }
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                child: Card(
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingLg),
                    // key: rebuild the form if a different book is opened
                    child: BookForm(key: ValueKey(book.id), existing: book),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
