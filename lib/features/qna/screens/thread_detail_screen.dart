import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/note.dart';
import '../../../core/models/user.dart';
import '../../../core/realtime/thread_realtime.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/providers/session.dart';

/// 질문 스레드 상세 — 메시지를 채팅 형태로 보고 작성합니다.
/// 작성자(나/상대)에 따라 말풍선 정렬·라벨이 달라집니다. 1:1 방이므로
/// 상대 역할은 내 역할의 반대(학생↔멘토)로 표시합니다.
class ThreadDetailScreen extends ConsumerStatefulWidget {
  const ThreadDetailScreen({
    super.key,
    required this.threadId,
    this.title = '질문',
  });

  final String threadId;
  final String title;

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final TextEditingController _input = TextEditingController();
  bool _sending = false;

  /// 질문방 메시지 실시간 Broadcast(잠금 규칙). 같은 스레드를 연 상대가 보낸
  /// 메시지를 수신하면 목록을 새로고침한다. 데모 모드면 자동 무시.
  late final ThreadRealtime _realtime =
      ThreadRealtime('question-thread-${widget.threadId}');

  @override
  void initState() {
    super.initState();
    _realtime.subscribe(() {
      if (mounted) ref.invalidate(messagesProvider(widget.threadId));
    });
  }

  @override
  void dispose() {
    _realtime.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final myId = demoSession.user?.id ?? '';
    setState(() => _sending = true);
    try {
      await ref.read(threadsRepositoryProvider).postMessage(
            threadId: widget.threadId,
            authorId: myId,
            body: text,
          );
      _input.clear();
      ref.invalidate(messagesProvider(widget.threadId));
      // 상대에게 실시간 알림(데모 모드면 내부에서 무시).
      await _realtime.notifyNewMessage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('전송 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.threadId));
    final myId = demoSession.user?.id ?? '';
    final otherLabel =
        demoSession.role == UserRole.mentor ? '학생' : '멘토';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => AsyncErrorView(
                message: '$e',
                onRetry: () =>
                    ref.invalidate(messagesProvider(widget.threadId)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const AsyncEmptyView(
                    message: '첫 메시지를 남겨보세요.',
                    icon: Icons.chat_bubble_outline,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final mine = m.authorId == myId;
                    return _MessageBubble(
                      message: m,
                      mine: mine,
                      label: mine ? '나' : otherLabel,
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(controller: _input, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.label,
  });

  final QuestionMessage message;
  final bool mine;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color bg = mine ? AppColors.primary : AppColors.surface;
    final Color? fg = mine ? Colors.white : null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: mine ? null : Border.all(color: AppColors.border),
              ),
              child: Text(message.body,
                  style: TextStyle(fontSize: 14, color: fg, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '메시지 입력',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton.filled(
                    onPressed: onSend,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary),
                  ),
          ],
        ),
      ),
    );
  }
}
