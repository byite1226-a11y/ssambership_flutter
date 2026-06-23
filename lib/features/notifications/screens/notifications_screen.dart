import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_notification.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';

/// 앱바 액션용 종 아이콘 + 안 읽은 개수 배지.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);
    final n = count.maybeWhen(data: (v) => v, orElse: () => 0);
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: '알림',
          onPressed: () => context.push('/notifications'),
        ),
        if (n > 0)
          Positioned(
            right: 6,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                n > 9 ? '9+' : '$n',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.2),
              ),
            ),
          ),
      ],
    );
  }
}

/// 알림 목록 화면.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const AsyncEmptyView(
              message: '아직 알림이 없어요.',
              icon: Icons.notifications_none,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _NotiTile(
                noti: list[i],
                onTap: () async {
                  if (!list[i].read) {
                    await ref
                        .read(notificationsRepositoryProvider)
                        .markRead(list[i].id);
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadCountProvider);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotiTile extends StatelessWidget {
  const _NotiTile({required this.noti, required this.onTap});
  final AppNotification noti;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = noti.createdAt;
    final when = d == null
        ? ''
        : '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      child: Container(
        color: noti.read ? Colors.transparent : AppColors.primarySoft,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(noti.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(noti.title,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: noti.read
                                  ? FontWeight.w600
                                  : FontWeight.w800)),
                    ),
                    if (!noti.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.danger, shape: BoxShape.circle),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(noti.body,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4)),
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(when,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textDisabled)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
