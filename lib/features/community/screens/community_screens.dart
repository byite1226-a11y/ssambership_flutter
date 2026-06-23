import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/community.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';
import '../../support/screens/support_screen.dart';

// ============================================================================
// 커뮤니티 홈 (숏폼 스트립 + 게시판 피드) — 학생/멘토 공용
// ============================================================================
class CommunityHomeScreen extends ConsumerWidget {
  const CommunityHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shorts = ref.watch(shortformFeedProvider);
    final posts = ref.watch(communityFeedProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('커뮤니티')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/community/new'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('글쓰기'),
      ),
      body: ContentContainer(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(shortformFeedProvider);
            ref.invalidate(communityFeedProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text('숏폼',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              SizedBox(
                height: 188,
                child: shorts.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                      child: Text('숏폼을 불러오지 못했어요: $e',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary))),
                  data: (list) => ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _ShortCard(
                      short: list[i],
                      onTap: () =>
                          context.push('/community/shortform/${list[i].id}'),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 26, 20, 10),
                child: Text('게시판',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              posts.when(
                loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: AsyncErrorView(
                      message: '$e',
                      onRetry: () => ref.invalidate(communityFeedProvider)),
                ),
                data: (list) => list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('아직 게시글이 없어요.',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)))
                    : Column(
                        children: [
                          for (final p in list)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: _PostCard(
                                post: p,
                                onTap: () =>
                                    context.push('/community/post/${p.id}'),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortCard extends StatelessWidget {
  const _ShortCard({required this.short, required this.onTap});
  final ShortformPost short;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: 128,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(short.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.favorite, size: 12, color: AppColors.danger),
              const SizedBox(width: 3),
              Text('${short.likeCount}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});
  final CommunityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              Row(children: [
                if (post.category != null) ...[
                  _Chip(post.category!),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(post.authorLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(post.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4)),
              const SizedBox(height: 12),
              Row(children: [
                Icon(post.liked ? Icons.favorite : Icons.favorite_border,
                    size: 15,
                    color: post.liked
                        ? AppColors.danger
                        : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${post.likeCount}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(width: 14),
                const Icon(Icons.mode_comment_outlined,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${post.commentCount}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w700)),
      );
}

// ============================================================================
// 게시글 상세
// ============================================================================
class CommunityPostDetailScreen extends ConsumerWidget {
  const CommunityPostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(communityPostProvider(postId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') {
                showReportDialog(context, ref,
                    targetType: 'post', targetId: postId);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('신고')),
            ],
          ),
        ],
      ),
      body: post.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(communityPostProvider(postId))),
        data: (p) {
          if (p == null) {
            return const Center(
                child: Text('게시글을 찾을 수 없어요.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return ContentContainer(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  if (p.category != null) ...[
                    _Chip(p.category!),
                    const SizedBox(width: 8),
                  ],
                  Text(p.authorLabel,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ]),
                const SizedBox(height: 12),
                Text(p.title,
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.3)),
                const SizedBox(height: 14),
                Text(p.body,
                    style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.7,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                _LikeRow(
                  liked: p.liked,
                  count: p.likeCount,
                  onTap: () async {
                    await ref
                        .read(communityRepositoryProvider)
                        .toggleLike(postId: postId, postType: 'board');
                    ref.invalidate(communityPostProvider(postId));
                    ref.invalidate(communityFeedProvider);
                  },
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 16),
                _CommentsSection(postId: postId, postType: 'board'),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 숏폼 상세
// ============================================================================
class ShortformDetailScreen extends ConsumerWidget {
  const ShortformDetailScreen({super.key, required this.shortformId});
  final String shortformId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sf = ref.watch(shortformProvider(shortformId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('숏폼'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') {
                showReportDialog(context, ref,
                    targetType: 'shortform', targetId: shortformId);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('신고')),
            ],
          ),
        ],
      ),
      body: sf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(shortformProvider(shortformId))),
        data: (s) {
          if (s == null) {
            return const Center(
                child: Text('숏폼을 찾을 수 없어요.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return ContentContainer(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 64)),
                ),
                const SizedBox(height: 16),
                if (s.category != null) ...[
                  _Chip(s.category!),
                  const SizedBox(height: 10),
                ],
                Text(s.caption,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, height: 1.4)),
                const SizedBox(height: 4),
                Text(s.authorLabel,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                _LikeRow(
                  liked: s.liked,
                  count: s.likeCount,
                  onTap: () async {
                    await ref
                        .read(communityRepositoryProvider)
                        .toggleLike(
                            postId: shortformId, postType: 'shortform');
                    ref.invalidate(shortformProvider(shortformId));
                    ref.invalidate(shortformFeedProvider);
                  },
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 16),
                _CommentsSection(postId: shortformId, postType: 'shortform'),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LikeRow extends StatelessWidget {
  const _LikeRow(
      {required this.liked, required this.count, required this.onTap});
  final bool liked;
  final int count;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onTap(),
      style: OutlinedButton.styleFrom(
        foregroundColor: liked ? AppColors.danger : AppColors.textSecondary,
        side: BorderSide(
            color: liked ? AppColors.danger : AppColors.border),
      ),
      icon: Icon(liked ? Icons.favorite : Icons.favorite_border, size: 18),
      label: Text('좋아요 $count'),
    );
  }
}

// ============================================================================
// 공용 댓글 섹션
// ============================================================================
class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({required this.postId, required this.postType});
  final String postId;
  final String postType;
  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  (String, String) get _key => (widget.postId, widget.postType);

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityRepositoryProvider).addComment(
            postId: widget.postId,
            postType: widget.postType,
            body: text,
          );
      _ctrl.clear();
      ref.invalidate(commentsProvider(_key));
      if (widget.postType == 'board') {
        ref.invalidate(communityPostProvider(widget.postId));
        ref.invalidate(communityFeedProvider);
      } else {
        ref.invalidate(shortformProvider(widget.postId));
        ref.invalidate(shortformFeedProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('댓글 등록 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(commentsProvider(_key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('댓글',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '댓글을 입력하세요',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
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
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('등록'),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        comments.when(
          loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('댓글을 불러오지 못했어요: $e',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('첫 댓글을 남겨보세요.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)))
              : Column(children: [for (final c in list) _CommentTile(c)]),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile(this.comment);
  final CommunityComment comment;
  @override
  Widget build(BuildContext context) {
    final d = comment.createdAt;
    final when = d == null ? '' : '${d.month}/${d.day}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.person, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(comment.authorLabel,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text(when,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ]),
                const SizedBox(height: 3),
                Text(comment.body,
                    style: const TextStyle(fontSize: 13.5, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 글쓰기
// ============================================================================
class CommunityComposeScreen extends ConsumerStatefulWidget {
  const CommunityComposeScreen({super.key});
  @override
  ConsumerState<CommunityComposeScreen> createState() =>
      _CommunityComposeScreenState();
}

class _CommunityComposeScreenState
    extends ConsumerState<CommunityComposeScreen> {
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _body = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('제목과 내용을 입력해 주세요.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(communityRepositoryProvider).createPost(
            title: _title.text.trim(),
            body: _body.text.trim(),
            category:
                _category.text.trim().isEmpty ? null : _category.text.trim(),
          );
      ref.invalidate(communityFeedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('게시글을 올렸어요.')));
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('글쓰기')),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field('제목', _title, '제목을 입력하세요'),
            _field('카테고리', _category, '예) 학습법 · 자료 · 수험생활'),
            _field('내용', _body, '내용을 입력하세요', maxLines: 8),
            const SizedBox(height: 8),
            const Text('타인의 저작물을 올릴 때는 출처를 표기하고 권리를 확인해 주세요.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
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
                    : const Text('게시하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, String hint,
      {int maxLines = 1}) {
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
            controller: c,
            maxLines: maxLines,
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
