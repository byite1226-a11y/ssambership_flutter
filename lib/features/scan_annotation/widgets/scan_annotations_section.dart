import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/providers/session.dart';
import '../../handwriting/models/ink_sketch.dart';
import '../models/scan_annotation.dart';
import '../screens/scan_annotation_editor_screen.dart';

/// 방 상세의 스캔 첨삭 섹션 — 저장된 첨삭 목록 + 새 스캔.
/// basePath 예: '/student/rooms/<id>' → '<basePath>/scan' 으로 새 스캔 진입.
class ScanAnnotationsSection extends ConsumerWidget {
  const ScanAnnotationsSection({
    super.key,
    required this.roomId,
    required this.authorRole,
    required this.basePath,
  });

  final String roomId;
  final String authorRole;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annos = ref.watch(scanAnnotationsProvider(roomId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NewScanButton(onTap: () => context.push('$basePath/scan')),
        const SizedBox(height: 12),
        annos.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(scanAnnotationsProvider(roomId)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '아직 스캔 첨삭이 없어요. 위에서 새로 시작해보세요.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              );
            }
            return Column(
              children: [
                for (final a in list)
                  _ScanTile(
                    anno: a,
                    onTap: () => openScanAnnotationForEdit(
                      context,
                      ref,
                      roomId: roomId,
                      authorRole: authorRole,
                      anno: a,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 저장된 스캔 첨삭 재편집 — 원본을 다시 깔고 주석을 복원.
Future<void> openScanAnnotationForEdit(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required String authorRole,
  required ScanAnnotation anno,
}) async {
  final authorId = demoSession.user?.id ?? '';
  final bytes =
      await ref.read(scanAnnotationsRepositoryProvider).loadOriginalImage(anno.id);
  if (!context.mounted) return;
  if (bytes == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원본 이미지를 불러오지 못했어요.')));
    return;
  }
  InkSketch? initial;
  try {
    initial = InkSketch.decode(anno.annotationJson);
  } catch (_) {
    // 손상 시 주석 없이 원본만
  }
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => ScanAnnotationEditorScreen(
        image: MemoryImage(bytes),
        authorRole: authorRole,
        title: '스캔 첨삭',
        initialAnnotation: initial,
        onSave: (payload) async {
          await ref.read(scanAnnotationsRepositoryProvider).saveAnnotation(
                roomId: roomId,
                authorId: authorId,
                authorRole: authorRole,
                annotationId: anno.id,
                originalImage: bytes,
                annotationJson: payload.annotationJson,
                previewPng: payload.flattenedPng,
                hasAnnotations: payload.hasAnnotations,
              );
        },
      ),
    ),
  );
  ref.invalidate(scanAnnotationsProvider(roomId));
}

class _NewScanButton extends StatelessWidget {
  const _NewScanButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.mentorAccent.withValues(alpha: 0.4)),
          ),
          child: const Row(children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.mentorAccent),
            SizedBox(width: 10),
            Text('새 스캔 첨삭',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.mentorAccent)),
          ]),
        ),
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.anno, required this.onTap});
  final ScanAnnotation anno;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final authorLabel = anno.isMentorAuthored ? '멘토' : '학생';
    final d = anno.createdAt;
    final when = d == null ? '' : '${d.month}/${d.day}';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.mentorAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.draw_outlined,
                    color: AppColors.mentorAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('스캔 첨삭',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppColors.mentorAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$authorLabel 작성',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mentorAccent)),
                      ),
                      if (when.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('· $when',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ]),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}
