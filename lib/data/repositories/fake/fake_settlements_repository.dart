import '../../../core/models/settlement.dart';
import '../settlements_repository.dart';
import 'demo_store.dart';

/// 더미 구현 — 정산 항목을 (시드 구독 정산 + 멘토 주문에서 파생)으로 계산하고
/// 출금 요청/내역을 메모리에 보관.
class FakeSettlementsRepository implements SettlementsRepository {
  final DemoStore _store = DemoStore.instance;

  List<SettlementEntry> _all() {
    _store.ensureSeed();
    final list = <SettlementEntry>[..._store.seededSettlements];
    for (final o in _store.orders) {
      final share = (o.amountCash * 0.8).round(); // 의뢰 80%
      if (o.status == 'accepted') {
        list.add(SettlementEntry(
          id: 'sto-${o.id}',
          label: '의뢰 정산 — ${o.title}',
          amountCash: share,
          kind: 'order',
          settled: true,
          createdAt: o.createdAt,
        ));
      } else if (o.status == 'in_progress' || o.status == 'delivered') {
        list.add(SettlementEntry(
          id: 'sto-${o.id}',
          label: '의뢰 예정 — ${o.title}',
          amountCash: share,
          kind: 'order',
          settled: false,
          createdAt: o.createdAt,
        ));
      }
    }
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  int _settledTotal(List<SettlementEntry> all) =>
      all.where((e) => e.settled).fold<int>(0, (s, e) => s + e.amountCash);

  @override
  Future<List<SettlementEntry>> fetchSettlements() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _all();
  }

  @override
  Future<SettlementSummary> fetchSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final all = _all();
    final pending =
        all.where((e) => !e.settled).fold<int>(0, (s, e) => s + e.amountCash);
    final withdrawn = _store.withdrawnCents ~/ 100;
    var withdrawable = _settledTotal(all) - withdrawn;
    if (withdrawable < 0) withdrawable = 0;
    return SettlementSummary(
      pendingCash: pending,
      withdrawableCash: withdrawable,
      withdrawnCash: withdrawn,
    );
  }

  @override
  Future<List<Withdrawal>> fetchWithdrawals() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final list = List<Withdrawal>.of(_store.withdrawals);
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<Withdrawal> requestWithdrawal(int amountCash) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));
    final all = _all();
    final withdrawn = _store.withdrawnCents ~/ 100;
    final withdrawable = _settledTotal(all) - withdrawn;
    if (amountCash <= 0) throw Exception('출금 금액을 입력해 주세요.');
    if (amountCash > withdrawable) throw Exception('출금 가능액을 초과했어요.');
    final w = Withdrawal(
      id: 'wd${DateTime.now().microsecondsSinceEpoch}',
      amountCash: amountCash,
      status: 'requested',
      createdAt: DateTime.now(),
    );
    _store.withdrawals.insert(0, w);
    _store.withdrawnCents += amountCash * 100;
    return w;
  }
}
