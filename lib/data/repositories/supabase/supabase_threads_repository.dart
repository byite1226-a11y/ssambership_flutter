import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/note.dart';
import '../threads_repository.dart';

/// 실DB 구현 — `question_threads` / `question_messages`.
///
/// 주의(다음 단계 TODO):
///  - 컬럼명(room_id/thread_id/author_id/body/status)은 운영 스키마 기준 best-effort.
///    실제 마이그레이션 확정 후 일치 확인 필요(특히 thread↔room FK명).
///  - 작성 시 무료/유료 질문 한도는 RPC(check_free_question_usage_limits)로
///    선검사하도록 확장 예정.
class SupabaseThreadsRepository implements ThreadsRepository {
  SupabaseThreadsRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<QuestionThread>> fetchThreads(String roomId) async {
    final rows = await _db
        .from('question_threads')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => QuestionThread.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<QuestionMessage>> fetchMessages(String threadId) async {
    final rows = await _db
        .from('question_messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at');
    return (rows as List)
        .map((e) => QuestionMessage.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<QuestionMessage> postMessage({
    required String threadId,
    required String authorId,
    required String body,
  }) async {
    final row = await _db
        .from('question_messages')
        .insert({
          'thread_id': threadId,
          'author_id': authorId,
          'body': body,
        })
        .select()
        .single();
    return QuestionMessage.fromMap(row);
  }

  @override
  Future<QuestionThread> createThread({
    required String roomId,
    required String title,
  }) async {
    final row = await _db
        .from('question_threads')
        .insert({
          'room_id': roomId,
          'title': title,
          'status': 'open',
        })
        .select()
        .single();
    return QuestionThread.fromMap(row);
  }

  @override
  Future<int> weeklyQuestionCount(String roomId) async {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 7));
    final rows = await _db
        .from('question_threads')
        .select('id')
        .eq('room_id', roomId)
        .gte('created_at', since.toIso8601String());
    return (rows as List).length;
  }
}
