import 'package:flutter/material.dart';

import '../../handwriting/canvas/handwriting_painter.dart';
import '../../handwriting/input/handwriting_controller.dart';

/// 스캔 이미지 위 주석 캔버스.
///
/// ★ 좌표 정합 핵심 (스캔주석 기획서 2-2):
/// 이미지를 비율 유지(AspectRatio)로 깔고, 그 박스 "로컬 좌표"에 그림을 그립니다.
/// 줌/팬은 이미지+주석을 함께 감싼 InteractiveViewer가 변환하므로, 주석은 항상
/// 이미지의 같은 위치에 얹힙니다. 저장 시에는 박스 크기로 나눠 0~1 정규화 좌표로
/// 보관하면 기기·해상도가 달라도 위치가 어긋나지 않습니다.
class ScanAnnotationCanvas extends StatefulWidget {
  const ScanAnnotationCanvas({
    super.key,
    required this.controller,
    required this.image,
    required this.imageAspectRatio,
    this.showAnnotations = true,
    this.boxKey,
    this.captureKey,
  });

  final HandwritingController controller;
  final ImageProvider image;
  final double imageAspectRatio; // width / height
  final bool showAnnotations;

  /// 정규화 분모로 쓰일 "실제 이미지 박스" 크기 측정용 key.
  /// ★ 반드시 그림이 그려지는 AspectRatio 박스에 붙어야 좌표 정합이 맞습니다.
  final GlobalKey? boxKey;

  /// 평탄화 PNG 캡처 경계 key. 이미지 박스만(레터박스 여백 제외) 캡처합니다.
  final GlobalKey? captureKey;

  @override
  State<ScanAnnotationCanvas> createState() => _ScanAnnotationCanvasState();
}

class _ScanAnnotationCanvasState extends State<ScanAnnotationCanvas> {
  final TransformationController _tc = TransformationController();
  bool _absorbing = false;
  int? _activePointer;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  HandwritingController get c => widget.controller;
  Offset _toScene(Offset p) => _tc.toScene(p);

  void _down(PointerDownEvent e) {
    if (_activePointer != null) return;
    if (!c.acceptsInput(e.kind)) return; // 손가락+펜전용 → 줌/팬
    _activePointer = e.pointer;
    setState(() => _absorbing = true);
    c.startStroke(_toScene(e.localPosition),
        pressure: e.pressure.clamp(0.05, 1.0));
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _activePointer) return;
    c.appendPoint(_toScene(e.localPosition),
        pressure: e.pressure.clamp(0.05, 1.0));
  }

  void _up(PointerEvent e) {
    if (e.pointer != _activePointer) return;
    c.endStroke();
    _activePointer = null;
    if (mounted) setState(() => _absorbing = false);
  }

  @override
  Widget build(BuildContext context) {
    // ★ 실제 그림이 그려지는 박스(=정규화 분모, 캡처 대상)
    Widget imageBox = AspectRatio(
      key: widget.boxKey,
      aspectRatio:
          widget.imageAspectRatio.isFinite && widget.imageAspectRatio > 0
              ? widget.imageAspectRatio
              : 0.7071, // A4 세로 비율 폴백
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 레이어 — 스캔 원본(편집 불가)
          Image(image: widget.image, fit: BoxFit.fill),
          // 주석 레이어 — 펜 첨삭(벡터). '원본만 보기' 시 숨김.
          if (widget.showAnnotations)
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
    );

    // 평탄화 PNG는 이미지 박스만 캡처(레터박스 여백 제외, 줌과 무관하게 원본 크기).
    if (widget.captureKey != null) {
      imageBox = RepaintBoundary(key: widget.captureKey, child: imageBox);
    }

    return Center(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: InteractiveViewer(
          transformationController: _tc,
          minScale: 1.0,
          maxScale: 6.0,
          panEnabled: !_absorbing,
          scaleEnabled: !_absorbing,
          child: imageBox,
        ),
      ),
    );
  }
}
