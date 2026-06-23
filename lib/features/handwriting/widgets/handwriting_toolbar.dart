import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../input/handwriting_controller.dart';
import '../models/ink_stroke.dart';
import '../models/ink_sketch.dart';

/// 필기 툴바.
/// - 태블릿/데스크톱: 세로 측면 레일(펜 쥔 손과 안 겹치게, 좌/우 선택 가능)
/// - 모바일: 하단 가로 바(핵심 도구만 큼직하게)
/// (기획서 5-4 디바이스별 레이아웃)
class HandwritingToolbar extends StatelessWidget {
  const HandwritingToolbar({
    super.key,
    required this.controller,
    this.leftHanded = false,
  });

  final HandwritingController controller;
  final bool leftHanded;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return context.useWideLayout
            ? _SideRail(controller: controller)
            : _BottomBar(controller: controller);
      },
    );
  }
}

// ===========================================================================
// 태블릿/데스크톱 — 측면 레일
// ===========================================================================
class _SideRail extends StatelessWidget {
  const _SideRail({required this.controller});
  final HandwritingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      width: 64,
      color: AppColors.surface,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _toolBtn(c, InkTool.pen, Icons.edit, '펜'),
            _toolBtn(c, InkTool.highlighter, Icons.brush, '형광펜'),
            _toolBtn(c, InkTool.eraser, Icons.cleaning_services, '지우개'),
            _toolBtn(c, InkTool.text, Icons.title, '텍스트'),
            const Divider(height: 16, indent: 12, endIndent: 12),
            _ColorStrip(controller: c, vertical: true),
            const SizedBox(height: 8),
            _WidthControl(controller: c, vertical: true),
            const Divider(height: 16, indent: 12, endIndent: 12),
            _iconBtn(Icons.undo, '실행취소', c.canUndo ? c.undo : null),
            _iconBtn(Icons.redo, '다시실행', c.canRedo ? c.redo : null),
            _iconBtn(Icons.delete_outline, '전체 지우기',
                () => _confirmClear(context, c),
                color: AppColors.danger),
            const Divider(height: 16, indent: 12, endIndent: 12),
            _PenOnlyToggle(controller: c, vertical: true),
            const SizedBox(height: 8),
            _TemplateButton(controller: c),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 모바일 — 하단 바
// ===========================================================================
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller});
  final HandwritingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ColorStrip(controller: c, vertical: false),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _toolBtn(c, InkTool.pen, Icons.edit, '펜'),
                _toolBtn(c, InkTool.highlighter, Icons.brush, '형광'),
                _toolBtn(c, InkTool.eraser, Icons.cleaning_services, '지우개'),
                _toolBtn(c, InkTool.text, Icons.title, '글자'),
                _iconBtn(Icons.undo, '취소', c.canUndo ? c.undo : null),
                _iconBtn(Icons.redo, '재실행', c.canRedo ? c.redo : null),
                _PenOnlyToggle(controller: c, vertical: false),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 공통 부품
// ===========================================================================
Widget _toolBtn(
    HandwritingController c, InkTool tool, IconData icon, String label) {
  final selected = c.tool == tool;
  return Tooltip(
    message: label,
    child: InkWell(
      onTap: () => c.setTool(tool),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 22,
            color: selected ? AppColors.primary : AppColors.textSecondary),
      ),
    ),
  );
}

Widget _iconBtn(IconData icon, String label, VoidCallback? onTap,
    {Color? color}) {
  return Tooltip(
    message: label,
    child: IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      color: color ?? AppColors.textSecondary,
      disabledColor: AppColors.textDisabled,
    ),
  );
}

class _ColorStrip extends StatelessWidget {
  const _ColorStrip({required this.controller, required this.vertical});
  final HandwritingController controller;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final color in AppColors.penPresets)
        _colorDot(color.value & 0xFFFFFFFF | 0xFF000000),
    ];
    return vertical
        ? Column(children: chips)
        : SizedBox(
            height: 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: chips,
            ),
          );
  }

  Widget _colorDot(int argb) {
    final selected = controller.color == argb && controller.tool != InkTool.eraser;
    return GestureDetector(
      onTap: () => controller.setColor(argb),
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Color(argb),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _WidthControl extends StatelessWidget {
  const _WidthControl({required this.controller, required this.vertical});
  final HandwritingController controller;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    const widths = [2.0, 4.0, 8.0];
    final dots = [
      for (final w in widths)
        GestureDetector(
          onTap: () => controller.setWidth(w),
          child: Container(
            width: 40,
            height: 28,
            alignment: Alignment.center,
            child: Container(
              width: w + 6,
              height: w + 6,
              decoration: BoxDecoration(
                color: controller.width == w
                    ? AppColors.primary
                    : AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
    ];
    return vertical ? Column(children: dots) : Row(children: dots);
  }
}

class _PenOnlyToggle extends StatelessWidget {
  const _PenOnlyToggle({required this.controller, required this.vertical});
  final HandwritingController controller;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final on = controller.penOnlyMode;
    return Tooltip(
      message: on ? '펜 전용 모드 (손가락=이동)' : '손가락 그리기 켜짐',
      child: IconButton(
        onPressed: controller.togglePenOnly,
        icon: Icon(on ? Icons.draw : Icons.touch_app),
        color: on ? AppColors.primary : AppColors.accent,
      ),
    );
  }
}

class _TemplateButton extends StatelessWidget {
  const _TemplateButton({required this.controller});
  final HandwritingController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PaperTemplate>(
      tooltip: '배경 템플릿',
      icon: const Icon(Icons.grid_4x4, color: AppColors.textSecondary),
      onSelected: controller.setTemplate,
      itemBuilder: (_) => const [
        PopupMenuItem(value: PaperTemplate.blank, child: Text('무지')),
        PopupMenuItem(value: PaperTemplate.lined, child: Text('줄')),
        PopupMenuItem(value: PaperTemplate.grid, child: Text('모눈')),
        PopupMenuItem(value: PaperTemplate.dotted, child: Text('점선')),
      ],
    );
  }
}

Future<void> _confirmClear(
    BuildContext context, HandwritingController c) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('전체 지우기'),
      content: const Text('이 노트의 모든 필기를 지울까요? 되돌리기로 복구할 수 있어요.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('지우기', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (ok == true) c.clearAll();
}
