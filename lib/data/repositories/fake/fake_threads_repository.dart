import '../../../core/models/note.dart';
import '../threads_repository.dart';

/// 더미 구현 — 메모리에 스레드/메시지를 저장합니다.
/// post/create 가 실제로 반영되어, 키 없이도 "질문 작성 → 목록 갱신"을
/// 데모로 확인할 수 있습니다. (Provider가 인스턴스를 캐시하므로 저장 유지)
class FakeThreadsRepository implements ThreadsRepository {
  final Map<String, List<QuestionThread>> _threads = {};
  final Map<String, List<QuestionMessage>> _messages = {};
  bool _seeded = false;

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    _threads['demo-room-1'] = [
      QuestionThread(
        id: 't1',
        roomId: 'demo-room-1',
        title: '미적분 12번 문제 풀이',
        status: ThreadStatus.answered,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      QuestionThread(
        id: 't2',
        roomId: 'demo-room-1',
        title: '함수 극한 개념 질문',
        status: ThreadStatus.open,
        createdAt: now,
      ),
    ];
    _messages['t1'] = [
      QuestionMessage(
        id: 'm1',
        threadId: 't1',
        authorId: 'demo-student',
        body: '12번 풀이 과정이 잘 이해가 안 돼요.',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      QuestionMessage(
        id: 'm2',
        threadId: 't1',
        authorId: 'demo-mentor',
        body: '먼저 도함수를 구하고, 부호 변화를 보면 풀려요. 같이 해볼까요?',
        createdAt: now.subtract(const Duration(days: 1, hours: 1)),
      ),
    ];
    _messages['t2'] = [
      QuestionMessage(
        id: 'm3',
        threadId: 't2',
        authorId: 'demo-student',
        body: '좌극한과 우극한이 다를 때 극한이 없다고 보면 되나요?',
        createdAt: now,
      ),
    ];
  }

  @override
  Future<List<QuestionThread>> fetchThreads(String roomId) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List.of(_threads[roomId] ?? const []);
  }

  @override
  Future<List<QuestionMessage>> fetchMessages(String threadId) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List.of(_messages[threadId] ?? const []);
  }

  @override
  Future<QuestionMessage> postMessage({
    required String threadId,
    required String authorId,
    required String body,
  }) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final msg = QuestionMessage(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      threadId: threadId,
      authorId: authorId,
      body: body,
      createdAt: DateTime.now(),
    );
    (_messages[threadId] ??= []).add(msg);
    return msg;
  }

  @override
  Future<QuestionThread> createThread({
    required String roomId,
    required String title,
  }) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final thread = QuestionThread(
      id: 't${DateTime.now().microsecondsSinceEpoch}',
      roomId: roomId,
      title: title,
      status: ThreadStatus.open,
      createdAt: DateTime.now(),
    );
    (_threads[roomId] ??= []).insert(0, thread);
    _messages[thread.id] = [];
    return thread;
  }

  @override
  Future<int> weeklyQuestionCount(String roomId) async {
    _seed();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final since = DateTime.now().subtract(const Duration(days: 7));
    final list = _threads[roomId] ?? const <QuestionThread>[];
    return list
        .where((t) => (t.createdAt ?? DateTime.now()).isAfter(since))
        .length;
  }
}
