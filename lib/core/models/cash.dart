/// 캐시(지갑/내역/충전패키지) 모델. 1캐시 = 1원, 내부는 cents(*100) 보관.
library;

/// cash_wallets — 사용자 지갑 잔액.
class CashWallet {
  const CashWallet({required this.balanceCents});

  final int balanceCents;
  int get balanceWon => balanceCents ~/ 100;

  factory CashWallet.fromMap(Map<String, dynamic> m) => CashWallet(
        balanceCents: (m['balance_cents'] as num?)?.toInt() ??
            (((m['balance'] as num?)?.toInt() ?? 0) * 100),
      );

  static const empty = CashWallet(balanceCents: 0);
}

/// cash_ledger — 입출 내역 한 줄.
class CashLedgerEntry {
  const CashLedgerEntry({
    required this.id,
    required this.amountCents, // +충전 / -사용
    required this.kind, // 'topup' | 'subscription' | 'refund' | ...
    required this.description,
    this.createdAt,
  });

  final String id;
  final int amountCents;
  final String kind;
  final String description;
  final DateTime? createdAt;

  bool get isCredit => amountCents >= 0;
  int get amountWon => amountCents ~/ 100;

  factory CashLedgerEntry.fromMap(Map<String, dynamic> m) => CashLedgerEntry(
        id: m['id'] as String,
        amountCents: (m['amount_cents'] as num?)?.toInt() ??
            ((m['amount'] as num?)?.toInt() ?? 0),
        kind: (m['kind'] as String?) ?? (m['type'] as String?) ?? 'etc',
        description: (m['description'] as String?) ??
            (m['memo'] as String?) ??
            (m['note'] as String?) ??
            '',
        createdAt: _cashDate(m['created_at']),
      );
}

/// cash_topup_packages — 충전 상품.
class TopupPackage {
  const TopupPackage({
    required this.id,
    required this.amountCents, // 충전되는 캐시
    required this.priceWon, // 실제 결제 금액(원)
    this.label,
  });

  final String id;
  final int amountCents;
  final int priceWon;
  final String? label;

  int get amountWon => amountCents ~/ 100;

  factory TopupPackage.fromMap(Map<String, dynamic> m) => TopupPackage(
        id: m['id'] as String,
        amountCents: (m['amount_cents'] as num?)?.toInt() ??
            (((m['cash_amount'] as num?)?.toInt() ?? 0) * 100),
        priceWon: (m['price_won'] as num?)?.toInt() ??
            ((m['price'] as num?)?.toInt() ?? 0),
        label: m['label'] as String?,
      );
}

DateTime? _cashDate(dynamic v) =>
    v is String ? DateTime.tryParse(v) : (v is DateTime ? v : null);
