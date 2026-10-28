import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';

enum ButtonType { primary, secondary, text }
enum ButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final bool isLoading;
  final IconData? icon;
  final bool isTrailingIcon;

  const AppButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.isTrailingIcon = false,
  }) : super(key: key);

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine height based on size
    double height;
    double fontSize;
    EdgeInsets padding;
    
    switch (widget.size) {
      case ButtonSize.small:
        height = 32;
        fontSize = 12;
        padding = const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd);
        break;
      case ButtonSize.large:
        height = 56;
        fontSize = 16;
        padding = const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl);
        break;
      case ButtonSize.medium:
        height = 48;
        fontSize = 14;
        padding = const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg);
        break;
    }

    // Determine colors
    Color backgroundColor;
    Color textColor;
    BorderSide borderSide = BorderSide.none;
    
    switch (widget.type) {
      case ButtonType.secondary:
        backgroundColor = Colors.transparent;
        textColor = isDark ? AppColors.darkTextPrimary : AppColors.primary;
        borderSide = BorderSide(color: AppColors.primary, width: 1.5);
        break;
      case ButtonType.text:
        backgroundColor = Colors.transparent;
        textColor = isDark ? AppColors.darkTextPrimary : AppColors.primary;
        break;
      case ButtonType.primary:
        backgroundColor = AppColors.primary;
        textColor = Colors.white;
        break;
    }

    if (widget.onPressed == null) {
      backgroundColor = isDark ? AppColors.darkCard : Colors.grey[300]!;
      textColor = isDark ? AppColors.darkTextSecondary : Colors.grey[600]!;
      if (widget.type == ButtonType.secondary) {
        borderSide = BorderSide(color: textColor, width: 1.5);
        backgroundColor = Colors.transparent;
      }
    } else if (_isHovered && widget.type == ButtonType.primary) {
      backgroundColor = AppColors.primaryDark;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: fontSize,
            height: fontSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingSm),
        ],
        if (!widget.isLoading && widget.icon != null && !widget.isTrailingIcon) ...[
          Icon(widget.icon, size: fontSize * 1.2, color: textColor),
          const SizedBox(width: AppDimensions.paddingSm),
        ],
        Text(
          widget.text,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        if (!widget.isLoading && widget.icon != null && widget.isTrailingIcon) ...[
          const SizedBox(width: AppDimensions.paddingSm),
          Icon(widget.icon, size: fontSize * 1.2, color: textColor),
        ],
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        child: widget.type == ButtonType.text
            ? TextButton(
                onPressed: widget.isLoading ? null : widget.onPressed,
                style: TextButton.styleFrom(
                  padding: padding,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: content,
              )
            : widget.type == ButtonType.secondary
                ? OutlinedButton(
                    onPressed: widget.isLoading ? null : widget.onPressed,
                    style: OutlinedButton.styleFrom(
                      padding: padding,
                      side: borderSide,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                    child: content,
                  )
                : ElevatedButton(
                    onPressed: widget.isLoading ? null : widget.onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: backgroundColor,
                      padding: padding,
                      elevation: _isHovered ? 4 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                    child: content,
                  ),
      ),
    );
  }
}
