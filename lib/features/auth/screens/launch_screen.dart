import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/repository_providers.dart';

/// 앱 진입 화면 (Expo AppLaunchScreen 대응).
///
/// - 더미 모드(SUPABASE 키 미주입): 역할(학생/멘토)을 골라 전체 흐름을 데모.
/// - 실데이터 모드(키 주입): 이메일/비밀번호로 Supabase 로그인 → RLS 적용된 실데이터.
///   로그인 성공 시 users.role 로 역할이 동기화되어 라우터가 알맞은 영역으로 보냅니다.
class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});
  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goByRole() {
    final role = ref.read(authRepositoryProvider).role;
    context.go(role == UserRole.mentor ? '/mentor/rooms' : '/student/rooms');
  }

  void _demoRole(UserRole role) {
    ref.read(authRepositoryProvider).signInAs(role);
    context.go(role == UserRole.mentor ? '/mentor/rooms' : '/student/rooms');
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pw = _password.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: pw);
      if (mounted) _goByRole();
    } catch (e) {
      setState(() => _error = '로그인에 실패했어요: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseConfig.isConfigured;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: const Text('쌤',
                        style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ),
                  const SizedBox(height: 20),
                  const Text('쌤버십',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('구독형 Q&A 멘토링 — 질문하고, 첨삭받고, 성장하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFFD7E3FB), height: 1.5)),
                  const SizedBox(height: 36),

                  if (configured) ..._emailLogin() else ..._rolePick(),

                  const SizedBox(height: 28),
                  const Row(children: [
                    Expanded(child: Divider(color: Color(0x55FFFFFF))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('리뉴얼 핵심 기능 미리보기',
                          style: TextStyle(
                              color: Color(0xFFD7E3FB), fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Color(0x55FFFFFF))),
                  ]),
                  const SizedBox(height: 16),
                  _DemoLink(
                    title: '연결노트 필기',
                    subtitle: '펜 + 텍스트 하이브리드 노트',
                    icon: Icons.edit_note,
                    onTap: () => context.push('/demo/connection-note'),
                  ),
                  const SizedBox(height: 10),
                  _DemoLink(
                    title: '질문방 스캔 첨삭',
                    subtitle: '스캔 위에 펜으로 첨삭(정규화 좌표)',
                    icon: Icons.draw_outlined,
                    onTap: () => context.push('/demo/scan-annotation'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 더미 모드: 역할 선택
  List<Widget> _rolePick() => [
        _RoleButton(
          label: '학생으로 시작',
          icon: Icons.school_outlined,
          filled: true,
          onTap: () => _demoRole(UserRole.student),
        ),
        const SizedBox(height: 12),
        _RoleButton(
          label: '멘토로 시작',
          icon: Icons.workspace_premium_outlined,
          filled: false,
          onTap: () => _demoRole(UserRole.mentor),
        ),
        const SizedBox(height: 10),
        const Text('데모 모드 · 더미 데이터로 전체 흐름을 둘러볼 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFD7E3FB), fontSize: 11)),
      ];

  // 실데이터 모드: 이메일 로그인
  List<Widget> _emailLogin() => [
        _LoginField(
          controller: _email,
          hint: '이메일',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _LoginField(
          controller: _password,
          hint: '비밀번호',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFD7D7), fontSize: 12.5)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
            ),
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('로그인',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _loading ? null : () => context.push('/signup'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('처음이신가요? 회원가입',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        const Text('Supabase 실데이터 모드 · 계정으로 로그인해야 데이터가 보여요',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFD7E3FB), fontSize: 11)),
      ];
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: filled
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
    );
  }
}

class _DemoLink extends StatelessWidget {
  const _DemoLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFFD7E3FB), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
