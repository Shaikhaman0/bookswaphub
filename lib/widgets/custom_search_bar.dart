import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';

class CustomSearchBar extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String initialText;
  final VoidCallback? onFilterTap;
  final String hintText;

  const CustomSearchBar({
    Key? key,
    this.onChanged,
    this.onSubmitted,
    this.initialText = '',
    this.onFilterTap,
    this.hintText = 'Search books, authors, genres...',
  }) : super(key: key);

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);
  final FocusNode _focusNode = FocusNode();

  bool _hasText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.isNotEmpty;
      });
    });

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard
            : AppColors.card,
        borderRadius: BorderRadius.circular(
          AppDimensions.radiusLg,
        ),
        boxShadow: _isFocused
            ? [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ]
            : [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.3 : 0.05,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isFocused
              ? AppColors.primary
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: AppDimensions.md,
          ),

          Icon(
            Icons.search,
            color: _isFocused
                ? AppColors.primary
                : (isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary),
          ),

          const SizedBox(
            width: AppDimensions.sm,
          ),

          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: GoogleFonts.inter(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: GoogleFonts.inter(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textHint,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),

          if (_hasText)
            IconButton(
              icon: Icon(
                Icons.close,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () {
                _controller.clear();

                if (widget.onChanged != null) {
                  widget.onChanged!('');
                }
              },
            ),

          if (widget.onFilterTap != null) ...[
            Container(
              height: 32,
              width: 1,
              color: isDark
                  ? Colors.grey[800]
                  : Colors.grey[300],
              margin: const EdgeInsets.symmetric(
                horizontal: 4,
              ),
            ),

            IconButton(
              icon: Icon(
                Icons.tune,
                color: AppColors.primary,
              ),
              onPressed: widget.onFilterTap,
            ),
          ],

          const SizedBox(width: 4),
        ],
      ),
    );
  }
}