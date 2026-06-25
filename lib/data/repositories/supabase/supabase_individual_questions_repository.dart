import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/individual_question.dart';
import '../individual_questions_repository.dart';

/// 실DB 구현 — `individual_questions` / `individual_question_messages` /
/// `mentor_individual_question_pricing` + 예치/정산 RPC.
///
/// 컬럼/RPC 명은 웹(공유 DB)을 기준으로 정렬했다. 돈 직결 RPC는 service_role 코어를
/// 직접 부르지 않고, auth.uid()를 강제하는 인증 래퍼(091·092)를 경유한다.
///  - 예치 등록: rpc('create_individual_question_as_student') — 092
///  - 공개 풀: rpc('list_open_individual_questions_for_mentor')
///  - 가져가기: rpc('claim_individual_question_as_mentor') — 092
///  - 답변: individual_question_messages insert + status='answered' (RPC 아님)
///  - 정산/환불: rpc('release_individual_question') / rpc('refund_individual_question') — 091
///    래퍼가 auth.uid()=student_id·상태를 검증한 뒤 service_role 코어 함수를 내부 호출한다.
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
    String? idempotencyKey,
  }) async {
    // 학생 본인용 인증 래퍼(092). 래퍼가 student_id=auth.uid()를 강제하고
    // 멱등성 키로 이중 예치를 막은 뒤 service_role 코어 함수를 내부 호출한다.
    final row = await _db.rpc('create_individual_question_as_student', params: {
      'p_question_type': 'open',
      'p_title': title,
      'p_body': body,
      'p_amount_cents': priceCash * 100,
      if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
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
    String? idempotencyKey,
  }) async {
    // 지정질문 가격은 래퍼가 멘토 가격표에서 직접 조회한다(앱 표시가와 동일 소스).
    final row = await _db.rpc('create_individual_question_as_student', params: {
      'p_question_type': 'direct',
      'p_designated_mentor_id': mentorId,
      'p_title': title,
      'p_body': body,
      if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
    });
    return IndividualQuestion.fromMap(
        (row is List ? row.first : row) as Map<String, dynamic>);
  }

  @override
  Future<void> claimOpen(String id) async {
    // 멘토 본인용 인증 래퍼(092). 래퍼가 mentor_id=auth.uid()를 강제한다.
    await _db.rpc('claim_individual_question_as_mentor',
        params: {'p_question_id': id});
  }

  @override
  Future<IndividualQuestionMessage> answer({
    required String id,
    required String body,
  }) async {
    // 070 설계(에스크로 테이블은 RPC 경유 변경만)에 맞춰, 메시지 기록 + 상태
    // 전이(answered)를 단일 RPC 로 원자 처리한다. 멘토 권한·상태 가드는 서버가
    // 강제(담당=claimed/지정=designated 멘토, 상태 claimed/assigned 만).
    // RPC 는 갱신된 individual_questions 행을 반환하므로, 호출부가 쓰지 않는
    // 반환 메시지는 알려진 입력값으로 구성한다.
    await _db.rpc('answer_individual_question', params: {
      'p_question_id': id,
      'p_body': body,
    });
    return IndividualQuestionMessage(
      id: id,
      questionId: id,
      authorId: _uid ?? '',
      body: body,
      createdAt: DateTime.now().toUtc(),
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
