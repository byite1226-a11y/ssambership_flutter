import '../../core/models/community.dart';

/// 커뮤니티(게시판/숏폼/댓글/좋아요) 데이터 창구.
abstract class CommunityRepository {
  // 게시판
  Future<List<CommunityPost>> fetchPosts();
  Future<CommunityPost?> fetchPost(String id);
  Future<CommunityPost> createPost({
    required String title,
    required String body,
    String? category,
  });

  // 숏폼
  Future<List<ShortformPost>> fetchShortforms();
  Future<ShortformPost?> fetchShortform(String id);

  // 댓글 (board/shortform 공용)
  Future<List<CommunityComment>> fetchComments(String postId, String postType);
  Future<CommunityComment> addComment({
    required String postId,
    required String postType,
    required String body,
  });

  /// 좋아요 토글 → 변경된 liked 상태 반환.
  Future<bool> toggleLike({required String postId, required String postType});
}
