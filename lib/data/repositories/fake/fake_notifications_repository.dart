import '../../../core/models/app_notification.dart';
import '../notifications_repository.dart';
import 'demo_store.dart';

/// 더미 구현 — 알림 목록과 읽음 상태를 메모리에 보관(Provider 캐시로 세션 유지).
class FakeNotificationsRepository implements NotificationsRepository {
  final List<AppNotification> _items = [];
  bool _seeded = false;

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    _items.addAll([
      AppNotification(
        id: 'n1',
        type: 'question',
        title: '멘토가 답변을 남겼어요',
        body: '미적분 질문에 김수학 멘토가 답변했어요. 확인해보세요.',
        read: false,
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      AppNotification(
        id: 'n2',
        type: 'order',
        title: '맞춤의뢰에 지원이 도착했어요',
        body: '미적분 모의고사 오답 해설 의뢰에 새 지원이 있어요.',
        read: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'n3',
        type: 'community',
        title: '내 글에 댓글이 달렸어요',
        body: '"수능 D-200 루틴 공유합니다" 글에 새 댓글이 있어요.',
        read: false,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      AppNotification(
        id: 'n4',
        type: 'cash',
        title: '캐시 충전 완료',
        body: '300,000 캐시가 충전됐어요.',
        read: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AppNotification(
        id: 'n5',
        type: 'system',
        title: '쌤버십에 오신 걸 환영해요 🎉',
        body: '멘토를 구독하거나 맞춤의뢰로 1:1 도움을 받아보세요.',
        read: true,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);
  }

  // 시드 알림 + 앱 이벤트로 쌓인 동적 알림(DemoStore)을 함께 노출.
  List<AppNotification> get _all =>
      [...DemoStore.instance.notifications, ..._items];

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final list = _all;
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<int> unreadCount() async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _all.where((n) => !n.read).length;
  }

  @override
  Future<void> markRead(String id) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final dyn = DemoStore.instance.notifications;
    final di = dyn.indexWhere((n) => n.id == id);
    if (di >= 0) {
      dyn[di] = dyn[di].copyWith(read: true);
      return;
    }
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0) _items[i] = _items[i].copyWith(read: true);
  }

  @override
  Future<void> markAllRead() async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final dyn = DemoStore.instance.notifications;
    for (int i = 0; i < dyn.length; i++) {
      dyn[i] = dyn[i].copyWith(read: true);
    }
    for (int i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(read: true);
    }
  }
}
