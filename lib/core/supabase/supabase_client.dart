import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 설정 — 웹/Expo와 동일한 Supabase 프로젝트를 재사용합니다.
///
/// 🔐 보안: 실제 URL/anon 키는 코드에 하드코딩하지 않습니다.
///    앱 실행 시 아래처럼 주입하세요 (값은 웹 프로젝트 .env와 동일):
///
///    flutter run \
///      --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///      --dart-define=SUPABASE_ANON_KEY=eyJ....
///
///    (Expo의 EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY 와 같은 값)
class SupabaseConfig {
  SupabaseConfig._();

  static const String url =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Storage 버킷 — CLAUDE.md "Storage 버킷 (public = false 필수)".
  /// 필기 리뉴얼은 기존 분리 원칙(원본/썸네일 분리)을 그대로 따릅니다.
  static const String bucketConnectionNoteInk = 'connection-note-ink';
  static const String bucketConnectionNoteThumb = 'connection-note-thumbnails';
  static const String bucketScanOriginals = 'custom-request-post-attachments';
  static const String bucketCommunityImages = 'community-post-images';
}

/// 앱 전역에서 쓰는 Supabase 클라이언트 단축 접근자.
SupabaseClient get supabase => Supabase.instance.client;

/// main()에서 한 번 호출. 키가 없으면 더미로 초기화해 부팅이 깨지지 않게 합니다
/// (Expo 앱의 placeholder 클라이언트와 동일한 안전장치).
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.isConfigured
        ? SupabaseConfig.url
        : 'https://placeholder.invalid',
    anonKey: SupabaseConfig.isConfigured
        ? SupabaseConfig.anonKey
        : 'placeholder-anon-key',
    // 모바일 세션 지속: supabase_flutter가 기본으로 안전 저장소에 보관.
  );
}
