import '../../../core/models/cash.dart';
import '../../../core/models/custom_request.dart';
import '../custom_requests_repository.dart';
import 'demo_store.dart';

/// 더미 구현 — 게시글을 공유 DemoStore에 보관. 학생이 올린 의뢰가 멘토 둘러보기에도
/// 즉시 나타나, 게시 흐름을 양쪽에서 검증할 수 있습니다.
class FakeCustomRequestsRepository implements CustomRequestsRepository {
  final DemoStore _store = DemoStore.instance;

  @override
  Future<List<CustomRequestPost>> fetchMyPosts() async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final list = _store.customPosts
        .where((p) => p.authorId == 'demo-student')
        .toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<List<CustomRequestPost>> fetchOpenPosts() async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final list = _store.customPosts.where((p) => p.isOpen).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<CustomRequestPost?> fetchPost(String postId) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    for (final p in _store.customPosts) {
      if (p.id == postId) return p;
    }
    return null;
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
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final post = CustomRequestPost(
      id: 'crp${DateTime.now().microsecondsSinceEpoch}',
      authorId: 'demo-student',
      title: title,
      description: description,
      subject: subject,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      deadline: deadline,
      status: 'open',
      createdAt: DateTime.now(),
    );
    _store.customPosts.insert(0, post);
    return post;
  }

  // ── 지원 / 주문(에스크로) ──────────────────────────────────────────────

  @override
  Future<List<CustomRequestApplication>> fetchApplications(
      String postId) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final list =
        _store.applications.where((a) => a.postId == postId).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<CustomRequestApplication> applyToPost({
    required String postId,
    required String message,
    int? proposedCash,
  }) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (_store.applications
        .any((a) => a.postId == postId && a.mentorId == 'demo-mentor')) {
      throw Exception('이미 지원한 의뢰예요.');
    }
    final app = CustomRequestApplication(
      id: 'app${DateTime.now().microsecondsSinceEpoch}',
      postId: postId,
      mentorId: 'demo-mentor',
      mentorName: '데모 멘토',
      message: message,
      proposedCash: proposedCash,
      status: 'applied',
      createdAt: DateTime.now(),
      avgRating: 4.9,
      universityName: '데모대학교',
    );
    _store.applications.insert(0, app);
    final idx = _store.customPosts.indexWhere((p) => p.id == postId);
    if (idx >= 0) {
      _store.customPosts[idx] = _store.customPosts[idx].copyWith(
          applicationsCount:
              _store.customPosts[idx].applicationsCount + 1);
    }
    return app;
  }

  @override
  Future<CustomOrder> selectApplication({
    required String postId,
    required String applicationId,
  }) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 420));
    final app = _store.applications.firstWhere((a) => a.id == applicationId,
        orElse: () => throw Exception('지원 정보를 찾을 수 없어요.'));
    final post = _store.customPosts.firstWhere((p) => p.id == postId,
        orElse: () => throw Exception('의뢰를 찾을 수 없어요.'));
    if (_store.orders.any((o) => o.postId == postId)) {
      throw Exception('이미 진행 중인 주문이 있어요.');
    }
    final amount = app.proposedCash ?? post.budgetMax ?? post.budgetMin ?? 0;
    final costCents = amount * 100;
    if (_store.walletCents < costCents) {
      throw Exception('캐시가 부족해요. 충전 후 다시 시도해주세요.');
    }
    // 에스크로 보관(차감)
    _store.walletCents -= costCents;
    _store.ledger.insert(
      0,
      CashLedgerEntry(
        id: 'l${DateTime.now().microsecondsSinceEpoch}',
        amountCents: -costCents,
        kind: 'escrow_hold',
        description: '${app.mentorName} 주문 에스크로 보관',
        createdAt: DateTime.now(),
      ),
    );
    // 주문 생성
    final order = CustomOrder(
      id: 'ord${DateTime.now().microsecondsSinceEpoch}',
      postId: postId,
      studentId: 'demo-student',
      mentorId: app.mentorId,
      mentorName: app.mentorName,
      title: post.title,
      amountCash: amount,
      status: 'in_progress',
      createdAt: DateTime.now(),
    );
    _store.orders.insert(0, order);
    // 지원 상태 갱신: 선정/탈락
    for (int i = 0; i < _store.applications.length; i++) {
      final a = _store.applications[i];
      if (a.postId == postId) {
        _store.applications[i] =
            a.copyWith(status: a.id == applicationId ? 'selected' : 'rejected');
      }
    }
    // 게시글 상태 → 진행중
    final pIdx = _store.customPosts.indexWhere((p) => p.id == postId);
    if (pIdx >= 0) {
      _store.customPosts[pIdx] =
          _store.customPosts[pIdx].copyWith(status: 'in_progress');
    }
    return order;
  }

  @override
  Future<List<CustomOrder>> fetchMyOrders() async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final list =
        _store.orders.where((o) => o.studentId == 'demo-student').toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<List<CustomOrder>> fetchMentorOrders() async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final list =
        _store.orders.where((o) => o.mentorId == 'demo-mentor').toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<CustomOrder?> fetchOrder(String orderId) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    for (final o in _store.orders) {
      if (o.id == orderId) return o;
    }
    return null;
  }

  @override
  Future<CustomOrder?> fetchOrderForPost(String postId) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    for (final o in _store.orders) {
      if (o.postId == postId) return o;
    }
    return null;
  }

  // ── 납품 / 수락 / 정산 ─────────────────────────────────────────────────

  @override
  Future<List<OrderDeliverable>> fetchDeliverables(String orderId) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final list =
        _store.deliverables.where((d) => d.orderId == orderId).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  void _setOrderStatus(String orderId, String status) {
    final i = _store.orders.indexWhere((o) => o.id == orderId);
    if (i >= 0) _store.orders[i] = _store.orders[i].copyWith(status: status);
  }

  @override
  Future<OrderDeliverable> submitDeliverable({
    required String orderId,
    required String message,
    String? fileName,
  }) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final d = OrderDeliverable(
      id: 'dlv${DateTime.now().microsecondsSinceEpoch}',
      orderId: orderId,
      mentorId: 'demo-mentor',
      message: message,
      fileName: fileName,
      createdAt: DateTime.now(),
    );
    _store.deliverables.insert(0, d);
    _setOrderStatus(orderId, 'delivered');
    return d;
  }

  @override
  Future<CustomOrder> acceptOrder(String orderId) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 360));
    final i = _store.orders.indexWhere((o) => o.id == orderId);
    if (i < 0) throw Exception('주문을 찾을 수 없어요.');
    // 에스크로는 hold 시 이미 차감됨. 수락 시 멘토에게 정산(데모는 상태만 변경).
    _store.orders[i] = _store.orders[i].copyWith(status: 'accepted');
    return _store.orders[i];
  }

  @override
  Future<CustomOrder> refundOrder(String orderId) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 360));
    final i = _store.orders.indexWhere((o) => o.id == orderId);
    if (i < 0) throw Exception('주문을 찾을 수 없어요.');
    final order = _store.orders[i];
    if (order.status == 'accepted') {
      throw Exception('이미 정산된 주문은 환불할 수 없어요.');
    }
    // 에스크로 환불 → 학생 지갑 복귀
    _store.walletCents += order.amountCash * 100;
    _store.ledger.insert(
      0,
      CashLedgerEntry(
        id: 'l${DateTime.now().microsecondsSinceEpoch}',
        amountCents: order.amountCash * 100,
        kind: 'refund',
        description: '${order.mentorName} 주문 에스크로 환불',
        createdAt: DateTime.now(),
      ),
    );
    _store.orders[i] = order.copyWith(status: 'refunded');
    return _store.orders[i];
  }

  @override
  Future<CustomOrder> disputeOrder({
    required String orderId,
    required String reason,
  }) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final i = _store.orders.indexWhere((o) => o.id == orderId);
    if (i < 0) throw Exception('주문을 찾을 수 없어요.');
    if (_store.orders[i].status == 'accepted') {
      throw Exception('이미 정산된 주문은 분쟁 신청할 수 없어요.');
    }
    _store.orders[i] = _store.orders[i].copyWith(status: 'disputed');
    return _store.orders[i];
  }
}
