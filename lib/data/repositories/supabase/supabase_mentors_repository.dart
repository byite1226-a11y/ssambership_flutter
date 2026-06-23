import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/review.dart';
import '../../../core/models/user.dart';
import '../mentors_repository.dart';

/// 실DB 구현 — 멘토 디렉터리/프로필 RPC + 구독 RPC.
///
/// 주의: RPC 인자/반환 형태는 운영 함수 시그니처에 맞춰 확정해야 합니다.
///  - mentor_directory_list / mentor_user_public: 읽기
///  - record_subscription_cash_debit: 캐시 차감 + 구독 + 방 생성(원자적)
class SupabaseMentorsRepository implements MentorsRepository {
  SupabaseMentorsRepository(this._db);

  final SupabaseClient _db;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<List<MentorProfile>> fetchMentors({String? subject}) async {
    final res = await _db.rpc('mentor_directory_list', params: {
      if (subject != null && subject.isNotEmpty) 'p_subject': subject,
    });
    final list = (res is List) ? res : const [];
    return list
        .map((e) => MentorProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MentorProfile?> fetchMentor(String mentorId) async {
    final res = await _db
        .rpc('mentor_user_public', params: {'p_user_id': mentorId});
    if (res is Map<String, dynamic>) return MentorProfile.fromMap(res);
    if (res is List && res.isNotEmpty && res.first is Map) {
      return MentorProfile.fromMap(res.first as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<SubscribeResult> subscribe({
    required String mentorId,
    required String mentorName,
    required PlanType plan,
    String? subject,
  }) async {
    // record_subscription_cash_debit: 캐시 차감 + 구독 + 방 생성을 한 번에.
    final res = await _db.rpc('record_subscription_cash_debit', params: {
      'p_mentor_id': mentorId,
      'p_plan_id': plan.name, // 'limited' | 'standard' | 'premium'
    });

    String roomId = '';
    Map? row;
    if (res is Map) {
      row = res;
    } else if (res is List && res.isNotEmpty && res.first is Map) {
      row = res.first as Map;
    }
    if (row != null) {
      roomId = (row['mentor_student_room_id'] ??
              row['room_id'] ??
              row['id'] ??
              '') as String;
    }
    return SubscribeResult(roomId: roomId);
  }

  @override
  Future<void> cancelSubscription(String roomId) async {
    // 구독 해지: subscriptions 상태 변경(운영 정책에 맞춰 컬럼/RPC 확정 필요).
    await _db
        .from('subscriptions')
        .update({'status': 'cancelled'}).eq('mentor_student_room_id', roomId);
  }

  // ── 리뷰 / 즐겨찾기 ─────────────────────────────────────────────────────

  @override
  Future<List<Review>> fetchReviews(String mentorId) async {
    final rows = await _db
        .from('reviews')
        .select()
        .eq('mentor_id', mentorId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => Review.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Review> addReview({
    required String mentorId,
    required int rating,
    required String body,
  }) async {
    final row = await _db
        .from('reviews')
        .insert({
          'mentor_id': mentorId,
          'author_id': _uid,
          'rating': rating,
          'body': body,
        })
        .select()
        .single();
    return Review.fromMap(row);
  }

  @override
  Future<bool> toggleFavorite(String mentorId) async {
    final existing = await _db
        .from('favorites')
        .select('id')
        .eq('user_id', _uid ?? '')
        .eq('mentor_id', mentorId)
        .maybeSingle();
    if (existing == null) {
      await _db
          .from('favorites')
          .insert({'user_id': _uid, 'mentor_id': mentorId});
      return true;
    } else {
      await _db.from('favorites').delete().eq('id', existing['id'] as Object);
      return false;
    }
  }

  @override
  Future<List<MentorProfile>> fetchFavorites() async {
    final ids = await fetchFavoriteIds();
    if (ids.isEmpty) return [];
    final rows = await _db
        .from('mentor_profiles')
        .select()
        .inFilter('user_id', ids.toList());
    return (rows as List)
        .map((e) => MentorProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Set<String>> fetchFavoriteIds() async {
    final rows = await _db
        .from('favorites')
        .select('mentor_id')
        .eq('user_id', _uid ?? '');
    return {
      for (final r in (rows as List)) (r['mentor_id'] as String),
    };
  }
}
