import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/user.dart';
import '../../features/auth/providers/session.dart';

/// 인증 창구.
///
/// 현재 데모는 역할 선택(런치 화면)으로 로그인하고 [DemoSession]을 단일 소스로
/// 사용합니다. 실제 Supabase 연동 시 [SupabaseAuthRepository]가 `auth`와
/// `users` 테이블의 역할을 읽어 [DemoSession]을 채우도록 바꾸면, 라우터의
/// redirect/refreshListenable 로직은 그대로 재사용됩니다.
abstract class AuthRepository {
  bool get isSignedIn;
  UserRole? get role;

  /// 데모 로그인(역할 선택). 실연동 시 이메일/비번 또는 OAuth로 대체.
  void signInAs(UserRole role);

  /// 이메일/비밀번호 로그인(실DB 모드). 성공 시 역할까지 동기화.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

/// 더미 — 역할 선택 기반 데모 세션.
class DemoAuthRepository implements AuthRepository {
  @override
  bool get isSignedIn => demoSession.isAuthenticated;

  @override
  UserRole? get role => demoSession.role;

  @override
  void signInAs(UserRole role) => demoSession.signInAs(role);

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnsupportedError('데모 모드에서는 역할 선택으로 로그인하세요.');
  }

  @override
  Future<void> signOut() async => demoSession.signOut();
}

/// 실DB — Supabase Auth. (역할은 users/메타데이터에서 조회하도록 확장)
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._db);

  final SupabaseClient _db;

  @override
  bool get isSignedIn => _db.auth.currentUser != null;

  @override
  UserRole? get role => demoSession.role; // TODO: users.role 조회로 대체

  @override
  void signInAs(UserRole role) => demoSession.signInAs(role);

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res =
        await _db.auth.signInWithPassword(email: email, password: password);
    final uid = res.user?.id;
    // users.role 로 역할 동기화 → 라우터 redirect 재사용.
    UserRole r = UserRole.student;
    if (uid != null) {
      try {
        final row =
            await _db.from('users').select('role').eq('id', uid).maybeSingle();
        if ((row?['role'] as String?) == 'mentor') r = UserRole.mentor;
      } catch (_) {
        // role 조회 실패 시 기본 학생으로 둠(운영에서 메타데이터 매핑으로 보강).
      }
    }
    demoSession.signInAs(r);
  }

  @override
  Future<void> signOut() async {
    await _db.auth.signOut();
    demoSession.signOut();
  }
}
