import 'package:flutter/material.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';

class SkeletonContainer extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonContainer({
    Key? key,
    this.width,
    this.height,
    this.borderRadius = AppDimensions.radiusMd,
  }) : super(key: key);

  @override
  State<SkeletonContainer> createState() => _SkeletonContainerState();
}

class _SkeletonContainerState extends State<SkeletonContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: (isDark ? Colors.grey[800] : Colors.grey[300])!.withOpacity(0.5 + (_controller.value * 0.5)),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class BookCardSkeleton extends StatelessWidget {
  const BookCardSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(
          aspectRatio: 3 / 4,
          child: SkeletonContainer(),
        ),
        const SizedBox(height: 8),
        const SkeletonContainer(height: 16, width: double.infinity),
        const SizedBox(height: 4),
        const SkeletonContainer(height: 12, width: 100),
        const SizedBox(height: 8),
        const SkeletonContainer(height: 14, width: 60),
      ],
    );
  }
}

class ListTileSkeleton extends StatelessWidget {
  const ListTileSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SkeletonContainer(width: 48, height: 48, borderRadius: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonContainer(height: 16, width: double.infinity),
              SizedBox(height: 8),
              SkeletonContainer(height: 12, width: 150),
            ],
          ),
        ),
      ],
    );
  }
}
