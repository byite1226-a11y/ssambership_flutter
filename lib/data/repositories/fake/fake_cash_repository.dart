import '../../../core/models/cash.dart';
import '../cash_repository.dart';
import 'demo_store.dart';

/// 더미 구현 — 지갑/원장을 공유 DemoStore에 보관.
/// 충전·구독 차감이 같은 지갑에 반영되어, 캐시 화면과 구독 흐름이 일관됩니다.
class FakeCashRepository implements CashRepository {
  final DemoStore _store = DemoStore.instance;

  @override
  Future<CashWallet> fetchWallet() async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return CashWallet(balanceCents: _store.walletCents);
  }

  @override
  Future<List<CashLedgerEntry>> fetchLedger() async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final list = List<CashLedgerEntry>.of(_store.ledger);
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<List<TopupPackage>> fetchTopupPackages() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const [
      TopupPackage(id: 'p1', amountCents: 1000000, priceWon: 10000),
      TopupPackage(id: 'p2', amountCents: 3100000, priceWon: 30000), // +1,000 보너스
      TopupPackage(id: 'p3', amountCents: 5200000, priceWon: 50000), // +2,000 보너스
      TopupPackage(id: 'p4', amountCents: 10600000, priceWon: 100000), // +6,000 보너스
    ];
  }

  @override
  Future<CashWallet> topup(TopupPackage pkg) async {
    _store.ensureSeed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _store.walletCents += pkg.amountCents;
    _store.ledger.insert(
      0,
      CashLedgerEntry(
        id: 'l${DateTime.now().microsecondsSinceEpoch}',
        amountCents: pkg.amountCents,
        kind: 'topup',
        description: '캐시 충전 (${pkg.amountWon} 캐시)',
        createdAt: DateTime.now(),
      ),
    );
    return CashWallet(balanceCents: _store.walletCents);
  }
}
