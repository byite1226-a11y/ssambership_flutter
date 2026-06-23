import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/note.dart';
import '../../../core/models/settlement.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/models/custom_request.dart';
import '../../../providers/repository_providers.dart';
import '../../connection_note/widgets/connection_notes_section.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../qna/widgets/room_threads_section.dart';
import '../../scan_annotation/widgets/scan_annotations_section.dart';

// ============================================================================
// 멘토 대시보드
// ============================================================================
class MentorDashboardScreen extends ConsumerWidget {
  const MentorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(mentorOrdersProvider);
    final rooms = ref.watch(roomListProvider);
    final pending = orders.maybeWhen(
        data: (l) => l
            .where((o) =>
                o.status == 'in_progress' || o.status == 'delivered')
            .length,
        orElse: () => 0);
    final roomCount =
        rooms.maybeWhen(data: (l) => l.length, orElse: () => 0);
    final settle = orders.maybeWhen(
        data: (l) => l
            .where((o) =>
                o.status == 'in_progress' || o.status == 'delivered')
            .fold<int>(0, (s, o) => s + (o.amountCash * 0.8).round()),
        orElse: () => 0);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('대시보드'),
        actions: const [NotificationBell()],
      ),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('오늘도 좋은 멘토링 되세요 👋',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _StatCard(
                      label: '진행 중 작업',
                      value: '$pending',
                      icon: Icons.assignment_outlined,
                      color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      label: '질문방',
                      value: '$roomCount',
                      icon: Icons.forum_outlined,
                      color: AppColors.secondary)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('정산 예정액 (의뢰 80%)',
                      style:
                          TextStyle(color: Color(0xFFD7E3FB), fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('$settle 캐시',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('구독 30/70 · 단건 의뢰 20/80 기준',
                      style:
                          TextStyle(color: Color(0xFFD7E3FB), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('바로가기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _DashLink(
                icon: Icons.forum_outlined,
                label: '질문방 관리',
                onTap: () => context.go('/mentor/rooms')),
            _DashLink(
                icon: Icons.assignment_outlined,
                label: '맞춤의뢰 둘러보기',
                onTap: () => context.go('/mentor/commission')),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _DashLink extends StatelessWidget {
  const _DashLink(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: AppColors.textDisabled),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// 멘토 질문방 목록
// ============================================================================
class MentorRoomListScreen extends ConsumerWidget {
  const MentorRoomListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('질문방'),
        actions: [
          TextButton(
            onPressed: () => context.push('/mentor/individual-questions'),
            child: const Text('개별 질문'),
          ),
          const NotificationBell(),
        ],
      ),
      body: ContentContainer(
        child: rooms.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(roomListProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const AsyncEmptyView(
                message: '아직 담당 질문방이 없어요.\n학생이 구독하면 방이 생겨요.',
                icon: Icons.forum_outlined,
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(roomListProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final room = list[i];
                  return _MentorRoomCard(
                    room: room,
                    onTap: () => context.push('/mentor/rooms/${room.id}'),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MentorRoomCard extends StatelessWidget {
  const _MentorRoomCard({required this.room, required this.onTap});

  final Room room;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final studentName = room.studentName.isNotEmpty ? room.studentName : '학생';
    final meta = room.subscriptionLabel ?? '';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFD7F0EC),
                child: Icon(Icons.person, color: AppColors.mentorAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(meta,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.mentorAccent)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 멘토 질문방 상세 — ★ 연결노트/스캔 첨삭 진입(멘토 권한)
// ============================================================================
class MentorRoomDetailScreen extends ConsumerWidget {
  const MentorRoomDetailScreen({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider(roomId));
    final title = room.maybeWhen(
      data: (r) => (r != null && r.studentName.isNotEmpty) ? r.studentName : '질문방',
      orElse: () => '질문방',
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.notifications_active_outlined,
                    color: AppColors.accent, size: 18),
                SizedBox(width: 8),
                Expanded(
                    child: Text('답변을 기다리는 질문이 있는지 확인해 주세요',
                        style: TextStyle(fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('질문 스레드',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            // 학생 질문에 답변 — 스레드를 눌러 메시지 작성
            RoomThreadsSection(
              roomId: roomId,
              basePath: '/mentor/rooms/$roomId',
            ),
            const SizedBox(height: 24),
            const Text('연결노트',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            ConnectionNotesSection(roomId: roomId, authorRole: 'mentor'),
            const SizedBox(height: 24),
            const Text('스캔 첨삭',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            ScanAnnotationsSection(
              roomId: roomId,
              authorRole: 'mentor',
              basePath: '/mentor/rooms/$roomId',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 맞춤의뢰 (멘토)
// ============================================================================
class MentorCommissionScreen extends ConsumerWidget {
  const MentorCommissionScreen({super.key});

  static (String, UiTone) _orderStatus(String s) {
    switch (s) {
      case 'in_progress':
        return ('작업 중', UiTone.primary);
      case 'delivered':
        return ('납품 완료', UiTone.warning);
      case 'accepted':
        return ('정산 완료', UiTone.success);
      case 'disputed':
        return ('분쟁', UiTone.danger);
      case 'refunded':
        return ('환불', UiTone.danger);
      case 'escrow_held':
      default:
        return ('작업 대기', UiTone.warning);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(mentorOrdersProvider);
    final postsAsync = ref.watch(openCustomPostsProvider);
    final summaryAsync = ref.watch(settlementSummaryProvider);

    final orders = ordersAsync.asData?.value ?? const <CustomOrder>[];
    final summary = summaryAsync.asData?.value;

    int countBy(String st) => orders.where((o) => o.status == st).length;
    final waiting = countBy('escrow_held');
    final inProgress = countBy('in_progress');
    final delivered = countBy('delivered');
    final accepted = countBy('accepted');
    final disputed = countBy('disputed');
    final active = orders
        .where((o) =>
            o.status == 'escrow_held' ||
            o.status == 'in_progress' ||
            o.status == 'delivered' ||
            o.status == 'disputed')
        .toList();
    final pending = summary?.pendingCash ?? 0;
    final withdrawable = summary?.withdrawableCash ?? 0;
    String cash(int v) => '${_mcMoney(v)} 캐시';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('맞춤의뢰'),
        actions: const [_BellAction(), SizedBox(width: 4)],
      ),
      body: ContentContainer(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mentorOrdersProvider);
            ref.invalidate(openCustomPostsProvider);
            ref.invalidate(settlementSummaryProvider);
            ref.invalidate(unreadCountProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const Text('맞춤의뢰 대시보드',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('할 일 · 수익 · 진행 현황을 한눈에 확인하세요.',
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              SizedBox(
                height: 144,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    StatCard(
                        icon: Icons.description_outlined,
                        tone: UiTone.primary,
                        label: '새 의뢰',
                        value: '${postsAsync.asData?.value.length ?? 0}건'),
                    const SizedBox(width: 12),
                    StatCard(
                        icon: Icons.play_circle_outline,
                        tone: UiTone.indigo,
                        label: '진행 중',
                        value: '$inProgress건'),
                    const SizedBox(width: 12),
                    StatCard(
                        icon: Icons.inventory_2_outlined,
                        tone: UiTone.warning,
                        label: '납품 대기',
                        value: '$delivered건'),
                    const SizedBox(width: 12),
                    StatCard(
                        icon: Icons.verified_outlined,
                        tone: UiTone.success,
                        label: '완료',
                        value: '$accepted건'),
                    const SizedBox(width: 12),
                    StatCard(
                        icon: Icons.payments_outlined,
                        tone: UiTone.warning,
                        label: '정산 예정',
                        value: _mcMoney(pending),
                        sub: '캐시'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: '할 일',
                icon: Icons.bolt,
                tone: UiTone.primary,
                child: (disputed == 0 && waiting == 0)
                    ? const Text('지금 처리할 일이 없어요.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary))
                    : Column(
                        children: [
                          if (disputed > 0)
                            WarnRow(
                                label: '분쟁',
                                count: disputed,
                                tone: UiTone.danger),
                          if (disputed > 0 && waiting > 0)
                            const SizedBox(height: 8),
                          if (waiting > 0)
                            WarnRow(
                                label: '작업 대기 (시작 전)',
                                count: waiting,
                                tone: UiTone.warning),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '수익',
                icon: Icons.trending_up,
                tone: UiTone.success,
                trailing: TextButton(
                  onPressed: () => context.push('/mentor/cash'),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('정산 · 수익 관리 →',
                      style: TextStyle(fontSize: 12.5)),
                ),
                child: Column(
                  children: [
                    MetricRow('진행 중 정산', cash(pending)),
                    MetricRow('출금 가능', cash(withdrawable)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '진행 현황',
                icon: Icons.assignment_outlined,
                tone: UiTone.violet,
                child: Column(
                  children: [
                    MetricRow('작업 대기', '$waiting건'),
                    MetricRow('작업 진행 중', '$inProgress건'),
                    MetricRow('납품 대기', '$delivered건'),
                    MetricRow('분쟁', '$disputed건',
                        valueColor:
                            disputed > 0 ? AppColors.danger : null),
                    MetricRow('완료', '$accepted건'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '진행 중 의뢰',
                icon: Icons.work_outline,
                tone: UiTone.primary,
                trailing: Text('${active.length}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary)),
                child: ordersAsync.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SkeletonBlock(height: 40)),
                  error: (e, _) => Text('불러오지 못했어요: $e',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  data: (_) => active.isEmpty
                      ? const Text('진행 중인 의뢰가 없어요.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary))
                      : Column(
                          children: [
                            for (int i = 0; i < active.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 1, color: AppColors.border),
                              Builder(builder: (_) {
                                final o = active[i];
                                final (label, tone) = _orderStatus(o.status);
                                return ListRowTile(
                                  title: o.title,
                                  sub: cash(o.amountCash),
                                  statusLabel: label,
                                  statusTone: tone,
                                  onTap: () => context.push(
                                      '/mentor/commission/order/${o.id}'),
                                );
                              }),
                            ],
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '열린 의뢰',
                icon: Icons.campaign_outlined,
                tone: UiTone.indigo,
                child: postsAsync.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SkeletonBlock(height: 40)),
                  error: (e, _) => AsyncErrorView(
                      message: '$e',
                      onRetry: () =>
                          ref.invalidate(openCustomPostsProvider)),
                  data: (list) => list.isEmpty
                      ? const Text('지금은 열린 의뢰가 없어요.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary))
                      : Column(
                          children: [
                            for (int i = 0; i < list.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 1, color: AppColors.border),
                              Builder(builder: (_) {
                                final p = list[i];
                                final hasBudget = p.budgetMin != null ||
                                    p.budgetMax != null;
                                final budget = hasBudget
                                    ? '${_mcMoney(p.budgetMin ?? p.budgetMax ?? 0)}${(p.budgetMin != null && p.budgetMax != null) ? '~${_mcMoney(p.budgetMax!)}' : ''} 캐시'
                                    : '예산 협의';
                                return ListRowTile(
                                  title: p.title,
                                  sub: '${p.subject ?? '과목'} · $budget',
                                  statusLabel: '지원 ${p.applicationsCount}',
                                  statusTone: UiTone.neutral,
                                  onTap: () => context
                                      .push('/mentor/commission/${p.id}'),
                                );
                              }),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _mcMoney(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class _BellAction extends ConsumerWidget {
  const _BellAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).asData?.value ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => context.push('/notifications'),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}
// ============================================================================
// 멘토 캐시/정산
// ============================================================================
class MentorCashScreen extends ConsumerStatefulWidget {
  const MentorCashScreen({super.key});
  @override
  ConsumerState<MentorCashScreen> createState() => _MentorCashScreenState();
}

class _MentorCashScreenState extends ConsumerState<MentorCashScreen> {
  bool _busy = false;

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _withdraw(int withdrawable) async {
    if (withdrawable <= 0) {
      _snack('출금 가능한 금액이 없어요.');
      return;
    }
    final ctrl = TextEditingController(text: '$withdrawable');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('출금 요청'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('출금 가능액: $withdrawable 캐시',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: '출금 금액(캐시)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('요청')),
        ],
      ),
    );
    final amount = int.tryParse(ctrl.text.trim()) ?? 0;
    ctrl.dispose();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(settlementsRepositoryProvider).requestWithdrawal(amount);
      ref.invalidate(settlementSummaryProvider);
      ref.invalidate(withdrawalsProvider);
      _snack('출금을 요청했어요.');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(settlementSummaryProvider);
    final settlements = ref.watch(settlementsProvider);
    final withdrawals = ref.watch(withdrawalsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('캐시 · 정산'),
        actions: const [NotificationBell()],
      ),
      body: ContentContainer(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(settlementSummaryProvider);
            ref.invalidate(settlementsProvider);
            ref.invalidate(withdrawalsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              summary.when(
                loading: () => const SizedBox(
                    height: 150,
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => AsyncErrorView(
                    message: '$e',
                    onRetry: () =>
                        ref.invalidate(settlementSummaryProvider)),
                data: (s) => Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('출금 가능액',
                            style: TextStyle(
                                color: Color(0xFFD7E3FB), fontSize: 13)),
                        const SizedBox(height: 6),
                        Text('${_mcMoney(s.withdrawableCash)} 캐시',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary),
                            onPressed: _busy
                                ? null
                                : () => _withdraw(s.withdrawableCash),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('출금 요청',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _MiniStat(
                            label: '정산 예정', value: _mcMoney(s.pendingCash))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _MiniStat(
                            label: '누적 출금', value: _mcMoney(s.withdrawnCash))),
                  ]),
                ]),
              ),
              const SizedBox(height: 24),
              const Text('정산 내역',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('구독 70% · 단건 의뢰 80% 기준',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              settlements.when(
                loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('정산 내역을 불러오지 못했어요: $e',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                data: (list) => list.isEmpty
                    ? const Text('아직 정산 내역이 없어요.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary))
                    : Column(
                        children: [for (final e in list) _SettlementTile(e)]),
              ),
              const SizedBox(height: 24),
              const Text('출금 내역',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              withdrawals.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('출금 내역을 불러오지 못했어요: $e',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                data: (list) => list.isEmpty
                    ? const Text('아직 출금 내역이 없어요.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary))
                    : Column(
                        children: [for (final w in list) _WithdrawalTile(w)]),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('$value 캐시',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile(this.entry);
  final SettlementEntry entry;
  @override
  Widget build(BuildContext context) {
    final d = entry.createdAt;
    final when = d == null ? '' : '${d.month}/${d.day}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(entry.kind == 'order' ? Icons.assignment : Icons.school,
            size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(children: [
                StatusPill(entry.settled ? '정산완료' : '정산예정',
                    tone: entry.settled ? UiTone.success : UiTone.neutral),
                if (when.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(when,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textDisabled)),
                ],
              ]),
            ],
          ),
        ),
        Text('+${_mcMoney(entry.amountCash)}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary)),
      ]),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile(this.w);
  final Withdrawal w;
  @override
  Widget build(BuildContext context) {
    final d = w.createdAt;
    final when = d == null
        ? ''
        : '${d.year}.${d.month}.${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.account_balance_outlined,
            size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_mcMoney(w.amountCash)} 캐시 출금',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
              if (when.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(when,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textDisabled)),
              ],
            ],
          ),
        ),
        StatusPill(w.status == 'paid' ? '지급완료' : '요청됨',
            tone: w.status == 'paid' ? UiTone.success : UiTone.warning),
      ]),
    );
  }
}

// ============================================================================
// 멘토 프로필
// ============================================================================
class MentorProfileScreen extends ConsumerWidget {
  const MentorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const subjects = ['수학', '미적분', '기하'];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const _ProfileAppBar(),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primarySoft,
                child:
                    Icon(Icons.person, size: 32, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Text('데모 멘토',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(width: 6),
                      Icon(Icons.verified, size: 18, color: AppColors.primary),
                    ]),
                    const SizedBox(height: 4),
                    const Text('데모대학교 · 데모학과',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(children: const [
                      Icon(Icons.star, size: 16, color: AppColors.accent),
                      SizedBox(width: 4),
                      Text('4.9',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      SizedBox(width: 6),
                      Text('후기 128개',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            const Text('담당 과목',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in subjects)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('검증 상태',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: const [
                Icon(Icons.verified_user, color: AppColors.success, size: 20),
                SizedBox(width: 10),
                Text('학력 인증 완료',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success)),
              ]),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('프로필 편집은 추후 연결돼요.'))),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('프로필 편집'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/support'),
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text('고객지원'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ProfileAppBar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('내 프로필'),
        actions: const [NotificationBell()],
      );
}
