import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/settlement.dart';
import '../settlements_repository.dart';

/// 실DB 구현 — 정산은 custom_orders(멘토 몫 80%)에서 파생, 출금은 withdrawals.
///
/// 정산/출금 전용 테이블·뷰·RPC는 운영 정책에 맞춰 확정 필요. 아래는 best-effort.
class SupabaseSettlementsRepository implements SettlementsRepository {
  SupabaseSettlementsRepository(this._db);

  final SupabaseClient _db;
  String? get _uid => _db.auth.currentUser?.id;

  Future<List<SettlementEntry>> _all() async {
    final rows = await _db
        .from('custom_orders')
        .select()
        .eq('mentor_id', _uid ?? '')
        .order('created_at', ascending: false);
    final list = <SettlementEntry>[];
    for (final raw in (rows as List)) {
      final o = raw as Map<String, dynamic>;
      final amount = (o['amount_cash'] as num?)?.toInt() ??
          ((o['amount_cents'] as num?)?.toInt() ?? 0) ~/ 100;
      final share = (amount * 0.8).round();
      final status = (o['status'] as String?) ?? '';
      final title = (o['title'] as String?) ?? '의뢰';
      final created = switch (o['created_at']) {
        String s => DateTime.tryParse(s),
        _ => null,
      };
      if (status == 'accepted') {
        list.add(SettlementEntry(
            id: 'sto-${o['id']}',
            label: '의뢰 정산 — $title',
            amountCash: share,
            kind: 'order',
            settled: true,
            createdAt: created));
      } else if (status == 'in_progress' || status == 'delivered') {
        list.add(SettlementEntry(
            id: 'sto-${o['id']}',
            label: '의뢰 예정 — $title',
            amountCash: share,
            kind: 'order',
            settled: false,
            createdAt: created));
      }
    }
    return list;
  }

  @override
  Future<List<SettlementEntry>> fetchSettlements() => _all();

  @override
  Future<SettlementSummary> fetchSummary() async {
    final all = await _all();
    final pending =
        all.where((e) => !e.settled).fold<int>(0, (s, e) => s + e.amountCash);
    final settled =
        all.where((e) => e.settled).fold<int>(0, (s, e) => s + e.amountCash);
    final withdrawals = await fetchWithdrawals();
    final withdrawn =
        withdrawals.fold<int>(0, (s, w) => s + w.amountCash);
    var withdrawable = settled - withdrawn;
    if (withdrawable < 0) withdrawable = 0;
    return SettlementSummary(
        pendingCash: pending,
        withdrawableCash: withdrawable,
        withdrawnCash: withdrawn);
  }

  @override
  Future<List<Withdrawal>> fetchWithdrawals() async {
    final rows = await _db
        .from('withdrawals')
        .select()
        .eq('mentor_id', _uid ?? '')
        .order('created_at', ascending: false);
    return (rows as List).map((e) {
      final m = e as Map<String, dynamic>;
      return Withdrawal(
        id: m['id'] as String,
        amountCash: (m['amount_cash'] as num?)?.toInt() ??
            ((m['amount_cents'] as num?)?.toInt() ?? 0) ~/ 100,
        status: (m['status'] as String?) ?? 'requested',
        createdAt: switch (m['created_at']) {
          String s => DateTime.tryParse(s),
          _ => null,
        },
      );
    }).toList();
  }

  @override
  Future<Withdrawal> requestWithdrawal(int amountCash) async {
    final row = await _db
        .from('withdrawals')
        .insert({
          'mentor_id': _uid,
          'amount_cash': amountCash,
          'status': 'requested',
        })
        .select()
        .single();
    return Withdrawal(
      id: row['id'] as String,
      amountCash: amountCash,
      status: 'requested',
      createdAt: switch (row['created_at']) {
        String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }
}
