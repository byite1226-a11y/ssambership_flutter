import '../../core/models/note.dart';
import '../../core/models/user.dart';

/// 질문방 데이터 창구.
///
/// 화면은 이 인터페이스에만 의존하고, 실제 출처(더미/Supabase)는 모릅니다.
/// 구현은 두 가지:
///  - FakeRoomsRepository    : 더미데이터 (키 주입 전)
///  - SupabaseRoomsRepository : 실제 DB (mentor_student_rooms)
/// 전환은 providers/repository_providers.dart 한 곳에서.
abstract class RoomsRepository {
  /// 현재 사용자의 질문방 목록.
  /// - 학생: 내가 student_id 인 방
  /// - 멘토: 내가 mentor_id 인 방 (미답변 우선 정렬은 추후 RPC/뷰로)
  Future<List<Room>> fetchRooms({
    required UserRole role,
    required String userId,
  });

  /// 단일 방 조회 (상세 화면용).
  Future<Room?> fetchRoom(String roomId);
}
