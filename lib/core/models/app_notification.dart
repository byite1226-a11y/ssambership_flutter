import 'package:flutter/material.dart';

/// notifications 테이블 — 인앱 알림. (Flutter의 Notification과 구분 위해 AppNotification)
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String type; // question | order | community | cash | system ...
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  IconData get icon => switch (type) {
        'question' => Icons.question_answer_outlined,
        'order' || 'commission' => Icons.assignment_outlined,
        'community' => Icons.forum_outlined,
        'cash' || 'payment' => Icons.payments_outlined,
        _ => Icons.notifications_outlined,
      };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        type: (m['type'] as String?) ??
            (m['kind'] as String?) ??
            (m['category'] as String?) ??
            'system',
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? (m['message'] as String?) ?? '',
        read: (m['is_read'] as bool?) ?? (m['read'] as bool?) ?? false,
        createdAt: switch (m['created_at']) {
          String s => DateTime.tryParse(s),
          DateTime d => d,
          _ => null,
        },
      );
}
