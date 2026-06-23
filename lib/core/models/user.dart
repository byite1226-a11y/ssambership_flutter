/// 도메인 핵심 모델 — CLAUDE.md "핵심 DB 테이블·컬럼" + Expo types/room.ts 기준.
library;

/// 사용자 역할.
enum UserRole { student, mentor, admin }

UserRole userRoleFromString(String? v) => switch (v) {
      'mentor' => UserRole.mentor,
      'admin' => UserRole.admin,
      _ => UserRole.student,
    };

/// 요금제 — 잠금값 (CLAUDE.md "요금제 표기").
/// 베이직(주4)/스탠다드(주9,추천)/프리미엄(FUP) · id: limited/standard/premium.
enum PlanType { limited, standard, premium }

class PlanInfo {
  const PlanInfo({
    required this.type,
    required this.label,
    required this.weeklyLabel,
    required this.priceCash, // 캐시/월 (1캐시=1원)
    required this.cap,
    this.recommended = false,
  });

  final PlanType type;
  final String label;
  final String weeklyLabel;
  final int priceCash;
  final double cap;
  final bool recommended;

  /// 잠금값: 가격 55,000 / 114,900 / 249,900 · cap 1.0 / 2.5 / 4.5.
  static const Map<PlanType, PlanInfo> all = {
    PlanType.limited: PlanInfo(
      type: PlanType.limited,
      label: 'Limited',
      weeklyLabel: '주 4개 질문',
      priceCash: 55000,
      cap: 1.0,
    ),
    PlanType.standard: PlanInfo(
      type: PlanType.standard,
      label: 'Standard',
      weeklyLabel: '주 9개 질문',
      priceCash: 114900,
      cap: 2.5,
      recommended: true,
    ),
    PlanType.premium: PlanInfo(
      type: PlanType.premium,
      label: 'Premium',
      weeklyLabel: '질문 무제한',
      priceCash: 249900,
      cap: 4.5,
    ),
  };
}

/// users 테이블.
class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.fullName,
    this.nickname,
    this.email,
    this.gradeLevel,
    this.avatarUrl,
  });

  final String id;
  final UserRole role;
  final String fullName;
  final String? nickname;
  final String? email;
  final String? gradeLevel;
  final String? avatarUrl;

  String get displayName => nickname?.isNotEmpty == true ? nickname! : fullName;

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        role: userRoleFromString(m['role'] as String?),
        fullName: (m['full_name'] as String?) ?? '',
        nickname: m['nickname'] as String?,
        email: m['email'] as String?,
        gradeLevel: m['grade_level'] as String?,
        avatarUrl: m['avatar_url'] as String?,
      );
}

/// mentor_profiles 테이블 (요약).
class MentorProfile {
  const MentorProfile({
    required this.userId,
    required this.displayName,
    this.universityName,
    this.departmentName,
    this.teachingSubjects = const [],
    this.verificationStatus = 'pending',
    this.avgRating = 0,
    this.reviewCount = 0,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? universityName;
  final String? departmentName;
  final List<String> teachingSubjects;
  final String verificationStatus;
  final double avgRating;
  final int reviewCount;
  final String? avatarUrl;

  factory MentorProfile.fromMap(Map<String, dynamic> m) => MentorProfile(
        userId: m['user_id'] as String,
        displayName: (m['display_name'] as String?) ??
            (m['full_name'] as String?) ??
            '멘토',
        universityName: m['university_name'] as String?,
        departmentName: m['department_name'] as String?,
        teachingSubjects:
            (m['teaching_subjects'] as List?)?.cast<String>() ?? const [],
        verificationStatus:
            (m['verification_status'] as String?) ?? 'pending',
        avgRating: (m['avg_rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (m['review_count'] as num?)?.toInt() ?? 0,
        avatarUrl: m['avatar_url'] as String?,
      );
}
