import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../features/scan_annotation/models/scan_annotation.dart';
import '../scan_annotations_repository.dart';

/// 실DB 구현 — `scan_annotations` 행 + 원본/미리보기 Storage.
///
/// 주의(기획서 Part 5 선행 필요):
///  - scan_annotations 테이블과 버킷은 현재 운영 스키마에 없습니다. 신설 후 동작.
///  - 원본은 변경 불가 레이어로 한 번만 업로드, 주석(annotation_json)만 갱신하는
///    것이 이상적입니다. 아래는 best-effort(갱신 시 원본 재업로드 생략 가능).
class SupabaseScanAnnotationsRepository implements ScanAnnotationsRepository {
  SupabaseScanAnnotationsRepository(this._db);

  final SupabaseClient _db;

  String get _bucket => SupabaseConfig.bucketScanOriginals;

  @override
  Future<List<ScanAnnotation>> fetchAnnotations(String roomId) async {
    final rows = await _db
        .from('scan_annotations')
        .select()
        .eq('mentor_student_room_id', roomId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => ScanAnnotation.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ScanAnnotation> saveAnnotation({
    required String roomId,
    required String authorId,
    required String authorRole,
    String? annotationId,
    required Uint8List originalImage,
    required String annotationJson,
    Uint8List? previewPng,
    required bool hasAnnotations,
  }) async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final imagePath = '$roomId/$stamp-original.jpg';
    await _db.storage.from(_bucket).uploadBinary(
          imagePath,
          originalImage,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );

    String? previewPath;
    if (previewPng != null) {
      previewPath = '$roomId/$stamp-preview.png';
      await _db.storage.from(_bucket).uploadBinary(
            previewPath,
            previewPng,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/png'),
          );
    }

    final values = <String, dynamic>{
      'mentor_student_room_id': roomId,
      'author_id': authorId,
      'author_role': authorRole,
      'annotation_json': annotationJson,
      'scan_image_path': imagePath,
      'has_annotations': hasAnnotations,
      if (previewPath != null) 'preview_path': previewPath,
    };

    final row = annotationId == null
        ? await _db.from('scan_annotations').insert(values).select().single()
        : await _db
            .from('scan_annotations')
            .update(values)
            .eq('id', annotationId)
            .select()
            .single();
    return ScanAnnotation.fromMap(row);
  }

  @override
  Future<Uint8List?> loadOriginalImage(String annotationId) async {
    final row = await _db
        .from('scan_annotations')
        .select('scan_image_path')
        .eq('id', annotationId)
        .maybeSingle();
    final path = row?['scan_image_path'] as String?;
    if (path == null || path.isEmpty) return null;
    try {
      return await _db.storage.from(_bucket).download(path);
    } catch (_) {
      return null;
    }
  }
}
