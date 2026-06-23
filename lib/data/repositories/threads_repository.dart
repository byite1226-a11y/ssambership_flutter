import '../../core/models/note.dart';

/// 질문 스레드·메시지 데이터 창구.
///
/// 질문방(room) → 스레드(thread) → 메시지(message) 3단 구조.
/// 화면은 이 인터페이스에만 의존합니다. 구현은 fake/supabase 두 가지.
abstract class ThreadsRepository {
  /// 방 안의 질문 스레드 목록.
  Future<List<QuestionThread>> fetchThreads(String roomId);

  /// 스레드 안의 메시지 목록(시간순).
  Future<List<QuestionMessage>> fetchMessages(String threadId);

  /// 메시지 작성.
  /// (실DB 단계에서는 무료/유료 질문 한도 RPC 검사를 앞단에 둘 수 있음)
  Future<QuestionMessage> postMessage({
    required String threadId,
    required String authorId,
    required String body,
  });

  /// 새 질문 스레드 생성.
  Future<QuestionThread> createThread({
    required String roomId,
    required String title,
  });

  /// 이번 주(최근 7일) 해당 방에서 생성된 질문 수 — 구독 cap 적용용.
  Future<int> weeklyQuestionCount(String roomId);
}
