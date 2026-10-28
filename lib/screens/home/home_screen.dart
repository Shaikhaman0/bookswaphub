import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/core/constants/categories.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/widgets/empty_state.dart';
import 'package:bookswaphub/widgets/error_state.dart';
import 'package:bookswaphub/widgets/book_card.dart';
import 'package:bookswaphub/widgets/category_card.dart';
import 'package:bookswaphub/widgets/custom_search_bar.dart';
import 'package:bookswaphub/widgets/section_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < AppDimensions.mobileBreakpoint;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeroSection(isMobile),
            const SizedBox(height: 32),
            _buildSearchSection(),
            const SizedBox(height: 48),
            _buildContentArea(isMobile),
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea(bool isMobile) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? AppDimensions.paddingMd : AppDimensions.paddingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoriesSection(isMobile),
            const SizedBox(height: 48),
            _buildFeaturedBooks(isMobile),
            const SizedBox(height: 48),
            _buildRecommendedSection(),
            const SizedBox(height: 48),
            _buildRecentlyAddedSection(isMobile),
            const SizedBox(height: 48),
            _buildNearbySection(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppDimensions.paddingLg : AppDimensions.paddingXxl,
        vertical: isMobile ? 64 : 100,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover Books.\nShare Stories.\nSwap Knowledge.',
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 36 : 56,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -1,
                      ),
                      textAlign: isMobile ? TextAlign.center : TextAlign.left,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Find your next favorite book or give your old books a new home. Join thousands of readers swapping books globally.',
                      style: GoogleFonts.lato(
                        fontSize: isMobile ? 16 : 20,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: isMobile ? TextAlign.center : TextAlign.left,
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: () => context.go('/discover'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                          ),
                          child: Text(
                            'Explore Books',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () => context.go('/add-book'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                          ),
                          child: Text(
                            'List a Book',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 250,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
        child: CustomSearchBar(
          onSubmitted: (val) {
            final q = val.trim();
            context.go(q.isEmpty ? '/discover' : '/discover?q=${Uri.encodeQueryComponent(q)}');
          },
          onFilterTap: () => context.go('/discover'),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(bool isMobile) {
    void open(String id) => context.go('/discover?category=$id');
    return Column(
      children: [
        SectionHeader(
          title: 'Browse Categories',
          onViewAll: () => context.go('/discover'),
        ),
        const SizedBox(height: 24),
        if (isMobile)
          SizedBox(
            height: 175,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bookCategories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final c = bookCategories[index];
                return CategoryCard(category: c, onTap: () => open(c.id));
              },
            ),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: bookCategories.map((cat) {
              return SizedBox(
                width: 160,
                child: CategoryCard(category: cat, onTap: () => open(cat.id)),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// Shows loading / error (with retry) / empty / the real list for one home section.
  Widget _section(
    AsyncValue<List<Book>> value,
    FutureProvider<List<Book>> provider,
    String emptyText,
    Widget Function(List<Book> books) builder,
  ) {
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 220,
        child: ErrorState(
          message: 'Could not load books. Check your connection.',
          onRetry: () => ref.invalidate(provider),
        ),
      ),
      data: (books) => books.isEmpty
          ? SizedBox(
              height: 200,
              child: EmptyState(icon: Icons.menu_book_outlined, title: 'Nothing here yet', description: emptyText),
            )
          : builder(books),
    );
  }

  Widget _grid(List<Book> books, {required int Function(double) columns, required double aspect}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns(constraints.maxWidth),
            childAspectRatio: aspect,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) => BookCard(book: books[index]),
        );
      },
    );
  }

  int _cols(double w) {
    if (w < AppDimensions.mobileBreakpoint) return 2;
    if (w < AppDimensions.tabletBreakpoint) return 3;
    return 4;
  }

  Widget _buildFeaturedBooks(bool isMobile) {
    return Column(
      children: [
        SectionHeader(
          title: '📚 Featured Books',
          subtitle: 'Top rated by the community',
          onViewAll: () => context.go('/discover'),
        ),
        const SizedBox(height: 24),
        _section(
          ref.watch(homeFeaturedProvider),
          homeFeaturedProvider,
          'Be the first to list a book!',
          (books) => _grid(books, columns: _cols, aspect: 0.45),
        ),
      ],
    );
  }

  Widget _buildRecommendedSection() {
    return Column(
      children: [
        SectionHeader(
          title: '✨ Recommended For You',
          subtitle: 'Based on your wishlist',
          onViewAll: () => context.go('/discover'),
        ),
        const SizedBox(height: 24),
        _section(
          ref.watch(homeRecommendedProvider),
          homeRecommendedProvider,
          'Add books to your wishlist to get recommendations.',
          (books) => SizedBox(
            height: 400,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) => SizedBox(width: 200, child: BookCard(book: books[index])),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyAddedSection(bool isMobile) {
    return Column(
      children: [
        SectionHeader(
          title: '🕐 Recently Added',
          subtitle: 'Fresh listings from the community',
          onViewAll: () => context.go('/discover'),
        ),
        const SizedBox(height: 24),
        _section(
          ref.watch(homeRecentProvider),
          homeRecentProvider,
          'No listings yet.',
          (books) => _grid(books, columns: _cols, aspect: 0.45),
        ),
      ],
    );
  }

  Widget _buildNearbySection(bool isMobile) {
    final city = ref.watch(myProfileProvider).when(
          data: (u) => u?.location ?? '',
          loading: () => '',
          error: (_, __) => '',
        );
    return Column(
      children: [
        SectionHeader(
          title: '📍 Nearby Books',
          subtitle: city.isEmpty ? 'Set your location in your profile' : 'Available in $city',
          onViewAll: () => context.go('/discover'),
        ),
        const SizedBox(height: 24),
        _section(
          ref.watch(homeNearbyProvider),
          homeNearbyProvider,
          'No books listed in your city yet.',
          (books) => _grid(
            books,
            columns: (w) => w < AppDimensions.mobileBreakpoint ? 2 : 4,
            aspect: 0.50,
          ),
        ),
      ],
    );
  }
}
