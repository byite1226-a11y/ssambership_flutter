import '../../core/models/individual_question.dart';

/// 개별 질문 데이터 창구. 화면은 이 인터페이스에만 의존(fake/supabase 구현).
abstract class IndividualQuestionsRepository {
  /// 내가(학생) 올린 개별 질문 목록.
  Future<List<IndividualQuestion>> fetchMine();

  /// 나에게(멘토) 지정된 개별 질문 목록.
  Future<List<IndividualQuestion>> fetchAssignedForMentor();

  /// 공개 풀(아직 아무도 안 가져간 공개 질문) 목록 — 멘토용.
  Future<List<IndividualQuestion>> listOpenForMentor();

  /// 단건 조회.
  Future<IndividualQuestion?> fetchOne(String id);

  /// 답변 메시지 목록.
  Future<List<IndividualQuestionMessage>> fetchMessages(String id);

  /// 멘토의 지정 질문 1건 가격(캐시).
  Future<int> mentorPrice(String mentorId);

  /// 내(멘토) 1:1 질문 가격 조회/설정.
  Future<int> myMentorPrice();
  Future<void> setMyMentorPrice(int priceCash);

  /// 공개 질문 등록 + 예치.
  /// [idempotencyKey] 동일 등록의 재시도 시 이중 예치(이중 과금)를 막는 키.
  Future<IndividualQuestion> createOpen({
    required String title,
    required String body,
    required int priceCash,
    String? idempotencyKey,
  });

  /// 지정 질문 등록 + 예치(멘토 고정가).
  /// [idempotencyKey] 동일 등록의 재시도 시 이중 예치(이중 과금)를 막는 키.
  Future<IndividualQuestion> createDirect({
    required String mentorId,
    required String mentorName,
    required String title,
    required String body,
    String? idempotencyKey,
  });

  /// 공개 질문 가져가기(멘토).
  Future<void> claimOpen(String id);

  /// 답변 등록(멘토).
  Future<IndividualQuestionMessage> answer({
    required String id,
    required String body,
  });

  /// 답변 확인 → 정산(학생).
  Future<void> confirmAndRelease(String id);

  /// 취소 → 환불(답변 전, 학생).
  Future<void> cancel(String id);
}
