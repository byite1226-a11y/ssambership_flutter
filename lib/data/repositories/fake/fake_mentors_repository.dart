import '../../../core/models/cash.dart';
import '../../../core/models/note.dart';
import '../../../core/models/review.dart';
import '../../../core/models/user.dart';
import '../mentors_repository.dart';
import 'demo_store.dart';

/// 더미 구현 — 멘토 몇 명을 제공하고, 구독 시 DemoStore의 캐시를 차감하고
/// 새 방을 만들어 질문방 목록에 노출합니다(실제 결제 흐름의 데모).
class FakeMentorsRepository implements MentorsRepository {
  final DemoStore _store = DemoStore.instance;

  static const _mentors = <MentorProfile>[
    MentorProfile(
      userId: 'm-seoul-math',
      displayName: '김수학 멘토',
      universityName: '서울대학교',
      departmentName: '수리과학부',
      teachingSubjects: ['수학', '미적분', '기하'],
      verificationStatus: 'verified',
      avgRating: 4.9,
      reviewCount: 128,
    ),
    MentorProfile(
      userId: 'm-yonsei-eng',
      displayName: '이영어 멘토',
      universityName: '연세대학교',
      departmentName: '영어영문학과',
      teachingSubjects: ['영어', '내신영어', '수능영어'],
      verificationStatus: 'verified',
      avgRating: 4.7,
      reviewCount: 86,
    ),
    MentorProfile(
      userId: 'm-kaist-sci',
      displayName: '박과학 멘토',
      universityName: 'KAIST',
      departmentName: '물리학과',
      teachingSubjects: ['물리', '화학', '과학탐구'],
      verificationStatus: 'verified',
      avgRating: 4.8,
      reviewCount: 64,
    ),
  ];

  @override
  Future<List<MentorProfile>> fetchMentors({String? subject}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (subject == null || subject.trim().isEmpty) return _mentors;
    final q = subject.trim();
    return _mentors
        .where((m) => m.teachingSubjects.any((s) => s.contains(q)))
        .toList();
  }

  @override
  Future<MentorProfile?> fetchMentor(String mentorId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final m in _mentors) {
      if (m.userId == mentorId) return m;
    }
    return null;
  }

  @override
  Future<SubscribeResult> subscribe({
    required String mentorId,
    required String mentorName,
    required PlanType plan,
    String? subject,
  }) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (_store.isSubscribedTo(mentorId)) {
      throw Exception('이미 구독 중인 멘토예요.');
    }

    final info = PlanInfo.all[plan]!;
    final costCents = info.priceCash * 100;
    if (_store.walletCents < costCents) {
      throw Exception('캐시가 부족해요. 충전 후 다시 시도해주세요.');
    }

    // 캐시 차감 + 원장 기록 (RPC record_subscription_cash_debit 의 데모 대응)
    _store.walletCents -= costCents;
    _store.ledger.insert(
      0,
      CashLedgerEntry(
        id: 'l${DateTime.now().microsecondsSinceEpoch}',
        amountCents: -costCents,
        kind: 'subscription',
        description: '$mentorName ${info.label} 구독 결제',
        createdAt: DateTime.now(),
      ),
    );

    // 방 생성
    final roomId = 'room-$mentorId-${DateTime.now().microsecondsSinceEpoch}';
    final label = (subject == null || subject.isEmpty)
        ? '${info.label} 구독'
        : '$subject · ${info.label} 구독';
    _store.subscribedRooms.insert(
      0,
      Room(
        id: roomId,
        studentId: 'demo-student',
        mentorId: mentorId,
        mentorName: mentorName,
        studentName: '데모 학생',
        subscriptionLabel: label,
        lastMessagePreview: '구독을 시작했어요! 궁금한 걸 질문해보세요.',
        updatedAt: DateTime.now(),
      ),
    );

    return SubscribeResult(roomId: roomId);
  }

  @override
  Future<void> cancelSubscription(String roomId) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    _store.cancelledRoomIds.add(roomId);
    _store.subscribedRooms.removeWhere((r) => r.id == roomId);
  }

  // ── 리뷰 / 즐겨찾기 ─────────────────────────────────────────────────────

  @override
  Future<List<Review>> fetchReviews(String mentorId) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final list =
        _store.reviews.where((r) => r.mentorId == mentorId).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<Review> addReview({
    required String mentorId,
    required int rating,
    required String body,
  }) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final r = Review(
      id: 'rv${DateTime.now().microsecondsSinceEpoch}',
      mentorId: mentorId,
      authorLabel: '나 (데모)',
      rating: rating,
      body: body,
      createdAt: DateTime.now(),
    );
    _store.reviews.insert(0, r);
    return r;
  }

  @override
  Future<bool> toggleFavorite(String mentorId) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    final nowFav = !_store.favoriteMentorIds.contains(mentorId);
    if (nowFav) {
      _store.favoriteMentorIds.add(mentorId);
    } else {
      _store.favoriteMentorIds.remove(mentorId);
    }
    return nowFav;
  }

  @override
  Future<List<MentorProfile>> fetchFavorites() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return _mentors
        .where((m) => _store.favoriteMentorIds.contains(m.userId))
        .toList();
  }

  @override
  Future<Set<String>> fetchFavoriteIds() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return Set<String>.of(_store.favoriteMentorIds);
  }
}
