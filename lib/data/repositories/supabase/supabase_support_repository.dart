import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/content_report.dart';
import '../support_repository.dart';

/// 실DB 구현 — content_reports.
class SupabaseSupportRepository implements SupportRepository {
  SupabaseSupportRepository(this._db);

  final SupabaseClient _db;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<ContentReport> createReport({
    required String targetType,
    String? targetId,
    required String reason,
    String description = '',
  }) async {
    final row = await _db
        .from('content_reports')
        .insert({
          'reporter_id': _uid,
          'target_type': targetType,
          if (targetId != null) 'target_id': targetId,
          'reason': reason,
          'description': description,
        })
        .select()
        .single();
    return ContentReport.fromMap(row);
  }

  @override
  Future<List<ContentReport>> fetchMyReports() async {
    final rows = await _db
        .from('content_reports')
        .select()
        .eq('reporter_id', _uid ?? '')
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => ContentReport.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
