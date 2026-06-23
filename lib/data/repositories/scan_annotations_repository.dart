import 'dart:typed_data';

import '../../features/scan_annotation/models/scan_annotation.dart';

/// 스캔 첨삭 데이터 창구 (room 단위).
///
/// 원본 이미지는 화면(파일 경로)에서 바이트로 읽어 넘깁니다. 데이터 계층은
/// 그 바이트를 Storage에 올리고, 주석은 정규화 JSON으로 보관합니다.
abstract class ScanAnnotationsRepository {
  /// 방의 스캔 첨삭 목록(최신순).
  Future<List<ScanAnnotation>> fetchAnnotations(String roomId);

  /// 저장. annotationId == null 이면 신규(원본+주석), 아니면 주석 갱신.
  Future<ScanAnnotation> saveAnnotation({
    required String roomId,
    required String authorId,
    required String authorRole, // 'student' | 'mentor'
    String? annotationId,
    required Uint8List originalImage, // 스캔 원본(배경, 편집 불가)
    required String annotationJson, // 정규화(0~1) 주석
    Uint8List? previewPng, // 평탄화 미리보기
    required bool hasAnnotations,
  });

  /// 재편집용 원본 이미지 바이트 (배경으로 다시 깔기 위함).
  Future<Uint8List?> loadOriginalImage(String annotationId);
}
