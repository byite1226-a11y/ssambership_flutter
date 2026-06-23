import 'package:flutter/material.dart';

/// 쌤버십 브랜드 컬러 — CLAUDE.md "브랜드 컬러 (변경 금지)" 잠금값.
///
/// 웹 본체가 디자인 기준점이므로, Expo 앱이 임의로 쓰던 indigo(#4F46E5) 대신
/// 웹의 잠금 토큰(#1A56DB 계열)을 단일 소스로 사용합니다.
class AppColors {
  AppColors._();

  // --- 잠금값 (CLAUDE.md) ---
  static const Color primary = Color(0xFF1A56DB);
  static const Color secondary = Color(0xFF3F83F8);
  static const Color accent = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color background = Color(0xFFF9FAFB);

  // --- 파생 중립색 (UI 구성용) ---
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF4F6FD);
  static const Color primarySoft = Color(0xFFEFF4FE); // primary 10% 배경
  static const Color primaryTint = Color(0xFFD7E3FB);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // --- 섹션/통계 톤 (디자인 시스템 PNG의 컬러 섹션 바) ---
  static const Color purple = Color(0xFF7C3AED);
  static const Color indigo = Color(0xFF4F46E5);

  // --- 역할/상태 ---
  static const Color studentAccent = accent; // 학생 = amber 계열
  static const Color mentorAccent = Color(0xFF0F766E); // 멘토 = teal 계열
  static const Color statusPending = accent;
  static const Color statusDone = success;
  static const Color statusClosed = textSecondary;

  // --- 필기 작성자 구분색 (연결노트 9-3 / 스캔주석 6) ---
  /// 멘토 첨삭색: 빨강 계열(가독성 높은 첨삭)
  static const Color inkMentor = Color(0xFFE11D48);

  /// 학생 표시색: 파랑 계열
  static const Color inkStudent = Color(0xFF1D4ED8);

  /// 기본 펜 색 프리셋 (6색) — 툴바 색상 프리셋
  static const List<Color> penPresets = <Color>[
    Color(0xFF111827), // 검정
    Color(0xFF1D4ED8), // 파랑
    Color(0xFFE11D48), // 빨강
    Color(0xFF059669), // 초록
    Color(0xFFF59E0B), // 노랑/주황
    Color(0xFF7C3AED), // 보라
  ];

  /// 형광펜 프리셋 (반투명) — P1
  static const List<Color> highlighterPresets = <Color>[
    Color(0x80FDE047), // 노랑
    Color(0x8086EFAC), // 연두
    Color(0x80FDA4AF), // 분홍
    Color(0x8093C5FD), // 하늘
  ];
}
