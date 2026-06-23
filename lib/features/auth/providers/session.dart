import 'package:flutter/foundation.dart';

import '../../../core/models/user.dart';

/// 데모용 세션 상태.
///
/// 현재 환경엔 라이브 Supabase 인증이 연결돼 있지 않으므로, 역할(학생/멘토)을
/// 직접 골라 화면 흐름을 확인할 수 있게 합니다. 실제 연동 시에는 이 클래스를
/// Supabase `onAuthStateChange` 구독으로 교체하면 라우터/리다이렉트 로직은
/// 그대로 재사용됩니다. (auth 흐름은 Expo RootNavigator의 authStatus/role 분기를 미러)
class DemoSession extends ChangeNotifier {
  UserRole? _role; // null = 미인증
  AppUser? _user;

  UserRole? get role => _role;
  AppUser? get user => _user;
  bool get isAuthenticated => _role != null;

  void signInAs(UserRole role) {
    _role = role;
    _user = AppUser(
      id: role == UserRole.mentor ? 'demo-mentor' : 'demo-student',
      role: role,
      fullName: role == UserRole.mentor ? '데모 멘토' : '데모 학생',
      nickname: role == UserRole.mentor ? '멘토쌤' : '학생',
    );
    notifyListeners();
  }

  /// 실 인증 사용자 적용(Supabase 세션 기준). 데모와 달리 실제 uid·이름을 보관해
  /// 작성자 id 등이 올바르게 들어가도록 한다. 같은 사용자면 불필요한 알림을 생략.
  void applyUser(AppUser user) {
    if (_user?.id == user.id && _role == user.role) return;
    _role = user.role;
    _user = user;
    notifyListeners();
  }

  void signOut() {
    _role = null;
    _user = null;
    notifyListeners();
  }
}

/// 전역 단일 인스턴스(간단화). 규모가 커지면 Riverpod Provider로 승격.
final demoSession = DemoSession();
