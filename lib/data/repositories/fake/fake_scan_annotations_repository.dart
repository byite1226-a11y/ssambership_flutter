import 'dart:typed_data';

import '../../../features/scan_annotation/models/scan_annotation.dart';
import '../scan_annotations_repository.dart';

/// 더미 구현 — 원본 이미지 바이트와 주석을 메모리에 저장합니다.
/// 실제 이미지가 필요해 시드는 없고, 첫 저장부터 목록에 쌓입니다.
class FakeScanAnnotationsRepository implements ScanAnnotationsRepository {
  final Map<String, List<ScanAnnotation>> _byRoom = {};
  final Map<String, Uint8List> _originalById = {};

  @override
  Future<List<ScanAnnotation>> fetchAnnotations(String roomId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final list = List<ScanAnnotation>.of(_byRoom[roomId] ?? const []);
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
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
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final id = annotationId ?? 'sa${DateTime.now().microsecondsSinceEpoch}';
    _originalById[id] = originalImage;
    final anno = ScanAnnotation(
      id: id,
      roomId: roomId,
      authorId: authorId,
      authorRole: authorRole,
      annotationJson: annotationJson,
      scanImageUrl: 'mem://scan/$id',
      previewUrl: (previewPng != null) ? 'mem://scan-preview/$id' : null,
      hasAnnotations: hasAnnotations,
      createdAt: DateTime.now(),
    );
    final list = _byRoom[roomId] ??= [];
    final idx = list.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      list[idx] = anno;
    } else {
      list.insert(0, anno);
    }
    return anno;
  }

  @override
  Future<Uint8List?> loadOriginalImage(String annotationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _originalById[annotationId];
  }
}
