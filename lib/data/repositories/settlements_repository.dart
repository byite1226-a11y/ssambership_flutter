import '../../core/models/settlement.dart';

/// 멘토 정산/출금 데이터 창구.
abstract class SettlementsRepository {
  Future<List<SettlementEntry>> fetchSettlements();
  Future<SettlementSummary> fetchSummary();
  Future<List<Withdrawal>> fetchWithdrawals();

  /// 출금 요청 → 출금 가능액에서 차감.
  Future<Withdrawal> requestWithdrawal(int amountCash);
}
