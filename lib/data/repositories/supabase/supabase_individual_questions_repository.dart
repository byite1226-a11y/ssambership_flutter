import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/individual_question.dart';
import '../individual_questions_repository.dart';

/// 실DB 구현 — `individual_questions` / `individual_question_messages` /
/// `mentor_individual_question_pricing` + 예치/정산 RPC.
///
/// 주의(운영 스키마 확정 시 검증): 컬럼/ RPC 명은 웹 기준 best-effort.
///  - 예치 등록: rpc('create_individual_question_with_hold')
///  - 공개 풀: rpc('list_open_individual_questions_for_mentor')
///  - 가져가기/답변/정산/환불: claim/answer/release/refund RPC
class SupabaseIndividualQuestionsRepository
    implements IndividualQuestionsRepository {
  SupabaseIndividualQuestionsRepository(this._db);
  final SupabaseClient _db;

  String? get _uid => _db.auth.currentUser?.id;

  List<IndividualQuestion> _mapList(dynamic rows) => (rows as List)
      .map((e) => IndividualQuestion.fromMap(e as Map<String, dynamic>))
      .toList();

  @override
  Future<List<IndividualQuestion>> fetchMine() async {
    final rows = await _db
        .from('individual_questions')
        .select()
        .eq('asker_id', (_uid ?? '') as Object)
        .order('created_at', ascending: false);
    return _mapList(rows);
  }

  @override
  Future<List<IndividualQuestion>> fetchAssignedForMentor() async {
    final rows = await _db
        .from('individual_questions')
        .select()
        .eq('designated_mentor_id', (_uid ?? '') as Object)
        .order('created_at', ascending: false);
    return _mapList(rows);
  }

  @override
  Future<List<IndividualQuestion>> listOpenForMentor() async {
    try {
      final rows =
          await _db.rpc('list_open_individual_questions_for_mentor');
      return _mapList(rows);
    } catch (_) {
      final rows = await _db
          .from('individual_questions')
          .select()
          .eq('question_type', 'open')
          .eq('status', 'open')
          .order('created_at', ascending: false);
      return _mapList(rows);
    }
  }

  @override
  Future<IndividualQuestion?> fetchOne(String id) async {
    final row = await _db
        .from('individual_questions')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : IndividualQuestion.fromMap(row);
  }

  @override
  Future<List<IndividualQuestionMessage>> fetchMessages(String id) async {
    final rows = await _db
        .from('individual_question_messages')
        .select()
        .eq('question_id', id)
        .order('created_at');
    return (rows as List)
        .map((e) => IndividualQuestionMessage.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> mentorPrice(String mentorId) async {
    final row = await _db
        .from('mentor_individual_question_pricing')
        .select('amount_cents')
        .eq('mentor_id', mentorId)
        .maybeSingle();
    final cents = (row?['amount_cents'] as num?)?.toInt();
    return cents != null ? cents ~/ 100 : 8000;
  }

  @override
  Future<int> myMentorPrice() async {
    final uid = _uid;
    if (uid == null) return 8000;
    return mentorPrice(uid);
  }

  @override
  Future<void> setMyMentorPrice(int priceCash) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요해요.');
    await _db.from('mentor_individual_question_pricing').upsert({
      'mentor_id': uid,
      'amount_cents': priceCash * 100,
    });
  }

  @override
  Future<IndividualQuestion> createOpen({
    required String title,
    required String body,
    required int priceCash,
  }) async {
    final row = await _db.rpc('create_individual_question_with_hold', params: {
      'p_question_type': 'open',
      'p_title': title,
      'p_body': body,
      'p_amount_cents': priceCash * 100,
    });
    return IndividualQuestion.fromMap(
        (row is List ? row.first : row) as Map<String, dynamic>);
  }

  @override
  Future<IndividualQuestion> createDirect({
    required String mentorId,
    required String mentorName,
    required String title,
    required String body,
  }) async {
    final row = await _db.rpc('create_individual_question_with_hold', params: {
      'p_question_type': 'direct',
      'p_designated_mentor_id': mentorId,
      'p_title': title,
      'p_body': body,
    });
    return IndividualQuestion.fromMap(
        (row is List ? row.first : row) as Map<String, dynamic>);
  }

  @override
  Future<void> claimOpen(String id) async {
    await _db.rpc('claim_individual_question', params: {'p_question_id': id});
  }

  @override
  Future<IndividualQuestionMessage> answer({
    required String id,
    required String body,
  }) async {
    final row = await _db.rpc('answer_individual_question',
        params: {'p_question_id': id, 'p_body': body});
    if (row is Map<String, dynamic>) {
      return IndividualQuestionMessage.fromMap(row);
    }
    return IndividualQuestionMessage(
      id: 'iqm-${DateTime.now().microsecondsSinceEpoch}',
      questionId: id,
      authorId: _uid ?? '',
      body: body,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> confirmAndRelease(String id) async {
    await _db.rpc('release_individual_question', params: {'p_question_id': id});
  }

  @override
  Future<void> cancel(String id) async {
    await _db.rpc('refund_individual_question', params: {'p_question_id': id});
  }
}
