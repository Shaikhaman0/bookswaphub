import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/data/models/notification_item.dart';

class NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;

  const NotificationTile({
    Key? key,
    required this.notification,
    this.onTap,
    this.onMarkRead,
  }) : super(key: key);

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inDays > 7) {
      return '${time.day}/${time.month}/${time.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.swap:
        return Icons.swap_horiz;

      case NotificationType.message:
        return Icons.chat_bubble_outline;

      case NotificationType.wishlist:
        return Icons.favorite_border;

      case NotificationType.review:
        return Icons.star_border;

      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case NotificationType.swap:
        return AppColors.primary;

      case NotificationType.message:
        return Colors.blue;

      case NotificationType.wishlist:
        return Colors.red;

      case NotificationType.review:
        return Colors.amber;

      case NotificationType.system:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(
          AppDimensions.paddingMd,
        ),
        decoration: BoxDecoration(
          color: notification.isRead
              ? (isDark
              ? AppColors.darkSurface
              : AppColors.surface)
              : (isDark
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.05)),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? AppColors.darkCard
                  : AppColors.divider,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getIconColor().withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(),
                color: _getIconColor(),
                size: 24,
              ),
            ),

            const SizedBox(
              width: AppDimensions.paddingMd,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.inter(
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),

                      Text(
                        _formatTimeAgo(
                          notification.timestamp,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    notification.body,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            if (!notification.isRead) ...[
              const SizedBox(
                width: AppDimensions.paddingMd,
              ),

              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],

            if (onMarkRead != null &&
                !notification.isRead)
              IconButton(
                icon: const Icon(
                  Icons.check,
                  size: 20,
                ),
                onPressed: onMarkRead,
                tooltip: 'Mark as read',
              ),
          ],
        ),
      ),
    );
  }
}