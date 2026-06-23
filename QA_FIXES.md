# QA 대응 내역 (2026-06-17 · Codex QA2 반영)

Codex `QA_RESULT.md`(2026-06-17) 지적 사항을 반영한 변경입니다.

## [Critical] `SupabaseMentorsRepository._uid` 누락 → 수정
- `lib/data/repositories/supabase/supabase_mentors_repository.dart`에
  `String? get _uid => _db.auth.currentUser?.id;` 추가.
- 전체 Supabase repository를 전수 점검: `_uid`를 사용하는 8개 파일 모두 정의 보유 확인.

## [High] 인증 간극(“키만 주입하면 실데이터”) → 실제 로그인 구현
- `AuthRepository.signInWithEmail({email, password})` 추가.
  - `SupabaseAuthRepository`: `auth.signInWithPassword` 후 `users.role`로 역할 동기화
    하여 `demoSession`에 반영(라우터 redirect 재사용).
  - `DemoAuthRepository`: 데모 모드에선 미지원(역할 선택 사용) 명시.
- `launch_screen.dart`: `SupabaseConfig.isConfigured`면 **이메일/비밀번호 로그인 폼**,
  아니면 **역할 선택(데모)** 으로 분기. 로그인 성공 시 역할 영역으로 이동.
- `README.md`: “실데이터 모드는 로그인 필요(미로그인 시 RLS로 빈 목록/권한 오류)”로 정정.

## [High] 저장 실패 후에도 화면 pop → 실패 시 닫지 않도록 수정
- `connection_note_editor_screen.dart`, `scan_annotation_editor_screen.dart`:
  `_save()`가 `Future<bool>`(성공 여부) 반환. `_handleClose()`는 **성공 시에만 pop**,
  실패 시 닫지 않고 **스낵바 + 재시도** 액션 제공.

## [Medium] 문서 스캔 미연동 → 실제 연동
- `scan_entry_screen.dart`: `_tryNativeScan()`이 `CunningDocumentScanner.getPictures()`
  를 호출(미지원/취소 시 `null` → 갤러리 폴백). import 추가.

## [Medium] Supabase 스키마/RPC 확정 전제 → 문서로 명시(설계 의도)
- 해당 주석/README의 “운영 정책에 맞춰 확정” 표기 유지. 적용 기준은
  `docs/WORKFLOW_DB_PLAN_v2.md` 참고. (실데이터 smoke test는 마이그레이션 적용 후)

## [Low] 테스트 부재 → 단위 테스트 추가
- `test/scan_coord_mapper_test.dart`: 좌표 정규화/복원(굵기·중앙 보존, 0가드).
- `test/fake_repository_test.dart`: 구독→캐시 차감→방 생성, 커뮤니티 글/좋아요 토글.

---

### 재QA 권장 순서(변경 후)
1. `flutter create .` → `flutter pub get`
2. `flutter analyze` (이제 `_uid` 미정의로 인한 실패 없음)
3. `flutter test` (단위 테스트 2개)
4. 더미 모드 `flutter run` 수동 QA
5. 실데이터 모드: 키 주입 + **이메일 로그인** 후 RLS 동작 확인
