import '../../core/models/cash.dart';

/// 캐시 데이터 창구.
///
/// 충전은 실제로는 토스페이먼츠 결제 → 검증 후 `record_cash_topup` RPC 로
/// 지갑/원장에 반영됩니다(직접 INSERT 금지). 앱은 카드정보를 직접 받지 않습니다.
abstract class CashRepository {
  /// 현재 사용자 지갑 잔액.
  Future<CashWallet> fetchWallet();

  /// 입출 내역(최신순).
  Future<List<CashLedgerEntry>> fetchLedger();

  /// 충전 상품 목록.
  Future<List<TopupPackage>> fetchTopupPackages();

  /// 충전 실행 → 갱신된 지갑 반환.
  /// (실DB: 결제 검증 후 record_cash_topup RPC. 더미: 즉시 잔액 반영)
  Future<CashWallet> topup(TopupPackage pkg);
}
