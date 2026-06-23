# 웹 ↔ 앱(Flutter) 기능 1:1 대조 — 검증판

**작성일:** 2026-06-23
**대상:** 웹(`ssambership_web`, Next.js) ↔ 앱(`ssambership_flutter`)
**방법:** 코드 직접 감사 — 라우터·repository·화면 규모(줄 수)·grep 마커. 구조 단위로 검증했으며,
각 화면을 한 줄씩 정독한 것은 아니다(아래 "확신도" 표기 참고).
**주의:** 기존 `EXPO_FEATURE_REFERENCE.md`는 계획 시점(2026-05) 기준이라 **실제보다 뒤처진 stale 문서**다.
앱은 그 문서보다 훨씬 진척돼 있다(거의 모든 도메인에 실 Supabase repository 존재).

---

## 0. 핵심 결론

앱은 **데이터 계층(repository)·핵심 화면 대부분이 구현**돼 있다. 웹 대비 앱의 진짜 미구현은 **3대 축**으로 압축된다.

| 우선순위 | 미구현 축 | 현재 상태 | 작업 크기 |
|---|---|---|---|
| 1 | **실 인증(로그인/회원가입)** | 앱은 "역할 선택 데모 모드"(`DemoSession`). `signInWithEmail`은 구현돼 있으나 **회원가입 메서드·실 로그인/가입 화면이 없음** | 중 |
| 2 | **결제·구독(토스페이먼츠)** | 캐시 충전이 "데모 즉시 반영", 토스·`record_cash_topup` RPC 미연동. 구독 결제 미착수 | 대 |
| 3 | **관리자 콘솔** | 앱에 admin 화면·repository **전무**(웹은 풀세트) | 대(또는 앱 제외) |

> 데이터 연동 인프라는 완비: `--dart-define=SUPABASE_URL/ANON_KEY` 주입 시 fake→Supabase 자동 전환
> (`lib/providers/repository_providers.dart`, `lib/core/supabase/supabase_client.dart`).

---

## 1. 큰 구조 차이

- **앱 전용(웹에 없음):** 필기 연결노트(`scribble`+`perfect_freehand`), 스캔 이미지 펜 첨삭(좌표 0~1 정규화 벡터). 태블릿/스타일러스 기반.
- **웹 전용(앱에 없음):** 관리자 콘솔 전체(멘토승인·검수·분쟁·환불·정산·공지·신고·리뷰관리·감사로그), 토스 결제/구독, 법률/정책 페이지(`/legal/*`).
- **데이터 소스:** 양쪽 다 동일 Supabase(테이블·버킷 공유). 앱은 fake/supabase 토글 구조.

---

## 2. 도메인별 1:1 대조표

> 확신도: ✅검증 · ◐부분검증(추가 점검 권장) · ❓미검증
> 앱 상태: 구현=화면+repo 연동 / 데모=fake만 / 없음

| 도메인 | 웹 | 앱(Flutter) | 앱 미구현/갭 | 확신도 |
|---|---|---|---|---|
| 인증·로그인 | 로그인/회원가입/비번재설정 | **데모(역할선택)** | 실 로그인/회원가입/비번재설정 화면, `signUp` 메서드 | ✅ |
| 질문방 3단 | 구현 | 방목록·방상세·스레드 구현(repo 연동) | 학생 새 질문 작성 폼 | ◐ |
| 연결노트 | 텍스트 | **텍스트+펜 필기**(앱이 앞섬) | — (웹↔앱 데이터 호환 점검) | ✅ |
| 스캔 첨삭 | 없음 | **스캔+펜 주석**(앱 전용) | — | ✅ |
| 개별 질문 | 구현 | 구현(948줄, repo 연동) | 결제 연동부 | ◐ |
| 맞춤의뢰 | 풀플로우+관리자 | 구현(1489줄, repo 연동) | 분쟁 해결=관리자(웹) 의존 | ◐ |
| 캐시/충전 | 토스 연동 | **데모 충전** | 토스 결제·`record_cash_topup` RPC | ✅ |
| 구독 | 토스 구독 | 요금제 표시만 | 구독 결제 전체 | ✅ |
| 정산(멘토) | 구현 | repo 있음, 화면 부분 | 정산 화면 완성도 | ◐ |
| 커뮤니티 | 게시판+숏폼 | 구현(757줄, repo 연동) | 숏폼 영상재생·좋아요(웹도 미완) | ◐ |
| 리뷰 | 작성·자격·신고 | **작성 있음**(`addReview`→reviews insert) | 자격/신고 흐름 동등성 | ◐ |
| 알림 | 목록 | 구현(repo 연동) | 알림 설정 토글(웹도 미완) | ◐ |
| 마이/프로필 | 구현 | 화면 부분, repo 연동 | 완성도 | ❓ |
| 멘토 인증 | 구현 | 미검증 | 검증 증빙 제출 흐름 | ❓ |
| 관리자 콘솔 | 풀세트 | **전무** | 콘솔 전체(또는 앱 제외) | ✅ |
| 법률/정책 | `/legal/*` | 미검증 | 약관·정책 화면 | ❓ |

---

## 3. 권장 작업 순서 (앱을 웹 수준으로)

1. **실 인증** — 로그인/회원가입/비번재설정 화면 + `signUp` + 세션 영속화. (인프라 준비됨, 화면 중심)
2. **결제·구독(토스)** — 충전/구독 실연동. 앱 결제는 웹뷰/딥링크 방식 결정 필요(돈 직결 → 대표 승인).
3. **리뷰 자격/신고 동등화**, 커뮤니티 숏폼 재생/좋아요 등 마감.
4. **관리자**는 웹으로 운영 → 앱에서는 제외 검토(중복 투자 방지).
5. **◐/❓ 항목 정밀 2차 대조**(질문방 새글·멘토 인증·법률·마이페이지).

---

## 4. 근거 파일(추적용)

- 인증: `lib/data/repositories/auth_repository.dart`, `lib/features/auth/providers/session.dart`, `lib/features/auth/screens/launch_screen.dart`
- 데이터 토글: `lib/providers/repository_providers.dart`, `lib/core/supabase/supabase_client.dart`
- 결제: `lib/features/cash/screens/cash_screen.dart`, `lib/data/repositories/cash_repository.dart`
- 리뷰: `lib/data/repositories/supabase/supabase_mentors_repository.dart` (`addReview`)
- 웹 라우트: `app/(student|mentor|admin|public)/**/page.tsx`
