import '../../../core/models/cash.dart';
import '../../../core/models/individual_question.dart';
import '../../../core/models/settlement.dart';
import '../individual_questions_repository.dart';
import 'demo_store.dart';

/// 더미 구현 — 예치는 지갑(walletCents) 차감 + 원장, 정산은 seededSettlements,
/// 환불은 지갑 복구로 반영되어 캐시/정산 화면과 일관되게 동작합니다.
class FakeIndividualQuestionsRepository implements IndividualQuestionsRepository {
  final DemoStore _store = DemoStore.instance;

  static const _meStudent = 'demo-student';
  static const _meMentor = 'demo-mentor';

  List<IndividualQuestion> get _list => _store.individualQuestions;

  void _replace(IndividualQuestion q) {
    final i = _list.indexWhere((e) => e.id == q.id);
    if (i >= 0) _list[i] = q;
  }

  IndividualQuestion? _find(String id) {
    for (final q in _list) {
      if (q.id == id) return q;
    }
    return null;
  }

  void _hold(int priceCash, String title) {
    final cents = priceCash * 100;
    if (_store.walletCents < cents) {
      throw Exception('잔액이 부족해요. 캐시를 충전해 주세요.');
    }
    _store.walletCents -= cents;
    _store.ledger.add(CashLedgerEntry(
      id: 'iqh${DateTime.now().microsecondsSinceEpoch}',
      amountCents: -cents,
      kind: 'escrow_hold',
      description: '개별질문 예치 · $title',
      createdAt: DateTime.now(),
    ));
  }

  void _refund(int priceCash, String title) {
    final cents = priceCash * 100;
    _store.walletCents += cents;
    _store.ledger.add(CashLedgerEntry(
      id: 'iqr${DateTime.now().microsecondsSinceEpoch}',
      amountCents: cents,
      kind: 'refund',
      description: '개별질문 환불 · $title',
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<List<IndividualQuestion>> fetchMine() async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final list = _list.where((q) => q.askerId == _meStudent).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<List<IndividualQuestion>> fetchAssignedForMentor() async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final list = _list
        .where((q) =>
            q.type == IQType.direct && q.designatedMentorId == _meMentor)
        .toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<List<IndividualQuestion>> listOpenForMentor() async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final list = _list
        .where((q) => q.type == IQType.open && q.status == IQStatus.open)
        .toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<IndividualQuestion?> fetchOne(String id) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return _find(id);
  }

  @override
  Future<List<IndividualQuestionMessage>> fetchMessages(String id) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return List.of(_store.iqMessages[id] ?? const []);
  }

  @override
  Future<int> mentorPrice(String mentorId) async {
    _store.ensureSeed();
    return _store.mentorIqPriceCash[mentorId] ?? 8000;
  }

  @override
  Future<int> myMentorPrice() async {
    _store.ensureSeed();
    return _store.mentorIqPriceCash[_meMentor] ?? 8000;
  }

  @override
  Future<void> setMyMentorPrice(int priceCash) async {
    _store.ensureSeed();
    if (priceCash <= 0) throw Exception('가격을 입력해 주세요.');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _store.mentorIqPriceCash[_meMentor] = priceCash;
  }

  @override
  Future<IndividualQuestion> createOpen({
    required String title,
    required String body,
    required int priceCash,
    String? idempotencyKey,
  }) async {
    _store.ensureSeed();
    if (priceCash <= 0) throw Exception('가격을 입력해 주세요.');
    await Future<void>.delayed(const Duration(milliseconds: 260));
    _hold(priceCash, title);
    final now = DateTime.now();
    final q = IndividualQuestion(
      id: 'iq${now.microsecondsSinceEpoch}',
      type: IQType.open,
      status: IQStatus.open,
      title: title,
      body: body,
      priceCash: priceCash,
      askerId: _meStudent,
      askerLabel: '학생',
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 48)),
    );
    _list.insert(0, q);
    return q;
  }

  @override
  Future<IndividualQuestion> createDirect({
    required String mentorId,
    required String mentorName,
    required String title,
    required String body,
    String? idempotencyKey,
  }) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final price = await mentorPrice(mentorId);
    _hold(price, title);
    final now = DateTime.now();
    final q = IndividualQuestion(
      id: 'iq${now.microsecondsSinceEpoch}',
      type: IQType.direct,
      status: IQStatus.assigned,
      title: title,
      body: body,
      priceCash: price,
      askerId: _meStudent,
      askerLabel: '학생',
      designatedMentorId: mentorId,
      designatedMentorName: mentorName,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 72)),
    );
    _list.insert(0, q);
    _store.pushNotification(
      type: 'question',
      title: '새 1:1 질문이 도착했어요',
      body: '“$title” 지정 질문이 들어왔어요. 답변해 주세요.',
    );
    return q;
  }

  @override
  Future<void> claimOpen(String id) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final q = _find(id);
    if (q == null) throw Exception('질문을 찾을 수 없어요.');
    if (q.status != IQStatus.open) throw Exception('이미 다른 멘토가 가져갔어요.');
    _replace(q.copyWith(
      status: IQStatus.claimed,
      claimedMentorId: _meMentor,
      claimedMentorName: '나',
      expiresAt: DateTime.now().add(const Duration(hours: 48)),
    ));
    _store.pushNotification(
      type: 'question',
      title: '멘토가 질문을 가져갔어요',
      body: '“${q.title}” 공개 질문을 멘토가 맡았어요.',
    );
  }

  @override
  Future<IndividualQuestionMessage> answer({
    required String id,
    required String body,
  }) async {
    _store.ensureSeed();
    if (body.trim().isEmpty) throw Exception('답변 내용을 입력해 주세요.');
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final q = _find(id);
    if (q == null) throw Exception('질문을 찾을 수 없어요.');
    if (!q.awaitingAnswer) throw Exception('답변할 수 있는 상태가 아니에요.');
    final msg = IndividualQuestionMessage(
      id: 'iqm${DateTime.now().microsecondsSinceEpoch}',
      questionId: id,
      authorId: _meMentor,
      body: body.trim(),
      createdAt: DateTime.now(),
    );
    (_store.iqMessages[id] ??= []).add(msg);
    _replace(q.copyWith(status: IQStatus.answered));
    _store.pushNotification(
      type: 'question',
      title: '멘토가 답변했어요',
      body: '“${q.title}” 개별 질문에 답변이 도착했어요. 확인해보세요.',
    );
    return msg;
  }

  @override
  Future<void> confirmAndRelease(String id) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final q = _find(id);
    if (q == null) throw Exception('질문을 찾을 수 없어요.');
    if (q.status != IQStatus.answered) {
      throw Exception('답변 완료 후에 확인할 수 있어요.');
    }
    final share = (q.priceCash * 0.8).round(); // 멘토 80%
    _store.seededSettlements.add(SettlementEntry(
      id: 'iqs-${q.id}',
      label: '개별질문 정산 — ${q.title}',
      amountCash: share,
      kind: 'individual',
      settled: true,
      createdAt: DateTime.now(),
    ));
    _replace(q.copyWith(status: IQStatus.released));
    _store.pushNotification(
      type: 'cash',
      title: '개별질문 정산 완료',
      body: '“${q.title}” 답변이 확정되어 ${share}캐시가 정산됐어요.',
    );
  }

  @override
  Future<void> cancel(String id) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final q = _find(id);
    if (q == null) throw Exception('질문을 찾을 수 없어요.');
    const cancelable = {
      IQStatus.open,
      IQStatus.assigned,
      IQStatus.claimed,
      IQStatus.escrowed,
    };
    if (!cancelable.contains(q.status)) {
      throw Exception('지금은 취소할 수 없어요.');
    }
    _refund(q.priceCash, q.title);
    _replace(q.copyWith(status: IQStatus.canceled));
  }
}
