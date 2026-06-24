# 쌤버십 스토어 앱(플러터) — 전체 설계 문서 (마스터)

작성일: 2026-06-24 · 대상: 쌤버십 플러터 앱(App Store / Play Store 제출용) · 백엔드: 웹과 공유하는 Supabase

> 이 문서는 "이미 ~80% 만들어진 플러터 앱을 **스토어에 올릴 수 있는 완성품**으로 마감"하는
> 작업의 **전체 그림**을 한 곳에 정리한 마스터 설계서다. 세부 잔여 결함의 구현 설계는
> 별도 문서 [`REALDATA_GAPS_DESIGN.md`](./REALDATA_GAPS_DESIGN.md)에 있고, 본 문서는 그 상위에서
> 목표·구조·진행상황·로드맵·승인 게이트를 묶는다.

---

## 0. 한눈에 보기 (Executive Summary)

- **목표**: 투자용 2트랙 중 **스토어 트랙**을 플러터로 완성한다. (웹은 PWA로 유지)
- **전략(B안)**: 단순 웹뷰 래퍼가 아니라 **네이티브 플러터 앱**으로 제출 → Apple 4.2(껍데기 앱) 반려 회피.
- **현 위치**: 화면·구조는 대부분 완성. **"화면은 떠도 실제 DB와 연결돼 작동하나"** 를 점검하는 단계.
- **이번에 끝낸 것**: 실로그인 연결(1단계), 맞춤의뢰 테이블명 교정(1순위), 개별질문 답변·컬럼 교정(2순위). 모두 CI 통과.
- **남은 것**: 돈·스키마가 걸린 4가지(개별질문 지급·환불 / 스캔첨삭 저장 / 출금·정산금액 / 질문방 실시간)와 토스 결제(보류 중), 그리고 스토어 등록 사전 준비(대표 실물 작업).
- **승인 원칙**: 돈·삭제·배포·공개·권한 변경은 **대표 승인 후** 진행(전사 규칙).

---

## 1. 프로젝트 배경과 목표

### 1-1. 왜 플러터 앱인가 (투자 2트랙)
- **웹(`ssambership_web`)**: Next.js + Supabase + 토스. PWA로 "앱처럼" 쓰는 트랙. 배포는 Vercel.
- **앱(`ssambership_flutter`)**: 같은 Supabase 백엔드를 쓰는 **네이티브 스토어 앱** 트랙. Android·iOS.
- 두 트랙은 **백엔드(테이블·RPC·정산·원장)를 공유**한다 → 한쪽에서 테이블/컬럼명을 잘못 쓰면 즉시 깨진다.
- 스토어 심사(특히 Apple App Store 4.2)는 "웹을 그대로 감싼 껍데기 앱"을 반려한다.
  → 그래서 **네이티브 화면·기능을 가진 플러터 앱**으로 간다(=B안).

### 1-2. 완료의 정의 (Definition of Done)
"스토어 제출 가능"이 되려면 아래가 모두 충족돼야 한다.
1. 로그인·구독·질문방·맞춤의뢰·캐시·정산 등 **핵심 흐름이 실제 DB와 연결돼 동작**한다(데모 데이터가 아니라 진짜).
2. 잠금 규칙(질문방 3단·원장 append-only·수수료·실시간 등)을 어기지 않는다.
3. 돈이 오가는 경로(결제·정산·환불·출금)가 **정확하고 안전**하다.
4. 스토어 등록 자산(아이콘·스크린샷·개인정보처리방침 URL·개발자 계정)이 준비된다.

---

## 2. 기술 구조 (Architecture)

### 2-1. 데이터 접근 — 레포지토리 토글
- 모든 데이터는 **레포지토리 인터페이스**를 통해 접근한다.
- `repository_providers.dart`가 `SupabaseConfig.isConfigured`이면 `SupabaseXxxRepository`(실DB), 아니면 `FakeXxxRepository`(데모)를 돌려준다.
- 스위치는 빌드 시 `--dart-define=SUPABASE_URL/ANON_KEY` 주입 여부로 결정.
- **함의**: 데모에서는 멀쩡해 보여도, 실DB 모드에서 테이블/RPC/컬럼명이 틀리면 그때 깨진다. → "실데이터 점검"이 핵심.

### 2-2. 세션·라우팅
- 전역 `demoSession`(`DemoSession extends ChangeNotifier`)이 **로그인 상태의 단일 진실원**.
  - go_router의 `refreshListenable: demoSession`로 연결 → 세션이 바뀌면 화면 라우팅이 자동 갱신.
  - `applyUser(AppUser)` = 실제 로그인 사용자 주입, `signInAs(role)` = 데모 로그인.
- `supabase_flutter ^2.x`는 세션을 자동 저장하고, `bindSupabaseAuthToSession()`이
  저장된 Supabase 세션 → `demoSession`으로 다리를 놓는다(`onAuthStateChange` 구독).
- 공개 경로: `/signup`, `/` 등 비로그인 진입 허용(멘토 찾기·멘토 상세 일부도 공개).

### 2-3. 백엔드 권한 모델 (중요)
- 민감한 로직(지급·환불 등)은 `security definer` RPC로 작성되고 **`service_role`(서버)에게만** 실행 권한을 준다.
  - `authenticated`/`anon`에서는 **직접 호출 불가** → 앱이 그대로 부르면 "권한 거부".
  - 웹은 **서버 액션에서 본인 확인 후** 관리자 권한으로 호출한다.
  - 앱(플러터)은 서버가 없으므로, 이런 경로는 **별도 설계(새 RPC 또는 엣지 함수)** 가 필요. (→ 3-1)

### 2-4. 검증 환경 (verify-don't-trust)
- 두 코드베이스 모두 **로컬에 빌드 SDK/패키지가 없다**. 검증은 **원격 CI가 유일**:
  - 웹: Vercel CI. 앱: GitHub Actions CI.
- CI는 **컴파일·정적분석 오류만** 잡는다. **런타임의 테이블/RPC/컬럼 불일치는 못 잡는다.**
  → 그래서 웹의 SQL 마이그레이션(`ssambership_web/supabase/sql/*.sql`, 약 98개)을 **진실의 원천**으로 삼아
    플러터의 `.from()`/`.rpc()` 호출명을 일일이 대조했다.
- 라이브 DB 직접 조회는 이번엔 불가(Supabase MCP에 접근 가능한 프로젝트가 안 잡힘) → SQL 파일 기준으로 점검.

---

## 3. 진행 상황 — 이미 끝낸 것 (검증 완료)

### 3-1. 실로그인 연결 (Step 1) — 커밋 b7b68c5
- `main.dart`: 실DB 설정이면 `bindSupabaseAuthToSession(supabase)` 호출로 저장 세션을 앱 세션에 연결.
- `app_router.dart`: `/signup` 라우트 추가(회원가입 화면 진입).
- `launch_screen.dart`: 로그인 화면에 "처음이신가요? 회원가입" 버튼 추가.
- 결과: 실제 Supabase 계정으로 로그인/가입 → 앱이 그 사용자로 동작. **CI 통과.**

### 3-2. 맞춤의뢰 테이블명 교정 (1순위) — 커밋 e24b5fb
- 플러터가 쓰던 `custom_orders` → 실제 테이블 **`custom_request_orders`** 로 전부 교체(11곳).
- 대상 테이블에 필요한 컬럼(id·post_id·student_id·mentor_id·status·created_at·amount) 존재 확인 후 교체.
- 효과: 맞춤의뢰 **주문·납품·수락·환불·분쟁** 흐름 전체 복구. **CI 통과.**
- 잔여 메모: 정산 레포가 금액을 `amount_cash`로 읽는데 실제 컬럼은 `amount` → 금액 0 문제(→ 3-3에서 다룸).

### 3-3. 개별질문 답변·컬럼 교정 (2순위) — 커밋 a16037b
- `answer()`를 **2단계**로 재작성: ① `individual_question_messages`에 답변 insert ② 질문 상태 `answered`로 갱신.
  (전용 answer RPC가 DB에 없어 직접 insert/update로 처리 — 웹과 동일한 방식.)
- `fetchMine()`의 `asker_id` → 실제 컬럼 **`student_id`** 로 교정(내 질문 목록 복구).
- 모델 `IndividualQuestion.fromMap`: 가격을 **`price_cents`** 기준으로 읽도록 교정(구버전 키 폴백 유지) → 가격 0 문제 해결.
- 잔여 메모: 지급/환불(`confirmAndRelease`/`cancel`)은 service_role 전용 RPC라 그대로 두면 권한 거부 → 3-1로 분리. **CI 통과.**

---

## 4. 남은 일 — 핵심 4가지 (상세 설계는 별도 문서)

> 아래 4가지의 문제·영향·구현 설계(테이블 DDL 포함)·리스크·검증 담당은
> **[`REALDATA_GAPS_DESIGN.md`](./REALDATA_GAPS_DESIGN.md)** 에 상세히 있다. 여기서는 요약만.

| # | 항목 | 성격 | 무엇이 필요한가 | 승인 |
|---|---|---|---|---|
| 3-1 | **개별질문 지급·환불** | 돈 직결 | 인증 사용자용 검증 래퍼 RPC 신설(권장) 또는 엣지 함수 | **승인 필수** |
| 3-2 | **스캔첨삭 저장** | 신규 테이블/버킷 | `scan_annotations` 테이블+RLS+전용 비공개 버킷 | **승인 필요(개인정보)** |
| 3-3 | **출금 + 정산 금액** | 돈 직결 | `withdrawals` 테이블 신설 + 금액 단위 확정/매핑 교정 | **승인 필수** |
| 3-4 | **질문방 실시간** | 돈 무관·독립 | 실시간 채널 방식 확정 + 구독/해제·invalidate | 보고 후 진행 |

**권장 순서**: 3-4(독립·돈무관) → 3-2(신규 테이블) → 3-1(돈) → 3-3(돈).
단, 개별질문 유료 흐름 복구가 급하면 대표 판단으로 3-1을 먼저 올릴 수 있다.

---

## 5. 보류·예정 (이번 범위 밖)

### 5-1. 토스 결제 (대표 지시로 보류)
- 캐시 충전·구독 결제의 실제 토스 연동은 **현재 보류**. 기능 점검을 먼저 끝내기로 함.
- 재개 시: 결제 위젯/웹훅 검증은 **돈 직결 + 외부 연동**이라 별도 설계·승인 필요.

### 5-2. 웹 PWA (다른 트랙, 미커밋 상태)
- `ssambership_web`에 PWA 1단계 산출물(manifest·아이콘·layout.tsx·계획서)이 **아직 커밋 대기**.
- 본 플러터 작업과 독립. 커밋 방식(A/B/C) 결정은 대표 보고 후.

### 5-3. 스토어 등록 사전 준비 (대표 실물 작업 필요)
- Apple Developer 계정, Google Play Console 계정.
- 빌드용 Mac/Xcode 환경(iOS 빌드·서명).
- 앱 아이콘·스크린샷·개인정보처리방침 URL·앱 설명.
- 이 항목들은 코드가 아니라 **대표가 실제로 발급/준비**해야 진행 가능.

---

## 6. 로드맵 (제안)

| 단계 | 내용 | 승인 | 산출물 |
|---|---|---|---|
| ✅ S1 | 실로그인 연결 | 완료 | b7b68c5 |
| ✅ S2 | 맞춤의뢰·개별질문 실데이터 교정(1·2순위) | 완료 | e24b5fb, a16037b |
| ⬜ S3 | 3-4 질문방 실시간 | 보고 후 | 실시간 구독 |
| ⬜ S4 | 3-2 스캔첨삭 저장(테이블·버킷·RLS) | 승인 | 마이그레이션+상수 교체 |
| ⬜ S5 | 3-1 개별질문 지급·환불(검증 RPC) | 승인 | 마이그레이션+RPC 교체 |
| ⬜ S6 | 3-3 출금·정산 금액 | 승인 | 마이그레이션+매핑 교정 |
| ⬜ S7 | 토스 결제 재개 | 승인 | 결제 연동 |
| ⬜ S8 | 스토어 자산·계정 준비 + 빌드 서명 + 제출 | 대표 실물 | 스토어 제출 |

---

## 7. 승인 게이트 & 협업 분담

### 7-1. 승인 게이트 (전사 규칙)
- **돈·삭제·배포·공개·권한 변경**은 자동 실행 금지 → **대표 승인 후 포그라운드 실행**.
- DB 스키마 변경(테이블/RPC/RLS/버킷)은 화면·정산·법무에 연쇄 영향 → 적용 전 승인.
- 잠금 규칙 변경 제안은 반드시 대표 승인.

### 7-2. 팀 분담 (예정)
- **백엔드팀(backend-lead)**: 모든 마이그레이션(테이블·RPC·RLS·버킷). 돈 항목은 finance-lead 협업.
- **보안팀(security-lead)**: 3-1 권한, 3-2 스토리지, 3-4 채널 모의해킹.
- **QA팀(qa-lead)**: 원장·정산·RLS·회귀 검증.
- **재무팀(finance-lead)**: 정산 금액 단위·수수료(구독30/70·맞춤20/80) 확정.
- **프론트(플러터)**: 백엔드 산출물 확정 후 RPC/버킷/상수 1:1 연결 + 실시간 구독.

---

## 8. 잠금 규칙 체크리스트 (이 앱이 반드시 지킬 것)

- [ ] 질문방 3단 구조: `mentor_student_room → question_threads → question_messages`. 연결노트는 room 단위.
- [ ] 캐시 원장 **append-only**(환불은 반대 부호 +row). 잔액은 snapshot, 진실은 원장.
- [ ] 캐시결제와 맞춤의뢰는 **분리**.
- [ ] 수수료 **구독 30/70 · 맞춤의뢰 20/80**. 요금제 Limited/Standard/Premium, cap 1.0/2.5/4.5.
- [ ] 리뷰는 동일 멘토 **2회 연속 결제 후**.
- [ ] 질문방 메시지 **실시간 Broadcast**(→ 3-4).
- [ ] 대필 금지(소재 정리·문장 피드백·구조 제안 범위), 외부 연락처 마스킹, 미성년자 동의, 검증 증빙 최소 열람.

---

## 9. 근거 (확인 위치)
- 지급/환불 RPC(서버 전용·소유자검증 없음): `ssambership_web/supabase/sql/070_individual_question_schema_escrow.sql`
- 맞춤의뢰 주문 테이블·금액 컬럼: `ssambership_web/supabase/sql/003_p0_custom_request_draft.sql` (`amount numeric`)
- 연결노트 RLS 본보기(room 스코프): `ssambership_web/supabase/sql/002_p0_subscriptions_questions_draft.sql`
- 개별질문 스키마(student_id·price_cents·answered_at): `sql/070_individual_question_schema_escrow.sql`
- 플러터 레포지토리(점검 대상): `ssambership_flutter/lib/data/repositories/supabase/*.dart`
- 잔여 결함 상세 설계: `ssambership_flutter/docs/REALDATA_GAPS_DESIGN.md`
