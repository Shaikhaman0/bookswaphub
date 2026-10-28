import 'package:flutter/material.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';

class ChartDataPoint {
  final String label;
  final double value;
  const ChartDataPoint({required this.label, required this.value});
}

class AdminMetricChart extends StatefulWidget {
  final String title;
  final String timeframe;
  final ValueChanged<String> onTimeframeChanged;
  final List<ChartDataPoint> data;
  final List<Color> gradientColors;
  final String? badgeText;

  const AdminMetricChart({
    super.key,
    required this.title,
    required this.timeframe,
    required this.onTimeframeChanged,
    required this.data,
    required this.gradientColors,
    this.badgeText,
  });

  @override
  State<AdminMetricChart> createState() => _AdminMetricChartState();
}

class _AdminMetricChartState extends State<AdminMetricChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = widget.data.fold<double>(1.0, (prev, e) => e.value > prev ? e.value : prev);

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : AppColors.divider.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title, Optional Badge, Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      if (widget.badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.badgeText!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.primaryLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.timeframe,
                      isDense: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
                      ),
                      icon: const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.primary),
                      items: const [
                        DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
                      ],
                      onChanged: (val) {
                        if (val != null) widget.onTimeframeChanged(val);
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Bar Chart Visualizer
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(widget.data.length, (index) {
                  final item = widget.data[index];
                  final fraction = (item.value / maxValue).clamp(0.06, 1.0);
                  final isHovered = _hoveredIndex == index;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _hoveredIndex = (_hoveredIndex == index) ? null : index;
                          });
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Value Tooltip / Label
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: (isHovered || index == widget.data.length - 1) ? 1.0 : 0.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: widget.gradientColors.first,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // Bar
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: fraction,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: widget.gradientColors,
                                      ),
                                      boxShadow: isHovered
                                          ? [
                                              BoxShadow(
                                                color: widget.gradientColors.first.withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // X-Axis Label
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
                                color: isHovered
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
