import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/custom_request.dart';
import '../custom_requests_repository.dart';

/// 실DB 구현 — custom_request_posts.
///
/// 단건 공개 조회는 get_public_custom_request_post_for_browse RPC도 있으나,
/// 여기서는 RLS 하의 select로 단순화했습니다(소유자/공개 정책 전제).
class SupabaseCustomRequestsRepository implements CustomRequestsRepository {
  SupabaseCustomRequestsRepository(this._db);

  final SupabaseClient _db;

  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<List<CustomRequestPost>> fetchMyPosts() async {
    final rows = await _db
        .from('custom_request_posts')
        .select()
        .eq('author_id', _uid ?? '')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => CustomRequestPost.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CustomRequestPost>> fetchOpenPosts() async {
    final rows = await _db
        .from('custom_request_posts')
        .select()
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => CustomRequestPost.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CustomRequestPost?> fetchPost(String postId) async {
    final row = await _db
        .from('custom_request_posts')
        .select()
        .eq('id', postId)
        .maybeSingle();
    return row == null ? null : CustomRequestPost.fromMap(row);
  }

  @override
  Future<CustomRequestPost> createPost({
    required String title,
    required String description,
    String? subject,
    int? budgetMin,
    int? budgetMax,
    DateTime? deadline,
  }) async {
    final values = <String, dynamic>{
      'author_id': _uid,
      'title': title,
      'body': description,
      'description': description,
      if (subject != null) 'subject': subject,
      if (budgetMin != null) 'budget_min': budgetMin,
      if (budgetMax != null) 'budget_max': budgetMax,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
      'status': 'open',
    };
    final row = await _db
        .from('custom_request_posts')
        .insert(values)
        .select()
        .single();
    return CustomRequestPost.fromMap(row);
  }

  // ── 지원 / 주문(에스크로) ──────────────────────────────────────────────

  @override
  Future<List<CustomRequestApplication>> fetchApplications(
      String postId) async {
    final rows = await _db
        .from('custom_request_applications')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) =>
            CustomRequestApplication.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CustomRequestApplication> applyToPost({
    required String postId,
    required String message,
    int? proposedCash,
  }) async {
    final values = <String, dynamic>{
      'post_id': postId,
      'mentor_id': _uid,
      'message': message,
      if (proposedCash != null) 'proposed_cash': proposedCash,
      'status': 'applied',
    };
    final row = await _db
        .from('custom_request_applications')
        .insert(values)
        .select()
        .single();
    return CustomRequestApplication.fromMap(row);
  }

  @override
  Future<CustomOrder> selectApplication({
    required String postId,
    required String applicationId,
  }) async {
    // record_custom_order_escrow_hold: 주문 생성 + 캐시 에스크로 보관(원자적).
    final res = await _db.rpc('record_custom_order_escrow_hold', params: {
      'p_post_id': postId,
      'p_application_id': applicationId,
    });
    Map? row;
    if (res is Map) {
      row = res;
    } else if (res is List && res.isNotEmpty && res.first is Map) {
      row = res.first as Map;
    }
    if (row != null) {
      return CustomOrder.fromMap(Map<String, dynamic>.from(row));
    }
    throw Exception('주문 생성 응답을 해석하지 못했어요.');
  }

  @override
  Future<List<CustomOrder>> fetchMyOrders() async {
    final rows = await _db
        .from('custom_orders')
        .select()
        .eq('student_id', _uid ?? '')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => CustomOrder.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CustomOrder>> fetchMentorOrders() async {
    final rows = await _db
        .from('custom_orders')
        .select()
        .eq('mentor_id', _uid ?? '')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => CustomOrder.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CustomOrder?> fetchOrder(String orderId) async {
    final row = await _db
        .from('custom_orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();
    return row == null ? null : CustomOrder.fromMap(row);
  }

  @override
  Future<CustomOrder?> fetchOrderForPost(String postId) async {
    final row = await _db
        .from('custom_orders')
        .select()
        .eq('post_id', postId)
        .maybeSingle();
    return row == null ? null : CustomOrder.fromMap(row);
  }

  // ── 납품 / 수락 / 정산 ─────────────────────────────────────────────────

  @override
  Future<List<OrderDeliverable>> fetchDeliverables(String orderId) async {
    final rows = await _db
        .from('custom_order_deliverables')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => OrderDeliverable.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderDeliverable> submitDeliverable({
    required String orderId,
    required String message,
    String? fileName,
  }) async {
    final values = <String, dynamic>{
      'order_id': orderId,
      'mentor_id': _uid,
      'message': message,
      if (fileName != null) 'file_name': fileName,
    };
    final row = await _db
        .from('custom_order_deliverables')
        .insert(values)
        .select()
        .single();
    // 주문 상태 → delivered
    await _db
        .from('custom_orders')
        .update({'status': 'delivered'}).eq('id', orderId);
    return OrderDeliverable.fromMap(row);
  }

  @override
  Future<CustomOrder> acceptOrder(String orderId) async {
    // 납품 수락 + 에스크로 정산(20/80)을 원자적으로.
    await _db.rpc('accept_custom_order_deliverable_atomic',
        params: {'p_order_id': orderId});
    final row = await _db
        .from('custom_orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) throw Exception('주문을 찾을 수 없어요.');
    return CustomOrder.fromMap(row);
  }

  @override
  Future<CustomOrder> refundOrder(String orderId) async {
    await _db.rpc('record_custom_order_escrow_refund',
        params: {'p_order_id': orderId});
    final row = await _db
        .from('custom_orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) throw Exception('주문을 찾을 수 없어요.');
    return CustomOrder.fromMap(row);
  }

  @override
  Future<CustomOrder> disputeOrder({
    required String orderId,
    required String reason,
  }) async {
    // 분쟁 행 생성(관리자 검토 대기). 정산 분할은 관리자 RPC(record_custom_order_dispute_split).
    await _db.from('disputes').insert({
      'order_id': orderId,
      'custom_request_order_id': orderId,
      'student_id': _uid,
      'reason': reason,
      'status': 'pending',
    });
    await _db
        .from('custom_orders')
        .update({'status': 'disputed'}).eq('id', orderId);
    final row = await _db
        .from('custom_orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) throw Exception('주문을 찾을 수 없어요.');
    return CustomOrder.fromMap(row);
  }
}
