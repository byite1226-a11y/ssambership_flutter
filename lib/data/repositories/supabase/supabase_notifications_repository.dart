import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/app_notification.dart';
import '../notifications_repository.dart';

/// 실DB 구현 — notifications.
class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._db);

  final SupabaseClient _db;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', _uid ?? '')
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => AppNotification.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> unreadCount() async {
    final rows = await _db
        .from('notifications')
        .select('id')
        .eq('user_id', _uid ?? '')
        .eq('is_read', false);
    return (rows as List).length;
  }

  @override
  Future<void> markRead(String id) async {
    await _db
        .from('notifications')
        .update({'is_read': true, 'read': true}).eq('id', id);
  }

  @override
  Future<void> markAllRead() async {
    await _db
        .from('notifications')
        .update({'is_read': true, 'read': true}).eq('user_id', _uid ?? '');
  }
}
