import 'dart:typed_data';

import '../../../core/models/note.dart';
import '../connection_notes_repository.dart';

/// 더미 구현 — 노트와 필기 JSON을 메모리에 저장합니다.
/// 신규/수정/재편집이 실제로 반영되어, 키 없이도 연결노트 흐름을 검증할 수 있습니다.
class FakeConnectionNotesRepository implements ConnectionNotesRepository {
  final Map<String, List<ConnectionNote>> _notes = {};
  final Map<String, String> _sketchById = {}; // noteId → 필기 JSON
  bool _seeded = false;

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    _notes['demo-room-1'] = [
      ConnectionNote(
        id: 'cn-seed-1',
        roomId: 'demo-room-1',
        authorId: 'demo-mentor',
        authorRole: 'mentor',
        category: NoteCategory.requestedByMentor,
        title: '이번 주 복습 과제',
        body: '미적분 12번 유형 3문제 더 풀어오기. 막히면 여기에 필기로 질문 남겨줘요.',
        hasInk: false,
        updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];
  }

  @override
  Future<List<ConnectionNote>> fetchNotes(String roomId) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final list = List<ConnectionNote>.of(_notes[roomId] ?? const []);
    list.sort((a, b) =>
        (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<ConnectionNote> saveNote({
    required String roomId,
    required String authorId,
    required String authorRole,
    String? noteId,
    required String title,
    required String textBody,
    required NoteCategory category,
    required String sketchJson,
    Uint8List? thumbnailPng,
    required bool hasInk,
  }) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final id = noteId ?? 'cn${DateTime.now().microsecondsSinceEpoch}';
    _sketchById[id] = sketchJson;
    final note = ConnectionNote(
      id: id,
      roomId: roomId,
      authorId: authorId,
      authorRole: authorRole,
      category: category,
      title: title.isEmpty ? '제목 없는 노트' : title,
      body: textBody,
      hasInk: hasInk,
      inkDataUrl: hasInk ? 'mem://ink/$id' : null,
      inkThumbnailUrl: (thumbnailPng != null) ? 'mem://thumb/$id' : null,
      updatedAt: DateTime.now(),
    );
    final list = _notes[roomId] ??= [];
    final idx = list.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      list[idx] = note;
    } else {
      list.insert(0, note);
    }
    return note;
  }

  @override
  Future<String?> fetchSketchJson(String noteId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _sketchById[noteId];
  }
}
