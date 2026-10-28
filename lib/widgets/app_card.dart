import 'package:flutter/material.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Color? color;

  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.onTap,
    this.width,
    this.height,
    this.color,
  }) : super(key: key);

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          transform: _isHovered && widget.onTap != null 
              ? (Matrix4.identity()..translate(0.0, -4.0)) 
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.color ?? (isDark ? AppColors.darkCard : AppColors.card),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            boxShadow: _isHovered && widget.onTap != null
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
