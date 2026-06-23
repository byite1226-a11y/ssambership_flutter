import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../providers/repository_providers.dart';

/// 회원가입 화면(실데이터 모드).
///
/// 웹의 회원가입과 동일한 메타데이터 계약(app_role/full_name/동의 등)으로
/// `supabase.auth.signUp`을 호출해, 공유 트리거가 `users` 행을 만들도록 한다.
/// 데모 모드(키 미주입)에서는 진입 자체를 막고 안내한다.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _fullName = TextEditingController();
  final _nickname = TextEditingController();
  // 학생
  final _gradeLevel = TextEditingController();
  final _birthDate = TextEditingController();
  // 멘토
  final _university = TextEditingController();
  final _department = TextEditingController();
  final _subjects = TextEditingController();
  final _highSchool = TextEditingController();
  final _intro = TextEditingController();

  UserRole _role = UserRole.student;
  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;
  bool _isMinor = false;
  bool _guardianConsent = false;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _email,
      _password,
      _passwordConfirm,
      _fullName,
      _nickname,
      _gradeLevel,
      _birthDate,
      _university,
      _department,
      _subjects,
      _highSchool,
      _intro,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return '올바른 이메일을 입력해 주세요.';
    }
    if (_password.text.length < 8) {
      return '비밀번호는 8자 이상으로 설정해 주세요.';
    }
    if (_password.text != _passwordConfirm.text) {
      return '비밀번호 확인이 일치하지 않아요.';
    }
    if (_fullName.text.trim().isEmpty) {
      return '이름을 입력해 주세요.';
    }
    if (_nickname.text.trim().isEmpty) {
      return '닉네임을 입력해 주세요.';
    }
    if (!_terms || !_privacy) {
      return '필수 약관(이용약관·개인정보)에 동의해 주세요.';
    }
    if (_role == UserRole.mentor) {
      if (_university.text.trim().isEmpty || _department.text.trim().isEmpty) {
        return '멘토는 대학교·학과를 입력해 주세요.';
      }
    }
    if (_isMinor && !_guardianConsent) {
      return '미성년자는 법정대리인(보호자) 동의가 필요해요.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final input = SignUpInput(
      email: _email.text.trim(),
      password: _password.text,
      role: _role,
      fullName: _fullName.text,
      nickname: _nickname.text,
      gradeLevel: _gradeLevel.text,
      birthDate: _birthDate.text,
      termsAgree: _terms,
      privacyAgree: _privacy,
      marketingAgree: _marketing,
      universityName: _university.text,
      departmentName: _department.text,
      teachingSubjectsCsv: _subjects.text,
      highSchoolName: _highSchool.text,
      introLine: _intro.text,
      isMinor: _isMinor,
      guardianConsent: _guardianConsent,
    );

    try {
      final result = await ref.read(authRepositoryProvider).signUp(input);
      if (!mounted) return;
      if (result.status == SignUpStatus.signedIn) {
        context.go(
            _role == UserRole.mentor ? '/mentor/rooms' : '/student/rooms');
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('가입 확인 메일을 보냈어요'),
            content: const Text('메일의 인증 링크를 누른 뒤 로그인해 주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        if (mounted) context.go('/');
      }
    } catch (e) {
      setState(() => _error =
          '회원가입에 실패했어요: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('회원가입')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '회원가입은 실데이터 모드에서만 가능합니다.\n(SUPABASE 키 주입 후 이용)',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    final isMentor = _role == UserRole.mentor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _roleSelector(),
                const SizedBox(height: 18),
                _field(_email, '이메일', keyboard: TextInputType.emailAddress),
                _field(_password, '비밀번호(8자 이상)', obscure: true),
                _field(_passwordConfirm, '비밀번호 확인', obscure: true),
                const Divider(height: 28),
                _field(_fullName, '이름'),
                _field(_nickname, '닉네임'),
                if (!isMentor) ...[
                  _field(_gradeLevel, '학년 (예: 고2)'),
                  _field(_birthDate, '생년월일 (YYYY-MM-DD, 선택)'),
                ] else ...[
                  _field(_university, '대학교'),
                  _field(_department, '학과'),
                  _field(_subjects, '담당 과목 (쉼표로 구분: 수학,영어)'),
                  _field(_highSchool, '출신 고등학교 (선택)'),
                  _field(_intro, '한 줄 소개 (선택)'),
                ],
                const Divider(height: 28),
                _check(
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v ?? false),
                  label: '[필수] 이용약관에 동의합니다.',
                ),
                _check(
                  value: _privacy,
                  onChanged: (v) => setState(() => _privacy = v ?? false),
                  label: '[필수] 개인정보 수집·이용에 동의합니다.',
                ),
                _check(
                  value: _marketing,
                  onChanged: (v) => setState(() => _marketing = v ?? false),
                  label: '[선택] 마케팅 정보 수신에 동의합니다.',
                ),
                _check(
                  value: _isMinor,
                  onChanged: (v) => setState(() => _isMinor = v ?? false),
                  label: '만 14세 미만 미성년자입니다.',
                ),
                if (_isMinor)
                  _check(
                    value: _guardianConsent,
                    onChanged: (v) =>
                        setState(() => _guardianConsent = v ?? false),
                    label: '[필수] 법정대리인(보호자) 동의를 받았습니다.',
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('가입하기',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : () => context.go('/'),
                  child: const Text('이미 계정이 있으신가요? 로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleSelector() {
    return Row(
      children: [
        Expanded(
          child: _roleChip(
            label: '학생',
            icon: Icons.school_outlined,
            selected: _role == UserRole.student,
            onTap: () => setState(() => _role = UserRole.student),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _roleChip(
            label: '멘토',
            icon: Icons.workspace_premium_outlined,
            selected: _role == UserRole.mentor,
            onTap: () => setState(() => _role = UserRole.mentor),
          ),
        ),
      ],
    );
  }

  Widget _roleChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _check({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(value: value, onChanged: onChanged),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13.5, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
