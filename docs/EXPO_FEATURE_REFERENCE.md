# Expo → 웹 → Flutter 기능 매핑 (레퍼런스)

**Task 1 산출물.** 기존 Expo 앱(`ssambership-app-v3-full`)의 화면을 기능별로 분해하고,
웹(Next.js, 디자인/기능 기준점)과 새 Flutter 화면을 한눈에 대응시킵니다.

빈 화면(스텁)을 채울 때 사용법:
1. 아래 표에서 만들 화면의 **웹 경로**와 **Expo 화면**을 찾는다.
2. 웹 코드에서 그 페이지의 **레이아웃·필드·동작**을 확인(디자인 기준점).
3. Expo 화면에서 **유저플로우(어디서 어디로 가는지)** 를 참고.
4. AI에게 "이 웹 페이지 기준으로, 이미 만든 ○○ 화면 톤에 맞춰 Flutter로" 라고 지시.

> 상태 표기: ✅ 완성 · 🚧 스텁(뼈대만) · ⏳ 미착수(라우트 추가 필요)
> 경로는 Expo `src/screens/...`, 웹 `app/...`, Flutter `lib/features/...` 기준.

---

## A. 인증 / 진입

| 기능 | Expo 화면 | 웹 경로 | Flutter | 상태 |
|---|---|---|---|---|
| 스플래시/진입 | `auth/AppLaunchScreen`, `Splash` | `app/page.tsx` | `auth/screens/launch_screen.dart` | ✅(데모: 역할선택) |
| 역할 선택 | `auth/RoleSelectScreen` | 회원가입 플로우 | 진입 화면에 통합 | ✅ |
| 로그인 | `auth/LoginScreen` | `app/(auth)/login` | `auth/` (데모 세션) | 🚧 |
| 회원가입(이메일/프로필) | `auth/SignupEmailScreen`, `SignupProfileScreen` | `app/(auth)/signup/*` | 미생성 | ⏳ |

> 데모 단계는 로그인 대신 역할만 골라 흐름을 봅니다. 실제 인증은 Supabase
> `onAuthStateChange`로 `DemoSession`을 교체(→ ARCHITECTURE 5절).

---

## B. 질문방 (핵심 흐름) — ✅ 구현됨

| 기능 | Expo 화면 | 웹 경로 | Flutter | 상태 |
|---|---|---|---|---|
| 학생 홈/방 목록 | `StudentHomeScreen`, `student/RoomListScreen` | `app/(student)/rooms` | `student/.../StudentRoomListScreen` | ✅ |
| 학생 방 상세 | `student/RoomDetailScreen` | `app/(student)/rooms/[id]` | `student/.../StudentRoomDetailScreen` | ✅ |
| 질문 스레드 상세 | `student/ThreadDetailScreen` | `.../threads/[id]` | 방 상세에서 진입(스레드 타일) | 🚧 상세 화면 분리 예정 |
| 새 질문 작성 | `student/NewThreadScreen` | `.../new` | ⏳ | ⏳ |
| 멘토 홈/방 목록 | `MentorHomeScreen`, `mentor/RoomListScreen` | `app/(mentor)/rooms` | `mentor/.../MentorRoomListScreen` | ✅ |
| 멘토 방 상세 | `mentor/RoomDetailScreen` | `app/(mentor)/rooms/[id]` | `mentor/.../MentorRoomDetailScreen` | ✅ |
| 멘토 스레드 상세 | `mentor/ThreadDetailScreen` | `.../threads/[id]` | 방 상세에서 진입 | 🚧 |

관련 서비스(웹/Expo): `roomService`, `threadService`. 테이블:
`mentor_student_rooms` → `question_threads` → `question_messages`.

---

## C. 연결노트 (★ 리뉴얼 — 필기) — ✅ 구현됨

| 기능 | Expo 화면 | 기준 문서 | Flutter | 상태 |
|---|---|---|---|---|
| 연결노트(학생) | `student/ConnectionNoteScreen` | **연결노트 필기 기획서** | `connection_note/.../ConnectionNoteEditorScreen` | ✅ |
| 연결노트(멘토) | `mentor/ConnectionNoteScreen` | 〃 | 같은 에디터(authorRole=mentor) | ✅ |

Expo는 순수 텍스트(`student_note`/`mentor_note`)였으나, 리뉴얼로 **텍스트+펜 필기
하이브리드**로 확장. 방 단위·공개형·카테고리·RLS는 유지. 엔진은 `features/handwriting/`
공유. (자세히 → ARCHITECTURE 7절) 관련 서비스: `noteService`.

---

## D. 스캔 이미지 첨삭 (★ 리뉴얼) — ✅ 구현됨

| 기능 | (Expo) | 기준 문서 | Flutter | 상태 |
|---|---|---|---|---|
| 스캔/첨삭 진입 | (신규) | **스캔이미지 주석 기획서** | `scan_annotation/.../ScanEntryScreen` | ✅ |
| 이미지 위 펜 첨삭 | (신규) | 〃 | `scan_annotation/.../ScanAnnotationEditorScreen` | ✅ |

신규 기능. 스캔 원본=배경(편집불가), 펜=주석 레이어(벡터). **좌표 0~1 정규화**로 정합
보장. 질문방 메시지/연결노트 첨부로 연결. 관련 서비스(연동 시): `uploadService`,
`downloadService`. 저장 버킷: `custom-request-post-attachments`(스캔 원본).

---

## E. 캐시 / 결제 / 정산

| 기능 | Expo 화면 | 웹 경로 | Flutter | 상태 |
|---|---|---|---|---|
| 캐시/요금제(학생) | `student/StudentCashScreen` | `app/(student)/cash` | `cash/.../CashScreen` | ✅ |
| 정산(멘토) | `mentor/SettlementScreen` | `app/(mentor)/settlement` | `mentor/.../MentorCashScreen` | 🚧 |
| 멘토 대시보드 | `mentor/DashboardScreen` | `app/(mentor)/dashboard` | `mentor/.../MentorDashboardScreen` | 🚧 |

요금제·수수료 잠금값 → ARCHITECTURE 6절. 관련 서비스: `cashService`, `settlementService`.
결제는 웹이 토스페이먼츠 사용 — 앱 결제 연동은 별도 작업(딥링크/웹뷰 등 결정 필요).

---

## F. 맞춤의뢰 (Commission)

Expo에 **학생 6개 + 멘토 5개** 하위 화면이 있는 가장 큰 흐름. 의뢰 생성 → 멘토 지원 →
선정 → 납품 → 검수 → 정산. 현재 Flutter는 진입 스텁만.

| 기능(예) | Expo (commission 하위) | 웹 경로(예) | Flutter | 상태 |
|---|---|---|---|---|
| 의뢰 목록/생성(학생) | `student/commission/*` (6) | `app/(student)/custom-requests/*` | `student/.../StudentCommissionScreen` | 🚧 |
| 의뢰 지원/납품(멘토) | `mentor/commission/*` (5) | `app/(mentor)/custom-orders/*` | `mentor/.../MentorCommissionScreen` | 🚧 |

> 채울 때: 단계가 많으므로 **상태 스테퍼(진행 단계 표시)** 패턴 권장(웹 목업의 "납품 대기"
> 스테퍼 참조). 서비스: `commissionService`. 버킷: `custom-order-deliverables`,
> `custom-request-post-attachments`.

---

## G. 커뮤니티 (게시판 + 숏폼)

| 기능 | Expo 화면 | 웹 경로 | Flutter | 상태 |
|---|---|---|---|---|
| 커뮤니티 홈 | `community/HomeScreen` | `app/(community)` | `student/.../CommunityHomeScreen` (공유) | 🚧 |
| 게시글 상세 | `community/PostDetailScreen` | `.../posts/[id]` | ⏳ | ⏳ |
| 글쓰기 | `community/PostNewScreen` | `.../posts/new` | ⏳ | ⏳ |
| 숏폼 피드 | `community/ShortsFeedScreen` | `.../shorts` | ⏳ | ⏳ |
| 숏폼 업로드 | `community/ShortUploadScreen` | `.../shorts/upload` | ⏳ | ⏳ |

게시판/숏폼은 **분리 테이블**(`community_posts` / `shortform_posts`). 서비스:
`communityService`. 버킷: `community-post-images`, `shortform-videos`/`-thumbnails`.

---

## H. 마이 / 프로필 / 보관함 / 알림

| 기능 | Expo 화면 | 웹 경로 | Flutter | 상태 |
|---|---|---|---|---|
| 마이페이지(학생) | (Home 내 + Archive) | `app/(student)/me` | `student/.../StudentMeScreen` | 🚧 |
| 보관함 | `student/StudentArchiveScreen` | `.../archive` | ⏳ | ⏳ |
| 멘토 프로필 | `mentor/ProfileScreen` | `app/(mentor)/profile` | `mentor/.../MentorProfileScreen` | 🚧 |
| 멘토 찾기/상세 | (student 내 mentor 하위 2) | `app/(student)/mentors`, `.../[id]` | `student/.../StudentMentorSearchScreen` | 🚧 |
| 알림 | `notifications/NotificationListScreen` | `.../notifications` | ⏳ | ⏳ |

서비스: `archiveService`, `mentorProfileService`, `mentorSearchService`,
`notificationService`.

---

## 부록: Expo 서비스(13) ↔ 데이터 영역

`archive · cash · commission · community · download · mentorProfile · mentorSearch ·
note · notification · room · settlement · thread · upload`

→ Flutter에서는 각 기능 폴더 안에 **repository/service**로 옮겨, supabase_flutter로
같은 테이블/버킷을 호출하면 됩니다. (지금은 UI 우선 — 데이터 연동은 Supabase 키 주입 후
화면별로 추가: README 5단계)

---

## 우선순위 제안 (스텁 채우는 순서)

1. **질문 스레드 상세 + 새 질문 작성** (B) — 핵심 흐름 완결
2. **커뮤니티 홈/글쓰기** (G) — 사용 빈도 높음
3. **마이페이지/멘토 프로필** (H)
4. **맞춤의뢰 전체 흐름** (F) — 단계 많음, 마지막에 집중
5. **연결노트/스캔 저장본 Supabase 업로드 연결** (C·D) — 데이터 영속화
