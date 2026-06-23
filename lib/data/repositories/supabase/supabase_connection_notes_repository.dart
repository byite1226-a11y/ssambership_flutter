import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/note.dart';
import '../../../core/supabase/supabase_client.dart';
import '../connection_notes_repository.dart';

/// 실DB 구현 — `connection_notes` 행 + 필기/썸네일 Storage.
///
/// 주의(기획서 Part 5 선행 필요):
///  - 현재 운영 스키마의 connection_notes 는 body/author 만 있습니다. 아래 코드는
///    필기 리뉴얼용 컬럼(title, category, has_ink, ink_data_url, ink_thumbnail_path)
///    과 버킷(connection-note-ink, connection-note-thumbnails)을 **전제**합니다.
///    Part 5 마이그레이션을 적용한 뒤에 동작합니다.
class SupabaseConnectionNotesRepository implements ConnectionNotesRepository {
  SupabaseConnectionNotesRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<ConnectionNote>> fetchNotes(String roomId) async {
    final rows = await _db
        .from('connection_notes')
        .select()
        .eq('mentor_student_room_id', roomId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((e) => ConnectionNote.fromMap(e as Map<String, dynamic>))
        .toList();
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
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();

    String? inkPath;
    if (hasInk) {
      inkPath = '$roomId/$stamp.json';
      await _db.storage.from(SupabaseConfig.bucketConnectionNoteInk).uploadBinary(
            inkPath,
            Uint8List.fromList(utf8.encode(sketchJson)),
            fileOptions:
                const FileOptions(upsert: true, contentType: 'application/json'),
          );
    }

    String? thumbPath;
    if (thumbnailPng != null) {
      thumbPath = '$roomId/$stamp.png';
      await _db.storage
          .from(SupabaseConfig.bucketConnectionNoteThumb)
          .uploadBinary(
            thumbPath,
            thumbnailPng,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/png'),
          );
    }

    final values = <String, dynamic>{
      'mentor_student_room_id': roomId,
      'author_id': authorId,
      'author_role': authorRole,
      'title': title,
      'body': textBody,
      'category': category.dbValue,
      'has_ink': hasInk,
      if (inkPath != null) 'ink_data_url': inkPath,
      if (thumbPath != null) 'ink_thumbnail_path': thumbPath,
    };

    final row = noteId == null
        ? await _db.from('connection_notes').insert(values).select().single()
        : await _db
            .from('connection_notes')
            .update(values)
            .eq('id', noteId)
            .select()
            .single();
    return ConnectionNote.fromMap(row);
  }

  @override
  Future<String?> fetchSketchJson(String noteId) async {
    final row = await _db
        .from('connection_notes')
        .select('ink_data_url')
        .eq('id', noteId)
        .maybeSingle();
    final path = row?['ink_data_url'] as String?;
    if (path == null || path.isEmpty) return null;
    try {
      final bytes =
          await _db.storage.from(SupabaseConfig.bucketConnectionNoteInk).download(path);
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
