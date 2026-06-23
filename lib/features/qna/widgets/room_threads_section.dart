import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/note.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';

Color _statusColor(ThreadStatus s) => switch (s) {
      ThreadStatus.answered => AppColors.success,
      ThreadStatus.open => AppColors.accent,
      ThreadStatus.closed => AppColors.textDisabled,
    };

/// 방 안의 질문 스레드 목록(클릭 → 스레드 상세). 학생·멘토 공용.
/// basePath 예: '/student/rooms/<id>' → '<basePath>/thread/<threadId>' 로 이동.
class RoomThreadsSection extends ConsumerWidget {
  const RoomThreadsSection({
    super.key,
    required this.roomId,
    required this.basePath,
  });

  final String roomId;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(threadsProvider(roomId));
    return threads.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AsyncErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(threadsProvider(roomId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '아직 질문이 없어요. 아래 ‘질문하기’로 시작해요.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          );
        }
        return Column(
          children: [
            for (final t in list)
              _ThreadTile(
                title: t.title,
                statusLabel: t.status.label,
                statusColor: _statusColor(t.status),
                onTap: () => context.push(
                  '$basePath/thread/${t.id}',
                  extra: {'title': t.title},
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final String title;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

/// 새 질문 스레드 생성 다이얼로그 → 생성 후 스레드 상세로 이동.
Future<void> createQuestionThread(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required String basePath,
  int? weeklyLimit,
}) async {
  // 구독 cap: 한도가 있으면(무제한 아님) 이번 주 사용량을 먼저 확인.
  if (weeklyLimit != null) {
    int used = 0;
    try {
      used = await ref.read(weeklyUsageProvider(roomId).future);
    } catch (_) {}
    if (used >= weeklyLimit && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('이번 주 질문을 다 썼어요'),
          content: Text(
              '이번 주 구독 질문 $weeklyLimit개를 모두 사용했어요.\n'
              '다음 주에 이어가거나, 개별 질문으로 물어볼 수 있어요.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인')),
          ],
        ),
      );
      return;
    }
  }
  final controller = TextEditingController();
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('새 질문'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '질문 제목 (예: 미적분 12번)'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('만들기')),
      ],
    ),
  );
  controller.dispose();
  if (title == null || title.isEmpty) return;
  try {
    final thread = await ref
        .read(threadsRepositoryProvider)
        .createThread(roomId: roomId, title: title);
    ref.invalidate(threadsProvider(roomId));
    ref.invalidate(weeklyUsageProvider(roomId));
    if (context.mounted) {
      context.push('$basePath/thread/${thread.id}',
          extra: {'title': thread.title});
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('생성 실패: $e')));
    }
  }
}
