import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/content_report.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/widgets/async_views.dart';
import '../../../providers/repository_providers.dart';

const _reportReasons = [
  '스팸/광고',
  '욕설/비방',
  '부적절한 콘텐츠',
  '저작권 침해',
  '기타',
];

/// 공용 신고 다이얼로그 — 게시글/댓글/숏폼/사용자 신고에 사용.
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  String? targetId,
}) async {
  String reason = _reportReasons.first;
  final descCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('신고하기'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('신고 사유',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              for (final r in _reportReasons)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: r,
                  groupValue: reason,
                  onChanged: (v) => setLocal(() => reason = v!),
                  title: Text(r, style: const TextStyle(fontSize: 14)),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: '상세 내용(선택)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('신고')),
        ],
      ),
    ),
  );
  final desc = descCtrl.text.trim();
  descCtrl.dispose();
  if (ok != true) return;
  try {
    await ref.read(supportRepositoryProvider).createReport(
          targetType: targetType,
          targetId: targetId,
          reason: reason,
          description: desc,
        );
    ref.invalidate(myReportsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수되었어요. 검토 후 조치할게요.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('신고 접수 실패: $e')));
    }
  }
}

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  Future<void> _inquiry(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문의하기'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
                labelText: '제목', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: '내용', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('보내기')),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    titleCtrl.dispose();
    bodyCtrl.dispose();
    if (ok != true) return;
    if (title.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('제목을 입력해 주세요.')));
      }
      return;
    }
    try {
      await ref.read(supportRepositoryProvider).createReport(
            targetType: 'inquiry',
            reason: title,
            description: body,
          );
      ref.invalidate(myReportsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('문의가 접수되었어요.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('접수 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('고객지원')),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('자주 묻는 질문',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ..._faq.map((f) => _FaqTile(question: f.$1, answer: f.$2)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('찾는 답변이 없나요?',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('문의를 남겨주시면 빠르게 도와드릴게요.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: () => _inquiry(context, ref),
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('문의하기'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('내 문의·신고 내역',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            reports.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => AsyncErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(myReportsProvider)),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('접수한 문의나 신고가 없어요.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)))
                  : Column(children: [for (final r in list) _ReportTile(r)]),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

const _faq = [
  ('캐시는 어떻게 충전하나요?', '마이페이지 > 캐시 충전에서 패키지를 선택해 결제할 수 있어요. 1캐시는 1원이에요.'),
  ('구독을 해지하면 환불되나요?', '구독은 기간제로, 해지 시 다음 결제가 중단돼요. 이미 결제한 기간은 그대로 이용할 수 있어요.'),
  ('맞춤의뢰 결제는 안전한가요?', '의뢰 금액은 에스크로로 안전하게 보관되고, 납품을 수락할 때 멘토에게 정산돼요.'),
  ('납품이 마음에 안 들면 어떻게 하나요?', '수락 전이라면 주문 상세에서 분쟁을 신청할 수 있어요. 관리자가 검토 후 조치해요.'),
];

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Text(question,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(answer,
                  style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.report);
  final ContentReport report;
  @override
  Widget build(BuildContext context) {
    final d = report.createdAt;
    final when = d == null ? '' : '${d.year}.${d.month}.${d.day}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(report.targetLabel,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text(report.statusLabel,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(report.reason,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(report.description,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
          if (when.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(when,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textDisabled)),
          ],
        ],
      ),
    );
  }
}
