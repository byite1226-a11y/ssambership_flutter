import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 쌤버십 디자인 시스템 — 리디자인 PNG의 컴포넌트 시트를 코드화한 공용 위젯.
///
/// 데이터 계층과 무관한 "그래픽 전용" 위젯들이며, 모든 화면이 이걸 재사용해
/// 일관된 룩(좌측 액센트 바 카드 · 통계 카드 · 상태 알약 · 에스크로 스테퍼 등)을 갖는다.

/// 섹션/통계 카드 톤.
enum UiTone { neutral, primary, success, warning, danger, violet, indigo }

Color uiToneColor(UiTone t) {
  switch (t) {
    case UiTone.primary:
      return AppColors.primary;
    case UiTone.success:
      return AppColors.success;
    case UiTone.warning:
      return AppColors.accent;
    case UiTone.danger:
      return AppColors.danger;
    case UiTone.violet:
      return AppColors.purple;
    case UiTone.indigo:
      return AppColors.indigo;
    case UiTone.neutral:
      return AppColors.textSecondary;
  }
}

/// 40×40 라운드(r12) 틴트 배경 + 아이콘.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone = UiTone.primary, this.size = 40});
  final IconData icon;
  final UiTone tone;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = uiToneColor(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}

/// 상태 알약 칩.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = UiTone.neutral});
  final String label;
  final UiTone tone;
  @override
  Widget build(BuildContext context) {
    final c = uiToneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

/// 카운트 배지(작은 알약 숫자).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.tone = UiTone.primary});
  final int count;
  final UiTone tone;
  @override
  Widget build(BuildContext context) {
    final c = uiToneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
      child: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

/// 가로 스크롤 통계 카드 (아이콘칩 + 라벨 + 큰 숫자 + 보조).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.tone = UiTone.primary,
    this.width = 148,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final UiTone tone;
  final double width;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon, tone: tone, size: 36),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textDisabled)),
          ],
        ],
      ),
    );
  }
}

/// 좌측 4px 액센트 바 + 헤더(아이콘+제목) + 본문 섹션 카드.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.tone = UiTone.primary,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final UiTone tone;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = uiToneColor(tone);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: c),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: c, size: 20),
                        const SizedBox(width: 8),
                        Text(title,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: c)),
                        const Spacer(),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    const SizedBox(height: 12),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 경고/알림 행 (옅은 danger 배경, 탭 가능). 예) "분쟁 1건 →".
class WarnRow extends StatelessWidget {
  const WarnRow(
      {super.key,
      required this.label,
      required this.count,
      this.onTap,
      this.tone = UiTone.danger});
  final String label;
  final int count;
  final VoidCallback? onTap;
  final UiTone tone;
  @override
  Widget build(BuildContext context) {
    final c = uiToneColor(tone);
    return Material(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: c, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$count건',
                  style: TextStyle(
                      color: c, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward, color: c, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 라벨 ... 값 한 줄.
class MetricRow extends StatelessWidget {
  const MetricRow(this.label, this.value,
      {super.key, this.valueColor, this.strong = true});
  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// 가로 스크롤 칩 필터.
class ChipStrip extends StatelessWidget {
  const ChipStrip(
      {super.key,
      required this.items,
      this.selected = 0,
      this.onSelected});
  final List<ChipItem> items;
  final int selected;
  final ValueChanged<int>? onSelected;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final on = i == selected;
          final it = items[i];
          return Material(
            color: on ? AppColors.primary : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                  color: on ? AppColors.primary : AppColors.borderStrong),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onSelected == null ? null : () => onSelected!(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Text(it.label,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color:
                                on ? Colors.white : AppColors.textSecondary)),
                    if (it.count != null && it.count! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: on
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${it.count}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color:
                                    on ? Colors.white : AppColors.primary)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ChipItem {
  const ChipItem(this.label, {this.count});
  final String label;
  final int? count;
}

/// 리스트 행 — 제목 + 보조줄 + 우측 상태 알약(또는 trailing).
class ListRowTile extends StatelessWidget {
  const ListRowTile({
    super.key,
    required this.title,
    this.sub,
    this.tone = UiTone.primary,
    this.statusLabel,
    this.statusTone,
    this.leading,
    this.trailing,
    this.onTap,
  });
  final String title;
  final String? sub;
  final UiTone tone;
  final String? statusLabel;
  final UiTone? statusTone;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (statusLabel != null)
              StatusPill(statusLabel!, tone: statusTone ?? tone)
            else if (trailing != null)
              trailing!,
          ],
        ),
      ),
    );
  }
}

/// 에스크로 진행 스테퍼 (보관 → 진행 → 납품 → 정산).
class EscrowStepper extends StatelessWidget {
  const EscrowStepper(
      {super.key,
      required this.currentIndex,
      this.labels = const ['보관', '진행', '납품', '정산']});
  final int currentIndex;
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          _dot(i),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i < currentIndex
                    ? AppColors.primary
                    : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }

  Widget _dot(int i) {
    final done = i < currentIndex;
    final active = i == currentIndex;
    final on = done || active;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? AppColors.primary : AppColors.surface,
            border: Border.all(
                color: on ? AppColors.primary : AppColors.borderStrong,
                width: 2),
          ),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Center(
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? Colors.white
                              : AppColors.textDisabled)),
                ),
        ),
        const SizedBox(height: 4),
        Text(labels[i],
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: on ? AppColors.primary : AppColors.textSecondary)),
      ],
    );
  }
}

/// 주간 질문 CAP 게이지 — "이번 주 질문 가능량 used/total".
class CapMeter extends StatelessWidget {
  const CapMeter({
    super.key,
    required this.used,
    required this.total,
    this.planLabel,
    this.renewLabel,
    this.unlimited = false,
  });
  final int used;
  final int total;
  final String? planLabel;
  final String? renewLabel;
  final bool unlimited;
  @override
  Widget build(BuildContext context) {
    final remain = (total - used).clamp(0, total);
    final ratio = unlimited || total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final full = !unlimited && remain <= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('이번 주 질문 가능량',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              if (unlimited)
                const Text('무제한',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary))
              else
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '$remain',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: full ? AppColors.danger : AppColors.primary)),
                  TextSpan(
                      text: ' / $total회',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ])),
            ],
          ),
          if (!unlimited) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation(
                    full ? AppColors.danger : AppColors.primary),
              ),
            ),
          ],
          if (planLabel != null || renewLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (planLabel != null)
                  Text(planLabel!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                if (renewLabel != null)
                  Text(renewLabel!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textDisabled)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 빈 상태.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// 로딩 스켈레톤 블록.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock(
      {super.key, this.height = 16, this.width = double.infinity, this.radius = 8});
  final double height;
  final double width;
  final double radius;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
