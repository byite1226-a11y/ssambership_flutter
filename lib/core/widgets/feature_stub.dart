import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/responsive.dart';

/// 아직 구현 전인 화면의 \"채울 자리\" 스캐폴드.
///
/// 단순한 빈 화면이 아니라, **이 화면을 무엇으로 채워야 하는지**(웹 라우트 기준,
/// Expo 화면 레퍼런스, 핵심 기능 목록)를 화면 안에 적어 둡니다. Cursor/Claude
/// Code가 이 파일 하나만 봐도 정확히 무엇을 만들어야 할지 알 수 있도록.
/// (Task 3 \"레퍼런스를 참고해 채워나간다\"를 코드 레벨에서 보조)
class FeatureStub extends StatelessWidget {
  const FeatureStub({
    super.key,
    required this.title,
    required this.webRoute,
    required this.expoScreen,
    required this.summary,
    this.todos = const [],
    this.actions = const [],
  });

  final String title;
  final String webRoute; // 웹(Next.js) 기준 라우트 — 디자인/기능의 기준점
  final String expoScreen; // Expo 레퍼런스 화면 파일
  final String summary;
  final List<String> todos;
  final List<Widget> actions; // 데모용 진입 버튼 등

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: ContentContainer(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _refCard(),
            const SizedBox(height: 16),
            if (actions.isNotEmpty) ...[
              Wrap(spacing: 12, runSpacing: 12, children: actions),
              const SizedBox(height: 16),
            ],
            if (todos.isNotEmpty) _todoCard(),
          ],
        ),
      ),
    );
  }

  Widget _refCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.construction, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(summary,
              style: const TextStyle(
                  color: AppColors.textSecondary, height: 1.5)),
          const Divider(height: 24),
          _refRow(Icons.public, '웹 기준', webRoute),
          const SizedBox(height: 6),
          _refRow(Icons.phone_iphone, 'Expo 참고', expoScreen),
        ],
      ),
    );
  }

  Widget _refRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('$label  ',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        Expanded(
          child: SelectableText(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _todoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('채울 내용',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...todos.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
