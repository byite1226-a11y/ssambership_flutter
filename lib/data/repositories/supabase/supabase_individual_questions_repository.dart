import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/individual_question.dart';
import '../individual_questions_repository.dart';

/// 실DB 구현 — `individual_questions` / `individual_question_messages` /
/// `mentor_individual_question_pricing` + 예치/정산 RPC.
///
/// 컬럼/RPC 명은 웹(공유 DB)을 기준으로 정렬했다.
///  - 예치 등록: rpc('create_individual_question_with_hold')
///  - 공개 풀: rpc('list_open_individual_questions_for_mentor')
///  - 가져가기: rpc('claim_individual_question')
///  - 답변: individual_question_messages insert + status='answered' (RPC 아님)
///  - 정산/환불(release/refund)은 service_role 전용 RPC라 클라이언트 직접 호출 불가
///    → 서버 경유 필요(별도 작업, 아래 confirmAndRelease/cancel 참고).
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
        .eq('student_id', (_uid ?? '') as Object)
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
    // 웹과 동일한 2단계: ① 답변 메시지를 individual_question_messages 에 기록,
    // ② 질문 상태를 answered 로 전이(학생이 [확인·정산] 버튼을 보게 됨).
    // 전용 answer RPC 는 DB 에 없으므로 직접 insert/update 로 처리한다.
    final inserted = await _db
        .from('individual_question_messages')
        .insert({
          'question_id': id,
          'author_id': _uid,
          'body': body,
        })
        .select()
        .single();
    await _db.from('individual_questions').update({
      'status': 'answered',
      'answered_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    return IndividualQuestionMessage.fromMap(inserted);
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
