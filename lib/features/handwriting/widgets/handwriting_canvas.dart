import 'package:flutter/material.dart';

import '../canvas/handwriting_painter.dart';
import '../input/handwriting_controller.dart';

/// 실제 필기 캔버스.
///
/// 핵심 동작 (기술기획서 3):
///  - 손가락(touch)  → InteractiveViewer 줌/팬
///  - 스타일러스(pen) → 그리기. 그리는 동안에는 줌/팬을 잠가(흡수) 캔버스가
///    흔들리지 않게 함 = shouldAbsorbScale 패턴.
///  - '손가락 그리기' 토글(penOnly=false)이면 손가락도 그리기로 처리.
///
/// 좌표 정합: 화면 좌표를 TransformationController.toScene()으로 캔버스(scene)
/// 좌표로 변환해 저장 → 줌 레벨이 달라져도 같은 위치에 그려짐.
class HandwritingCanvas extends StatefulWidget {
  const HandwritingCanvas({
    super.key,
    required this.controller,
    this.minScale = 0.5,
    this.maxScale = 5.0,
    this.background,
    this.onCoordinateTransform,
  });

  final HandwritingController controller;
  final double minScale;
  final double maxScale;

  /// 배경 위젯(스캔 주석에서 스캔 이미지를 깔 때 사용). null이면 흰 배경.
  final Widget? background;

  /// 좌표 후처리 훅(스캔 주석: scene 좌표 → 이미지 정규화 좌표). null이면 그대로.
  final Offset Function(Offset scene, Size canvasSize)? onCoordinateTransform;

  @override
  State<HandwritingCanvas> createState() => _HandwritingCanvasState();
}

class _HandwritingCanvasState extends State<HandwritingCanvas> {
  final TransformationController _tc = TransformationController();
  bool _absorbing = false; // 펜이 그리는 중 → 줌/팬 잠금
  int? _activePointer;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  HandwritingController get c => widget.controller;

  Offset _toScene(Offset viewportPoint) => _tc.toScene(viewportPoint);

  Offset _map(Offset scene, Size size) =>
      widget.onCoordinateTransform?.call(scene, size) ?? scene;

  void _onDown(PointerDownEvent e, Size size) {
    if (_activePointer != null) return; // 멀티터치 첫 포인터만 그림
    final draws = c.acceptsInput(e.kind);
    if (!draws) return; // 손가락 + 펜전용 → InteractiveViewer가 처리(팜 리젝션)

    _activePointer = e.pointer;
    setState(() => _absorbing = true); // 줌/팬 잠금
    c.startStroke(_map(_toScene(e.localPosition), size),
        pressure: e.pressure.clamp(0.05, 1.0));
  }

  void _onMove(PointerMoveEvent e, Size size) {
    if (e.pointer != _activePointer) return;
    c.appendPoint(_map(_toScene(e.localPosition), size),
        pressure: e.pressure.clamp(0.05, 1.0));
  }

  void _onUp(PointerEvent e) {
    if (e.pointer != _activePointer) return;
    c.endStroke();
    _activePointer = null;
    if (mounted) setState(() => _absorbing = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _onDown(e, size),
          onPointerMove: (e) => _onMove(e, size),
          onPointerUp: _onUp,
          onPointerCancel: _onUp,
          child: InteractiveViewer(
            transformationController: _tc,
            minScale: widget.minScale,
            maxScale: widget.maxScale,
            // 펜이 그리는 동안에는 잠가서 캔버스가 흔들리지 않게.
            panEnabled: !_absorbing,
            scaleEnabled: !_absorbing,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 배경: 스캔 이미지 또는 흰 종이
                  widget.background ??
                      const ColoredBox(color: Colors.white),
                  // 필기 레이어
                  ListenableBuilder(
                    listenable: c,
                    builder: (context, _) => CustomPaint(
                      isComplex: true,
                      willChange: true,
                      painter: HandwritingPainter(
                        strokes: c.strokes,
                        active: c.activeStroke,
                        template: c.template,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
