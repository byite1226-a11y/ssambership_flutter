import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/review.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';

/// 멘토 상세 — 프로필 + 요금제 선택 + 구독 결제.
///
/// 구독 버튼 → 확인 다이얼로그 → MentorsRepository.subscribe(캐시 차감 + 방 생성)
/// → 지갑/내역/방목록 갱신 → 새 질문방으로 이동.
class MentorDetailScreen extends ConsumerStatefulWidget {
  const MentorDetailScreen({super.key, required this.mentorId});
  final String mentorId;

  @override
  ConsumerState<MentorDetailScreen> createState() => _MentorDetailScreenState();
}

class _MentorDetailScreenState extends ConsumerState<MentorDetailScreen> {
  final _won = NumberFormat('#,###', 'ko_KR');
  PlanType _plan = PlanType.standard;
  bool _subscribing = false;

  Future<void> _subscribe(MentorProfile mentor) async {
    final info = PlanInfo.all[_plan]!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구독 확인'),
        content: Text(
          '${mentor.displayName} · ${info.label}\n'
          '매월 ${_won.format(info.priceCash)}캐시가 차감됩니다.\n계속할까요?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('구독하기')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _subscribing = true);
    try {
      final res = await ref.read(mentorsRepositoryProvider).subscribe(
            mentorId: mentor.userId,
            mentorName: mentor.displayName,
            plan: _plan,
            subject: mentor.teachingSubjects.isNotEmpty
                ? mentor.teachingSubjects.first
                : null,
          );
      ref.invalidate(walletProvider);
      ref.invalidate(cashLedgerProvider);
      ref.invalidate(roomListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${mentor.displayName} 구독 완료! 질문방이 생성됐어요.'),
      ));
      if (res.roomId.isNotEmpty) {
        context.go('/student/rooms/${res.roomId}');
      } else {
        context.go('/student/rooms');
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(mentorDetailProvider(widget.mentorId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('멘토 상세'),
        actions: [_FavoriteButton(mentorId: widget.mentorId)],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          message: '$e',
          onRetry: () =>
              ref.invalidate(mentorDetailProvider(widget.mentorId)),
        ),
        data: (mentor) {
          if (mentor == null) {
            return const Center(
              child: Text('멘토를 찾을 수 없어요.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ContentContainer(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Header(mentor: mentor),
                const SizedBox(height: 20),
                if (mentor.teachingSubjects.isNotEmpty) ...[
                  const Text('담당 과목',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in mentor.teachingSubjects)
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
                ],
                const Text('구독 요금제',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('멘토가 직접 설정한 요금제예요. 매월 자동 결제 · 구독 정산 30/70.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                for (final t in PlanType.values)
                  _PlanOption(
                    info: PlanInfo.all[t]!,
                    selected: _plan == t,
                    won: _won,
                    onTap: () => setState(() => _plan = t),
                  ),
                const SizedBox(height: 4),
                const Text(
                    '각 요금제는 한 멘토 기준이며, 무료 질문은 멘토당 최대 3개까지 사용할 수 있어요.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textDisabled,
                        height: 1.5)),
                const SizedBox(height: 28),
                _ReviewsSection(mentorId: widget.mentorId),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: detail.maybeWhen(
        data: (mentor) =>
            mentor == null ? null : _bottomBar(mentor),
        orElse: () => null,
      ),
    );
  }

  Widget _bottomBar(MentorProfile mentor) {
    final info = PlanInfo.all[_plan]!;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => context.push(
              '/student/mentors/${mentor.userId}/individual-question/new',
              extra: {'name': mentor.displayName},
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('1:1 질문'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _subscribing ? null : () => _subscribe(mentor),
                child: _subscribing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        '${info.label} 구독 · ${_won.format(info.priceCash)}캐시/월',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.mentor});
  final MentorProfile mentor;

  @override
  Widget build(BuildContext context) {
    final verified = mentor.verificationStatus == 'verified';
    final initial =
        mentor.displayName.isNotEmpty ? mentor.displayName.substring(0, 1) : '?';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primarySoft,
          backgroundImage:
              mentor.avatarUrl != null ? NetworkImage(mentor.avatarUrl!) : null,
          child: mentor.avatarUrl == null
              ? Text(initial,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary))
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(mentor.displayName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified,
                        size: 18, color: AppColors.primary),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [mentor.universityName, mentor.departmentName]
                    .where((e) => e != null && e.isNotEmpty)
                    .join(' · '),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(mentor.avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text('후기 ${mentor.reviewCount}개',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.info,
    required this.selected,
    required this.won,
    required this.onTap,
  });
  final PlanInfo info;
  final bool selected;
  final NumberFormat won;
  final VoidCallback onTap;

  List<String> _features() {
    switch (info.type) {
      case PlanType.limited:
        return const ['연결노트 제공', '질문 히스토리 무제한'];
      case PlanType.standard:
        return const ['연결노트 제공', '질문 히스토리 무제한', '우선 응답'];
      case PlanType.premium:
        return const ['연결노트 제공', '맞춤의뢰 할인', '실시간 화상 2회'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final feats = _features();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderStrong,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textDisabled),
                    const SizedBox(width: 8),
                    Text(info.label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    if (info.recommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('추천',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                    const Spacer(),
                    Text(info.weeklyLabel,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${won.format(info.priceCash)}캐시',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                    const SizedBox(width: 4),
                    const Text('/월',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    const Text('(VAT 포함)',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textDisabled)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final f in feats)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      const Icon(Icons.check,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(f,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textPrimary)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.mentorId});
  final String mentorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoriteIdsProvider);
    final isFav =
        favs.maybeWhen(data: (s) => s.contains(mentorId), orElse: () => false);
    return IconButton(
      tooltip: '즐겨찾기',
      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
          color: isFav ? AppColors.danger : null),
      onPressed: () async {
        await ref.read(mentorsRepositoryProvider).toggleFavorite(mentorId);
        ref.invalidate(favoriteIdsProvider);
        ref.invalidate(favoritesProvider);
      },
    );
  }
}

class _ReviewsSection extends ConsumerStatefulWidget {
  const _ReviewsSection({required this.mentorId});
  final String mentorId;
  @override
  ConsumerState<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<_ReviewsSection> {
  bool _busy = false;

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _write() async {
    int rating = 5;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('후기 작성'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setLocal(() => rating = i),
                      icon: Icon(
                          i <= rating ? Icons.star : Icons.star_border,
                          color: AppColors.accent),
                    ),
                ],
              ),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: '후기를 남겨주세요.', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('등록')),
          ],
        ),
      ),
    );
    final body = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    if (body.isEmpty) {
      _snack('후기 내용을 입력해 주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(mentorsRepositoryProvider).addReview(
            mentorId: widget.mentorId,
            rating: rating,
            body: body,
          );
      ref.invalidate(reviewsProvider(widget.mentorId));
      _snack('후기를 등록했어요.');
    } catch (e) {
      _snack('등록 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(reviewsProvider(widget.mentorId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('후기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          TextButton.icon(
            onPressed: _busy ? null : _write,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('후기 작성'),
          ),
        ]),
        const SizedBox(height: 4),
        reviews.when(
          loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('후기를 불러오지 못했어요: $e',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('아직 후기가 없어요. 첫 후기를 남겨보세요.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)))
              : Column(children: [for (final r in list) _ReviewTile(r)]),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.review);
  final Review review;
  @override
  Widget build(BuildContext context) {
    final d = review.createdAt;
    final when = d == null ? '' : '${d.year}.${d.month}.${d.day}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            for (int i = 1; i <= 5; i++)
              Icon(i <= review.rating ? Icons.star : Icons.star_border,
                  size: 15, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(review.authorLabel,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (when.isNotEmpty)
              Text(when,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textDisabled)),
          ]),
          const SizedBox(height: 6),
          Text(review.body,
              style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }
}
