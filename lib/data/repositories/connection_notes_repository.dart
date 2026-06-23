import 'dart:typed_data';

import '../../core/models/note.dart';

/// 연결노트 데이터 창구 (room 단위).
///
/// 저장 입력은 에디터 화면(NoteSavePayload)에 의존하지 않도록 개별 필드로 받습니다.
/// (데이터 계층이 화면을 import 하지 않게 하기 위함)
abstract class ConnectionNotesRepository {
  /// 방의 연결노트 목록(최신순).
  Future<List<ConnectionNote>> fetchNotes(String roomId);

  /// 노트 저장. noteId == null 이면 신규 생성, 아니면 수정.
  Future<ConnectionNote> saveNote({
    required String roomId,
    required String authorId,
    required String authorRole, // 'student' | 'mentor'
    String? noteId,
    required String title,
    required String textBody,
    required NoteCategory category,
    required String sketchJson, // 필기 벡터 원본(JSON)
    Uint8List? thumbnailPng, // 목록 썸네일
    required bool hasInk,
  });

  /// 필기 복원용 원본 JSON (재편집 시 캔버스에 다시 그리기 위함).
  /// 실DB에서는 ink 저장 위치(Storage)에서 내려받습니다.
  Future<String?> fetchSketchJson(String noteId);
}
