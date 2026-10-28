import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/data/models/category.dart';

class CategoryCard extends StatefulWidget {
  final BookCategory category;
  final VoidCallback? onTap;

  const CategoryCard({
    Key? key,
    required this.category,
    this.onTap,
  }) : super(key: key);

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.05))
              : Matrix4.identity(),
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard
                : AppColors.card,
            borderRadius: BorderRadius.circular(
              AppDimensions.radiusMd,
            ),
            border: Border.all(
              color: _isHovered
                  ? widget.category.color.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isHovered
                ? [
              BoxShadow(
                color: widget.category.color
                    .withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
                : [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark ? 0.3 : 0.05,
                ),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.category.color
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.category.icon,
                  color: widget.category.color,
                  size: 32,
                ),
              ),

              const SizedBox(
                height: AppDimensions.md,
              ),

              Text(
                widget.category.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                widget.category.bookCount > 0 ? '${widget.category.bookCount} Books' : 'Browse',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}