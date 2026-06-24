import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/individual_question.dart';
import '../../../core/models/user.dart';
import '../../../core/realtime/thread_realtime.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../providers/repository_providers.dart';
import '../../notifications/screens/notifications_screen.dart';

// ============================================================================
// 공용 헬퍼
// ============================================================================
String _money(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

UiTone iqStatusTone(IQStatus s) {
  switch (s) {
    case IQStatus.released:
      return UiTone.success;
    case IQStatus.answered:
      return UiTone.primary;
    case IQStatus.open:
      return UiTone.indigo;
    case IQStatus.assigned:
    case IQStatus.claimed:
      return UiTone.warning;
    case IQStatus.refunded:
    case IQStatus.canceled:
    case IQStatus.expired:
      return UiTone.danger;
    case IQStatus.escrowed:
      return UiTone.neutral;
  }
}

String iqExpiryText(DateTime? e) {
  if (e == null) return '';
  final diff = e.difference(DateTime.now());
  if (diff.isNegative) return '만료됨';
  if (diff.inHours < 24) return '오늘 마감 · ${diff.inHours}시간 남음';
  return 'D-${diff.inDays}';
}

void _refreshIq(WidgetRef ref, String id) {
  ref.invalidate(individualQuestionProvider(id));
  ref.invalidate(iqMessagesProvider(id));
  ref.invalidate(myIndividualQuestionsProvider);
  ref.invalidate(assignedIndividualQuestionsProvider);
  ref.invalidate(openIndividualQuestionsProvider);
  ref.invalidate(settlementSummaryProvider);
  ref.invalidate(settlementsProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadCountProvider);
}

// ============================================================================
// 학생 — 개별 질문 목록
// ============================================================================
class StudentIndividualQuestionsScreen extends ConsumerWidget {
  const StudentIndividualQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myIndividualQuestionsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('개별 질문'),
        actions: const [NotificationBell()],
      ),
      body: ContentContainer(
        child: mine.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AsyncErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(myIndividualQuestionsProvider)),
          data: (list) {
            if (list.isEmpty) {
              return EmptyStateView(
                icon: Icons.help_outline,
                title: '아직 개별 질문이 없어요',
                message: '구독과 별개로, 단건으로 멘토에게 물어볼 수 있어요.\n공개 질문은 먼저 가져간 멘토가 답변해요.',
                action: FilledButton(
                  onPressed: () =>
                      context.push('/student/individual-questions/new'),
                  child: const Text('공개 질문하기'),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(myIndividualQuestionsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final q = list[i];
                  final exp = iqExpiryText(q.expiresAt);
                  final sub = [
                    IndividualQuestion.typeLabel(q.type),
                    '${_money(q.priceCash)}캐시',
                    if (!q.isTerminal && exp.isNotEmpty) exp,
                  ].join(' · ');
                  return _IqCard(
                    title: q.title,
                    sub: sub,
                    statusLabel: IndividualQuestion.statusLabel(q.status),
                    statusTone: iqStatusTone(q.status),
                    leadingTone:
                        q.isOpen ? UiTone.indigo : UiTone.primary,
                    leadingIcon:
                        q.isOpen ? Icons.public : Icons.person_outline,
                    onTap: () => context
                        .push('/student/individual-questions/${q.id}'),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/student/individual-questions/new'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('공개 질문'),
      ),
    );
  }
}

class _IqCard extends StatelessWidget {
  const _IqCard({
    required this.title,
    required this.sub,
    required this.statusLabel,
    required this.statusTone,
    required this.leadingIcon,
    required this.leadingTone,
    required this.onTap,
    this.trailing,
  });
  final String title;
  final String sub;
  final String statusLabel;
  final UiTone statusTone;
  final IconData leadingIcon;
  final UiTone leadingTone;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconTile(leadingIcon, tone: leadingTone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? StatusPill(statusLabel, tone: statusTone),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 작성 — 공개/지정
// ============================================================================
class IndividualQuestionComposeScreen extends ConsumerStatefulWidget {
  const IndividualQuestionComposeScreen({
    super.key,
    required this.mode,
    this.mentorId,
    this.mentorName,
  });
  final IQType mode;
  final String? mentorId;
  final String? mentorName;

  @override
  ConsumerState<IndividualQuestionComposeScreen> createState() =>
      _IndividualQuestionComposeScreenState();
}

class _IndividualQuestionComposeScreenState
    extends ConsumerState<IndividualQuestionComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _price = TextEditingController(text: '5000');
  bool _busy = false;

  /// 이 등록 화면 1회분의 멱등성 키. 처음 제출 시 한 번 만들어 재사용하므로
  /// 네트워크 재시도로 제출이 두 번 가도 서버가 한 번만 예치한다(이중 과금 방지).
  late final String _idem =
      'iq-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';

  bool get _isOpen => widget.mode == IQType.open;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _price.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _submit(int directPrice) async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty) {
      _snack('제목을 입력해 주세요.');
      return;
    }
    if (body.isEmpty) {
      _snack('내용을 입력해 주세요.');
      return;
    }
    final repo = ref.read(individualQuestionsRepositoryProvider);
    setState(() => _busy = true);
    try {
      if (_isOpen) {
        final price = int.tryParse(_price.text.trim()) ?? 0;
        if (price <= 0) {
          _snack('가격을 입력해 주세요.');
          setState(() => _busy = false);
          return;
        }
        await repo.createOpen(
            title: title,
            body: body,
            priceCash: price,
            idempotencyKey: _idem);
      } else {
        await repo.createDirect(
          mentorId: widget.mentorId!,
          mentorName: widget.mentorName ?? '멘토',
          title: title,
          body: body,
          idempotencyKey: _idem,
        );
      }
      ref.invalidate(myIndividualQuestionsProvider);
      ref.invalidate(openIndividualQuestionsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      if (mounted) {
        _snack(_isOpen ? '공개 질문을 등록했어요.' : '질문을 보냈어요.');
        context.pop();
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceAsync = _isOpen
        ? const AsyncValue<int>.data(0)
        : ref.watch(mentorIqPriceProvider(widget.mentorId ?? ''));
    final directPrice = priceAsync.asData?.value ?? 8000;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isOpen ? '공개 질문' : '1:1 지정 질문')),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 대상/유형 안내
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  IconTile(_isOpen ? Icons.public : Icons.person,
                      tone: _isOpen ? UiTone.indigo : UiTone.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isOpen ? '공개 질문' : (widget.mentorName ?? '멘토'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                            _isOpen
                                ? '멘토 지정 없이 공개돼요. 먼저 가져간 멘토 1명이 답변해요.'
                                : '이 멘토에게 1:1 비공개로 질문해요.',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('제목',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _title,
              decoration:
                  const InputDecoration(hintText: '질문 제목을 입력하세요'),
            ),
            const SizedBox(height: 16),
            const Text('내용',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _body,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                  hintText: '궁금한 내용을 자세히 적어주세요.'),
            ),
            const SizedBox(height: 16),
            if (_isOpen) ...[
              const Text('가격(캐시)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '예) 5000',
                  prefixIcon: Icon(Icons.toll_outlined),
                ),
              ),
              const SizedBox(height: 6),
              const Text('등록 시 가격만큼 캐시가 안전하게 예치돼요. 답변 확인 후 멘토에게 정산됩니다.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textDisabled,
                      height: 1.5)),
            ] else ...[
              Row(
                children: [
                  const Text('예치 금액',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text('${_money(directPrice)}캐시',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('멘토가 설정한 1:1 질문 가격이에요. 답변 확인 후 정산됩니다.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textDisabled,
                      height: 1.5)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _busy ? null : () => _submit(directPrice),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isOpen
                        ? '예치하고 공개 등록'
                        : '예치하고 질문 보내기 · ${_money(directPrice)}캐시'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 상세 — 역할별 액션
// ============================================================================
class IndividualQuestionDetailScreen extends ConsumerStatefulWidget {
  const IndividualQuestionDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<IndividualQuestionDetailScreen> createState() =>
      _IndividualQuestionDetailScreenState();
}

class _IndividualQuestionDetailScreenState
    extends ConsumerState<IndividualQuestionDetailScreen> {
  final _answer = TextEditingController();
  bool _busy = false;

  /// 개별질문 메시지·상태 실시간 Broadcast. 상대(학생↔멘토)가 답변/정산/환불 등으로
  /// 변경을 일으키면 수신해 질문·답변을 새로고침한다. 데모 모드면 자동 무시.
  late final ThreadRealtime _realtime =
      ThreadRealtime('individual-question-${widget.id}');

  @override
  void initState() {
    super.initState();
    _realtime.subscribe(() {
      if (!mounted) return;
      ref.invalidate(iqMessagesProvider(widget.id));
      ref.invalidate(individualQuestionProvider(widget.id));
    });
  }

  @override
  void dispose() {
    _realtime.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      _refreshIq(ref, widget.id);
      // 상대에게 실시간 알림(데모 모드면 내부에서 무시).
      await _realtime.notifyNewMessage();
      if (mounted) _snack(okMsg);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qAsync = ref.watch(individualQuestionProvider(widget.id));
    final msgs = ref.watch(iqMessagesProvider(widget.id));
    final isMentor =
        ref.watch(authRepositoryProvider).role == UserRole.mentor;
    final repo = ref.read(individualQuestionsRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('개별 질문')),
      body: qAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () =>
                ref.invalidate(individualQuestionProvider(widget.id))),
        data: (q) {
          if (q == null) {
            return const AsyncEmptyView(
                message: '질문을 찾을 수 없어요.', icon: Icons.help_outline);
          }
          final exp = iqExpiryText(q.expiresAt);
          return ContentContainer(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    StatusPill(
                      '${IndividualQuestion.typeLabel(q.type)} 질문',
                      tone: q.isOpen ? UiTone.indigo : UiTone.primary,
                    ),
                    const SizedBox(width: 6),
                    StatusPill(IndividualQuestion.statusLabel(q.status),
                        tone: iqStatusTone(q.status)),
                    const Spacer(),
                    if (!q.isTerminal && exp.isNotEmpty)
                      Text(exp,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(q.title,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('예치 ${_money(q.priceCash)}캐시',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    if (q.answeringMentorName != null) ...[
                      const Text('  ·  ',
                          style: TextStyle(color: AppColors.textDisabled)),
                      Text('담당 ${q.answeringMentorName}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(q.body,
                      style:
                          const TextStyle(fontSize: 14.5, height: 1.55)),
                ),
                if (isMentor && q.isOpen) ...[
                  const SizedBox(height: 10),
                  Row(children: const [
                    Icon(Icons.lock_outline,
                        size: 14, color: AppColors.textDisabled),
                    SizedBox(width: 6),
                    Text('학생 신원은 비공개예요.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textDisabled)),
                  ]),
                ],
                const SizedBox(height: 20),

                // 답변
                msgs.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) {
                    if (list.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('답변',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        for (final m in list)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(m.body,
                                style: const TextStyle(
                                    fontSize: 14.5, height: 1.5)),
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 12),
                ..._actions(q, isMentor, repo),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _actions(
      IndividualQuestion q, bool isMentor, dynamic repo) {
    // 멘토: 답변 가능 상태(받은 지정/가져간 공개)
    if (isMentor && q.awaitingAnswer) {
      return [
        const Text('답변 작성',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _answer,
          minLines: 3,
          maxLines: 8,
          decoration:
              const InputDecoration(hintText: '학생에게 보낼 답변을 입력하세요.'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                      () => repo.answer(id: q.id, body: _answer.text),
                      '답변을 등록했어요.',
                    ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('답변 등록'),
          ),
        ),
      ];
    }
    // 학생: 답변완료 → 확인/정산
    if (!isMentor && q.status == IQStatus.answered) {
      return [
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() => repo.confirmAndRelease(q.id),
                    '확인 완료! 멘토에게 정산됐어요.'),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('답변 확인 · 정산하기'),
          ),
        ),
      ];
    }
    // 학생: 답변 전 → 취소/환불
    if (!isMentor &&
        (q.status == IQStatus.open ||
            q.status == IQStatus.assigned ||
            q.status == IQStatus.claimed)) {
      return [
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger)),
            onPressed: _busy
                ? null
                : () => _run(() => repo.cancel(q.id), '취소하고 환불했어요.'),
            child: const Text('취소하고 환불'),
          ),
        ),
      ];
    }
    // 종료 상태 안내
    if (q.isTerminal) {
      return [
        Center(
          child: Text(
            q.status == IQStatus.released
                ? '정산이 완료된 질문이에요.'
                : '${IndividualQuestion.statusLabel(q.status)}된 질문이에요.',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ];
    }
    return [const SizedBox.shrink()];
  }
}

// ============================================================================
// 멘토 — 받은 지정 + 공개 풀
// ============================================================================
class MentorIndividualQuestionsScreen extends ConsumerStatefulWidget {
  const MentorIndividualQuestionsScreen({super.key});
  @override
  ConsumerState<MentorIndividualQuestionsScreen> createState() =>
      _MentorIndividualQuestionsScreenState();
}

class _MentorIndividualQuestionsScreenState
    extends ConsumerState<MentorIndividualQuestionsScreen> {
  int _seg = 0; // 0=받은 지정, 1=공개 풀
  bool _busy = false;

  Future<void> _claim(String id) async {
    setState(() => _busy = true);
    try {
      await ref.read(individualQuestionsRepositoryProvider).claimOpen(id);
      ref.invalidate(openIndividualQuestionsProvider);
      ref.invalidate(assignedIndividualQuestionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('질문을 가져왔어요. 답변해 주세요.')));
        context.push('/mentor/individual-questions/$id');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _priceHeader() {
    final price = ref.watch(myMentorIqPriceProvider).asData?.value ?? 8000;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            const IconTile(Icons.toll_outlined, tone: UiTone.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('내 1:1 질문 가격',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text('${_money(price)}캐시',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => _editPrice(price),
              child: const Text('변경'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPrice(int current) async {
    final ctrl = TextEditingController(text: '$current');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('1:1 질문 가격 설정'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: '가격(캐시)', prefixIcon: Icon(Icons.toll_outlined)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장')),
        ],
      ),
    );
    final v = int.tryParse(ctrl.text.trim()) ?? 0;
    ctrl.dispose();
    if (ok != true) return;
    try {
      await ref
          .read(individualQuestionsRepositoryProvider)
          .setMyMentorPrice(v);
      ref.invalidate(myMentorIqPriceProvider);
      ref.invalidate(mentorIqPriceProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('가격을 저장했어요.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigned = ref.watch(assignedIndividualQuestionsProvider);
    final open = ref.watch(openIndividualQuestionsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('개별 질문'),
        actions: const [NotificationBell()],
      ),
      body: ContentContainer(
        child: Column(
          children: [
            _priceHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('받은 지정')),
                  ButtonSegment(value: 1, label: Text('공개 풀')),
                ],
                selected: {_seg},
                onSelectionChanged: (s) => setState(() => _seg = s.first),
              ),
            ),
            Expanded(
              child: _seg == 0
                  ? _assignedList(assigned)
                  : _openList(open),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assignedList(AsyncValue<List<IndividualQuestion>> a) {
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AsyncErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(assignedIndividualQuestionsProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateView(
              icon: Icons.inbox_outlined,
              title: '받은 지정 질문이 없어요',
              message: '학생이 1:1로 보낸 질문이 여기에 표시돼요.');
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(assignedIndividualQuestionsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final q = list[i];
              final exp = iqExpiryText(q.expiresAt);
              return _IqCard(
                title: q.title,
                sub: [
                  '${_money(q.priceCash)}캐시',
                  if (!q.isTerminal && exp.isNotEmpty) exp,
                ].join(' · '),
                statusLabel: IndividualQuestion.statusLabel(q.status),
                statusTone: iqStatusTone(q.status),
                leadingIcon: Icons.person_outline,
                leadingTone: UiTone.primary,
                onTap: () =>
                    context.push('/mentor/individual-questions/${q.id}'),
              );
            },
          ),
        );
      },
    );
  }

  Widget _openList(AsyncValue<List<IndividualQuestion>> o) {
    return o.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AsyncErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(openIndividualQuestionsProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateView(
              icon: Icons.public_off,
              title: '공개 질문이 없어요',
              message: '학생이 올린 공개 질문을 가져가 답변하면 정산받아요.');
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(openIndividualQuestionsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final q = list[i];
              final exp = iqExpiryText(q.expiresAt);
              return _IqCard(
                title: q.title,
                sub: [
                  '공개',
                  '${_money(q.priceCash)}캐시',
                  if (exp.isNotEmpty) exp,
                ].join(' · '),
                statusLabel: '공개중',
                statusTone: UiTone.indigo,
                leadingIcon: Icons.public,
                leadingTone: UiTone.indigo,
                onTap: () =>
                    context.push('/mentor/individual-questions/${q.id}'),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _busy ? null : () => _claim(q.id),
                  child: const Text('가져가기'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
