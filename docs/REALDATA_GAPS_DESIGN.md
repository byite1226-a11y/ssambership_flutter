# 실데이터 모드 잔여 기능 — 설계 문서 (3순위 + 실시간)

작성일: 2026-06-24 · 대상: 쌤버십 플러터 스토어 앱 · 기준 백엔드: 공유 Supabase(웹과 동일)

> 이 문서는 "화면은 떠도 실제로 작동하나" 점검에서 나온 **남은 결함**을, 대표 승인을 받아
> 하나씩 처리하기 위한 설계서다. 1·2순위(맞춤의뢰 테이블명·개별질문 답변/컬럼)는 이미
> 수정·검증(CI 통과) 완료. 여기서는 **백엔드 작업이 필요하거나 돈이 직접 걸린** 항목만 다룬다.

---

## 0. 점검 요약 (현재 상태)

| 기능 | 상태 | 비고 |
|---|---|---|
| 질문방·연결노트·커뮤니티·멘토찾기·구독·캐시잔액·알림·신고·개별질문 등록/수령 | ✅ 정상 | 테이블·RPC 일치 확인 |
| 맞춤의뢰 주문·정산 테이블명 | ✅ 수정완료 | `custom_orders`→`custom_request_orders` |
| 개별질문 답변·내질문목록·가격 | ✅ 수정완료 | 답변 2단계 + `student_id`/`price_cents` |
| **개별질문 지급·환불** | ❌ 남음 (돈) | 서버 전용 RPC — 본 문서 3-1 |
| **스캔 첨삭 저장** | ❌ 남음 | 테이블·버킷 신설 — 본 문서 3-2 |
| **멘토 출금 + 정산 금액** | ❌ 남음 (돈) | 테이블 신설·금액 매핑 — 본 문서 3-3 |
| **질문방 실시간** | ⚠️ 미구현 | 잠금 규칙 충족 — 본 문서 3-4 |

공통 원칙(전사 규칙 준수):
- **돈·삭제·배포·권한 변경은 대표 승인 후** 진행한다. 본 문서의 3-1·3-3은 돈 직결.
- 캐시 원장은 **append-only**(환불은 반대 부호 +row), 잔액은 snapshot·진실의 원천은 원장.
- 정산 수수료는 **구독 30/70 · 맞춤의뢰 20/80** 고정.
- DB 스키마 변경은 화면·정산·법무에 연쇄 영향 → 백엔드팀이 마이그레이션으로 작업, 적용 전 승인.

---

## 3-1. 개별질문 지급·환불 (돈 직결) ⭐ 최우선

### 문제
플러터 `confirmAndRelease()`/`cancel()`가 부르는 RPC가 두 가지 이유로 실패한다.
1. **이름 불일치**: `release_individual_question` → 실제 `release_individual_question_payout`,
   `refund_individual_question` → 실제 `refund_individual_question_hold`.
2. **권한 차단(핵심)**: 두 RPC는 `security definer`이고 **`service_role`(서버)에게만** 실행 권한이
   부여돼 있다. 함수 본문에 `auth.uid()` 소유자 검증이 **없다** — 그래서 누구나 부르면 위험해
   서버 전용으로 잠가둔 것. 웹은 **서버 액션에서 "로그인 사용자=질문 작성자"를 확인한 뒤**
   관리자 권한으로 이 RPC를 호출한다. 따라서 앱이 이름만 고쳐도 **권한 거부**로 실패한다.

### 영향
- 학생이 "답변 확인·정산하기"를 눌러도 멘토에게 **지급 불가**.
- 학생이 "취소하고 환불"을 눌러도 **환불 불가**.
- 둘 다 **돈이 오가는 핵심 경로**라, 미해결 시 개별질문 유료 흐름이 마비.

### 설계안 — 두 가지 (택1)

**안 A) 인증 사용자용 래퍼 RPC 신설 (권장)**
- 백엔드가 `release_individual_question_payout_as_student(p_question_id)` 같은 **새 함수**를 만든다.
  - `security definer`로 두되, 본문 첫머리에서 **소유자·상태 검증**을 직접 한다:
    - `auth.uid()`가 해당 질문의 `student_id`와 일치하는가(지급 확정은 작성자만).
    - 상태가 `answered`인가(지급), 또는 취소 가능 상태인가(환불).
  - 검증 통과 시 기존 `release_individual_question_payout`(또는 환불) 로직을 내부 호출/재사용.
  - `grant execute ... to authenticated`로 **앱에서 직접 호출 가능**하게.
- 환불도 동일하게 `refund_individual_question_hold_as_student(p_question_id)` 신설.
- 장점: 앱·웹이 같은 검증 규칙을 DB 한 곳에서 보장. 네트워크 1회. 구조 단순.
- 단점: 백엔드 마이그레이션 1건 + 검증 로직 작성 필요.

**안 B) Supabase 엣지 함수 경유**
- 엣지 함수가 사용자 JWT로 소유자·상태를 확인한 뒤, **service_role 키로** 기존 RPC를 호출.
- 장점: 웹 서버 액션과 동일한 패턴. 기존 RPC 그대로 사용.
- 단점: 엣지 함수 배포·시크릿 관리 추가. 콜드스타트 지연 가능.

> **추천: 안 A.** 돈 경로는 검증을 DB에 박아두는 편이 가장 안전하고, 엣지 함수 운영비/배포
> 부담이 없다. (단, 새 함수의 검증 로직은 **백엔드팀이 작성하고 QA-payment·security-payment가
> 검증**해야 한다.)

### 필요 산출물
- [ ] 마이그레이션: `release_*_as_student`, `refund_*_as_student` 함수 (소유자·상태 검증 포함)
- [ ] `grant execute to authenticated`, 기존 service_role 함수는 그대로 유지
- [ ] 플러터: `confirmAndRelease()`/`cancel()`가 새 RPC를 부르도록 1줄씩 교체
- [ ] 멱등성: 기존 함수가 `already_released`/`already_refunded` 가드를 이미 가짐 → 재호출 안전

### 돈·보안 리스크
- **상**: 권한 검증을 잘못 짜면 남의 질문을 정산/환불시킬 수 있음(권한 상승).
  → security-payment·security-authz **모의해킹 필수**, append-only·멱등 가드 재확인.

### 승인 / 검증
- 대표 승인 후 backend-lead 위임. 검증: qa-payment-ledger(원장 정합), qa-rls-money(권한 경계).

---

## 3-2. 스캔 첨삭 저장 (테이블·스토리지 신설)

### 문제
플러터 스캔 첨삭(리뉴얼 핵심 기능)이 저장하는 `scan_annotations` 테이블과 전용 버킷이
**공유 DB에 없다**(웹도 미사용). 또한 현재 버킷 상수가 스캔 전용이 아니라 맞춤의뢰 첨부
버킷(`custom-request-post-attachments`)을 재사용 중이라, 방(room) 단위 경로의 RLS가 안 맞을 수 있다.

### 영향
- 질문방 스캔 첨삭을 저장하면 **"테이블 없음"** 에러. 데모(fake) 외에는 동작 불가.

### 설계안
플러터가 이미 기대하는 컬럼에 맞춰 테이블을 **신설**한다(연결노트 테이블과 같은 room-스코프 패턴).

```
create table public.scan_annotations (
  id uuid primary key default gen_random_uuid(),
  mentor_student_room_id uuid not null references public.mentor_student_rooms(id) on delete cascade,
  author_id uuid not null references public.users(id) on delete cascade,
  author_role text not null check (author_role in ('student','mentor')),
  annotation_json text not null default '{}',
  scan_image_path text not null,      -- 원본 이미지(Storage 경로)
  preview_path text,                  -- 평탄화 미리보기(PNG)
  has_annotations boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```
- **RLS**: 해당 room의 당사자(학생·멘토)만 select/insert/update. (연결노트 RLS를 본보기로.)
- **Storage**: 스캔 전용 비공개 버킷 신설 권장 — 예 `scan-annotations`.
  - 경로 규칙 `{room_id}/{stamp}-original.jpg|preview.png`.
  - 버킷 RLS도 **room 당사자만** 접근. (현재 재사용 중인 맞춤의뢰 버킷은 정책이 달라 부적합)
  - 플러터 상수 `bucketScanOriginals`를 새 버킷명으로 교체.
- 원본 불변성: 기획상 원본은 1회 업로드·주석만 갱신이 이상적. 1차는 best-effort 허용, 추후 강화.

### 필요 산출물
- [ ] 마이그레이션: `scan_annotations` 테이블 + RLS
- [ ] 버킷 `scan-annotations` 생성 + Storage RLS
- [ ] 플러터: `bucketScanOriginals` 상수만 새 버킷명으로 교체(코드 로직은 그대로)

### 리스크
- **중(개인정보/저작권)**: 스캔 이미지에 학생 필체·개인정보 가능 → 비공개 버킷·당사자 RLS 필수.
- 돈과는 무관.

### 승인 / 검증
- 대표 승인 후 backend-lead(스키마/RLS/Storage) 위임. 검증: qa-rls-room, security-storage.

---

## 3-3. 멘토 출금 + 정산 금액 매핑 (돈 직결)

### 문제
1. **출금 테이블 없음**: 플러터 정산 화면이 `withdrawals` 테이블을 읽고/쓰는데 DB에 없다.
2. **정산 금액 0원 표시**: 정산 레포가 주문 금액을 `amount_cash`로 읽는데, 실제
   `custom_request_orders`의 금액 컬럼은 `amount`(numeric)다 → **정산액이 0으로 계산**된다.

### 영향
- 멘토 정산/출금 화면이 **에러 또는 0원**으로 표시. 멘토 신뢰 직결.

### 설계안
- **출금 테이블 신설** (플러터 기대 컬럼 기준):
```
create table public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.users(id) on delete restrict,
  amount_cash int not null check (amount_cash > 0),
  status text not null default 'requested'
    check (status in ('requested','approved','paid','rejected','canceled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```
  - **RLS**: 멘토는 본인 출금만 select/insert(요청). 승인·지급 상태 변경은 관리자만.
  - 실제 송금 연동(은행/PG)은 별도 운영 절차 — 1차는 "요청 접수"까지만.
- **정산 금액 매핑 교정**: 정산 레포가 `amount`(원 단위) → `amount_cash` 폴백을 읽도록 보정.
  - ⚠️ **단위 확인 필수**: `custom_request_orders.amount`가 "원"인지 "캐시"인지, 에스크로 보관액과
    일치하는지 backend/finance가 확정한 뒤 매핑한다. 잘못 매핑하면 **정산액 오류**(돈 사고).
  - 더 안전한 대안: 정산을 주문 테이블 추정이 아니라 **원장(cash_ledger)·정산 RPC** 기준으로
    뽑도록 재설계(웹의 정산 산출 방식과 정렬). 정확하지만 작업량 큼.

### 필요 산출물
- [ ] 마이그레이션: `withdrawals` 테이블 + RLS
- [ ] 금액 단위 확정(finance-settlement) → 정산 레포 금액 매핑 보정
- [ ] (선택·권장) 정산 산출을 원장/RPC 기준으로 재설계

### 돈 리스크
- **상**: 금액 단위/정산 기준을 잘못 잡으면 멘토에게 과다·과소 지급. finance-settlement 확정 필수.

### 승인 / 검증
- 대표 승인 후 backend-lead + finance-lead 협업. 검증: qa-payment-settlement, data-ledger-audit-settlement.

---

## 3-4. 질문방 실시간 (잠금 규칙 충족) — 돈과 무관·독립적

### 문제
플러터 어디에도 Realtime 구독 코드가 없다. 잠금 규칙은 **"질문방 메시지 실시간 Broadcast"**인데,
지금은 새로고침해야 새 메시지가 보인다.

### 영향
- 채팅 경험 저하(상대 답변이 즉시 안 뜸). 기능은 동작하나 잠금 규칙 미충족.

### 설계안
- 대상: `question_messages`(질문방), `individual_question_messages`(개별질문), `notifications`(알림 배지).
- 방식: Supabase Realtime 구독으로 새 메시지 수신 → 해당 Riverpod provider invalidate(자동 새로고침).
  - 잠금 규칙이 "Broadcast"를 명시하므로, **백엔드의 실시간 채널 설계(Broadcast vs Postgres Changes)**를
    backend-realtime-broadcast와 정렬한 뒤 클라이언트를 맞춘다.
- 권한: 남의 방 메시지 도청 금지 → 채널 권한이 RLS/room 당사자와 일치해야 함(security-realtime 점검).

### 필요 산출물
- [ ] 백엔드: 실시간 채널 방식 확정(+ 필요 시 publication/Broadcast 설정)
- [ ] 플러터: 방 진입 시 구독 시작/이탈 시 해제, 수신 시 provider invalidate

### 리스크
- **중(보안)**: 채널 권한 경계. 돈과는 무관.

### 승인 / 검증
- 스키마 변경이 작으면(구독만) 대표 보고 후 진행 가능. 검증: security-realtime, qa-regression-room-community.

---

## 4. 권장 순서 & 승인 게이트

| 순서 | 항목 | 성격 | 선행 | 승인 |
|---|---|---|---|---|
| 1 | 3-4 질문방 실시간 | 독립·돈무관 | 백엔드 채널 방식 확정 | 보고 후 진행 |
| 2 | 3-2 스캔 첨삭 저장 | 신규 테이블/버킷 | RLS·버킷 설계 | **승인 필요(개인정보)** |
| 3 | 3-1 개별질문 지급·환불 | **돈 직결** | 검증 RPC 설계 | **승인 필수** |
| 4 | 3-3 출금·정산 금액 | **돈 직결** | 금액 단위 확정 | **승인 필수** |

> 돈과 무관하고 독립적인 **3-4(실시간)**부터, 그다음 신규 테이블 **3-2(스캔)**, 마지막에 돈 직결
> **3-1·3-3**을 충분히 검증하며 처리하는 순서를 권장한다. 단, 사용자 가치 기준(개별질문 유료
> 흐름 복구가 급하면 3-1 먼저)으로 대표가 우선순위를 바꿀 수 있다.

## 5. 작업 분담(예정)
- **백엔드팀(backend-lead)**: 모든 마이그레이션(테이블·RPC·RLS·버킷). 돈 항목은 finance-lead 협업.
- **보안팀(security-lead)**: 3-1 권한, 3-2 스토리지, 3-4 채널 모의해킹.
- **QA팀(qa-lead)**: 원장·정산·RLS·회귀 검증.
- **프론트(플러터)**: RPC/버킷/상수 교체 + 실시간 구독 — 백엔드 산출물 확정 후 1:1 연결.

---

### 부록 — 근거(코드/스키마 확인 위치)
- 지급/환불 RPC: `ssambership_web/supabase/sql/070_individual_question_schema_escrow.sql`
  (`security definer`, `grant execute ... to service_role`, 본문 소유자검증 없음)
- 주문 금액 컬럼: `sql/003_p0_custom_request_draft.sql` (`amount numeric`, `amount_cash` 없음)
- 연결노트(RLS 본보기): `sql/002_p0_subscriptions_questions_draft.sql`
- 스캔 기대 컬럼/버킷: `ssambership_flutter/lib/data/repositories/supabase/supabase_scan_annotations_repository.dart`,
  `lib/core/supabase/supabase_client.dart`(`bucketScanOriginals='custom-request-post-attachments'`)
- 출금 기대 컬럼: `lib/data/repositories/supabase/supabase_settlements_repository.dart`
