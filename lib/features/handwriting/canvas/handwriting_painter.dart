import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../models/ink_stroke.dart';
import '../models/ink_sketch.dart';

/// 캔버스 렌더러.
/// 획 품질은 perfect_freehand의 getStroke로 필압 반응 외곽선을 만들어 채웁니다
/// (기술기획서 4-2 "획 품질은 perfect_freehand로 확보").
class HandwritingPainter extends CustomPainter {
  HandwritingPainter({
    required this.strokes,
    required this.active,
    required this.template,
    this.repaint,
  }) : super(repaint: repaint);

  final List<InkStroke> strokes;
  final InkStroke? active;
  final PaperTemplate template;
  final Listenable? repaint;

  @override
  void paint(Canvas canvas, Size size) {
    _paintTemplate(canvas, size);

    for (final s in strokes) {
      _paintStroke(canvas, s);
    }
    if (active != null) _paintStroke(canvas, active!);
  }

  void _paintStroke(Canvas canvas, InkStroke s) {
    if (s.points.isEmpty) return;

    final paint = Paint()
      ..color = Color(s.color)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 형광펜은 곱하기 블렌드로 본문 위에 자연스럽게 얹힘.
    if (s.tool == InkTool.highlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    final inputPoints = s.points
        .map((p) => PointVector(p.x, p.y, p.pressure))
        .toList(growable: false);

    final outline = getStroke(
      inputPoints,
      options: StrokeOptions(
        size: s.width,
        thinning: s.tool == InkTool.highlighter ? 0.0 : 0.6,
        smoothing: 0.5,
        streamline: 0.5,
        simulatePressure: true,
        isComplete: !identical(s, active),
      ),
    );

    if (outline.isEmpty) return;

    final path = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (var i = 1; i < outline.length; i++) {
      path.lineTo(outline[i].dx, outline[i].dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // ---- 배경 종이 템플릿 (연결노트 5-2) ----
  void _paintTemplate(Canvas canvas, Size size) {
    if (template == PaperTemplate.blank) return;
    final line = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    const gap = 28.0;

    switch (template) {
      case PaperTemplate.lined:
        for (double y = gap; y < size.height; y += gap) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        break;
      case PaperTemplate.grid:
        for (double y = gap; y < size.height; y += gap) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        for (double x = gap; x < size.width; x += gap) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
        break;
      case PaperTemplate.dotted:
        final dot = Paint()..color = const Color(0xFFD1D5DB);
        for (double y = gap; y < size.height; y += gap) {
          for (double x = gap; x < size.width; x += gap) {
            canvas.drawCircle(Offset(x, y), 1.2, dot);
          }
        }
        break;
      case PaperTemplate.blank:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant HandwritingPainter old) => true;
}
