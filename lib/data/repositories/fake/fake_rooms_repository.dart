import '../../../core/models/note.dart';
import '../../../core/models/user.dart';
import '../rooms_repository.dart';
import 'demo_store.dart';

/// 더미 구현 — Supabase 키가 없을 때 사용.
/// 시드 방 + 구독으로 생긴 방(DemoStore)을 함께 보여줘, 구독 직후 질문방 목록에
/// 새 방이 나타나는 흐름을 검증할 수 있습니다.
class FakeRoomsRepository implements RoomsRepository {
  final DemoStore _store = DemoStore.instance;

  Room get _seededStudentRoom => Room(
        id: 'demo-room-1',
        studentId: 'demo-student',
        mentorId: 'demo-mentor',
        mentorName: '김선생 멘토',
        studentName: '데모 학생',
        subscriptionLabel: '수학 · standard 구독',
        lastMessagePreview: '이번 주 미적분 질문 남겨두었어요',
        updatedAt: DateTime.now(),
      );

  @override
  Future<List<Room>> fetchRooms({
    required UserRole role,
    required String userId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (role == UserRole.mentor) {
      return [
        Room(
          id: 'demo-room-1',
          studentId: 'demo-student',
          mentorId: 'demo-mentor',
          studentName: '이학생',
          mentorName: '데모 멘토',
          subscriptionLabel: '수학 · standard · 미답변 1',
          lastMessagePreview: '이번 주 미적분 질문 남겨두었어요',
          updatedAt: DateTime.now(),
        ),
      ];
    }
    // 학생: 구독으로 생긴 방(최신) + 시드 방 — 해지된 건 제외
    final all = [..._store.subscribedRooms, _seededStudentRoom];
    return all.where((r) => !_store.cancelledRoomIds.contains(r.id)).toList();
  }

  @override
  Future<Room?> fetchRoom(String roomId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_store.cancelledRoomIds.contains(roomId)) return null;
    if (roomId == 'demo-room-1') return _seededStudentRoom;
    for (final r in _store.subscribedRooms) {
      if (r.id == roomId) return r;
    }
    return null;
  }
}
