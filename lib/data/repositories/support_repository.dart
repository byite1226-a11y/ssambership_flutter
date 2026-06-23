import '../../core/models/content_report.dart';

/// 고객지원 — 신고/문의 데이터 창구.
abstract class SupportRepository {
  /// 신고/문의 접수.
  Future<ContentReport> createReport({
    required String targetType,
    String? targetId,
    required String reason,
    String description,
  });

  /// 내가 낸 신고/문의 목록.
  Future<List<ContentReport>> fetchMyReports();
}
