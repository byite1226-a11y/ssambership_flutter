import 'dart:typed_data';

import '../../handwriting/models/ink_sketch.dart';
import '../../handwriting/models/ink_stroke.dart';

/// 스캔 주석 저장 묶음 — 데이터 레이어가 Storage에 올릴 재료.
/// (스캔 원본은 이미 업로드되어 있다고 가정, 여기서는 주석 JSON + 평탄화 PNG)
/// 기술기획서 5 "저장 옵션 B": 스캔 원본 + 주석 JSON + 미리보기 PNG 묶음.
class ScanAnnotationPayload {
  ScanAnnotationPayload({
    required this.annotationJson,
    required this.flattenedPng,
    required this.hasAnnotations,
  });

  /// 정규화 좌표(0~1)로 변환된 주석 스트로크 JSON. 이미지 기준이라
  /// 기기/줌/해상도가 달라도 위치가 어긋나지 않음 (기획서 2-2 ★).
  final String annotationJson;

  /// 배경(스캔) + 주석을 한 장으로 합친 PNG. 첨부/미리보기용.
  final Uint8List? flattenedPng;
  final bool hasAnnotations;
}

/// ★ 좌표 정합의 핵심 유틸 (스캔주석 기획서 2-2).
///
/// 캔버스는 박스 \"로컬 픽셀\" 좌표로 그리지만, 저장할 때는 이미지 기준
/// 0~1 정규화 좌표로 바꿔서 보관합니다. 다시 열 때는 새 박스 크기로 곱해
/// 복원합니다. 이렇게 하면 태블릿/폰/회전/줌이 달라도 주석이 스캔의 같은
/// 지점에 정확히 얹힙니다. (스캔 주석에서 가장 흔한 버그를 원천 차단)
class ScanCoordMapper {
  const ScanCoordMapper._();

  /// 박스 픽셀 좌표 → 0~1 정규화 (저장 직전).
  static InkSketch normalize(
    InkSketch boxLocal, {
    required double boxWidth,
    required double boxHeight,
  }) {
    if (boxWidth <= 0 || boxHeight <= 0) return boxLocal;
    final norm = boxLocal.strokes.map((s) {
      return s.copyWith(
        // 굵기도 박스 너비 기준 비율로 보관 → 복원 시 어떤 크기에서도 동일 두께감.
        widthNorm: s.width / boxWidth,
        points: s.points
            .map((p) => InkPoint(p.x / boxWidth, p.y / boxHeight, p.pressure))
            .toList(growable: false),
      );
    }).toList(growable: false);

    return InkSketch(
      strokes: norm,
      template: boxLocal.template,
      // 정규화본임을 표시 (cw/ch = 1.0 기준)
      canvasWidth: 1.0,
      canvasHeight: 1.0,
      version: boxLocal.version,
    );
  }

  /// 0~1 정규화 → 현재 박스 픽셀 좌표 (불러오기 직후).
  static InkSketch denormalize(
    InkSketch normalized, {
    required double boxWidth,
    required double boxHeight,
  }) {
    if (boxWidth <= 0 || boxHeight <= 0) return normalized;
    final px = normalized.strokes.map((s) {
      final w = s.widthNorm;
      return s.copyWith(
        width: (w != null && w > 0) ? w * boxWidth : s.width,
        points: s.points
            .map((p) => InkPoint(p.x * boxWidth, p.y * boxHeight, p.pressure))
            .toList(growable: false),
      );
    }).toList(growable: false);

    return InkSketch(
      strokes: px,
      template: normalized.template,
      canvasWidth: boxWidth,
      canvasHeight: boxHeight,
      version: normalized.version,
    );
  }
}

/// scan_annotations 행 모델 (기획서 Part 5 신설 테이블).
class ScanAnnotation {
  const ScanAnnotation({
    required this.id,
    required this.roomId,
    required this.authorId,
    required this.authorRole,
    required this.annotationJson,
    this.scanImageUrl,
    this.previewUrl,
    this.hasAnnotations = false,
    this.createdAt,
  });

  final String id;
  final String roomId;
  final String authorId;
  final String authorRole; // 'student' | 'mentor'
  final String annotationJson; // 정규화(0~1) 주석
  final String? scanImageUrl; // 원본 위치(표시/다운로드)
  final String? previewUrl; // 미리보기 위치
  final bool hasAnnotations;
  final DateTime? createdAt;

  bool get isMentorAuthored => authorRole == 'mentor';

  factory ScanAnnotation.fromMap(Map<String, dynamic> m) => ScanAnnotation(
        id: m['id'] as String,
        roomId: (m['mentor_student_room_id'] as String?) ??
            (m['room_id'] as String?) ??
            '',
        authorId: (m['author_id'] as String?) ?? '',
        authorRole: (m['author_role'] as String?) ?? 'student',
        annotationJson: (m['annotation_json'] as String?) ?? '{}',
        scanImageUrl: m['scan_image_path'] as String?,
        previewUrl: m['preview_path'] as String?,
        hasAnnotations: (m['has_annotations'] as bool?) ?? true,
        createdAt: _parseScanDate(m['created_at']),
      );
}

DateTime? _parseScanDate(dynamic v) =>
    v is String ? DateTime.tryParse(v) : (v is DateTime ? v : null);
