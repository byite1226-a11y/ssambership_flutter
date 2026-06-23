import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/community.dart';
import '../community_repository.dart';

/// 실DB 구현 — community_posts / shortform_posts / community_comments / post_reactions.
///
/// 좋아요 수·댓글 수 집계는 뷰/RPC가 이상적이나, 여기서는 단순 조회로 두고
/// liked 여부만 post_reactions로 확인합니다(게시판). 숏폼 좋아요는 운영 정책에
/// 맞춰 확장 필요(아래는 best-effort).
class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this._db);

  final SupabaseClient _db;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<List<CommunityPost>> fetchPosts() async {
    final rows = await _db
        .from('community_posts')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => CommunityPost.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CommunityPost?> fetchPost(String id) async {
    final row =
        await _db.from('community_posts').select().eq('id', id).maybeSingle();
    return row == null ? null : CommunityPost.fromMap(row);
  }

  @override
  Future<CommunityPost> createPost({
    required String title,
    required String body,
    String? category,
  }) async {
    final values = <String, dynamic>{
      'author_id': _uid,
      'title': title,
      'body': body,
      if (category != null) 'category': category,
    };
    final row = await _db
        .from('community_posts')
        .insert(values)
        .select()
        .single();
    return CommunityPost.fromMap(row);
  }

  @override
  Future<List<ShortformPost>> fetchShortforms() async {
    final rows = await _db
        .from('shortform_posts')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => ShortformPost.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ShortformPost?> fetchShortform(String id) async {
    final row =
        await _db.from('shortform_posts').select().eq('id', id).maybeSingle();
    return row == null ? null : ShortformPost.fromMap(row);
  }

  @override
  Future<List<CommunityComment>> fetchComments(
      String postId, String postType) async {
    final rows = await _db
        .from('community_comments')
        .select()
        .eq('post_id', postId)
        .eq('post_type', postType)
        .eq('status', 'visible')
        .order('created_at', ascending: true);
    return (rows as List)
        .map((e) => CommunityComment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CommunityComment> addComment({
    required String postId,
    required String postType,
    required String body,
  }) async {
    final values = <String, dynamic>{
      'post_id': postId,
      'post_type': postType,
      'author_id': _uid,
      'body': body,
    };
    final row = await _db
        .from('community_comments')
        .insert(values)
        .select()
        .single();
    return CommunityComment.fromMap(row);
  }

  @override
  Future<bool> toggleLike({
    required String postId,
    required String postType,
  }) async {
    // 게시판: post_reactions(type='like') 토글. (숏폼은 정책에 맞춰 확장)
    final existing = await _db
        .from('post_reactions')
        .select('id')
        .eq('user_id', _uid ?? '')
        .eq('post_id', postId)
        .eq('type', 'like')
        .maybeSingle();
    if (existing == null) {
      await _db.from('post_reactions').insert({
        'user_id': _uid,
        'post_id': postId,
        'type': 'like',
      });
      return true;
    } else {
      await _db
          .from('post_reactions')
          .delete()
          .eq('id', existing['id'] as Object);
      return false;
    }
  }
}
