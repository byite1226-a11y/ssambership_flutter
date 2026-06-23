import '../../core/models/review.dart';
import '../../core/models/user.dart';

/// 구독 결과 — 생성된(또는 연결된) 질문방 id.
class SubscribeResult {
  const SubscribeResult({required this.roomId});
  final String roomId;
}

/// 멘토 탐색·구독 데이터 창구.
///
/// 구독은 실제로는 `record_subscription_cash_debit` RPC 한 번으로 캐시 차감 +
/// 구독 생성 + 방 생성이 원자적으로 처리됩니다(직접 INSERT 금지).
abstract class MentorsRepository {
  /// 멘토 디렉터리(검증/노출 대상).
  Future<List<MentorProfile>> fetchMentors({String? subject});

  /// 멘토 단건 공개 프로필.
  Future<MentorProfile?> fetchMentor(String mentorId);

  /// 구독 결제 → 캐시 차감 + 방 생성. 생성된 방 id 반환.
  Future<SubscribeResult> subscribe({
    required String mentorId,
    required String mentorName,
    required PlanType plan,
    String? subject,
  });

  /// 구독 해지 → 해당 방(구독) 비활성화.
  Future<void> cancelSubscription(String roomId);

  // ── 리뷰 / 즐겨찾기 ─────────────────────────────────────────────────────

  /// 멘토 후기 목록.
  Future<List<Review>> fetchReviews(String mentorId);

  /// 후기 작성.
  Future<Review> addReview({
    required String mentorId,
    required int rating,
    required String body,
  });

  /// 즐겨찾기 토글 → 변경된 상태 반환.
  Future<bool> toggleFavorite(String mentorId);

  /// 즐겨찾기한 멘토 목록.
  Future<List<MentorProfile>> fetchFavorites();

  /// 즐겨찾기 멘토 id 집합(빠른 확인용).
  Future<Set<String>> fetchFavoriteIds();
}
