import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/cash.dart';
import '../cash_repository.dart';

/// 실DB 구현 — cash_wallets / cash_ledger / cash_topup_packages + RPC.
///
/// 충전(record_cash_topup)은 **토스페이먼츠 결제 검증 후** 호출하는 것이 정석입니다.
/// 아래 topup 은 결제 연동 자리를 비워둔 best-effort 골격입니다(RPC 파라미터는
/// 운영 함수 시그니처에 맞춰 확정 필요). 앱은 카드정보를 직접 수집하지 않습니다.
class SupabaseCashRepository implements CashRepository {
  SupabaseCashRepository(this._db);

  final SupabaseClient _db;

  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<CashWallet> fetchWallet() async {
    final row = await _db
        .from('cash_wallets')
        .select()
        .eq('user_id', _uid ?? '')
        .maybeSingle();
    return row == null ? CashWallet.empty : CashWallet.fromMap(row);
  }

  @override
  Future<List<CashLedgerEntry>> fetchLedger() async {
    final rows = await _db
        .from('cash_ledger')
        .select()
        .eq('user_id', _uid ?? '')
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((e) => CashLedgerEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<TopupPackage>> fetchTopupPackages() async {
    final rows = await _db.from('cash_topup_packages').select();
    return (rows as List)
        .map((e) => TopupPackage.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CashWallet> topup(TopupPackage pkg) async {
    // TODO(결제): 토스페이먼츠 결제창 → 성공 시 paymentId 확보 → 아래 RPC 호출.
    //   record_cash_topup 의 실제 인자는 운영 함수에 맞춰 채워야 합니다.
    await _db.rpc('record_cash_topup', params: {
      'p_package_id': pkg.id,
      'p_amount_cents': pkg.amountCents,
    });
    return fetchWallet();
  }
}
