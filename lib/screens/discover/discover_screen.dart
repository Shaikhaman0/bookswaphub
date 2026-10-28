import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/constants/categories.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/data/repositories/book_repository.dart';
import 'package:bookswaphub/widgets/book_card.dart';
import 'package:bookswaphub/widgets/custom_search_bar.dart';
import 'package:bookswaphub/widgets/empty_state.dart';
import 'package:bookswaphub/widgets/error_state.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  final String initialQuery;
  final String? initialCategory;
  const DiscoverScreen({super.key, this.initialQuery = '', this.initialCategory});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final ScrollController _scroll = ScrollController();

  static const _sortLabels = {
    BookSort.recent: 'Recently Added',
    BookSort.rating: 'Rating',
    BookSort.titleAZ: 'Title A-Z',
  };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(discoverProvider.notifier).loadMore();
      }
    });
    // Apply filters that came from the URL (e.g. from the Home search box or a category card).
    Future.microtask(() {
      ref.read(discoverProvider.notifier).apply(
            query: widget.initialQuery,
            categoryId: widget.initialCategory,
            clearCategory: widget.initialCategory == null,
          );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= AppDimensions.tabletBreakpoint;
          return Column(
            children: [
              _buildTopBar(isDesktop, state),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDesktop) _buildSidebar(state),
                    Expanded(child: _buildBody(state, constraints.maxWidth)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(DiscoverState state, double width) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.error != null && state.books.isEmpty) {
      return ErrorState(message: state.error!, onRetry: () => ref.read(discoverProvider.notifier).refresh());
    }
    final books = state.visible;
    if (books.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'No Books Found',
          description: 'No books found matching your filters.',
        ),
      );
    }
    return _buildBookGrid(state, books, width);
  }

  Widget _buildTopBar(bool isDesktop, DiscoverState state) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: CustomSearchBar(
              initialText: widget.initialQuery,
              hintText: 'Search by book title or author...',
              onSubmitted: (value) => ref.read(discoverProvider.notifier).apply(query: value.trim()),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          DropdownButton<BookSort>(
            value: state.sort,
            underline: const SizedBox(),
            items: BookSort.values
                .map((s) => DropdownMenuItem<BookSort>(value: s, child: Text(_sortLabels[s]!)))
                .toList(),
            onChanged: (newValue) {
              if (newValue != null) ref.read(discoverProvider.notifier).apply(sort: newValue);
            },
          ),
          if (!isDesktop) ...[
            const SizedBox(width: AppDimensions.sm),
            IconButton(
              icon: const Icon(Icons.filter_list, color: AppColors.primary),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => Consumer(
                    builder: (context, ref, _) => _buildSidebar(ref.watch(discoverProvider), inSheet: true),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebar(DiscoverState state, {bool inSheet = false}) {
    final controller = ref.read(discoverProvider.notifier);
    return Container(
      width: inSheet ? double.infinity : 250,
      padding: const EdgeInsets.all(AppDimensions.md),
      color: AppColors.surface,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const Divider(),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
            ...bookCategories.map((category) {
              return CheckboxListTile(
                title: Text(category.name),
                value: state.categoryId == category.id,
                onChanged: (value) {
                  if (value == true) {
                    controller.apply(categoryId: category.id);
                  } else {
                    controller.apply(clearCategory: true);
                  }
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
            const SizedBox(height: AppDimensions.md),
            const Text('Condition', style: TextStyle(fontWeight: FontWeight.bold)),
            ...['Like New', 'Good', 'Fair', 'Worn'].map((condition) {
              return CheckboxListTile(
                title: Text(condition),
                value: state.conditions.contains(condition),
                onChanged: (value) {
                  final next = {...state.conditions};
                  if (value == true) {
                    next.add(condition);
                  } else {
                    next.remove(condition);
                  }
                  controller.setConditions(next);
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
            const SizedBox(height: AppDimensions.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (inSheet && Navigator.canPop(context)) Navigator.pop(context);
                },
                child: Text(inSheet ? 'Done' : 'Filters apply instantly'),
              ),
            ),
            TextButton(
              onPressed: () {
                controller.setConditions(<String>{});
                controller.apply(query: '', clearCategory: true);
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookGrid(DiscoverState state, List<Book> books, double width) {
    int crossAxisCount = 1;
    if (width >= AppDimensions.tabletBreakpoint) {
      crossAxisCount = 4;
    } else if (width >= AppDimensions.mobileBreakpoint) {
      crossAxisCount = 3;
    } else if (width >= 400) {
      crossAxisCount = 2;
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.md),
            child: Text(
              'Showing ${books.length} books${state.hasMore ? ' (scroll for more)' : ''}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: _scroll,
              itemCount: books.length + (state.loadingMore ? 1 : 0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.47,
                crossAxisSpacing: AppDimensions.md,
                mainAxisSpacing: AppDimensions.md,
              ),
              itemBuilder: (context, index) {
                if (index >= books.length) return const Center(child: CircularProgressIndicator());
                return BookCard(book: books[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
