import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/supabase/supabase_client.dart';
import 'features/auth/auth_session_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 한국어 숫자/날짜 포맷 초기화 (intl).
  await initializeDateFormatting('ko_KR', null);

  // Supabase 초기화 — 키가 없으면 placeholder 로 부팅만 보장(데모 가능).
  // 실제 데이터 연동: --dart-define=SUPABASE_URL/ANON_KEY 주입 후 사용.
  try {
    await initSupabase();
  } catch (_) {
    // 키 미설정 환경에서도 UI 데모는 동작하도록 무시.
  }

  // 실데이터 모드: 저장된 Supabase 세션 ↔ 라우터 진실원천(demoSession) 동기화.
  // "앱을 껐다 켜도 로그인 유지"(세션 영속화)를 보장한다.
  if (SupabaseConfig.isConfigured) {
    try {
      bindSupabaseAuthToSession(supabase);
    } catch (_) {
      // 초기화 실패 시에도 데모 흐름은 계속 동작하도록 무시.
    }
  }

  runApp(const ProviderScope(child: SsambershipApp()));
}
