import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_client.dart';

/// 질문방/개별질문 메시지의 **실시간 Broadcast** 채널 헬퍼.
///
/// 잠금 규칙: "질문방 메시지 실시간 Broadcast". DB 스키마(Postgres publication)를
/// 건드리지 않고 클라이언트만으로 동작하도록 **Broadcast** 방식을 쓴다.
///  - 같은 스레드를 연 두 사용자(학생·멘토)는 같은 채널명을 구독한다.
///  - 한쪽이 메시지를 보내면 [notifyNewMessage]로 같은 채널에 broadcast.
///  - 다른 쪽은 [subscribe]의 콜백으로 이를 수신해 메시지 목록을 새로고침한다.
///
/// 보낸 사람 자신은 기본 설정(self=false)이라 자기 broadcast를 되받지 않는다.
/// 보낸 직후 로컬에서 직접 새로고침하므로 중복 갱신이 없다.
///
/// 데모(fake) 모드에서는 Supabase가 placeholder라 채널을 열지 않는다.
/// 호출부에서 [SupabaseConfig.isConfigured]로 가드하거나, 본 헬퍼의
/// [subscribe]/[notifyNewMessage]가 비활성 상태에서 안전하게 무시되도록 한다.
class ThreadRealtime {
  ThreadRealtime(this.channelName);

  /// 스레드/질문 단위 채널명. 양쪽 클라이언트가 동일해야 한다.
  /// 예: `question-thread-<threadId>`, `individual-question-<questionId>`.
  final String channelName;

  static const String _event = 'new_message';

  RealtimeChannel? _channel;
  bool _active = false;

  /// 실시간 모드(실DB)에서만 채널을 연다. 새 메시지가 도착하면 [onMessage] 호출.
  /// 데모 모드면 아무것도 하지 않는다(안전).
  void subscribe(void Function() onMessage) {
    if (!SupabaseConfig.isConfigured || _active) return;
    final ch = supabase.channel(channelName);
    ch.onBroadcast(
      event: _event,
      callback: (_) => onMessage(),
    ).subscribe();
    _channel = ch;
    _active = true;
  }

  /// 내가 메시지를 보낸 뒤 호출 → 같은 채널의 상대에게 알림.
  /// 채널이 없으면(데모/미구독) 조용히 무시.
  Future<void> notifyNewMessage() async {
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch.sendBroadcastMessage(
          event: _event, payload: <String, dynamic>{});
    } catch (_) {
      // 실시간 전송 실패는 치명적이지 않다(상대는 새로고침으로 볼 수 있음).
    }
  }

  /// 화면 dispose 시 반드시 호출 — 채널 누수 방지.
  Future<void> dispose() async {
    final ch = _channel;
    _channel = null;
    _active = false;
    if (ch != null) {
      try {
        await supabase.removeChannel(ch);
      } catch (_) {}
    }
  }
}
