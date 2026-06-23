import '../../../core/models/app_notification.dart';
import '../../../core/models/cash.dart';
import '../../../core/models/custom_request.dart';
import '../../../core/models/individual_question.dart';
import '../../../core/models/note.dart';
import '../../../core/models/review.dart';
import '../../../core/models/settlement.dart';

/// 더미 구현들이 공유하는 데모 상태(메모리).
///
/// 구독 결제는 "캐시 차감 + 구독 생성 + 방 생성"이 한 번에 일어납니다. 이 효과가
/// 캐시 화면(잔액·내역)과 질문방 목록 양쪽에서 일관되게 보이도록, 지갑·원장·
/// 구독으로 생긴 방을 한곳(싱글턴)에 모아 여러 Fake 리포지토리가 공유합니다.
class DemoStore {
  DemoStore._();
  static final DemoStore instance = DemoStore._();

  int walletCents = 30000000; // 300,000 캐시 (요금제 구독이 가능한 데모 잔액)
  final List<CashLedgerEntry> ledger = [];
  final List<Room> subscribedRooms = []; // 구독으로 생긴 방(학생 관점)
  final List<CustomRequestPost> customPosts = []; // 맞춤의뢰 게시글
  final List<CustomRequestApplication> applications = []; // 의뢰 지원
  final List<CustomOrder> orders = []; // 선정 후 주문(에스크로)
  final List<OrderDeliverable> deliverables = []; // 납품 산출물
  final Set<String> cancelledRoomIds = {}; // 해지된 구독(방) id
  final Set<String> favoriteMentorIds = {}; // 즐겨찾기한 멘토
  final List<Review> reviews = []; // 멘토 후기
  final List<SettlementEntry> seededSettlements = []; // 정산 시드(구독 등)
  final List<Withdrawal> withdrawals = []; // 출금 내역
  int withdrawnCents = 0; // 누적 출금(원)

  // --- 개별 질문(공개/지정) ---
  final List<IndividualQuestion> individualQuestions = [];
  final Map<String, List<IndividualQuestionMessage>> iqMessages = {};
  final Map<String, int> mentorIqPriceCash = {}; // 멘토별 지정질문 가격

  // --- 동적 알림(앱 내 이벤트로 쌓이는 알림) ---
  final List<AppNotification> notifications = [];

  /// 이벤트성 알림을 큐에 추가(최신이 위로). 알림 화면/뱃지에 반영됨.
  void pushNotification({
    required String type,
    required String title,
    required String body,
  }) {
    notifications.insert(
      0,
      AppNotification(
        id: 'dn${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        title: title,
        body: body,
        read: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  bool _seeded = false;
  void ensureSeed() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    ledger.add(
      CashLedgerEntry(
        id: 'l1',
        amountCents: 30000000,
        kind: 'topup',
        description: '캐시 충전 (300,000 캐시)',
        createdAt: now.subtract(const Duration(days: 7)),
      ),
    );
    customPosts.addAll([
      CustomRequestPost(
        id: 'crp-seed-1',
        authorId: 'demo-student',
        title: '미적분 모의고사 오답 해설 의뢰',
        description: '6월 모평 22번·30번 풀이 과정을 단계별로 자세히 설명해 주세요. '
            '제가 어디서 막혔는지도 짚어주시면 좋겠어요.',
        subject: '수학',
        budgetMin: 30000,
        budgetMax: 50000,
        deadline: now.add(const Duration(days: 3)),
        status: 'open',
        createdAt: now.subtract(const Duration(hours: 8)),
        applicationsCount: 2,
      ),
      CustomRequestPost(
        id: 'crp-seed-2',
        authorId: 'demo-student',
        title: '영어 내신 서술형 첨삭',
        description: '중간고사 대비 서술형 5문항 답안을 첨삭해 주세요. 문법/표현 위주로요.',
        subject: '영어',
        budgetMin: 20000,
        budgetMax: 20000,
        deadline: now.add(const Duration(days: 5)),
        status: 'open',
        createdAt: now.subtract(const Duration(days: 1)),
        applicationsCount: 0,
      ),
    ]);
    applications.addAll([
      CustomRequestApplication(
        id: 'app-seed-1',
        postId: 'crp-seed-1',
        mentorId: 'demo-mentor',
        mentorName: '데모 멘토',
        message: '미적분 오답 해설은 제 전문이에요. 풀이 과정을 단계별로 영상+필기로 드릴게요.',
        proposedCash: 40000,
        status: 'applied',
        createdAt: now.subtract(const Duration(hours: 6)),
        avgRating: 4.9,
        universityName: '서울대학교',
      ),
      CustomRequestApplication(
        id: 'app-seed-2',
        postId: 'crp-seed-1',
        mentorId: 'm-seoul-math',
        mentorName: '김수학 멘토',
        message: '22번·30번 모두 자신 있습니다. 비슷한 유형 2문제도 함께 정리해 드려요.',
        proposedCash: 45000,
        status: 'applied',
        createdAt: now.subtract(const Duration(hours: 3)),
        avgRating: 4.8,
        universityName: '서울대학교',
      ),
    ]);
    reviews.addAll([
      Review(
        id: 'rv1',
        mentorId: 'm-seoul-math',
        authorLabel: '고3 학생',
        rating: 5,
        body: '오답 짚어주시는 게 정확해요. 덕분에 22번 유형 감 잡았어요!',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'rv2',
        mentorId: 'm-seoul-math',
        authorLabel: '재수생',
        rating: 4,
        body: '풀이가 깔끔합니다. 답변도 빠른 편이에요.',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      Review(
        id: 'rv3',
        mentorId: 'm-yonsei-eng',
        authorLabel: '고2 학생',
        rating: 5,
        body: '서술형 첨삭 꼼꼼하게 해주셔서 내신 등급 올랐어요.',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);
    seededSettlements.addAll([
      SettlementEntry(
        id: 'st1',
        label: '구독 정산 — 김민수 학생 (Standard)',
        amountCash: 80430, // 114,900 * 0.7
        kind: 'subscription',
        settled: true,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      SettlementEntry(
        id: 'st2',
        label: '구독 정산 — 박서연 학생 (Limited)',
        amountCash: 38500, // 55,000 * 0.7
        kind: 'subscription',
        settled: true,
        createdAt: now.subtract(const Duration(days: 9)),
      ),
    ]);

    // 개별 질문 시드
    mentorIqPriceCash['demo-mentor'] = 8000;
    individualQuestions.addAll([
      IndividualQuestion(
        id: 'iq-open-1',
        type: IQType.open,
        status: IQStatus.open,
        title: '확률변수 기댓값 선형성 증명',
        body: 'E(aX+bY)=aE(X)+bE(Y) 증명 과정을 단계별로 알고 싶어요.',
        priceCash: 5000,
        askerId: 'demo-student',
        askerLabel: '학생',
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.add(const Duration(hours: 46)),
      ),
      IndividualQuestion(
        id: 'iq-direct-1',
        type: IQType.direct,
        status: IQStatus.assigned,
        title: '치환적분 구간 변환이 헷갈려요',
        body: 'u = 2x+1 로 치환할 때 적분 구간이 어떻게 바뀌는지 모르겠어요.',
        priceCash: 8000,
        askerId: 'demo-student',
        askerLabel: '학생',
        designatedMentorId: 'demo-mentor',
        designatedMentorName: '양준용 멘토',
        createdAt: now.subtract(const Duration(hours: 3)),
        expiresAt: now.add(const Duration(hours: 69)),
      ),
      IndividualQuestion(
        id: 'iq-direct-2',
        type: IQType.direct,
        status: IQStatus.answered,
        title: '로피탈 정리 적용 조건',
        body: '0/0 꼴이 아닐 때도 로피탈을 쓸 수 있나요?',
        priceCash: 8000,
        askerId: 'demo-student',
        askerLabel: '학생',
        designatedMentorId: 'demo-mentor',
        designatedMentorName: '양준용 멘토',
        createdAt: now.subtract(const Duration(days: 1)),
        expiresAt: now.add(const Duration(hours: 12)),
      ),
    ]);
    iqMessages['iq-direct-2'] = [
      IndividualQuestionMessage(
        id: 'iqm-1',
        questionId: 'iq-direct-2',
        authorId: 'demo-mentor',
        body: '∞/∞ 꼴에도 적용돼요. 단, 미분 가능·분모 도함수≠0 조건을 먼저 확인하세요.',
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
    ];
  }

  bool isSubscribedTo(String mentorId) =>
      subscribedRooms.any((r) => r.mentorId == mentorId);
}
