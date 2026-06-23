import 'package:flutter_test/flutter_test.dart';
import 'package:ssambership/features/handwriting/models/ink_sketch.dart';
import 'package:ssambership/features/handwriting/models/ink_stroke.dart';
import 'package:ssambership/features/scan_annotation/models/scan_annotation.dart';

/// 스캔 첨삭 좌표 정합의 핵심 로직 회귀 검증.
void main() {
  group('ScanCoordMapper', () {
    test('normalize → denormalize 로 픽셀 좌표가 원복된다', () {
      const w = 400.0, h = 600.0;
      final sketch = InkSketch(
        canvasWidth: w,
        canvasHeight: h,
        strokes: [
          InkStroke(
            tool: InkTool.pen,
            color: 0xFF000000,
            width: 4,
            points: const [
              InkPoint(100, 150, 0.5),
              InkPoint(200, 300, 0.7),
            ],
          ),
        ],
      );

      final norm = ScanCoordMapper.normalize(sketch, boxWidth: w, boxHeight: h);
      final p0 = norm.strokes.first.points.first;
      expect(p0.x, closeTo(0.25, 1e-9));
      expect(p0.y, closeTo(0.25, 1e-9));
      expect(norm.canvasWidth, 1.0);
      expect(norm.canvasHeight, 1.0);

      final back = ScanCoordMapper.denormalize(norm, boxWidth: w, boxHeight: h);
      final b0 = back.strokes.first.points.first;
      final b1 = back.strokes.first.points[1];
      expect(b0.x, closeTo(100, 1e-6));
      expect(b0.y, closeTo(150, 1e-6));
      expect(b1.x, closeTo(200, 1e-6));
      expect(b1.y, closeTo(300, 1e-6));
    });

    test('다른 크기 박스로 복원해도 비율(중앙·굵기)이 유지된다', () {
      const w = 300.0, h = 300.0;
      final sketch = InkSketch(
        canvasWidth: w,
        canvasHeight: h,
        strokes: [
          InkStroke(
            tool: InkTool.pen,
            color: 0xFF000000,
            width: 6,
            points: const [InkPoint(150, 150, 0.5)],
          ),
        ],
      );

      final norm = ScanCoordMapper.normalize(sketch, boxWidth: w, boxHeight: h);
      final big =
          ScanCoordMapper.denormalize(norm, boxWidth: 600, boxHeight: 600);
      final p = big.strokes.first.points.first;
      expect(p.x, closeTo(300, 1e-6)); // 중앙 유지
      expect(p.y, closeTo(300, 1e-6));
      expect(big.strokes.first.width, closeTo(12, 1e-6)); // 6/300*600
    });

    test('박스 크기가 0이면 가드로 원본을 그대로 반환한다', () {
      final sketch = InkSketch(
        strokes: [
          InkStroke(
            tool: InkTool.pen,
            color: 0xFF000000,
            width: 4,
            points: const [InkPoint(10, 10)],
          ),
        ],
      );
      final norm = ScanCoordMapper.normalize(sketch, boxWidth: 0, boxHeight: 0);
      expect(identical(norm, sketch), isTrue);
    });
  });
}
