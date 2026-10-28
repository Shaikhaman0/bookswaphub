import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/book.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/widgets/book_cover_placeholder.dart';

class BookCard extends ConsumerStatefulWidget {
  final Book book;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onWishlistToggle;

  const BookCard({
    Key? key,
    required this.book,
    this.onTap,
    this.onWishlistToggle,
  }) : super(key: key);

  @override
  ConsumerState<BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<BookCard> {
  bool _isHovered = false;

  /// Adds/removes the book in the signed-in user's wishlist (Firestore).
  Future<void> _toggleWishlist(bool currentlyWishlisted) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final repo = ref.read(wishlistRepositoryProvider);
    try {
      if (currentlyWishlisted) {
        await repo.remove(uid, widget.book.id);
      } else {
        await repo.add(uid, widget.book.id);
      }
      widget.onWishlistToggle?.call(!currentlyWishlisted);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wishlisted = ref.watch(wishlistIdSetProvider).contains(widget.book.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;

        Widget imageWidget = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusMd)),
          child: SizedBox.expand(
            child: widget.book.imageUrls.isNotEmpty
                ? Image.network(
                    widget.book.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => BookCoverPlaceholder(
                      title: widget.book.title,
                      author: widget.book.author,
                    ),
                  )
                : BookCoverPlaceholder(
                    title: widget.book.title,
                    author: widget.book.author,
                  ),
          ),
        );

        Widget imageStack = Stack(
          fit: hasBoundedHeight ? StackFit.expand : StackFit.loose,
          children: [
            hasBoundedHeight
                ? imageWidget
                : AspectRatio(
                    aspectRatio: 3 / 4,
                    child: imageWidget,
                  ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _toggleWishlist(wishlisted),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      wishlisted ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey<bool>(wishlisted),
                      color: wishlisted ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            if (!widget.book.isAvailable)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(
                    'Unavailable',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap ?? () => context.go('/book/${widget.book.id}'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: _isHovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.card,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Section
                  if (hasBoundedHeight) Expanded(child: imageStack) else imageStack,

                  // Details Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              widget.book.rating.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              ' (${widget.book.ratingCount})',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.book.condition,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.book.location.length > 10 ? '${widget.book.location.substring(0, 10)}…' : widget.book.location,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
