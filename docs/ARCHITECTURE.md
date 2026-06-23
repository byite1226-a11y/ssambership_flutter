# 아키텍처 (ARCHITECTURE)

쌤버십 Flutter 앱의 구조·디자인 규칙·데이터 모델을 정리합니다. 새 화면을 만들거나
AI 도구에게 작업을 시킬 때 **이 문서를 근거로** 지시하면 일관성이 유지됩니다.

> 기준점 원칙: **웹(Next.js)이 디자인/기능의 단일 진실 소스**입니다. Expo 앱은
> 유저플로우 참고용입니다. 연결노트 필기 / 스캔 첨삭만 **리뉴얼 기획서**가 우선합니다.

---

## 1. 기술 스택

| 영역 | 선택 | 이유 |
|---|---|---|
| 언어/프레임워크 | Flutter (Dart), Android 우선 | 단일 코드로 폰/태블릿 + 펜 입력 정밀 제어 |
| 상태관리 | flutter_riverpod | 가볍고 테스트 쉬움 |
| 라우팅 | go_router | 셸·딥링크·리다이렉트(역할 분기)에 적합 |
| 백엔드 | supabase_flutter | **웹과 동일한 Supabase** 재사용(인증/DB/Storage) |
| 필기 엔진 | perfect_freehand (코어) | 필압 반응 외곽선. (대안: scribble) |
| 스캔 주석 | 커스텀 레이어 + 정규화 좌표 | 이미지 위 정합 보장 (대안: flutter_painter_v2) |

---

## 2. 폴더 구조 (feature-first)

기능 단위로 폴더를 나눕니다. "공통"은 `core/`, "기능"은 `features/<이름>/`.

```
lib/
├─ main.dart                 # 앱 부팅(인텔/Supabase 초기화) → SsambershipApp
├─ app.dart                  # MaterialApp.router (테마 + 라우터 연결)
├─ core/
│  ├─ theme/
│  │  ├─ app_colors.dart     # ★ 브랜드 색(잠금값) + 필기 색
│  │  ├─ app_theme.dart      # Material3 테마(카드/버튼/칩 스타일)
│  │  └─ responsive.dart     # ★ 반응형: FormFactor, 브레이크포인트, 헬퍼
│  ├─ router/app_router.dart # ★ 전 화면 라우팅 + 역할 리다이렉트
│  ├─ models/                # user.dart(요금제 포함), note.dart(방/스레드/연결노트)
│  ├─ supabase/              # supabase_client.dart(키 주입·버킷 상수)
│  └─ widgets/               # feature_stub.dart(빈 화면 안내 위젯)
└─ features/
   ├─ handwriting/           # ★ 펜 필기 엔진 (연결노트·스캔이 공유)
   │  ├─ models/             # ink_stroke / ink_sketch (벡터 직렬화)
   │  ├─ input/              # handwriting_controller (도구·팜리젝션·undo)
   │  ├─ canvas/             # handwriting_painter (perfect_freehand 렌더)
   │  └─ widgets/            # canvas / toolbar / exporter(PNG)
   ├─ connection_note/       # ★ 연결노트 필기 에디터(텍스트+필기 하이브리드)
   ├─ scan_annotation/       # ★ 스캔 첨삭(배경 이미지 + 주석 + 좌표 정규화)
   ├─ auth/                  # 진입/역할 선택(데모 세션)
   ├─ shell/                 # 반응형 네비게이션 셸
   ├─ student/ · mentor/     # 역할별 화면(일부 스텁)
   ├─ community/ commission/ # 커뮤니티·맞춤의뢰(스텁)
   ├─ cash/                  # 요금제·결제
   └─ notifications/
```

**규칙**: 한 기능 안에서만 쓰는 위젯·모델은 그 기능 폴더 안에. 두 기능 이상이
공유하면 `core/`로 올립니다. (예: 필기 엔진은 연결노트·스캔이 공유하므로 별도 feature)

---

## 3. 디자인 토큰 (변경 금지 — 웹 CLAUDE.md 잠금값)

새 화면은 **항상 이 토큰만** 사용합니다. 임의 색/여백 금지.

### 색 (`AppColors`)
| 토큰 | 값 | 용도 |
|---|---|---|
| `primary` | `#1A56DB` | 주요 버튼·강조 |
| `secondary` | `#3F83F8` | 보조 강조 |
| `accent` | `#F59E0B` | 포인트(학생 계열) |
| `success` | `#10B981` | 완료·정상 |
| `danger` | `#EF4444` | 경고·삭제 |
| `background` | `#F9FAFB` | 화면 배경 |
| `surface` | `#FFFFFF` | 카드 배경 |
| `primarySoft` | `#EFF4FE` | 선택/연한 강조 배경 |
| `textPrimary/Secondary` | `#111827` / `#6B7280` | 본문/보조 텍스트 |

필기 작성자 구분색: 멘토 `inkMentor #E11D48`(빨강), 학생 `inkStudent #1D4ED8`(파랑).

### 모양·간격 (관례)
- 카드 모서리 반경 **16**, 작은 요소 **12~14**
- 화면 외곽 패딩 **20**, 요소 간격 **12~16**
- 넓은 화면(태블릿)에서는 본문 최대폭을 제한해 한 줄이 너무 길어지지 않게 함

> 새 화면을 만들 때 **본보기**: `StudentRoomListScreen`(목록 카드), `CashScreen`(선택 카드),
> 연결노트/스캔 에디터(상단바·툴바). "이 화면처럼 만들어줘"가 가장 안전합니다.

---

## 4. 반응형 / 태블릿 전략 (`responsive.dart`)

태블릿 사용 비중이 높을 것으로 보고, 처음부터 폼팩터를 구분합니다.

- `FormFactor { mobile, tablet, desktop }` — 화면 폭으로 자동 판별
  (tablet ≥ 600, desktop ≥ 1100)
- `context.useWideLayout` — 태블릿/데스크톱이면 true
- **셸**: 폰 = 하단 `NavigationBar`, 넓은 화면 = 측면 `NavigationRail` (세로 공간 절약)
- **필기 툴바**: 폰 = 하단 바, 태블릿 = 측면 레일(한 손/양손 대응)
- **에디터 레이아웃**: 넓은 화면에서 텍스트·캔버스를 더 여유 있게 배치

새 화면에서도 `context.useWideLayout` 로 분기하거나 `ResponsiveLayout`/`ContentContainer`
를 쓰면 폰/태블릿 모두 자연스럽게 보입니다.

---

## 5. 라우팅 (`app_router.dart`)

Expo `RootNavigator`의 인증/역할 분기를 미러링합니다.

```
/                         진입(역할 선택)  ← 미인증 기본
/demo/connection-note     연결노트 필기 미리보기(인증 불필요)
/demo/scan-annotation     스캔 첨삭 미리보기(인증 불필요)
/annotate                 스캔 → 주석 에디터(이미지 경로 전달)

학생 셸 (하단 탭 5)
  /student/mentors        멘토찾기            (스텁)
  /student/rooms          질문방 목록          ✅
    └ :roomId             질문방 상세          ✅
        ├ note            연결노트 필기 에디터  ✅
        └ scan            스캔 첨삭 진입        ✅
  /student/community      커뮤니티            (스텁)
  /student/commission     맞춤의뢰            (스텁)
  /student/me             마이페이지          (스텁)
  /student/cash           요금제·결제          ✅ (셸 위 전체화면)

멘토 셸 (하단 탭 5)
  /mentor/dashboard       대시보드            (스텁)
  /mentor/rooms           질문방 목록          ✅ → :roomId → note/scan ✅
  /mentor/community       커뮤니티            (공유)
  /mentor/commission      맞춤의뢰            (스텁)
  /mentor/cash            캐시·정산            (스텁)
```

- **리다이렉트**: 미인증이 앱 영역 접근 → `/`. 학생이 `/mentor/*`(혹은 반대) 접근 차단.
- **세션**: 지금은 `DemoSession`(역할만 선택). 실제 연동 시 Supabase
  `onAuthStateChange` 구독으로 **이 클래스만 교체**하면 라우터는 그대로 재사용.
- 질문방 상세·에디터는 셸 위에 **전체화면**으로 띄웁니다(`parentNavigatorKey = root`).

---

## 6. 데이터 모델 (웹 Supabase 재사용)

앱은 웹과 **같은 테이블**을 바라봅니다. 핵심만 요약(자세한 컬럼은 웹 코드/Supabase 콘솔 참조):

### 질문방 흐름
- `mentor_student_rooms` — 학생↔멘토 1:1 방 (요금제 `plan` 포함)
- `question_threads` — 방 안의 질문 스레드 (상태: open/answered/closed)
- `question_messages` — 스레드 안의 메시지(텍스트/첨부)

### 연결노트 (★ 리뉴얼)
- `connection_notes` — **방(room) 단위, 공개형**. RLS로 방 참여자만 접근.
- 카테고리: 멘토에게 요청 / 멘토가 요청 / 메모 (보기 필터엔 "전체")
- **리뉴얼 확장(앱)**: 기존 텍스트 본문 + **필기 데이터(벡터 JSON) + 썸네일 PNG** 참조.
  앱의 `ConnectionNote` 모델에 `hasInk / inkDataUrl / inkThumbnailUrl` 추가.

### 커뮤니티
- `community_posts` (게시판), `shortform_posts` (숏폼) — 분리 운영

### 캐시·정산
- 1 캐시 = 1 원. 잔액은 `balance_cents ÷ 100`.
- 수수료: **구독 30/70**, **맞춤의뢰 20/80** (플랫폼/멘토).
- 요금제(잠금값, `PlanInfo.all`):

| 플랜 | 가격(캐시/월) | 주간 질문 | cap | 비고 |
|---|---|---|---|---|
| limited | 55,000 | 주 4 | 1.0 | |
| standard | 114,900 | 주 9 | 2.5 | 추천 |
| premium | 249,900 | 무제한 | 4.5 | |

### Storage 버킷 (모두 비공개 `public=false`)
- `student-id-images`, `custom-order-deliverables`,
  `custom-request-post-attachments`(스캔 원본도 여기 재사용),
  `community-post-images`, `shortform-videos` / `shortform-thumbnails`
- 연결노트 필기용으로 `connection-note-ink` / `connection-note-thumbnails`
  버킷을 추가하는 것을 권장(아직 미생성 — 데이터 연동 시 생성).

---

## 7. 필기 엔진 설계 (★ 차별화 핵심)

연결노트와 스캔 첨삭이 **같은 엔진**을 공유합니다. 핵심 아이디어:

- **벡터 우선**: 획을 좌표·필압·색·굵기의 JSON으로 저장(원본). 썸네일/평탄화 PNG는 분리.
  → 다시 열어 편집 가능, 용량 작음. (`InkStroke` / `InkSketch`)
- **입력 분기(팜 리젝션)**: `PointerEvent.kind`로 펜/손가락 구분. 펜=쓰기, 손가락=확대·이동.
  태블릿 기본은 "펜만 쓰기"(`penOnlyMode`). (`HandwritingController.acceptsInput`)
- **렌더**: `perfect_freehand`의 `getStroke`로 필압 반응 외곽선을 만들어 채움.
  형광펜은 multiply 블렌드. (`HandwritingPainter`)
- **좌표 정합(스캔의 핵심)**: 캔버스는 박스 로컬 픽셀로 그리지만, **저장 직전 이미지 기준
  0~1로 정규화**(`ScanCoordMapper.normalize`), 다시 열 때 새 박스 크기로 복원
  (`denormalize`). → 기기/회전/줌이 달라도 첨삭 위치가 안 어긋남. (스캔 주석에서 가장
  흔한 버그를 원천 차단)

저장 흐름(데이터 연동 시): 필기 JSON + 썸네일 PNG → Storage 업로드 →
`connection_notes`(연결노트) 또는 `question_messages`(스캔 첨삭) 레코드에 참조 연결.
현재는 **저장 직전까지** 구현(에디터 `onSave` 콜백), 업로드 자리만 비워둠.

---

## 8. 새 기능 추가 체크리스트

1. 화면 파일을 알맞은 `features/<기능>/screens/` 에 만든다.
2. **색·간격은 `AppColors`/관례만** 사용. 본보기 화면을 따라 한다.
3. 폰/태블릿 분기는 `context.useWideLayout` 또는 반응형 위젯으로.
4. `app_router.dart` 에 라우트를 추가(필요하면 셸 탭 or 셸 위 전체화면).
5. 데이터가 필요하면 Supabase 테이블/버킷(위 6절)을 따른다.
6. 끝나면 `QA_PLAN.md` 의 해당 항목으로 점검.
