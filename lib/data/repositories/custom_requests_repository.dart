import '../../core/models/custom_request.dart';

/// 맞춤의뢰 게시 데이터 창구.
///
/// 게시까지가 1단계. 지원/주문/에스크로(record_custom_order_escrow_*)는 다음 단계.
abstract class CustomRequestsRepository {
  /// 내가 올린 의뢰(학생).
  Future<List<CustomRequestPost>> fetchMyPosts();

  /// 열린 의뢰 둘러보기(멘토).
  Future<List<CustomRequestPost>> fetchOpenPosts();

  /// 의뢰 단건.
  Future<CustomRequestPost?> fetchPost(String postId);

  /// 의뢰 게시 → 생성된 의뢰 반환.
  Future<CustomRequestPost> createPost({
    required String title,
    required String description,
    String? subject,
    int? budgetMin,
    int? budgetMax,
    DateTime? deadline,
  });

  // ── 지원 / 주문(에스크로) ──────────────────────────────────────────────

  /// 의뢰의 지원자 목록(학생이 검토).
  Future<List<CustomRequestApplication>> fetchApplications(String postId);

  /// 멘토가 의뢰에 지원.
  Future<CustomRequestApplication> applyToPost({
    required String postId,
    required String message,
    int? proposedCash,
  });

  /// 학생이 지원자 선정 → 주문 생성 + 캐시 에스크로 보관.
  /// (실DB: record_custom_order_escrow_hold RPC. 더미: 잔액 차감 + 주문 생성)
  Future<CustomOrder> selectApplication({
    required String postId,
    required String applicationId,
  });

  /// 내가 의뢰한 주문(학생).
  Future<List<CustomOrder>> fetchMyOrders();

  /// 내가 맡은 주문(멘토).
  Future<List<CustomOrder>> fetchMentorOrders();

  /// 주문 단건.
  Future<CustomOrder?> fetchOrder(String orderId);

  /// 의뢰에 연결된 주문(없으면 null).
  Future<CustomOrder?> fetchOrderForPost(String postId);

  // ── 납품 / 수락 / 정산 ─────────────────────────────────────────────────

  /// 주문의 납품 산출물 목록.
  Future<List<OrderDeliverable>> fetchDeliverables(String orderId);

  /// 멘토가 산출물 납품 → 주문 'delivered'.
  Future<OrderDeliverable> submitDeliverable({
    required String orderId,
    required String message,
    String? fileName,
  });

  /// 학생이 납품 수락 → 에스크로 정산(20/80), 주문 'accepted'.
  /// (실DB: accept_custom_order_deliverable_atomic + escrow_payout)
  Future<CustomOrder> acceptOrder(String orderId);

  /// 주문 취소·환불 → 에스크로 환불(학생 지갑 복귀), 주문 'refunded'.
  /// (실DB: record_custom_order_escrow_refund)
  Future<CustomOrder> refundOrder(String orderId);

  /// 분쟁 신청 → 주문 'disputed'(정산 보류, 관리자 검토 대기).
  /// (실DB: disputes 행 생성. 정산 분할은 관리자가 record_custom_order_dispute_split 처리)
  Future<CustomOrder> disputeOrder({
    required String orderId,
    required String reason,
  });
}
