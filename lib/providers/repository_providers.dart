import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/note.dart';
import '../core/models/user.dart';
import '../core/supabase/supabase_client.dart';
import '../data/repositories/rooms_repository.dart';
import '../data/repositories/fake/fake_rooms_repository.dart';
import '../data/repositories/supabase/supabase_rooms_repository.dart';
import '../data/repositories/threads_repository.dart';
import '../data/repositories/fake/fake_threads_repository.dart';
import '../data/repositories/supabase/supabase_threads_repository.dart';
import '../data/repositories/individual_questions_repository.dart';
import '../data/repositories/fake/fake_individual_questions_repository.dart';
import '../data/repositories/supabase/supabase_individual_questions_repository.dart';
import '../core/models/individual_question.dart';
import '../data/repositories/connection_notes_repository.dart';
import '../data/repositories/fake/fake_connection_notes_repository.dart';
import '../data/repositories/supabase/supabase_connection_notes_repository.dart';
import '../data/repositories/scan_annotations_repository.dart';
import '../data/repositories/fake/fake_scan_annotations_repository.dart';
import '../data/repositories/supabase/supabase_scan_annotations_repository.dart';
import '../data/repositories/cash_repository.dart';
import '../data/repositories/fake/fake_cash_repository.dart';
import '../data/repositories/supabase/supabase_cash_repository.dart';
import '../data/repositories/mentors_repository.dart';
import '../data/repositories/fake/fake_mentors_repository.dart';
import '../data/repositories/supabase/supabase_mentors_repository.dart';
import '../data/repositories/custom_requests_repository.dart';
import '../data/repositories/fake/fake_custom_requests_repository.dart';
import '../data/repositories/supabase/supabase_custom_requests_repository.dart';
import '../data/repositories/community_repository.dart';
import '../data/repositories/fake/fake_community_repository.dart';
import '../data/repositories/supabase/supabase_community_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/fake/fake_notifications_repository.dart';
import '../data/repositories/supabase/supabase_notifications_repository.dart';
import '../data/repositories/settlements_repository.dart';
import '../data/repositories/fake/fake_settlements_repository.dart';
import '../data/repositories/supabase/supabase_settlements_repository.dart';
import '../data/repositories/support_repository.dart';
import '../data/repositories/fake/fake_support_repository.dart';
import '../data/repositories/supabase/supabase_support_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../core/models/app_notification.dart';
import '../core/models/content_report.dart';
import '../core/models/cash.dart';
import '../core/models/community.dart';
import '../core/models/custom_request.dart';
import '../core/models/review.dart';
import '../core/models/settlement.dart';
import '../features/auth/providers/session.dart';
import '../features/scan_annotation/models/scan_annotation.dart';

/// ★ 전환 스위치 (단일 지점)
/// SUPABASE_URL/ANON_KEY 가 --dart-define 으로 주입되면 실DB, 아니면 더미.
/// 화면 코드는 전혀 바뀌지 않습니다.
final roomsRepositoryProvider = Provider<RoomsRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseRoomsRepository(supabase);
  }
  return FakeRoomsRepository();
});

/// 질문방 목록 — 현재 세션 역할/유저 기준 (비동기: 로딩/에러/데이터 3상태).
///
/// 지금은 전역 demoSession 을 직접 읽습니다. 실인증 연동 단계에서 세션을
/// Provider 로 승격하면, 로그인/로그아웃 시 이 목록도 자동 갱신됩니다.
final roomListProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  final repo = ref.watch(roomsRepositoryProvider);
  final role = demoSession.role ?? UserRole.student;
  final userId = demoSession.user?.id ?? '';
  return repo.fetchRooms(role: role, userId: userId);
});

/// 단일 방(상세 헤더용).
final roomProvider =
    FutureProvider.autoDispose.family<Room?, String>((ref, roomId) async {
  return ref.watch(roomsRepositoryProvider).fetchRoom(roomId);
});

/// 스레드 데이터 창구 — fake/supabase 전환. (Provider 캐시로 더미 저장 유지)
final threadsRepositoryProvider = Provider<ThreadsRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseThreadsRepository(supabase);
  }
  return FakeThreadsRepository();
});

/// 방 안의 질문 스레드 목록.
final threadsProvider = FutureProvider.autoDispose
    .family<List<QuestionThread>, String>((ref, roomId) async {
  return ref.watch(threadsRepositoryProvider).fetchThreads(roomId);
});

/// 이번 주(최근 7일) 질문 사용량 — 구독 cap 표시/적용용.
final weeklyUsageProvider = FutureProvider.autoDispose
    .family<int, String>((ref, roomId) async {
  return ref.watch(threadsRepositoryProvider).weeklyQuestionCount(roomId);
});

// ---- 개별 질문(공개/지정) ----
final individualQuestionsRepositoryProvider =
    Provider<IndividualQuestionsRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseIndividualQuestionsRepository(supabase);
  }
  return FakeIndividualQuestionsRepository();
});

/// 내가(학생) 올린 개별 질문.
final myIndividualQuestionsProvider =
    FutureProvider.autoDispose<List<IndividualQuestion>>((ref) async {
  return ref.watch(individualQuestionsRepositoryProvider).fetchMine();
});

/// 나에게(멘토) 지정된 개별 질문.
final assignedIndividualQuestionsProvider =
    FutureProvider.autoDispose<List<IndividualQuestion>>((ref) async {
  return ref
      .watch(individualQuestionsRepositoryProvider)
      .fetchAssignedForMentor();
});

/// 공개 질문 풀(멘토용).
final openIndividualQuestionsProvider =
    FutureProvider.autoDispose<List<IndividualQuestion>>((ref) async {
  return ref.watch(individualQuestionsRepositoryProvider).listOpenForMentor();
});

/// 개별 질문 단건.
final individualQuestionProvider = FutureProvider.autoDispose
    .family<IndividualQuestion?, String>((ref, id) async {
  return ref.watch(individualQuestionsRepositoryProvider).fetchOne(id);
});

/// 개별 질문 답변 메시지.
final iqMessagesProvider = FutureProvider.autoDispose
    .family<List<IndividualQuestionMessage>, String>((ref, id) async {
  return ref.watch(individualQuestionsRepositoryProvider).fetchMessages(id);
});

/// 멘토 지정질문 가격.
final mentorIqPriceProvider =
    FutureProvider.autoDispose.family<int, String>((ref, mentorId) async {
  return ref.watch(individualQuestionsRepositoryProvider).mentorPrice(mentorId);
});

/// 내(멘토) 1:1 질문 가격.
final myMentorIqPriceProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(individualQuestionsRepositoryProvider).myMentorPrice();
});

/// 스레드 안의 메시지 목록.
final messagesProvider = FutureProvider.autoDispose
    .family<List<QuestionMessage>, String>((ref, threadId) async {
  return ref.watch(threadsRepositoryProvider).fetchMessages(threadId);
});

/// 연결노트 데이터 창구 — fake/supabase 전환. (Provider 캐시로 더미 저장 유지)
final connectionNotesRepositoryProvider =
    Provider<ConnectionNotesRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseConnectionNotesRepository(supabase);
  }
  return FakeConnectionNotesRepository();
});

/// 방의 연결노트 목록.
final connectionNotesProvider = FutureProvider.autoDispose
    .family<List<ConnectionNote>, String>((ref, roomId) async {
  return ref.watch(connectionNotesRepositoryProvider).fetchNotes(roomId);
});

/// 스캔 첨삭 데이터 창구 — fake/supabase 전환. (Provider 캐시로 더미 저장 유지)
final scanAnnotationsRepositoryProvider =
    Provider<ScanAnnotationsRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseScanAnnotationsRepository(supabase);
  }
  return FakeScanAnnotationsRepository();
});

/// 방의 스캔 첨삭 목록.
final scanAnnotationsProvider = FutureProvider.autoDispose
    .family<List<ScanAnnotation>, String>((ref, roomId) async {
  return ref.watch(scanAnnotationsRepositoryProvider).fetchAnnotations(roomId);
});

/// 캐시 데이터 창구 — fake/supabase 전환. (Provider 캐시로 더미 잔액 유지)
final cashRepositoryProvider = Provider<CashRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseCashRepository(supabase);
  }
  return FakeCashRepository();
});

/// 지갑 잔액.
final walletProvider = FutureProvider.autoDispose<CashWallet>((ref) async {
  return ref.watch(cashRepositoryProvider).fetchWallet();
});

/// 캐시 입출 내역.
final cashLedgerProvider =
    FutureProvider.autoDispose<List<CashLedgerEntry>>((ref) async {
  return ref.watch(cashRepositoryProvider).fetchLedger();
});

/// 충전 상품.
final topupPackagesProvider =
    FutureProvider.autoDispose<List<TopupPackage>>((ref) async {
  return ref.watch(cashRepositoryProvider).fetchTopupPackages();
});

/// 멘토 탐색·구독 창구 — fake/supabase 전환.
final mentorsRepositoryProvider = Provider<MentorsRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseMentorsRepository(supabase);
  }
  return FakeMentorsRepository();
});

/// 멘토 디렉터리 목록.
final mentorListProvider =
    FutureProvider.autoDispose<List<MentorProfile>>((ref) async {
  return ref.watch(mentorsRepositoryProvider).fetchMentors();
});

/// 멘토 단건 상세.
final mentorDetailProvider =
    FutureProvider.autoDispose.family<MentorProfile?, String>((ref, id) async {
  return ref.watch(mentorsRepositoryProvider).fetchMentor(id);
});

/// 멘토 후기 목록.
final reviewsProvider =
    FutureProvider.autoDispose.family<List<Review>, String>((ref, id) async {
  return ref.watch(mentorsRepositoryProvider).fetchReviews(id);
});

/// 즐겨찾기한 멘토 목록.
final favoritesProvider =
    FutureProvider.autoDispose<List<MentorProfile>>((ref) async {
  return ref.watch(mentorsRepositoryProvider).fetchFavorites();
});

/// 즐겨찾기 멘토 id 집합.
final favoriteIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  return ref.watch(mentorsRepositoryProvider).fetchFavoriteIds();
});

/// 맞춤의뢰 창구 — fake/supabase 전환.
final customRequestsRepositoryProvider =
    Provider<CustomRequestsRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseCustomRequestsRepository(supabase);
  }
  return FakeCustomRequestsRepository();
});

/// 내가 올린 의뢰(학생).
final myCustomPostsProvider =
    FutureProvider.autoDispose<List<CustomRequestPost>>((ref) async {
  return ref.watch(customRequestsRepositoryProvider).fetchMyPosts();
});

/// 열린 의뢰 둘러보기(멘토).
final openCustomPostsProvider =
    FutureProvider.autoDispose<List<CustomRequestPost>>((ref) async {
  return ref.watch(customRequestsRepositoryProvider).fetchOpenPosts();
});

/// 의뢰 단건 상세.
final customPostDetailProvider = FutureProvider.autoDispose
    .family<CustomRequestPost?, String>((ref, id) async {
  return ref.watch(customRequestsRepositoryProvider).fetchPost(id);
});

/// 의뢰 지원자 목록.
final applicationsProvider = FutureProvider.autoDispose
    .family<List<CustomRequestApplication>, String>((ref, postId) async {
  return ref.watch(customRequestsRepositoryProvider).fetchApplications(postId);
});

/// 의뢰에 연결된 주문(없으면 null).
final postOrderProvider =
    FutureProvider.autoDispose.family<CustomOrder?, String>((ref, postId) async {
  return ref.watch(customRequestsRepositoryProvider).fetchOrderForPost(postId);
});

/// 주문 단건.
final orderProvider =
    FutureProvider.autoDispose.family<CustomOrder?, String>((ref, orderId) async {
  return ref.watch(customRequestsRepositoryProvider).fetchOrder(orderId);
});

/// 내 주문(학생).
final myOrdersProvider =
    FutureProvider.autoDispose<List<CustomOrder>>((ref) async {
  return ref.watch(customRequestsRepositoryProvider).fetchMyOrders();
});

/// 내가 맡은 주문(멘토).
final mentorOrdersProvider =
    FutureProvider.autoDispose<List<CustomOrder>>((ref) async {
  return ref.watch(customRequestsRepositoryProvider).fetchMentorOrders();
});

/// 주문의 납품 산출물.
final deliverablesProvider = FutureProvider.autoDispose
    .family<List<OrderDeliverable>, String>((ref, orderId) async {
  return ref.watch(customRequestsRepositoryProvider).fetchDeliverables(orderId);
});

/// 커뮤니티 창구 — fake/supabase 전환.
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseCommunityRepository(supabase);
  }
  return FakeCommunityRepository();
});

/// 게시판 피드.
final communityFeedProvider =
    FutureProvider.autoDispose<List<CommunityPost>>((ref) async {
  return ref.watch(communityRepositoryProvider).fetchPosts();
});

/// 게시글 단건.
final communityPostProvider = FutureProvider.autoDispose
    .family<CommunityPost?, String>((ref, id) async {
  return ref.watch(communityRepositoryProvider).fetchPost(id);
});

/// 숏폼 피드.
final shortformFeedProvider =
    FutureProvider.autoDispose<List<ShortformPost>>((ref) async {
  return ref.watch(communityRepositoryProvider).fetchShortforms();
});

/// 숏폼 단건.
final shortformProvider = FutureProvider.autoDispose
    .family<ShortformPost?, String>((ref, id) async {
  return ref.watch(communityRepositoryProvider).fetchShortform(id);
});

/// 댓글 (postId, postType).
final commentsProvider = FutureProvider.autoDispose
    .family<List<CommunityComment>, (String, String)>((ref, key) async {
  return ref
      .watch(communityRepositoryProvider)
      .fetchComments(key.$1, key.$2);
});

/// 알림 창구 — fake/supabase 전환.
final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseNotificationsRepository(supabase);
  }
  return FakeNotificationsRepository();
});

/// 알림 목록.
final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  return ref.watch(notificationsRepositoryProvider).fetchNotifications();
});

/// 안 읽은 알림 개수(배지).
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});

/// 정산 창구 — fake/supabase 전환.
final settlementsRepositoryProvider = Provider<SettlementsRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseSettlementsRepository(supabase);
  }
  return FakeSettlementsRepository();
});

/// 정산 항목 목록.
final settlementsProvider =
    FutureProvider.autoDispose<List<SettlementEntry>>((ref) async {
  return ref.watch(settlementsRepositoryProvider).fetchSettlements();
});

/// 정산 요약.
final settlementSummaryProvider =
    FutureProvider.autoDispose<SettlementSummary>((ref) async {
  return ref.watch(settlementsRepositoryProvider).fetchSummary();
});

/// 출금 내역.
final withdrawalsProvider =
    FutureProvider.autoDispose<List<Withdrawal>>((ref) async {
  return ref.watch(settlementsRepositoryProvider).fetchWithdrawals();
});

/// 고객지원 창구 — fake/supabase 전환.
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseSupportRepository(supabase);
  }
  return FakeSupportRepository();
});

/// 내 신고/문의 목록.
final myReportsProvider =
    FutureProvider.autoDispose<List<ContentReport>>((ref) async {
  return ref.watch(supportRepositoryProvider).fetchMyReports();
});

/// 인증 창구 — fake(데모 세션)/supabase 전환.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAuthRepository(supabase);
  }
  return DemoAuthRepository();
});
