# 쌤버십 (Ssambership) — Flutter 앱

구독형 질문 멘토링 + 교육형 커뮤니티 앱 (Android first, Flutter).
웹(Next.js)/Expo 버전과 **동일한 Supabase 백엔드**를 재사용하도록 설계됐습니다.

이 패키지는 **앱 소스 전체**입니다. 모든 화면이 **더미 데이터로 즉시 실행**되며,
Supabase 키를 주입하면 **실데이터 연동**으로 전환됩니다(화면 코드는 동일).

---

## 1. 앱으로 실행하기 (3단계)

> 이 zip에는 `lib/` 소스와 `pubspec.yaml`만 들어 있고, 플랫폼 폴더
> (`android/`, `ios/` 등)는 포함하지 않았습니다. 아래 1번 명령이 플랫폼 폴더를
> **자동 생성**합니다. (기존 `lib/`·`pubspec.yaml`은 건드리지 않습니다.)

```bash
# 0) 압축 풀기 → 폴더로 이동
cd ssambership_flutter

# 1) 플랫폼 폴더(android/ios/web) 생성 — 한 번만
flutter create .

# 2) 패키지 설치
flutter pub get

# 3) 실행 (더미 데이터로 바로 동작)
flutter run
```

Flutter SDK 3.27 이상 권장(`flutter --version`으로 확인). 설치가 안 되어 있으면
[flutter.dev/setup](https://docs.flutter.dev/get-started/install)을 참고하세요.

### Supabase 실데이터로 연동하려면

키 두 개를 주입해서 실행하면 됩니다(웹 `.env`와 동일한 값):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ....
```

키가 있으면 `SupabaseConfig.isConfigured == true`가 되어 모든 Repository가
자동으로 **Supabase 구현**으로 바뀌고, **런치 화면이 이메일/비밀번호 로그인 폼으로
전환**됩니다. 키가 없으면(더미 모드) 역할 선택만으로 전체 흐름을 데모합니다.

> ⚠️ **실데이터 모드는 로그인이 필요합니다.** Supabase RLS가 적용된 운영 DB에서는
> `auth.currentUser`가 있어야 데이터가 보입니다. 키만 주입하고 로그인하지 않으면
> 빈 목록/권한 오류가 날 수 있어요. 로그인 성공 시 `users.role`로 역할이
> 동기화되어 학생/멘토 영역으로 이동합니다. (구현: `auth_repository.dart`의
> `SupabaseAuthRepository.signInWithEmail`)

---

## 2. 코드 QA 안내 (Codex 등)

`flutter analyze`는 루트 `analysis_options.yaml`(flutter_lints 기반)을 따릅니다.

### 핵심 아키텍처 — 화면은 데이터 출처를 모른다
모든 도메인이 동일한 3겹 구조입니다. QA 시 이 패턴의 일관성을 보면 됩니다.

```
lib/data/repositories/<도메인>_repository.dart        # 추상 인터페이스
lib/data/repositories/fake/fake_<도메인>_repository.dart     # 더미(메모리, 지연 시뮬)
lib/data/repositories/supabase/supabase_<도메인>_repository.dart  # 실DB
lib/providers/repository_providers.dart               # isConfigured 로 fake/supabase 선택
```

- 화면(`lib/features/**`)은 **Provider만** 바라봅니다. Supabase/더미를 직접 import하지 않습니다.
- 더미는 `lib/data/repositories/fake/demo_store.dart`(싱글턴)를 공유해, 구독→캐시
  차감→방 생성, 에스크로, 즐겨찾기 등이 화면 간 **일관되게** 반영됩니다.
- 비동기는 모두 `AsyncValue`(로딩/에러+재시도/빈 상태) + 당겨 새로고침으로 처리.

### 의도된 TODO (QA에서 "미완성"이 아니라 "연동 지점"으로 봐주세요)
- `supabase_*_repository.dart`의 일부 컬럼/RPC/테이블 이름은 **운영 정책에 맞춰
  확정 필요**라는 주석이 달려 있습니다. 실제 웹 Supabase 스키마(43 테이블)를 기준으로
  작성했으나, 정산/출금/분쟁 등 일부는 관리자 RPC와 함께 최종 확정해야 합니다.
- 결제: 앱은 카드 정보를 **직접 수집하지 않습니다**. 충전·구독·에스크로는 RPC
  (`record_cash_topup`, `record_subscription_cash_debit`,
  `record_custom_order_escrow_*`)에 위임합니다.
- 인증: 더미 모드는 역할 선택(런치 화면), 실데이터 모드는 **이메일/비밀번호 로그인**
  (`SupabaseAuthRepository.signInWithEmail` → `auth.signInWithPassword` + `users.role`
  동기화). OAuth/회원가입 화면은 후속 확장 지점입니다.

### 알려진 환경 메모
- `Color.withValues(alpha:)`, `CardThemeData` 등 **Flutter 3.27+ API** 사용.
- 한글 안전을 위해 `String[0]` 대신 `substring(0,1)` 사용.

### 테스트
`test/`에 핵심 로직 단위 테스트가 있습니다. `flutter test`로 실행하세요.
- `scan_coord_mapper_test.dart` — 스캔 첨삭 좌표 정규화/복원(굵기·중앙 보존, 0가드).
- `fake_repository_test.dart` — 구독→캐시 차감→방 생성, 커뮤니티 글/좋아요 토글 상태 전이.

---

## 3. 프로젝트 구조

```
lib/
├─ main.dart                  # 진입점 (intl/Supabase 초기화 → ProviderScope)
├─ app.dart                   # MaterialApp.router + 테마
├─ core/
│  ├─ models/                 # 도메인 모델 (Room, Cash, CustomRequest, Community, Review ...)
│  ├─ router/app_router.dart  # go_router (학생/멘토 탭 + 풀스크린 라우트, redirect)
│  ├─ supabase/               # SupabaseConfig (env 주입) + 클라이언트
│  ├─ theme/                  # AppColors / 반응형
│  └─ widgets/                # 공용 위젯 (AsyncErrorView/EmptyView 등)
├─ data/repositories/         # 위 3겹 구조 (interface / fake / supabase)
├─ providers/                 # Riverpod Provider (repo 선택 + 화면용 Future/Family)
└─ features/                  # 화면 (auth, shell, qna, connection_note, scan_annotation,
                              #        cash, mentor, commission, community, notifications,
                              #        student, support, handwriting)
docs/                         # 설계/QA 문서 (ARCHITECTURE, WORKFLOW_DB_PLAN_v2 등)
```

### 구현된 워크플로우
질문방·스레드 · 연결노트(필기 복원) · 스캔 첨삭 · 캐시 지갑·충전 ·
멘토 탐색·구독 · 맞춤의뢰(게시→지원→에스크로→납품→정산→환불→분쟁) ·
커뮤니티·숏폼 · 알림 · 마이페이지·구독관리 · 리뷰·즐겨찾기 ·
멘토 정산·출금 · 고객지원(신고/문의) · 인증.

---

## 4. 더 자세한 안내
- **비개발자용 시작 가이드**: `README_시작가이드.md`
- **아키텍처 상세**: `docs/ARCHITECTURE.md`
- **워크플로우 ↔ DB 매핑**: `docs/WORKFLOW_DB_PLAN_v2.md`
- **QA 계획**: `docs/QA_PLAN.md`
