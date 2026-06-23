import '../../../core/models/community.dart';
import '../community_repository.dart';

/// 더미 구현 — 게시판/숏폼/댓글/좋아요를 메모리에 보관(Provider 캐시로 세션 유지).
class FakeCommunityRepository implements CommunityRepository {
  final List<CommunityPost> _posts = [];
  final List<ShortformPost> _shorts = [];
  final List<CommunityComment> _comments = [];
  final Set<String> _likes = {}; // 'type:id'
  bool _seeded = false;

  String _key(String type, String id) => '$type:$id';

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    _posts.addAll([
      CommunityPost(
        id: 'cp1',
        authorLabel: '서울대 수학 멘토',
        title: '내신 수학, 오답노트는 이렇게 쓰세요',
        body: '틀린 문제를 다시 푸는 것보다 "왜 그 풀이를 떠올리지 못했는지"를 적는 게 핵심이에요. '
            '저는 학생들에게 3단계 오답노트를 추천합니다…',
        category: '학습법',
        likeCount: 42,
        commentCount: 2,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      CommunityPost(
        id: 'cp2',
        authorLabel: '쌤버십 회원',
        title: '수능 D-200 루틴 공유합니다',
        body: '아침 6시 기상, 오답 30분, 인강 2개… 다들 어떻게 루틴 짜시나요?',
        category: '수험생활',
        likeCount: 18,
        commentCount: 1,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      CommunityPost(
        id: 'cp3',
        authorLabel: '연세대 영어 멘토',
        title: '영어 지문, 끊어읽기 훈련 자료',
        body: '구문 분석이 약한 학생을 위한 끊어읽기 연습 방법을 정리했어요. 출처: 직접 제작.',
        category: '자료',
        likeCount: 31,
        commentCount: 0,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ]);
    _shorts.addAll([
      ShortformPost(
        id: 'sf1',
        authorLabel: '서울대 수학 멘토',
        caption: '미적분 30번 1분 풀이 ⚡',
        category: '수학',
        likeCount: 120,
        commentCount: 1,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      ShortformPost(
        id: 'sf2',
        authorLabel: '연세대 영어 멘토',
        caption: '헷갈리는 가정법 3초 정리',
        category: '영어',
        likeCount: 88,
        createdAt: now.subtract(const Duration(hours: 9)),
      ),
      ShortformPost(
        id: 'sf3',
        authorLabel: 'KAIST 물리 멘토',
        caption: '관성 모멘트 직관적으로 이해하기',
        category: '과학',
        likeCount: 64,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      ShortformPost(
        id: 'sf4',
        authorLabel: '쌤버십 회원',
        caption: '공부 자극 타임랩스 📚',
        category: '동기부여',
        likeCount: 203,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ]);
    _comments.addAll([
      CommunityComment(
        id: 'cm1',
        postId: 'cp1',
        postType: 'board',
        authorLabel: '쌤버십 회원',
        body: '오답노트 3단계 너무 좋네요! 바로 적용해볼게요.',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      CommunityComment(
        id: 'cm2',
        postId: 'cp1',
        postType: 'board',
        authorLabel: '고2 학생',
        body: '왜 못 떠올렸는지를 적는다는 발상이 신선해요.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      CommunityComment(
        id: 'cm3',
        postId: 'cp2',
        postType: 'board',
        authorLabel: '재수생',
        body: '저도 아침 루틴 만들고 싶은데 기상이 제일 어렵네요 ㅠ',
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
      CommunityComment(
        id: 'cm4',
        postId: 'sf1',
        postType: 'shortform',
        authorLabel: '고3 학생',
        body: '1분 만에 이해됐어요 미쳤다',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    ]);
  }

  CommunityPost _withLike(CommunityPost p) =>
      p.copyWith(liked: _likes.contains(_key('board', p.id)));
  ShortformPost _withLikeS(ShortformPost s) =>
      s.copyWith(liked: _likes.contains(_key('shortform', s.id)));

  @override
  Future<List<CommunityPost>> fetchPosts() async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final list = _posts.map(_withLike).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<CommunityPost?> fetchPost(String id) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    for (final p in _posts) {
      if (p.id == id) return _withLike(p);
    }
    return null;
  }

  @override
  Future<CommunityPost> createPost({
    required String title,
    required String body,
    String? category,
  }) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final post = CommunityPost(
      id: 'cp${DateTime.now().microsecondsSinceEpoch}',
      authorLabel: '나 (데모)',
      title: title,
      body: body,
      category: category,
      createdAt: DateTime.now(),
    );
    _posts.insert(0, post);
    return post;
  }

  @override
  Future<List<ShortformPost>> fetchShortforms() async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final list = _shorts.map(_withLikeS).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<ShortformPost?> fetchShortform(String id) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    for (final s in _shorts) {
      if (s.id == id) return _withLikeS(s);
    }
    return null;
  }

  @override
  Future<List<CommunityComment>> fetchComments(
      String postId, String postType) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final list = _comments
        .where((c) => c.postId == postId && c.postType == postType)
        .toList();
    list.sort((a, b) =>
        (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<CommunityComment> addComment({
    required String postId,
    required String postType,
    required String body,
  }) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final c = CommunityComment(
      id: 'cm${DateTime.now().microsecondsSinceEpoch}',
      postId: postId,
      postType: postType,
      authorLabel: '나 (데모)',
      body: body,
      createdAt: DateTime.now(),
    );
    _comments.add(c);
    // 댓글 수 +1
    if (postType == 'board') {
      final i = _posts.indexWhere((p) => p.id == postId);
      if (i >= 0) {
        _posts[i] = _posts[i].copyWith(commentCount: _posts[i].commentCount + 1);
      }
    } else {
      final i = _shorts.indexWhere((s) => s.id == postId);
      if (i >= 0) {
        _shorts[i] =
            _shorts[i].copyWith(commentCount: _shorts[i].commentCount + 1);
      }
    }
    return c;
  }

  @override
  Future<bool> toggleLike({
    required String postId,
    required String postType,
  }) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final key = _key(postType, postId);
    final nowLiked = !_likes.contains(key);
    if (nowLiked) {
      _likes.add(key);
    } else {
      _likes.remove(key);
    }
    final delta = nowLiked ? 1 : -1;
    if (postType == 'board') {
      final i = _posts.indexWhere((p) => p.id == postId);
      if (i >= 0) {
        _posts[i] =
            _posts[i].copyWith(likeCount: _posts[i].likeCount + delta);
      }
    } else {
      final i = _shorts.indexWhere((s) => s.id == postId);
      if (i >= 0) {
        _shorts[i] =
            _shorts[i].copyWith(likeCount: _shorts[i].likeCount + delta);
      }
    }
    return nowLiked;
  }
}
