import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/user.dart';
import 'providers/session.dart';

/// Supabase 세션 ↔ 라우터 진실원천(`demoSession`) 동기화.
///
/// supabase_flutter는 로그인 세션을 안전저장소에 자동 보관한다. 하지만 라우터는
/// 전역 [demoSession]을 읽으므로, 앱 시작/토큰 갱신/로그아웃 시 그 세션을
/// [demoSession]에 반영해 줘야 "앱을 껐다 켜도 로그인이 유지"된다(세션 영속화).

/// 현재 Supabase 세션의 사용자를 [AppUser]로 로드한다.
///
/// 우선 `users` 테이블에서 실제 프로필을 읽고, (가입 직후 트리거 지연 등으로)
/// 행이 아직 없으면 auth 메타데이터(app_role/full_name 등)로 폴백한다.
Future<AppUser?> loadAppUserFromSession(SupabaseClient db) async {
  final authUser = db.auth.currentSession?.user;
  if (authUser == null) return null;

  try {
    final row = await db
        .from('users')
        .select('id, role, full_name, nickname, email, grade_level, avatar_url')
        .eq('id', authUser.id)
        .maybeSingle();
    if (row != null) {
      return AppUser.fromMap(Map<String, dynamic>.from(row));
    }
  } catch (_) {
    // 네트워크/권한 문제 시 메타데이터 폴백으로 진행.
  }

  final meta = authUser.userMetadata ?? const <String, dynamic>{};
  return AppUser(
    id: authUser.id,
    role: userRoleFromString(meta['app_role'] as String?),
    fullName: (meta['full_name'] as String?) ?? '',
    nickname: meta['nickname'] as String?,
    email: authUser.email,
    gradeLevel: meta['grade_level'] as String?,
  );
}

/// 앱 시작 시 1회 호출. 인증 상태 변화를 구독해 [demoSession]을 동기화한다.
void bindSupabaseAuthToSession(SupabaseClient db) {
  db.auth.onAuthStateChange.listen((state) async {
    switch (state.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        final user = await loadAppUserFromSession(db);
        if (user != null) demoSession.applyUser(user);
        break;
      case AuthChangeEvent.signedOut:
        demoSession.signOut();
        break;
      default:
        break;
    }
  });
}
