import '../../../core/models/content_report.dart';
import '../support_repository.dart';

/// 더미 구현 — 신고/문의를 메모리에 보관(Provider 캐시로 세션 유지).
class FakeSupportRepository implements SupportRepository {
  final List<ContentReport> _items = [];

  @override
  Future<ContentReport> createReport({
    required String targetType,
    String? targetId,
    required String reason,
    String description = '',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final r = ContentReport(
      id: 'cr${DateTime.now().microsecondsSinceEpoch}',
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      description: description,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _items.insert(0, r);
    return r;
  }

  @override
  Future<List<ContentReport>> fetchMyReports() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final list = List<ContentReport>.of(_items);
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }
}
