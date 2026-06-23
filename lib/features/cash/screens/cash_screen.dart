import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/cash.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';

/// 캐시 지갑·충전 + 구독 요금제.
///
/// 지갑/충전/내역은 CashRepository(더미↔Supabase)에 연결됩니다. 충전은 데모로
/// 즉시 반영되며, 실제로는 토스페이먼츠 결제 후 record_cash_topup RPC로 반영됩니다.
/// 구독 결제 연결은 다음 단계(Unit 6).
class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key});
  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen> {
  final _won = NumberFormat('#,###', 'ko_KR');
  PlanType _selected = PlanType.standard;
  bool _charging = false;

  Future<void> _topup(TopupPackage pkg) async {
    if (_charging) return;
    setState(() => _charging = true);
    try {
      await ref.read(cashRepositoryProvider).topup(pkg);
      ref.invalidate(walletProvider);
      ref.invalidate(cashLedgerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_won.format(pkg.amountWon)} 캐시 충전 완료 (데모)'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('충전 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _charging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final packages = ref.watch(topupPackagesProvider);
    final ledger = ref.watch(cashLedgerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('캐시 · 구독')),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _BalanceCard(wallet: wallet, won: _won),
            const SizedBox(height: 16),

            const Text('충전',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            packages.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AsyncErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(topupPackagesProvider),
              ),
              data: (list) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in list)
                    OutlinedButton(
                      onPressed: _charging ? null : () => _topup(p),
                      child: Text('+${_won.format(p.amountWon)}'),
                    ),
                ],
              ),
            ),
            if (_charging)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 8),
            const Text('※ 데모 충전입니다. 실제 결제는 토스페이먼츠로 연동됩니다.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),

            const SizedBox(height: 24),
            const Text('최근 내역',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ledger.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AsyncErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(cashLedgerProvider),
              ),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('내역이 없어요.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    )
                  : Column(
                      children: [
                        for (final e in list.take(6))
                          _LedgerRow(entry: e, won: _won),
                      ],
                    ),
            ),

            const SizedBox(height: 28),
            const Text('구독 요금제',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('구독 결제는 30/70, 단건 의뢰는 20/80으로 정산됩니다.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            context.useWideLayout
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: PlanType.values
                        .map((t) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: _PlanCard(
                                  info: PlanInfo.all[t]!,
                                  selected: _selected == t,
                                  onTap: () => setState(() => _selected = t),
                                  won: _won,
                                ),
                              ),
                            ))
                        .toList(),
                  )
                : Column(
                    children: PlanType.values
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PlanCard(
                                info: PlanInfo.all[t]!,
                                selected: _selected == t,
                                onTap: () => setState(() => _selected = t),
                                won: _won,
                              ),
                            ))
                        .toList(),
                  ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () {
                  final p = PlanInfo.all[_selected]!;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${p.label} 구독 결제는 다음 단계에서 연결돼요 — '
                        '${_won.format(p.priceCash)}캐시'),
                  ));
                },
                child: Text(
                    '${PlanInfo.all[_selected]!.label} 구독하기 · '
                    '${_won.format(PlanInfo.all[_selected]!.priceCash)}캐시/월',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet, required this.won});
  final AsyncValue<CashWallet> wallet;
  final NumberFormat won;

  @override
  Widget build(BuildContext context) {
    final balance = wallet.when(
      data: (w) => '${won.format(w.balanceWon)} 캐시',
      loading: () => '… 캐시',
      error: (_, __) => '— 캐시',
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('보유 캐시',
              style: TextStyle(color: Color(0xFFD7E3FB), fontSize: 13)),
          const SizedBox(height: 6),
          Text(balance,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('1 캐시 = 1원',
              style: TextStyle(color: Color(0xFFD7E3FB), fontSize: 12)),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.won});
  final CashLedgerEntry entry;
  final NumberFormat won;

  @override
  Widget build(BuildContext context) {
    final credit = entry.isCredit;
    final color = credit ? AppColors.success : AppColors.textPrimary;
    final d = entry.createdAt;
    final when = d == null ? '' : '${d.year}.${d.month}.${d.day}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    entry.description.isEmpty ? entry.kind : entry.description,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(when,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          Text('${credit ? '+' : '-'}${won.format(entry.amountWon.abs())}',
              style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.info,
    required this.selected,
    required this.onTap,
    required this.won,
  });
  final PlanInfo info;
  final bool selected;
  final VoidCallback onTap;
  final NumberFormat won;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(info.label,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if (info.recommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('추천',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text('${won.format(info.priceCash)}캐시',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const Text('/ 월',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              _line(Icons.help_outline, info.weeklyLabel),
              _line(Icons.speed, '동시 진행 cap ${info.cap}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ]),
      );
}
