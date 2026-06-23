/// 멘토 정산/출금 모델.
library;

/// 정산 항목 — 멘토가 번 금액(이미 정산됐거나 정산 예정).
class SettlementEntry {
  const SettlementEntry({
    required this.id,
    required this.label,
    required this.amountCash, // 멘토 몫(의뢰 80% / 구독 70%)
    required this.kind, // 'order' | 'subscription'
    required this.settled, // true=정산완료, false=정산예정
    this.createdAt,
  });

  final String id;
  final String label;
  final int amountCash;
  final String kind;
  final bool settled;
  final DateTime? createdAt;
}

/// 출금 요청.
class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.amountCash,
    required this.status, // 'requested' | 'paid'
    this.createdAt,
  });

  final String id;
  final int amountCash;
  final String status;
  final DateTime? createdAt;
}

/// 정산 요약.
class SettlementSummary {
  const SettlementSummary({
    required this.pendingCash, // 정산 예정
    required this.withdrawableCash, // 출금 가능
    required this.withdrawnCash, // 누적 출금
  });

  final int pendingCash;
  final int withdrawableCash;
  final int withdrawnCash;
}
