import '../../core/models/app_notification.dart';

/// 알림 데이터 창구.
abstract class NotificationsRepository {
  Future<List<AppNotification>> fetchNotifications();
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}
