import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/note.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/providers/session.dart';
import '../../handwriting/models/ink_sketch.dart';
import '../screens/connection_note_editor_screen.dart';

/// 방 상세의 연결노트 섹션 — 저장된 노트 목록 + 새 노트 작성.
class ConnectionNotesSection extends ConsumerWidget {
  const ConnectionNotesSection({
    super.key,
    required this.roomId,
    required this.authorRole,
  });

  final String roomId;
  final String authorRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(connectionNotesProvider(roomId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NewNoteButton(
          onTap: () => openConnectionNoteEditor(
            context,
            ref,
            roomId: roomId,
            authorRole: authorRole,
          ),
        ),
        const SizedBox(height: 12),
        notes.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(connectionNotesProvider(roomId)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '아직 연결노트가 없어요. 위에서 새로 작성해보세요.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              );
            }
            return Column(
              children: [
                for (final n in list)
                  _NoteTile(
                    note: n,
                    onTap: () => openConnectionNoteEditor(
                      context,
                      ref,
                      roomId: roomId,
                      authorRole: authorRole,
                      note: n,
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

/// 연결노트 에디터 열기 — 신규(note=null) 또는 재편집. 필기는 저장본에서 복원.
Future<void> openConnectionNoteEditor(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required String authorRole,
  ConnectionNote? note,
}) async {
  final authorId = demoSession.user?.id ?? '';
  InkSketch? initialSketch;
  if (note != null && note.hasInk) {
    final json =
        await ref.read(connectionNotesRepositoryProvider).fetchSketchJson(note.id);
    if (json != null && json.isNotEmpty) {
      try {
        initialSketch = InkSketch.decode(json);
      } catch (_) {
        // 손상된 JSON이면 빈 캔버스로 시작
      }
    }
  }
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => ConnectionNoteEditorScreen(
        roomId: roomId,
        authorRole: authorRole,
        initialTitle: note?.title ?? '',
        initialText: note?.body ?? '',
        initialCategory: note?.category ?? NoteCategory.memo,
        initialSketch: initialSketch,
        onSave: (payload) async {
          await ref.read(connectionNotesRepositoryProvider).saveNote(
                roomId: roomId,
                authorId: authorId,
                authorRole: authorRole,
                noteId: note?.id,
                title: payload.title,
                textBody: payload.textBody,
                category: payload.category,
                sketchJson: payload.sketchJson,
                thumbnailPng: payload.thumbnailPng,
                hasInk: payload.hasInk,
              );
        },
      ),
    ),
  );
  // 돌아오면 목록 갱신(저장 반영)
  ref.invalidate(connectionNotesProvider(roomId));
}

class _NewNoteButton extends StatelessWidget {
  const _NewNoteButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(Icons.add, color: AppColors.primary),
            SizedBox(width: 10),
            Text('새 연결노트 작성',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]),
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, required this.onTap});
  final ConnectionNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final authorLabel = note.isMentorAuthored ? '멘토' : '학생';
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
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    note.hasInk
                        ? Icons.draw_outlined
                        : Icons.sticky_note_2_outlined,
                    color: AppColors.primary,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.title.isEmpty ? '제목 없는 노트' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MiniChip(text: note.category.label),
                        if (note.hasInk) ...[
                          const SizedBox(width: 6),
                          const _MiniChip(
                              text: '필기', color: AppColors.mentorAccent),
                        ],
                        const SizedBox(width: 6),
                        Text('· $authorLabel',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.text, this.color = AppColors.primary});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
