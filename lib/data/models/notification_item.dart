import 'package:bookswaphub/core/utils/firestore_utils.dart';

enum NotificationType { swap, message, wishlist, review, system }

NotificationType parseNotificationType(String? s) {
  for (final v in NotificationType.values) {
    if (v.name == s) return v;
  }
  return NotificationType.system;
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String actionRoute;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.isRead,
    required this.actionRoute,
  });

  factory NotificationItem.fromMap(String id, Map<String, dynamic> d) {
    return NotificationItem(
      id: id,
      type: parseNotificationType(d['type'] as String?),
      title: readString(d['title']),
      body: readString(d['body']),
      timestamp: readDate(d['createdAt']),
      isRead: d['isRead'] == true,
      actionRoute: readString(d['actionRoute']),
    );
  }

  NotificationItem copyWith({
    NotificationType? type,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? actionRoute,
  }) {
    return NotificationItem(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
    );
  }
}
