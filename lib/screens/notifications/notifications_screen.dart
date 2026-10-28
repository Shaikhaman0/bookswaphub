import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';
import 'package:bookswaphub/core/constants/app_dimensions.dart';
import 'package:bookswaphub/core/routing/app_navigation_helper.dart';
import 'package:bookswaphub/core/utils/app_failure.dart';
import 'package:bookswaphub/data/models/notification_item.dart';
import 'package:bookswaphub/data/providers/providers.dart';
import 'package:bookswaphub/widgets/empty_state.dart';
import 'package:bookswaphub/widgets/error_state.dart';
import 'package:bookswaphub/widgets/notification_tile.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Swaps', 'Messages', 'Wishlist', 'Reviews', 'System'];

  void _toast(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));

  Future<void> _markAllAsRead(List<NotificationItem> items) async {
    final unread = items.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unread.isEmpty) return;
    try {
      await ref.read(notificationRepositoryProvider).markAllRead(unread);
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _open(NotificationItem n) async {
    try {
      if (!n.isRead) await ref.read(notificationRepositoryProvider).markRead(n.id);
    } catch (_) {}
    if (mounted && n.actionRoute.isNotEmpty) context.go(n.actionRoute);
  }

  List<NotificationItem> _filtered(List<NotificationItem> all) {
    if (_selectedFilter == 'All') return all;
    return all.where((n) {
      // Filter labels are plural ("Swaps"), enum names are singular ("swap").
      final label = _selectedFilter.toLowerCase();
      return label == n.type.name || label == '${n.type.name}s';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final all = async.when(data: (d) => d, loading: () => <NotificationItem>[], error: (_, __) => <NotificationItem>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => AppNavigationHelper.handleBack(context),
        ),
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(all),
            child: const Text('Mark all as read'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                return Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.paddingSm),
                  child: FilterChip(
                    label: Text(filter),
                    selected: _selectedFilter == filter,
                    onSelected: (selected) => setState(() => _selectedFilter = filter),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(message: friendlyError(e), onRetry: () => ref.invalidate(notificationsProvider)),
              data: (items) {
                final filtered = _filtered(items);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'No Notifications',
                    description: 'You\'re all caught up!',
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final notification = filtered[index];
                    return Dismissible(
                      key: Key(notification.id),
                      background: Container(
                        color: AppColors.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppDimensions.paddingL),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) async {
                        try {
                          await ref.read(notificationRepositoryProvider).delete(notification.id);
                        } catch (e) {
                          // Rebuild the list so the swiped row comes back.
                          ref.invalidate(notificationsProvider);
                          if (mounted) _toast(e);
                        }
                      },
                      child: NotificationTile(
                        notification: notification,
                        onTap: () => _open(notification),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
