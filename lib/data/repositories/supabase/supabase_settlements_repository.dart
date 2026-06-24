import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/settlement.dart';
import '../settlements_repository.dart';

/// 실DB 구현 — 정산은 custom_order_settlement_items(웹 정본), 출금은 withdrawals(093).
///
/// 정산 금액의 진실의 원천은 custom_order_settlement_items.mentor_amount 다.
///  - 이 값은 이미 "멘토 몫(= gross − 수수료 20%)"이라 0.8을 다시 곱하지 않는다(이중 차감 방지).
///  - 단위는 원 = 캐시(정수). 100으로 나누지 않는다.
///  - status: 'paid'=정산 완료(지급됨), 'pending'/'on_hold'/'payable'=정산 예정,
///    'cancelled'=분쟁 취소분이라 목록에서 제외(과다 집계 방지).
///  - 제목은 custom_request_orders(title)를 임베드해서 가져온다.
///
/// ⚠️ 출금(withdrawals)은 "요청 로그"까지만 기록한다(093 헤더 참조). 실제 송금/차감은
///    finance-settlement 가 지급 경로를 확정하기 전까지 연결하지 않는다(돈 사고 방지).
class SupabaseSettlementsRepository implements SettlementsRepository {
  SupabaseSettlementsRepository(this._db);

  final SupabaseClient _db;
  String? get _uid => _db.auth.currentUser?.id;

  Future<List<SettlementEntry>> _all() async {
    // 정본 정산 테이블에서 멘토 본인 몫을 읽는다(RLS: mentor_id=auth.uid() 허용).
    // custom_request_orders(title)를 FK로 임베드해 의뢰 제목을 함께 가져온다.
    final rows = await _db
        .from('custom_order_settlement_items')
        .select('id, mentor_amount, status, created_at, custom_request_orders(title)')
        .eq('mentor_id', _uid ?? '')
        .order('created_at', ascending: false);
    final list = <SettlementEntry>[];
    for (final raw in (rows as List)) {
      final o = raw as Map<String, dynamic>;
      final status = (o['status'] as String?) ?? '';
      if (status == 'cancelled') continue; // 분쟁 취소분은 정산에서 제외
      // mentor_amount = 이미 멘토 몫(수수료 20% 차감 후). 단위 원=캐시. 재차감/나눗셈 금지.
      final amount = (o['mentor_amount'] as num?)?.toInt() ?? 0;
      final order = o['custom_request_orders'] as Map<String, dynamic>?;
      final title = (order?['title'] as String?) ?? '의뢰';
      final created = switch (o['created_at']) {
        String s => DateTime.tryParse(s),
        _ => null,
      };
      final settled = status == 'paid'; // 지급 완료만 정산 완료로 집계
      list.add(SettlementEntry(
          id: 'cosi-${o['id']}',
          label: settled ? '의뢰 정산 — $title' : '의뢰 예정 — $title',
          amountCash: amount,
          kind: 'order',
          settled: settled,
          createdAt: created));
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
