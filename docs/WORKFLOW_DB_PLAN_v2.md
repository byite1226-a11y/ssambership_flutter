# 쌤버십 앱 — 웹 기준 워크플로우 재기획 + Supabase 실연동 설계서 (v2)

> 기준: 웹앱(`ssambership_web-main`)의 **실제 Supabase 스키마(43개 테이블) + 서버 RPC + 데이터 접근 계층(Queries/Actions)** 을 분석한 결과.
> 목적: 단순히 "화면만 보이는" 구현이 아니라, **더미데이터를 걷어내고 실제 DB에 연결해도 그대로 돌아가도록** 워크플로우·UI·UX를 설계.
> 연결노트 필기·스캔 첨삭은 이전 기획서(`REBUILD_PLAN_v1.md`)를 기준으로 워크플로우에 합류시킴.

---

# Part 0. 엔지니어 검토 — 핵심 결론 먼저

지금 앱을 실DB에 붙였을 때 "원활히 구동되는가?"에 대한 솔직한 진단입니다.

### 결론 4가지

1. **현재 앱은 데이터 계층이 없습니다.** 더미데이터가 화면 코드(`student_screens.dart`, `mentor_screens.dart`)에 **직접 박혀** 있어요. 이대로 Supabase를 붙이면 화면마다 코드를 뜯어고쳐야 합니다. → **선결 과제: Repository(데이터 창구) 계층 도입.** 화면은 "데이터를 어디서 가져오는지" 모르게 만들고, 더미↔실DB를 한 곳에서 바꾸도록 설계해야 합니다.

2. **웹은 중요한 쓰기를 직접 INSERT가 아니라 RPC 함수로 합니다.** 구독 결제(`record_subscription_cash_debit`), 캐시 충전(`record_cash_topup`), 맞춤의뢰 정산(`record_custom_order_escrow_hold/payout`) 등은 모두 서버 함수로 원자적 처리돼요. → 앱도 **반드시 같은 RPC를 호출**해야 합니다. 앱에서 직접 `cash_wallets`를 UPDATE하면 정합성·보안이 깨집니다.

3. **차별화 기능(필기·스캔)은 아직 DB에 자리가 없습니다.** 웹의 `connection_notes`는 **텍스트 본문(`body`)만** 있고, 필기 벡터/썸네일 컬럼이 없어요. 스캔 첨삭용 테이블도 없습니다. → 기획서대로 가려면 **컬럼·Storage 버킷을 신설**해야 합니다(Part 5에 명세).

4. **저장 경로가 비어 있어 "시각적으로만" 동작합니다.** 연결노트·스캔 에디터의 `onSave` 콜백이 라우터에서 `null`로 연결돼 있어, 그려도 어디에도 안 저장돼요. 이건 버그가 아니라 "데이터 계약을 아직 안 꽂은 상태"입니다. → 데이터 계약(Part 5) 정의 후 연결하면 됩니다.

### 한 줄 요약

> 지금은 **잘 만든 골격 + 동작하는 차별화 기능 UI**예요. 실DB로 가려면 **① 데이터 계층 도입 → ② RPC 기반 쓰기 → ③ 차별화 기능 스키마 신설** 세 가지가 핵심이고, 이 문서가 그 설계도입니다.

---

# Part 1. 데이터 모델 (실제 스키마, 도메인별 43개 테이블)

웹 Supabase에 실재하는 테이블입니다. 앱의 모델 클래스는 이 구조를 그대로 따라야 합니다.

### 인증·사용자
- `users` — 계정/역할(student·mentor·admin)/프로필
- `mentor_profiles` — 멘토 공개 프로필(학교·학과·소개)
- `mentor_plans` — 멘토가 설정한 요금제(Limited/Standard/Premium)
- `subjects` — 과목 마스터
- `verification_logs` — 멘토 인증 심사 로그
- `favorites` — 멘토 즐겨찾기

### 질문방·연결노트 (핵심)
- `mentor_student_rooms` — 학생↔멘토 1:1 방(구독으로 생성)
- `question_threads` — 방 안의 질문 스레드(주제 단위)
- `question_messages` — 스레드 안 메시지(질문/답변)
- `question_attachments` — 메시지 첨부(이미지 등)
- `connection_notes` — 연결노트(현재 **텍스트 `body`만**, `author_id`/`author_role` 있음) ★필기 리뉴얼 대상
- `free_question_usage` — 무료 질문 사용량(정책: 한 멘토당 일정 수, 7일 만료)

### 구독·캐시·결제
- `subscriptions` — 구독(학생-멘토-요금제)
- `cash_wallets` — 캐시 지갑(잔액)
- `cash_ledger` — 캐시 입출 내역
- `cash_topup_packages` — 충전 패키지
- `payments` / `order_payments` — 결제 기록
- (외부) 토스페이먼츠 — `lib/toss`

### 맞춤의뢰 (가장 복잡한 워크플로우)
- `custom_request_posts` — 의뢰 게시글
- `custom_request_post_attachments` — 게시글 첨부
- `custom_request_applications` — 멘토 지원
- `custom_request_application_attachments` — 지원 첨부
- `custom_request_orders` — 선정 후 주문(에스크로)
- `custom_order_messages` — 진행방 메시지
- `custom_order_deliverables` — 납품물
- `custom_order_revisions` — 수정 요청
- `custom_order_settlement_items` — 정산 항목
- `order_events` / `order_payments` — 주문 이벤트/결제

### 커뮤니티
- `community_posts` — 게시글
- `community_comments` / `comments` — 댓글
- `post_reactions` — 좋아요/반응
- `community_hashtags` — 해시태그
- `shortform_posts` — 숏폼 영상

### 신뢰·운영
- `reviews` — 후기(자격 검증 RPC 있음)
- `notifications` — 알림
- `disputes` — 분쟁
- `refunds` — 환불
- `content_reports` — 신고
- `app_notices` / `promotion_campaigns` — 공지/프로모션
- `admin_action_logs` — 관리자 액션 로그
- `ai_drafts` — AI 초안(보조 기능)

---

# Part 2. 서버 RPC = 쓰기의 진입점 (실연동 필수 규칙)

웹은 아래 작업을 **클라이언트 직접 INSERT/UPDATE가 아니라 Postgres 함수(RPC)** 로 처리합니다. 앱도 `supabase.rpc('함수명', params)` 로 **똑같이** 호출해야 정합성·보안이 유지됩니다.

| 워크플로우 | RPC 함수 | 하는 일 |
|---|---|---|
| 구독 결제 | `record_subscription_cash_debit` / `..._rollback` | 캐시 차감 + 구독 생성을 원자적으로 |
| 캐시 충전 | `record_cash_topup` | 결제 검증 후 지갑/원장 반영 |
| 무료 질문 | `check_free_question_usage_limits` / `get_weekly_question_usage` | 한도 검사 |
| 멘토 한도 | `enforce_mentor_cap` / `mentor_cap_used` / `mentor_cap_limit` | 멘토 동시 구독 상한 |
| 멘토 탐색 | `mentor_directory_list` / `mentor_profiles_for_directory` / `mentor_user_public` | 공개 멘토 목록(RLS 우회 안전 read) |
| 의뢰 탐색 | `list_open_custom_request_posts_for_mentor_browse` / `get_public_custom_request_post_for_browse` | 공개 의뢰 목록 |
| 의뢰 에스크로 | `record_custom_order_escrow_hold` / `..._payout` / `..._refund` / `record_custom_order_dispute_split` | 의뢰 대금 보관·지급·환불·분쟁분할 |
| 납품 수락 | `accept_custom_order_deliverable_atomic` | 납품 확정 + 정산 |
| 후기 | `check_review_eligibility` | 후기 작성 자격 |
| 가입 | `handle_new_auth_user` | auth 가입 시 프로필 생성(트리거) |
| 역할 | `is_admin` / `is_mentor` | 권한 검사 |
| 조회수 | `increment_community_post_view` / `increment_shortform_post_view` | 뷰 카운트 |
| 닉네임 | `get_mentor_student_nicknames` | 방별 표시 이름 |

> **설계 원칙**: 앱의 Repository에서 "쓰기"는 가능한 한 위 RPC를 호출한다. 단순 텍스트 저장(질문 메시지, 연결노트 본문 등)만 RLS가 걸린 일반 INSERT를 쓴다.

---

# Part 3. 웹 데이터 접근 패턴 → 앱 아키텍처

## 3-1. 웹의 방식 (그대로 본받기)

웹 `lib/`는 기능별 폴더에 **읽기와 쓰기를 분리**해 둡니다:
- `xxxQueries.ts` — 읽기(조회). 예: `cashQueries`, `mentorProfileQueries`, `communityBoardQueries`
- `xxxActions.ts` — 쓰기(변경). 예: `walletTopupActions`, `customRequestComposeActions`, `commentActions`

도메인 폴더: `auth / cash / qna / subscribe / mentor / customRequest / community / reviews / disputes / notifications / mypage / notices`.

## 3-2. 앱(Flutter)에 옮기는 구조 — Repository 패턴

화면이 **데이터 출처를 모르게** 만드는 게 핵심입니다. 그래야 더미↔실DB 전환이 한 곳에서 끝납니다.

```
lib/
  data/
    models/                 # DB 테이블 ↔ Dart 객체 (fromJson/toJson)
      room.dart, thread.dart, message.dart, connection_note.dart,
      subscription.dart, wallet.dart, mentor.dart, custom_order.dart, ...
    repositories/
      rooms_repository.dart        # 추상 인터페이스 (읽기/쓰기 메서드 정의)
      cash_repository.dart
      mentor_repository.dart
      ...
      fake/                        # 더미 구현 (지금 화면의 더미데이터를 여기로 이동)
        fake_rooms_repository.dart
      supabase/                    # 실DB 구현 (RLS select + rpc 호출)
        supabase_rooms_repository.dart
  providers/
    repository_providers.dart  # Riverpod: 환경에 따라 fake/supabase 주입
```

**전환 스위치 한 곳**:
```dart
// repository_providers.dart
final roomsRepositoryProvider = Provider<RoomsRepository>((ref) {
  // SupabaseConfig.isConfigured == true 이면 실DB, 아니면 더미
  return SupabaseConfig.isConfigured
      ? SupabaseRoomsRepository(supabase)
      : FakeRoomsRepository();
});
```

이렇게 하면:
- 화면은 `ref.watch(roomsRepositoryProvider).fetchRooms()` 만 부른다. 출처를 모른다.
- env(`--dart-define`)로 키가 들어오면 **자동으로 실DB**로 전환된다. 화면 코드 변경 0.
- 더미 단계에서도 화면이 정상 동작하고, 실연동은 `supabase/` 폴더만 채우면 된다.

**상태/로딩 처리**: 화면은 `AsyncValue`(Riverpod의 `FutureProvider`/`AsyncNotifier`)로 로딩·에러·데이터 3상태를 표준 처리한다. 지금처럼 동기 더미 리스트를 바로 박으면 실DB(비동기)로 갈 때 깨지므로, **처음부터 비동기(Future) 기반**으로 화면을 짠다.

---

# Part 4. 워크플로우별 분석 + 앱 구현 설계

각 워크플로우를 〔웹 흐름 → 관련 테이블·RPC(데이터 계약) → 앱 구현(화면+Repository) → 현재 상태 → 실연동 체크포인트〕로 정리합니다.

## 4-1. 인증·온보딩
- **웹 흐름**: `/signup` → 프로필 입력 → 역할별 `/login/student|mentor`. 미성년 동의(`legal/minor-consent`).
- **데이터**: `users`(가입 시 `handle_new_auth_user` 트리거로 생성), 멘토는 `mentor_profiles` + `verification_logs`.
- **앱 구현**: 가입(이메일→프로필 2단계) / 로그인 화면. `AuthRepository`(signUp/signIn/signOut/currentUser). 세션은 Supabase `onAuthStateChange` 구독으로 현재의 `DemoSession`을 교체.
- **현재 상태**: 🟡 데모 역할전환만. 실인증 ⛔.
- **실연동 체크포인트**: `DemoSession` → 실제 `AuthRepository` 교체가 라우터 redirect와 호환되게(이미 역할 기반 redirect 구현됨). 가입 직후 프로필 행 존재 보장.

## 4-2. 멘토 탐색·구독 (결제 핵심)
- **웹 흐름**: 멘토 찾기(`/mentors`) → 상세(`/mentors/[id]`) → 구독 요금제(`/subscribe`) → 결제 → 방 생성.
- **데이터**: 읽기 `mentor_directory_list`/`mentor_user_public`(공개 RPC), `mentor_plans`. 쓰기 `record_subscription_cash_debit`(캐시 차감+구독 생성). 한도 `enforce_mentor_cap`, 무료질문 `free_question_usage`.
- **앱 구현**: 멘토 검색/상세/요금제 화면. `MentorRepository.listMentors()/getMentor(id)`, `SubscriptionRepository.subscribe(plan)` → 내부에서 `rpc('record_subscription_cash_debit')`.
- **현재 상태**: 멘토 검색 🟡 / 요금제 UI ✅(가격 잠금 반영) / 실결제 ⛔.
- **실연동 체크포인트**: 구독은 **반드시 RPC**로(직접 INSERT 금지). 요금제 가격은 `mentor_plans`에서 읽되, 잠금값(55,000/114,900/249,900)과 일치 검증. 무료 질문 잔여 표시.

## 4-3. 질문방·스레드 (핵심 사용 루프)
- **웹 흐름**: 방 목록(`question-room`) → 방 상세(`[roomId]`) → 스레드(`thread/[threadId]`) → 질문 작성/답변.
- **데이터**: `mentor_student_rooms` → `question_threads` → `question_messages` → `question_attachments`. 한도 `check_free_question_usage_limits`. 표시명 `get_mentor_student_nicknames`. 첨부는 Storage(질문방 버킷, RLS 경로 검증 함수 `user_is_room_party_for_qra_path`).
- **앱 구현**: 방 목록/상세/스레드(채팅형). `RoomsRepository.fetchRooms()`, `ThreadsRepository.fetchThreads(roomId)/fetchMessages(threadId)/postMessage(...)`. 첨부 업로드는 `StorageRepository`.
- **현재 상태**: 방 목록/상세 ✅(더미) / 스레드 채팅 🟡 / '질문하기' 버튼은 안내 스낵바(스텁 처리됨).
- **실연동 체크포인트**: 방→스레드→메시지 3단 비동기 로딩(AsyncValue). 질문 작성 시 무료/유료 차감을 RPC로 사전 검사. 첨부 업로드 경로가 RLS 검증 함수와 일치.

## 4-4. ★ 연결노트 (필기 리뉴얼) — 워크플로우 합류
- **위치**: 질문방 상세 → 연결노트. room 단위·공개형(방 당사자 RLS).
- **기획서 기준(REBUILD_PLAN_v1)**: 텍스트 → **펜+텍스트 하이브리드**. 저장 = 벡터 스트로크 JSON(원본) + 썸네일 PNG + `has_ink`. 카테고리(전체/멘토에게요청/멘토가요청/메모). 작성자 색(`author_role`).
- **데이터(현 스키마 부족 → Part 5에서 신설)**: 현재 `connection_notes`는 `body`(텍스트)+`author_id`+`author_role`만. **필기 컬럼·버킷 추가 필요.**
- **앱 구현**: `ConnectionNoteRepository.fetchNotes(roomId)/saveNote(payload)`. 에디터의 `onSave`에 이 메서드를 연결(현재 `null`). 저장 시 벡터 JSON은 컬럼/버킷, 썸네일은 thumbnails 버킷.
- **현재 상태**: 에디터 ✅ 동작 / 저장 연결 ⛔(onSave null).
- **실연동 체크포인트**: `author_id`/`author_role`로 본인·상대 펜 색 구분(이미 에디터에 구현). 자동저장(이탈 시 await 저장 — 최근 수정 완료). 정규화 좌표/벡터 JSON 스키마 버전 필드 유지.

## 4-5. ★ 스캔 이미지 첨삭 — 워크플로우 합류
- **위치**: 질문방 상세 → 스캔/첨삭(카메라 또는 갤러리).
- **기획서 기준**: 스캔=배경(편집불가) + 펜=주석(벡터). **이미지 기준 정규화 좌표(0~1)** 로 기기·확대 무관 정합(좌표 매퍼 수정 완료). 저장 = 원본 이미지 + 주석 JSON + 미리보기 PNG. 작성자 색.
- **데이터(신설)**: 현 스키마에 스캔주석 테이블 없음 → **신설 또는 `question_attachments` 확장**(Part 5).
- **앱 구현**: `ScanAnnotationRepository.fetch/save`. 에디터 `onSave` 연결. 원본/미리보기는 Storage, 주석은 JSON 컬럼.
- **현재 상태**: 에디터 ✅(갤러리) / 카메라 스캔 ⛔(실기기 전용 임시 비활성) / 저장 연결 ⛔.
- **실연동 체크포인트**: 좌표 정합 실기기 검증(확대/회전/세로·가로). 원본은 변경 불가 레이어로 보존, 주석만 갱신.

## 4-6. 캐시 지갑·충전
- **웹 흐름**: 지갑(`/wallet`) → 충전(`/wallet/charge`, 성공/실패) → 내역(`/wallet/ledger`).
- **데이터**: `cash_wallets`, `cash_ledger`, `cash_topup_packages`. 쓰기 `record_cash_topup`(결제검증 후 반영). 토스페이먼츠(`lib/toss`).
- **앱 구현**: 지갑/충전/내역 화면. `CashRepository.fetchWallet()/fetchLedger()/topup(package)` → `rpc('record_cash_topup')`. 결제는 토스 결제창/웹뷰 위임(앱에서 카드정보 직접 수집 금지).
- **현재 상태**: 요금제 결제 UI ✅ / 지갑·내역·실결제 ⛔.
- **실연동 체크포인트**: 1캐시=1원(`balance_cents÷100`) 표기. 충전은 RPC로만. 결제 보안(토스 위임).

## 4-7. 맞춤의뢰 (작성→지원→선정→진행방→납품→정산→분쟁)
- **웹 흐름(4단계 + 진행방)**: 작성 → 정보확인 → 멘토 지원 대기 → 멘토 선택 → 진행방(작업·납품·수정·검수) → 완료/정산. 분쟁 발생 시 분할.
- **데이터**: `custom_request_posts`(+attachments) → `custom_request_applications`(+attachments) → `custom_request_orders` → `custom_order_messages`/`deliverables`/`revisions`/`settlement_items` + `order_events`. 쓰기 RPC: `record_custom_order_escrow_hold`(대금보관) → `accept_custom_order_deliverable_atomic`(납품수락+정산) → `..._payout`/`..._refund`/`record_custom_order_dispute_split`. 탐색 `list_open_custom_request_posts_for_mentor_browse`. 수수료 20/80.
- **앱 구현**: 작성/지원대기/멘토선택/진행방/납품/검수 화면. `CustomRequestRepository`(post/apply/order/deliverable/revision) — 쓰기는 위 escrow RPC. 첨부 Storage(RLS 경로 검증 함수들).
- **현재 상태**: 🟡 전부 스텁.
- **실연동 체크포인트**: 에스크로 전 과정 RPC로(대금 흐름은 절대 직접 UPDATE 금지). "선택 전 연락처 비공개" 규칙 화면 반영. 분쟁/환불 동선.

## 4-8. 커뮤니티·숏폼
- **웹 흐름**: 게시판(`community/board`) 글/댓글/반응, 숏폼(`community/shortform`) 영상.
- **데이터**: `community_posts`, `community_comments`, `post_reactions`, `community_hashtags`, `shortform_posts`. RPC: `increment_community_post_view`/`increment_shortform_post_view`, `community_sync_hashtags`, count refresh 함수들. 이미지/영상 Storage 버킷.
- **앱 구현**: 커뮤니티 홈(탭: 게시판/숏폼), 작성, 상세. `CommunityRepository`(posts/comments/reactions), `ShortformRepository`. 조회수는 RPC.
- **현재 상태**: 🟡 스텁.
- **실연동 체크포인트**: 좋아요/댓글 카운트는 서버 함수로 동기화. 신고/가이드(`legal/community-guidelines`) 연결.

## 4-9. 리뷰·즐겨찾기
- **데이터**: `reviews`(자격 `check_review_eligibility`, 연속/응답시간 지표 RPC), `favorites`.
- **앱 구현**: 멘토 상세의 후기 목록·작성, 즐겨찾기 토글. `ReviewRepository`/`FavoriteRepository`.
- **현재 상태**: ⛔(멘토 상세 자체가 스텁).
- **실연동 체크포인트**: 후기 작성은 자격 RPC 통과 시에만 노출.

## 4-10. 알림
- **데이터**: `notifications`(다중 후보 컬럼: type/kind/category, read 상태). 
- **앱 구현**: 알림 센터 + 헤더 배지 + FCM 푸시. `NotificationRepository.fetch()/markRead()`. 종류별 딥링크(해당 방/노트로 이동).
- **현재 상태**: ⛔ 화면 없음.
- **실연동 체크포인트**: 목업의 "새 답변 도착/연결노트 업데이트" 메시지를 알림 타입으로. 읽음 처리.

## 4-11. 마이페이지·구독관리
- **데이터**: `subscriptions`(내 구독), `users`(프로필), 지원(`disputes`/`refunds`/`content_reports`).
- **앱 구현**: 프로필 카드 + 메뉴(내 구독/캐시 내역/알림 설정/고객지원/약관/로그아웃). `SubscriptionRepository.mySubscriptions()/cancel()`.
- **현재 상태**: 🟡 스텁.

## 4-12. 멘토 정산·출금
- **데이터**: `mentor_payout_account`, `custom_order_settlement_items`, payout queries. 수수료(구독 30/70·의뢰 20/80) 반영.
- **앱 구현**: 정산(출금가능액·내역)·출금신청. `PayoutRepository`. 계좌정보 직접 입력 대신 검증 흐름(`payout-guide`).
- **현재 상태**: 🟡 스텁.

## 4-13. 고객지원 (분쟁·환불·신고)
- **데이터**: `disputes`(당사자 RLS), `refunds`(관리자 승인 RPC), `content_reports`.
- **앱 구현**: 분쟁 접수/조회, 환불 요청, 신고. `SupportRepository`.
- **현재 상태**: ⛔.

## 4-14. 관리자 (앱 제외)
관리자 콘솔(`(admin)/*`)은 **웹 전용**. 앱은 학생·멘토만 다루며 관리자 기능은 구현하지 않음(명시).

---

# Part 5. 차별화 기능 DB 합류 설계 (기획서 기준, 스키마 신설)

현 스키마에 없는 필기·스캔을 실연동 가능하게 만드는 **추가 명세**입니다. (실제 마이그레이션은 웹/DB 담당과 합의 후 적용)

## 5-1. 연결노트 필기 — `connection_notes` 확장

현재: `id, mentor_student_room_id, body, author_id, author_role, created_at, updated_at`

추가 제안:
```sql
alter table public.connection_notes
  add column if not exists title text,
  add column if not exists category text,             -- 전체/멘토에게요청/멘토가요청/메모
  add column if not exists ink_data jsonb,             -- 벡터 스트로크 JSON(원본)
  add column if not exists ink_thumbnail_path text,    -- 썸네일 PNG (Storage 경로)
  add column if not exists has_ink boolean default false,
  add column if not exists ink_schema_version int default 1;
```
- 벡터 JSON은 용량이 크면 `ink_data` 대신 Storage 버킷(`connection-note-ink`) 경로만 저장.
- 버킷 신설(둘 다 `public=false`): `connection-note-ink`, `connection-note-thumbnails`.
  (앱 `SupabaseConfig`에 이미 상수로 선언돼 있음 → DB에 실제 생성 필요)
- RLS: 방 당사자만 read/write(기존 방 RLS 패턴 재사용).

## 5-2. 스캔 이미지 첨삭 — 신설 테이블

질문 메시지/방에 첨삭을 붙이는 형태:
```sql
create table if not exists public.scan_annotations (
  id uuid primary key default gen_random_uuid(),
  mentor_student_room_id uuid not null references public.mentor_student_rooms(id) on delete cascade,
  question_message_id uuid references public.question_messages(id) on delete set null, -- 어느 질문에 대한 첨삭인지(선택)
  author_id uuid references public.users(id) on delete set null,
  author_role text,                          -- 작성자 색 구분
  scan_image_path text not null,             -- 원본 스캔 이미지(Storage, 편집불가)
  annotation_json jsonb not null,            -- 정규화(0~1) 주석 벡터
  preview_path text,                         -- 평탄화 미리보기 PNG(Storage)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```
- 버킷: 원본/미리보기는 비공개 버킷(예: `custom-request-post-attachments` 재사용 또는 `scan-annotations` 신설). RLS는 방 당사자.
- 핵심: `annotation_json`은 **이미지 기준 0~1 정규화 좌표**(앱 좌표 매퍼와 일치). 기기·해상도 무관 복원.

## 5-3. 데이터 계약(앱↔DB) 매핑

| 앱 페이로드 | DB 컬럼 |
|---|---|
| `NoteSavePayload.sketchJson` | `connection_notes.ink_data` 또는 버킷 |
| `NoteSavePayload.thumbnailPng` | `connection-note-thumbnails` 버킷 → `ink_thumbnail_path` |
| `NoteSavePayload.title/textBody/category/hasInk` | 동명 컬럼 |
| `ScanAnnotationPayload.annotationJson` | `scan_annotations.annotation_json` |
| `ScanAnnotationPayload.flattenedPng` | 버킷 → `preview_path` |
| 작성자 역할 | `author_role` (펜 색 자동) |

---

# Part 6. 현재 앱 Supabase-Ready 감사 (엔지니어 체크리스트)

"실DB 붙였을 때 그대로 도는가"를 화면 단위로 점검한 결과입니다.

| 영역 | 더미데이터 위치 | 실연동 준비도 | 조치 |
|---|---|---|---|
| 질문방 목록/상세 | `student_screens.dart`/`mentor_screens.dart` 내 하드코딩 | ❌ 낮음 | RoomsRepository로 분리, 비동기화 |
| 연결노트 저장 | 에디터 `onSave=null` (라우터) | ⚠️ 계약만 꽂으면 됨 | Repository.saveNote 연결 + 스키마 신설 |
| 스캔 첨삭 저장 | 에디터 `onSave=null` | ⚠️ 계약만 꽂으면 됨 | Repository.save 연결 + 테이블 신설 |
| 요금제/캐시 | `CashScreen` UI만, 결제 ⛔ | ❌ | CashRepository + `record_cash_topup` RPC |
| 멘토/커뮤니티/맞춤의뢰/마이/대시보드/정산 | 스텁(빈 화면) | — | 화면+Repository 동시 신규 |
| 세션/인증 | `DemoSession`(전역) | ⚠️ | AuthRepository로 교체(라우터는 호환) |
| Supabase 클라이언트 | `supabase_client.dart` 배관 OK, 키 미주입 | ✅ 구조 OK | env 주입 시 자동 동작 |

**핵심 부채 2가지**:
1. **동기 더미 → 비동기 실DB 전환 비용.** 지금 화면이 동기 리스트를 즉시 렌더하므로, 실DB(Future) 도입 시 로딩/에러 처리를 새로 넣어야 함. → 처음부터 `AsyncValue` 기반으로 재작성 권장.
2. **데이터 출처가 화면에 결합됨.** Repository 계층이 없어 화면이 더미를 직접 앎. → Part 3 구조로 디커플링.

---

# Part 7. 실연동 전환 로드맵 (더미 → 실DB)

순서대로 가면 "시각적 구현"이 "실DB 구동"으로 매끄럽게 전환됩니다.

1. **데이터 계층 골격 구축** — `data/models`, `data/repositories`(인터페이스), `providers`. 더미 구현(`fake/`)으로 현재 동작 유지하며 화면을 Repository 기반으로 리팩터.
2. **env 주입 + 인증** — `--dart-define-from-file`로 키 주입, `AuthRepository`로 `DemoSession` 교체.
3. **도메인별 vertical slice 전환**(읽기→쓰기 순):
   - ① 질문방·스레드(핵심 루프) → ② 차별화 기능 저장(스키마 신설 + onSave 연결) → ③ 캐시·구독 결제(RPC) → ④ 맞춤의뢰(에스크로 RPC) → ⑤ 커뮤니티 → ⑥ 알림.
4. **차별화 기능 스키마 신설**(Part 5) — connection_notes 컬럼·버킷, scan_annotations 테이블.
5. **실기기 QA** — 좌표 정합, 자동저장, RLS 접근, 결제 위임, 푸시.
6. **더미 제거** — `fake/` 구현 삭제, `repository_providers`가 항상 `supabase/`를 반환하도록 고정.

각 단계는 **웹의 해당 `xxxQueries`/`xxxActions`와 RPC를 그대로 모델로** 삼으면 됩니다. 화면을 채울 때 이 문서의 Part 4 해당 절 + `REBUILD_PLAN_v1.md`(화면 UI/UX) + `EXPO_FEATURE_REFERENCE.md`(Expo 매핑)를 함께 보세요.

---

*이 문서는 웹 실제 스키마(43 테이블)·서버 RPC·데이터 접근 계층을 분석해, "화면만 보이는" 구현과 "실DB로 도는" 구현의 간극을 메우는 설계도입니다. 다음 단계로 Part 3의 데이터 계층 골격(모델 + Repository + Provider)을 실제 코드로 깔고, Part 7의 순서대로 한 도메인씩 실연동하면 됩니다.*
