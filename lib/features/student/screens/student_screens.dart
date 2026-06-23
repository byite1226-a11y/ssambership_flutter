import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/note.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../providers/repository_providers.dart';
import '../../connection_note/widgets/connection_notes_section.dart';
import '../../commission/screens/commission_screens.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../qna/widgets/room_threads_section.dart';
import '../../scan_annotation/widgets/scan_annotations_section.dart';

// ============================================================================
// 멘토찾기
// ============================================================================
class StudentMentorSearchScreen extends ConsumerWidget {
  const StudentMentorSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentors = ref.watch(mentorListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('멘토 찾기'),
        actions: const [NotificationBell()],
      ),
      body: ContentContainer(
        child: mentors.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(mentorListProvider),
          ),
          data: (list) => list.isEmpty
              ? const AsyncEmptyView(
                  message: '등록된 멘토가 없어요.',
                  icon: Icons.person_search_outlined,
                )
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(mentorListProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _MentorListCard(
                      mentor: list[i],
                      onTap: () => context
                          .push('/student/mentors/${list[i].userId}'),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MentorListCard extends StatelessWidget {
  const _MentorListCard({required this.mentor, required this.onTap});
  final MentorProfile mentor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verified = mentor.verificationStatus == 'verified';
    final initial = mentor.displayName.isNotEmpty
        ? mentor.displayName.substring(0, 1)
        : '?';
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: mentor.avatarUrl != null
                    ? NetworkImage(mentor.avatarUrl!)
                    : null,
                child: mentor.avatarUrl == null
                    ? Text(initial,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(mentor.displayName,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified,
                              size: 15, color: AppColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [mentor.universityName, mentor.departmentName]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: AppColors.accent),
                        const SizedBox(width: 3),
                        Text(mentor.avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 5),
                        Text('(${mentor.reviewCount})',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        if (mentor.teachingSubjects.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                                mentor.teachingSubjects.take(3).join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _MentorFavHeart(mentorId: mentor.userId),
            ],
          ),
        ),
      ),
    );
  }
}

/// 멘토 목록 카드의 찜(하트) 버튼.
///
/// 찜 상태는 [favoriteIdsProvider]를 구독해 즉시 반영하고, 누르면
/// 토글 후 즐겨찾기 id 집합과 즐겨찾기 목록을 무효화해 마이페이지
/// "즐겨찾기한 멘토"까지 함께 갱신한다. IconButton이 자체적으로 탭을
/// 흡수하므로 카드 전체 onTap(상세 이동)과 충돌하지 않는다.
class _MentorFavHeart extends ConsumerWidget {
  const _MentorFavHeart({required this.mentorId});
  final String mentorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteIdsProvider).maybeWhen(
          data: (s) => s.contains(mentorId),
          orElse: () => false,
        );
    return IconButton(
      tooltip: isFav ? '찜 해제' : '찜하기',
      visualDensity: VisualDensity.compact,
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? AppColors.danger : AppColors.textDisabled,
      ),
      onPressed: () async {
        try {
          await ref.read(mentorsRepositoryProvider).toggleFavorite(mentorId);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '찜하기에 실패했어요: ${e.toString().replaceFirst('Exception: ', '')}'),
            ));
          }
          return;
        }
        ref.invalidate(favoriteIdsProvider);
        ref.invalidate(favoritesProvider);
      },
    );
  }
}

// ============================================================================
// 질문방 목록
// ============================================================================
class StudentRoomListScreen extends ConsumerWidget {
  const StudentRoomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('질문방'),
        actions: [
          TextButton(
            onPressed: () => context.push('/student/individual-questions'),
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
                message: '아직 질문방이 없어요.\n멘토를 구독하면 방이 만들어져요.',
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
                  return _RoomCard(
                    room: room,
                    onTap: () => context.push('/student/rooms/${room.id}'),
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

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mentorName = room.mentorName.isNotEmpty ? room.mentorName : '멘토';
    final subtitle = room.subscriptionLabel ?? '';
    final last = room.lastMessagePreview ?? '';
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderStrong),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryTint,
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mentorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primary)),
                    ],
                    if (last.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
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
// 질문방 상세 — ★ 연결노트/스캔 첨삭 진입점 (flagship 게이트웨이)
// ============================================================================
class StudentRoomDetailScreen extends ConsumerWidget {
  const StudentRoomDetailScreen({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider(roomId));
    final title = room.maybeWhen(
      data: (r) => (r != null && r.mentorName.isNotEmpty) ? r.mentorName : '질문방',
      orElse: () => '질문방',
    );
    final r = room.asData?.value;
    final used = ref.watch(weeklyUsageProvider(roomId)).asData?.value ?? 0;
    final planLc = (r?.subscriptionLabel ?? '').toLowerCase();
    final bool capUnlimited = planLc.contains('premium');
    final int capTotal = capUnlimited
        ? 0
        : (planLc.contains('standard')
            ? 9
            : (planLc.contains('limited') ? 4 : 0));
    final bool hasCap = capUnlimited || capTotal > 0;
    final int? capFabLimit =
        capUnlimited ? null : (capTotal > 0 ? capTotal : null);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hasCap)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: CapMeter(
                  used: used,
                  total: capTotal,
                  unlimited: capUnlimited,
                  planLabel: r?.subscriptionLabel,
                  renewLabel: '최근 7일 기준',
                ),
              ),
            // 질문 스레드 — question_threads 목록(클릭 → 스레드 상세)
            _SectionLabel('질문 스레드'),
            RoomThreadsSection(
              roomId: roomId,
              basePath: '/student/rooms/$roomId',
            ),
            const SizedBox(height: 24),

            // ★ 연결노트(필기) — 저장된 노트 목록 + 새 노트 작성
            _SectionLabel('연결노트'),
            ConnectionNotesSection(roomId: roomId, authorRole: 'student'),
            const SizedBox(height: 24),

            // ★ 스캔 첨삭 — 저장된 첨삭 목록 + 새 스캔
            _SectionLabel('스캔 첨삭'),
            ScanAnnotationsSection(
              roomId: roomId,
              authorRole: 'student',
              basePath: '/student/rooms/$roomId',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => createQuestionThread(
          context,
          ref,
          roomId: roomId,
          basePath: '/student/rooms/$roomId',
          weeklyLimit: capFabLimit,
        ),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('질문하기'),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
      );
}

// ============================================================================
// 맞춤의뢰 (학생)
// ============================================================================
class StudentCommissionScreen extends ConsumerWidget {
  const StudentCommissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(myCustomPostsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('맞춤 의뢰')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/student/commission/new'),
        icon: const Icon(Icons.add),
        label: const Text('새 의뢰'),
      ),
      body: ContentContainer(
        child: posts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(myCustomPostsProvider),
          ),
          data: (list) => list.isEmpty
              ? const AsyncEmptyView(
                  message: '아직 올린 의뢰가 없어요.\n오른쪽 아래 + 로 의뢰를 올려보세요.',
                  icon: Icons.assignment_outlined,
                )
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(myCustomPostsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => CommissionPostCard(
                      post: list[i],
                      showStatus: true,
                      onTap: () => context
                          .push('/student/commission/${list[i].id}'),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ============================================================================
// 마이페이지 (학생) — 프로필 + 내 구독(해지) + 빠른 링크
// ============================================================================
class StudentMeScreen extends ConsumerWidget {
  const StudentMeScreen({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref, Room room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구독을 해지할까요?'),
        content: Text('${room.mentorName} 구독이 해지되고 질문방이 닫혀요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('해지하기')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(mentorsRepositoryProvider).cancelSubscription(room.id);
    ref.invalidate(roomListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('구독을 해지했어요.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomListProvider);
    final wallet = ref.watch(walletProvider);
    final favorites = ref.watch(favoritesProvider);
    final balance =
        wallet.maybeWhen(data: (w) => '${w.balanceWon}', orElse: () => '—');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('마이페이지')),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.person, size: 30, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('데모 학생',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('학생 계정',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            _MeBalanceTile(
              balance: balance,
              onTap: () => context.push('/student/cash'),
            ),
            const SizedBox(height: 16),
            _MeLinkTile(
              icon: Icons.assignment_outlined,
              label: '내 맞춤의뢰',
              onTap: () => context.push('/student/commission'),
            ),
            _MeLinkTile(
              icon: Icons.notifications_outlined,
              label: '알림',
              onTap: () => context.push('/notifications'),
            ),
            _MeLinkTile(
              icon: Icons.support_agent_outlined,
              label: '고객지원',
              onTap: () => context.push('/support'),
            ),
            const SizedBox(height: 24),
            const Text('즐겨찾기한 멘토',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            favorites.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('즐겨찾기를 불러오지 못했어요: $e',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('멘토찾기·멘토 상세에서 하트를 눌러 찜해보세요.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)))
                  : Column(children: [
                      for (final m in list)
                        _MeFavTile(
                          mentor: m,
                          onTap: () =>
                              context.push('/student/mentors/${m.userId}'),
                        ),
                    ]),
            ),
            const SizedBox(height: 24),
            const Text('내 구독',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            rooms.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => AsyncErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(roomListProvider)),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('구독 중인 멘토가 없어요. 멘토를 찾아 구독해보세요.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)))
                  : Column(children: [
                      for (final r in list)
                        _MeSubTile(
                            room: r, onCancel: () => _cancel(context, ref, r)),
                    ]),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeBalanceTile extends StatelessWidget {
  const _MeBalanceTile({required this.balance, required this.onTap});
  final String balance;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('보유 캐시',
                      style: TextStyle(color: Color(0xFFD7E3FB), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('$balance 캐시',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Text('충전 →',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _MeLinkTile extends StatelessWidget {
  const _MeLinkTile(
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

class _MeSubTile extends StatelessWidget {
  const _MeSubTile({required this.room, required this.onCancel});
  final Room room;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primarySoft,
          child: Icon(Icons.school_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room.mentorName,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800)),
              if (room.subscriptionLabel != null) ...[
                const SizedBox(height: 2),
                Text(room.subscriptionLabel!,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
        TextButton(
          onPressed: onCancel,
          child: const Text('해지', style: TextStyle(color: AppColors.danger)),
        ),
      ]),
    );
  }
}

class _MeFavTile extends StatelessWidget {
  const _MeFavTile({required this.mentor, required this.onTap});
  final MentorProfile mentor;
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
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.person, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mentor.displayName,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                      [mentor.universityName, mentor.departmentName]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.favorite, color: AppColors.danger, size: 18),
          ]),
        ),
      ),
    );
  }
}
