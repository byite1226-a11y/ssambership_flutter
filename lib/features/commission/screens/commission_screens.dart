import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/custom_request.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';

// ============================================================================
// 공용 위젯
// ============================================================================

/// 의뢰 목록/둘러보기 공통 카드.
class CommissionPostCard extends StatelessWidget {
  const CommissionPostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.showStatus = false,
  });

  final CustomRequestPost post;
  final VoidCallback onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final d = post.deadline;
    final deadline = d == null ? null : '${d.month}/${d.day} 마감';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (post.subject != null) _SubjectChip(post.subject!),
                  if (showStatus) ...[
                    const SizedBox(width: 6),
                    StatusChip(status: post.status),
                  ],
                  const Spacer(),
                  if (deadline != null)
                    Text(deadline,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              Text(post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(post.budgetLabel,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const Spacer(),
                  const Icon(Icons.people_alt_outlined,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('지원 ${post.applicationsCount}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip(this.subject);
  final String subject;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(subject,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w700)),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'open' => ('모집중', AppColors.success),
      'in_progress' => ('진행중', AppColors.primary),
      'delivered' => ('납품완료', AppColors.accent),
      'accepted' || 'fulfilled' => ('정산완료', AppColors.textSecondary),
      'refunded' => ('환불', AppColors.danger),
      'disputed' => ('분쟁', AppColors.danger),
      'closed' || 'cancelled' || 'canceled' => ('마감', AppColors.textDisabled),
      _ => (status, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ============================================================================
// 의뢰 상세 (학생/멘토 공용)
// ============================================================================
class CustomRequestDetailScreen extends ConsumerWidget {
  const CustomRequestDetailScreen({
    super.key,
    required this.postId,
    required this.viewerRole, // 'student' | 'mentor'
  });

  final String postId;
  final String viewerRole;

  bool get _isMentor => viewerRole == 'mentor';
  String get _basePath =>
      _isMentor ? '/mentor/commission' : '/student/commission';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(customPostDetailProvider(postId));
    final order = ref.watch(postOrderProvider(postId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('의뢰 상세')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(customPostDetailProvider(postId)),
        ),
        data: (post) {
          if (post == null) {
            return const Center(
              child: Text('의뢰를 찾을 수 없어요.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          final d = post.deadline;
          return ContentContainer(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  if (post.subject != null) _SubjectChip(post.subject!),
                  const SizedBox(width: 8),
                  StatusChip(status: post.status),
                ]),
                const SizedBox(height: 14),
                Text(post.title,
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.3)),
                const SizedBox(height: 16),
                _InfoRow(
                    icon: Icons.payments_outlined,
                    label: '예산',
                    value: post.budgetLabel),
                if (d != null)
                  _InfoRow(
                      icon: Icons.event_outlined,
                      label: '마감',
                      value: '${d.year}.${d.month}.${d.day}'),
                _InfoRow(
                    icon: Icons.people_alt_outlined,
                    label: '지원자',
                    value: '${post.applicationsCount}명'),
                const SizedBox(height: 20),
                const Text('의뢰 내용',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(post.description,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 24),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 20),

                // 주문이 있으면 주문 배너, 없으면 지원자(학생)/지원(멘토)
                order.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('주문 정보를 불러오지 못했어요: $e',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  data: (o) {
                    if (o != null) {
                      return _OrderBanner(
                        order: o,
                        onTap: () =>
                            context.push('$_basePath/order/${o.id}'),
                      );
                    }
                    return _isMentor
                        ? _MentorApplySection(postId: postId)
                        : _StudentApplicantsSection(postId: postId);
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary))),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ============================================================================
// 학생: 지원자 목록 + 선정(에스크로)
// ============================================================================
class _StudentApplicantsSection extends ConsumerStatefulWidget {
  const _StudentApplicantsSection({required this.postId});
  final String postId;
  @override
  ConsumerState<_StudentApplicantsSection> createState() =>
      _StudentApplicantsSectionState();
}

class _StudentApplicantsSectionState
    extends ConsumerState<_StudentApplicantsSection> {
  bool _busy = false;

  Future<void> _select(CustomRequestApplication app) async {
    final amount = app.proposedCash;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 멘토를 선정할까요?'),
        content: Text(
          '${app.mentorName} 선정\n'
          '${amount != null ? '$amount 캐시' : '예산 범위'}가 에스크로로 보관됩니다.\n'
          '납품을 수락하면 멘토에게 정산돼요.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('선정하기')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final order =
          await ref.read(customRequestsRepositoryProvider).selectApplication(
                postId: widget.postId,
                applicationId: app.id,
              );
      ref.invalidate(postOrderProvider(widget.postId));
      ref.invalidate(applicationsProvider(widget.postId));
      ref.invalidate(customPostDetailProvider(widget.postId));
      ref.invalidate(myCustomPostsProvider);
      ref.invalidate(openCustomPostsProvider);
      ref.invalidate(myOrdersProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(cashLedgerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('선정 완료! 캐시가 에스크로로 보관됐어요.')));
      context.push('/student/commission/order/${order.id}');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(applicationsProvider(widget.postId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('지원한 멘토',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('한 명을 선정하면 주문이 시작되고 캐시가 에스크로로 보관됩니다.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        apps.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () =>
                ref.invalidate(applicationsProvider(widget.postId)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('아직 지원한 멘토가 없어요.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              );
            }
            return Column(
              children: [
                for (final a in list)
                  _ApplicantCard(
                    app: a,
                    busy: _busy,
                    onSelect: () => _select(a),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard(
      {required this.app, required this.busy, required this.onSelect});
  final CustomRequestApplication app;
  final bool busy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                    app.mentorName.isNotEmpty
                        ? app.mentorName.substring(0, 1)
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.mentorName,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                    if (app.universityName != null ||
                        app.avgRating != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [
                          if (app.avgRating != null) ...[
                            const Icon(Icons.star,
                                size: 13, color: AppColors.accent),
                            const SizedBox(width: 3),
                            Text(app.avgRating!.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                          ],
                          if (app.universityName != null)
                            Text(app.universityName!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                        ]),
                      ),
                  ],
                ),
              ),
              if (app.proposedCash != null)
                Text('${app.proposedCash} 캐시',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
            ],
          ),
          if (app.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(app.message,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton(
              onPressed: busy ? null : onSelect,
              child: const Text('이 멘토 선정하기',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 멘토: 지원하기
// ============================================================================
class _MentorApplySection extends ConsumerStatefulWidget {
  const _MentorApplySection({required this.postId});
  final String postId;
  @override
  ConsumerState<_MentorApplySection> createState() =>
      _MentorApplySectionState();
}

class _MentorApplySectionState extends ConsumerState<_MentorApplySection> {
  bool _busy = false;

  Future<void> _apply() async {
    final msgCtrl = TextEditingController();
    final cashCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('의뢰에 지원'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: '어떻게 도와드릴지 적어주세요.',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: '제안 금액(캐시)',
                  hintText: '40000',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('지원하기')),
        ],
      ),
    );
    final message = msgCtrl.text.trim();
    final cash = int.tryParse(cashCtrl.text.replaceAll(',', '').trim());
    msgCtrl.dispose();
    cashCtrl.dispose();
    if (ok != true) return;
    if (message.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('지원 메시지를 입력해 주세요.')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(customRequestsRepositoryProvider).applyToPost(
            postId: widget.postId,
            message: message,
            proposedCash: cash,
          );
      ref.invalidate(applicationsProvider(widget.postId));
      ref.invalidate(customPostDetailProvider(widget.postId));
      ref.invalidate(openCustomPostsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('지원을 보냈어요.')));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(applicationsProvider(widget.postId));
    return apps.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AsyncErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(applicationsProvider(widget.postId)),
      ),
      data: (list) {
        final mine = list.where((a) => a.mentorId == 'demo-mentor').toList();
        if (mine.isNotEmpty) {
          final a = mine.first;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                  SizedBox(width: 6),
                  Text('지원 완료',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ]),
                const SizedBox(height: 8),
                if (a.proposedCash != null)
                  Text('제안 금액: ${a.proposedCash} 캐시',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                if (a.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.message,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 6),
                const Text('학생이 선정하면 작업이 시작돼요.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _busy ? null : _apply,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.how_to_reg_outlined),
            label: const Text('이 의뢰에 지원하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 주문 배너 / 카드 / 상세
// ============================================================================
class _OrderBanner extends StatelessWidget {
  const _OrderBanner({required this.order, required this.onTap});
  final CustomOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('주문 진행 중',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Text(
                        '${order.mentorName} · ${order.amountCash} 캐시 에스크로 보관',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 주문 목록용 카드(멘토 진행 작업 등).
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});
  final CustomOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_turned_in_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('${order.amountCash} 캐시',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              StatusChip(status: order.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// 주문 상세 — 에스크로/진행 스테퍼 + 납품/수락/환불.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.viewerRole, // 'student' | 'mentor'
  });

  final String orderId;
  final String viewerRole;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;
  bool get _isMentor => widget.viewerRole == 'mentor';

  int _activeStep(String status) => switch (status) {
        'escrow_held' || 'in_progress' => 1,
        'delivered' => 2,
        'accepted' || 'fulfilled' => 3,
        'refunded' => 0,
        _ => 1,
      };

  void _invalidateAll() {
    ref.invalidate(orderProvider(widget.orderId));
    ref.invalidate(deliverablesProvider(widget.orderId));
    ref.invalidate(myOrdersProvider);
    ref.invalidate(mentorOrdersProvider);
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _run(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('확인')),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _submitDeliverable() async {
    final msgCtrl = TextEditingController();
    final fileCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('산출물 납품'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: '작업 내용을 설명해 주세요.',
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: fileCtrl,
              decoration: const InputDecoration(
                  labelText: '파일명(선택)',
                  hintText: '예) 풀이_해설.pdf',
                  border: OutlineInputBorder())),
          const SizedBox(height: 8),
          const Text('데모에서는 파일명만 기록돼요. 실제 앱은 파일을 업로드합니다.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('납품하기')),
        ],
      ),
    );
    final message = msgCtrl.text.trim();
    final file = fileCtrl.text.trim();
    msgCtrl.dispose();
    fileCtrl.dispose();
    if (ok != true) return;
    if (message.isEmpty) {
      _snack('납품 설명을 입력해 주세요.');
      return;
    }
    await _run(() async {
      await ref.read(customRequestsRepositoryProvider).submitDeliverable(
            orderId: widget.orderId,
            message: message,
            fileName: file.isEmpty ? null : file,
          );
      _invalidateAll();
      _snack('산출물을 납품했어요.');
    });
  }

  Future<void> _accept() async {
    final ok = await _confirm(
        '납품을 수락할까요?', '수락하면 에스크로가 멘토에게 정산(20/80)되고 주문이 완료돼요.');
    if (!ok) return;
    await _run(() async {
      await ref.read(customRequestsRepositoryProvider).acceptOrder(widget.orderId);
      _invalidateAll();
      _snack('정산 완료! 주문이 마무리됐어요.');
    });
  }

  Future<void> _refund() async {
    final ok = await _confirm('주문을 취소하고 환불할까요?', '에스크로 캐시가 환불됩니다. 정산 전에만 가능해요.');
    if (!ok) return;
    await _run(() async {
      await ref.read(customRequestsRepositoryProvider).refundOrder(widget.orderId);
      _invalidateAll();
      ref.invalidate(walletProvider);
      ref.invalidate(cashLedgerProvider);
      _snack('환불됐어요.');
    });
  }

  Future<void> _dispute() async {
    final reasons = ['미납품', '품질 불만', '연락 두절', '기타'];
    String reason = reasons.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('분쟁 신청'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('사유를 선택하면 관리자가 검토 후 정산을 조정해요.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              for (final r in reasons)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: r,
                  groupValue: reason,
                  onChanged: (v) => setLocal(() => reason = v!),
                  title: Text(r, style: const TextStyle(fontSize: 14)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('신청')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref
          .read(customRequestsRepositoryProvider)
          .disputeOrder(orderId: widget.orderId, reason: reason);
      _invalidateAll();
      _snack('분쟁을 신청했어요. 관리자가 검토할게요.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));
    final deliverables = ref.watch(deliverablesProvider(widget.orderId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('주문 상세')),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(orderProvider(widget.orderId))),
        data: (o) {
          if (o == null) {
            return const Center(
                child: Text('주문을 찾을 수 없어요.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          final step = _activeStep(o.status);
          final payout = (o.amountCash * 0.8).round();
          final fee = o.amountCash - payout;
          return ContentContainer(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  Expanded(
                      child: Text(o.title,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.3))),
                  StatusChip(status: o.status),
                ]),
                const SizedBox(height: 20),
                _EscrowCard(
                  amount: o.amountCash,
                  released: o.status == 'accepted',
                  refunded: o.status == 'refunded',
                ),
                const SizedBox(height: 20),
                _StepBar(active: step),
                const SizedBox(height: 20),
                _InfoRow(
                    icon: Icons.person_outline,
                    label: '멘토',
                    value: o.mentorName),
                _InfoRow(
                    icon: Icons.payments_outlined,
                    label: '금액',
                    value: '${o.amountCash} 캐시'),
                if (o.status == 'accepted') ...[
                  _InfoRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '멘토 정산',
                      value: '$payout 캐시 (80%)'),
                  _InfoRow(
                      icon: Icons.percent,
                      label: '플랫폼',
                      value: '$fee 캐시 (20%)'),
                ],
                const SizedBox(height: 20),
                const Text('납품 산출물',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                deliverables.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Text('납품을 불러오지 못했어요: $e',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  data: (list) => list.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('아직 납품된 산출물이 없어요.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)))
                      : Column(children: [
                          for (final d in list) _DeliverableTile(deliverable: d)
                        ]),
                ),
                const SizedBox(height: 20),
                _actions(o),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actions(CustomOrder o) {
    if (o.status == 'accepted') {
      return _infoBox('정산이 완료된 주문이에요. 🎉', AppColors.success);
    }
    if (o.status == 'refunded') {
      return _infoBox('환불된 주문이에요.', AppColors.danger);
    }
    if (o.status == 'disputed') {
      return _infoBox('분쟁 검토 중이에요. 관리자 확인 후 안내드릴게요.', AppColors.danger);
    }
    if (_isMentor) {
      if (o.status == 'delivered') {
        return _infoBox('납품 완료 · 학생의 수락을 기다리고 있어요.', AppColors.primary);
      }
      return SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: _busy ? null : _submitDeliverable,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_file_outlined),
          label: const Text('산출물 납품하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
    }
    return Column(children: [
      if (o.status == 'delivered')
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _busy ? null : _accept,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('납품 수락하기',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        )
      else
        _infoBox('멘토가 작업 중이에요. 납품되면 알려드릴게요.', AppColors.primary),
      const SizedBox(height: 10),
      TextButton(
          onPressed: _busy ? null : _refund,
          child: const Text('주문 취소·환불',
              style: TextStyle(color: AppColors.danger))),
      TextButton(
          onPressed: _busy ? null : _dispute,
          child: const Text('분쟁 신청',
              style: TextStyle(color: AppColors.textSecondary))),
    ]);
  }

  Widget _infoBox(String text, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class _DeliverableTile extends StatelessWidget {
  const _DeliverableTile({required this.deliverable});
  final OrderDeliverable deliverable;
  @override
  Widget build(BuildContext context) {
    final d = deliverable.createdAt;
    final when = d == null
        ? ''
        : '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (deliverable.message.isNotEmpty)
          Text(deliverable.message,
              style: const TextStyle(fontSize: 13.5, height: 1.5)),
        if (deliverable.fileName != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.attach_file, size: 15, color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(
                child: Text(deliverable.fileName!,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600))),
          ]),
        ],
        if (when.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(when,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}

class _EscrowCard extends StatelessWidget {
  const _EscrowCard(
      {required this.amount, this.released = false, this.refunded = false});
  final int amount;
  final bool released;
  final bool refunded;
  @override
  Widget build(BuildContext context) {
    final label =
        refunded ? '환불 완료' : (released ? '정산 완료' : '에스크로 보관 중');
    final icon = refunded
        ? Icons.undo
        : (released ? Icons.check_circle : Icons.lock_outline);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFFD7E3FB), fontSize: 12)),
                const SizedBox(height: 4),
                Text('$amount 캐시',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.active});
  final int active;
  static const _labels = ['에스크로', '작업 중', '납품', '정산완료'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: i <= active
                        ? AppColors.primary
                        : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      i < active ? Icons.check : Icons.circle,
                      size: i < active ? 16 : 8,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(_labels[i],
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            i <= active ? FontWeight.w700 : FontWeight.w400,
                        color: i <= active
                            ? AppColors.textPrimary
                            : AppColors.textSecondary)),
              ],
            ),
          ),
          if (i < _labels.length - 1)
            Container(
              width: 16,
              height: 2,
              margin: const EdgeInsets.only(bottom: 22),
              color: i < active ? AppColors.primary : AppColors.border,
            ),
        ],
      ],
    );
  }
}

// ============================================================================
// 의뢰 작성 폼 (학생)
// ============================================================================
class CustomRequestComposeScreen extends ConsumerStatefulWidget {
  const CustomRequestComposeScreen({super.key});

  @override
  ConsumerState<CustomRequestComposeScreen> createState() =>
      _CustomRequestComposeScreenState();
}

class _CustomRequestComposeScreenState
    extends ConsumerState<CustomRequestComposeScreen> {
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _desc = TextEditingController();
  final _budgetMin = TextEditingController();
  final _budgetMax = TextEditingController();
  DateTime? _deadline;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _desc.dispose();
    _budgetMin.dispose();
    _budgetMax.dispose();
    super.dispose();
  }

  int? _parseBudget(String s) {
    final cleaned = s.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('제목과 의뢰 내용을 입력해 주세요.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(customRequestsRepositoryProvider).createPost(
            title: _title.text.trim(),
            description: _desc.text.trim(),
            subject:
                _subject.text.trim().isEmpty ? null : _subject.text.trim(),
            budgetMin: _parseBudget(_budgetMin.text),
            budgetMax: _parseBudget(_budgetMax.text),
            deadline: _deadline,
          );
      ref.invalidate(myCustomPostsProvider);
      ref.invalidate(openCustomPostsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('의뢰를 올렸어요.')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _deadline;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('새 맞춤의뢰')),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Field(label: '제목', controller: _title, hint: '예) 미적분 오답 해설 의뢰'),
            _Field(label: '과목', controller: _subject, hint: '예) 수학'),
            _Field(
              label: '의뢰 내용',
              controller: _desc,
              hint: '어떤 도움이 필요한지 자세히 적어주세요.',
              maxLines: 6,
            ),
            Row(children: [
              Expanded(
                child: _Field(
                  label: '예산 최소(캐시)',
                  controller: _budgetMin,
                  hint: '30000',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: '예산 최대(캐시)',
                  controller: _budgetMax,
                  hint: '50000',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ]),
            const SizedBox(height: 6),
            const Text('마감일',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(d == null
                  ? '마감일 선택(선택사항)'
                  : '${d.year}.${d.month}.${d.day}'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('의뢰 올리기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
