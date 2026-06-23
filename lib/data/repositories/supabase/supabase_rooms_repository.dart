import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/note.dart';
import '../../../core/models/user.dart';
import '../rooms_repository.dart';

/// 실DB 구현 — Supabase `mentor_student_rooms` 조회.
///
/// 표(mentor_student_rooms)의 RLS가 "방 당사자만 조회"를 보장하므로, 여기서는
/// 내 역할 컬럼(student_id/mentor_id) 기준으로 필터만 겁니다.
///
/// 주의(다음 단계 TODO):
///  - 멘토명/학생명/구독 라벨/마지막 메시지는 조인 또는 뷰가 필요합니다.
///    현재는 기본 컬럼만 매핑하므로 이름이 비어 보일 수 있습니다. 실제 운영
///    스키마 확정 후 select 에 조인(또는 전용 RPC/뷰)을 추가하세요.
class SupabaseRoomsRepository implements RoomsRepository {
  SupabaseRoomsRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Room>> fetchRooms({
    required UserRole role,
    required String userId,
  }) async {
    final column = role == UserRole.mentor ? 'mentor_id' : 'student_id';
    final rows = await _db
        .from('mentor_student_rooms')
        .select()
        .eq(column, userId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((e) => Room.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Room?> fetchRoom(String roomId) async {
    final row = await _db
        .from('mentor_student_rooms')
        .select()
        .eq('id', roomId)
        .maybeSingle();
    return row == null ? null : Room.fromMap(row);
  }
}
