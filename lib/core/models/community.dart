/// 커뮤니티(게시판/숏폼/댓글) 모델.
library;

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorLabel,
    required this.title,
    required this.body,
    this.category,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
    this.createdAt,
  });

  final String id;
  final String authorLabel;
  final String title;
  final String body;
  final String? category;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final DateTime? createdAt;

  CommunityPost copyWith({int? likeCount, bool? liked, int? commentCount}) =>
      CommunityPost(
        id: id,
        authorLabel: authorLabel,
        title: title,
        body: body,
        category: category,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        liked: liked ?? this.liked,
        createdAt: createdAt,
      );

  factory CommunityPost.fromMap(Map<String, dynamic> m) => CommunityPost(
        id: m['id'] as String,
        authorLabel: (m['author_label'] as String?) ??
            (m['author_role'] as String?) ??
            '쌤버십 회원',
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? (m['content'] as String?) ?? '',
        category: m['category'] as String?,
        likeCount: (m['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (m['comment_count'] as num?)?.toInt() ?? 0,
        createdAt: _cDate(m['created_at']),
      );
}

class ShortformPost {
  const ShortformPost({
    required this.id,
    required this.authorLabel,
    required this.caption,
    this.category,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
    this.createdAt,
  });

  final String id;
  final String authorLabel;
  final String caption;
  final String? category;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final DateTime? createdAt;

  ShortformPost copyWith({int? likeCount, bool? liked, int? commentCount}) =>
      ShortformPost(
        id: id,
        authorLabel: authorLabel,
        caption: caption,
        category: category,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        liked: liked ?? this.liked,
        createdAt: createdAt,
      );

  factory ShortformPost.fromMap(Map<String, dynamic> m) => ShortformPost(
        id: m['id'] as String,
        authorLabel: (m['author_label'] as String?) ??
            (m['author_role'] as String?) ??
            '쌤버십 회원',
        caption: (m['title'] as String?) ??
            (m['text'] as String?) ??
            (m['body'] as String?) ??
            (m['content'] as String?) ??
            '',
        category: m['category'] as String?,
        likeCount: (m['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (m['comment_count'] as num?)?.toInt() ?? 0,
        createdAt: _cDate(m['created_at']),
      );
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.postType, // 'board' | 'shortform'
    required this.authorLabel,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String postId;
  final String postType;
  final String authorLabel;
  final String body;
  final DateTime? createdAt;

  factory CommunityComment.fromMap(Map<String, dynamic> m) => CommunityComment(
        id: m['id'] as String,
        postId: (m['post_id'] as String?) ?? '',
        postType: (m['post_type'] as String?) ?? 'board',
        authorLabel: (m['author_label'] as String?) ?? '쌤버십 회원',
        body: (m['body'] as String?) ?? '',
        createdAt: _cDate(m['created_at']),
      );
}

DateTime? _cDate(dynamic v) =>
    v is String ? DateTime.tryParse(v) : (v is DateTime ? v : null);
