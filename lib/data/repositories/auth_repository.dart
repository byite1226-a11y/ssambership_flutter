import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/user.dart';
import '../../features/auth/auth_session_sync.dart';
import '../../features/auth/providers/session.dart';

/// 회원가입 결과 — 이메일 인증 설정에 따라 즉시 로그인 또는 인증 대기.
enum SignUpStatus { signedIn, needsEmailConfirmation }

class SignUpResult {
  const SignUpResult(this.status);
  final SignUpStatus status;
}

/// 회원가입 입력값. 웹 `buildSignupUserMetadata`와 동일한 메타데이터 키를 생성해,
/// 공유 Supabase 트리거 `handle_new_auth_user()`가 양쪽 클라이언트에서 똑같이
/// `users`(및 멘토면 `mentor_profiles`) 행을 만들도록 맞춘다.
class SignUpInput {
  const SignUpInput({
    required this.email,
    required this.password,
    required this.role,
    required this.fullName,
    required this.nickname,
    this.gradeLevel = '',
    this.studentStatus = '',
    this.birthDate = '',
    this.termsAgree = false,
    this.privacyAgree = false,
    this.marketingAgree = false,
    this.universityName = '',
    this.departmentName = '',
    this.teachingSubjectsCsv = '',
    this.highSchoolName = '',
    this.introLine = '',
    this.isMinor = false,
    this.guardianConsent = false,
  });

  final String email;
  final String password;
  final UserRole role;
  final String fullName;
  final String nickname;
  final String gradeLevel;
  final String studentStatus;
  final String birthDate;
  final bool termsAgree;
  final bool privacyAgree;
  final bool marketingAgree;
  final String universityName;
  final String departmentName;
  final String teachingSubjectsCsv;
  final String highSchoolName;
  final String introLine;
  final bool isMinor;
  final bool guardianConsent;

  Map<String, dynamic> toMetadata() => <String, dynamic>{
        'app_role': role == UserRole.mentor ? 'mentor' : 'student',
        'full_name': fullName.trim(),
        'nickname': nickname.trim(),
        'grade_level': gradeLevel.trim(),
        'student_status': studentStatus.trim(),
        'birth_date': birthDate.trim(),
        'terms_agreed': termsAgree ? 'true' : 'false',
        'privacy_agreed': privacyAgree ? 'true' : 'false',
        'marketing_agreed': marketingAgree ? 'true' : 'false',
        'university_name': universityName.trim(),
        'department_name': departmentName.trim(),
        'teaching_subjects_csv': teachingSubjectsCsv.trim(),
        'high_school_name': highSchoolName.trim(),
        'intro_line': introLine.trim(),
        'is_minor': isMinor ? 'true' : 'false',
        'guardian_consent': guardianConsent ? 'true' : 'false',
        'consent_version': '',
        'guardian_ref': '',
        'age_gate_checked_at': '',
        'guardian_verification_method': '',
      };
}

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

  /// 이메일/비밀번호 회원가입(실DB 모드). 성공 시 즉시 로그인 또는 인증 대기.
  Future<SignUpResult> signUp(SignUpInput input);

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
  Future<SignUpResult> signUp(SignUpInput input) async {
    throw UnsupportedError(
        '데모 모드에서는 회원가입을 사용할 수 없어요. 실데이터 모드(SUPABASE 키 주입)에서 가능합니다.');
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
    await _db.auth.signInWithPassword(email: email, password: password);
    // 실제 uid·이름까지 담은 사용자로 세션을 채운다(가짜 데모 id 주입 방지).
    // onAuthStateChange 브리지도 동일 처리하지만, 로그인 직후 즉시성을 위해 동기 적용.
    final user = await loadAppUserFromSession(_db);
    if (user != null) demoSession.applyUser(user);
  }

  @override
  Future<SignUpResult> signUp(SignUpInput input) async {
    final res = await _db.auth.signUp(
      email: input.email,
      password: input.password,
      data: input.toMetadata(),
    );
    // 이메일 인증이 꺼져 있으면 즉시 세션 발급 → 바로 로그인 상태로.
    if (res.session != null) {
      final user = await loadAppUserFromSession(_db);
      if (user != null) {
        demoSession.applyUser(user);
      } else {
        demoSession.applyUser(AppUser(
          id: res.user?.id ?? '',
          role: input.role,
          fullName: input.fullName.trim(),
          nickname: input.nickname.trim(),
          email: input.email.trim(),
        ));
      }
      return const SignUpResult(SignUpStatus.signedIn);
    }
    // 이메일 인증이 켜져 있으면 세션 없음 → 인증 후 로그인 안내.
    return const SignUpResult(SignUpStatus.needsEmailConfirmation);
  }

  @override
  Future<void> signOut() async {
    await _db.auth.signOut();
    demoSession.signOut();
  }
}
