import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// RepaintBoundary 위젯을 PNG 바이트로 캡처.
///
/// 용도:
///  - 연결노트: 목록용 썸네일 PNG 생성 (원본 JSON과 분리 저장, 기획서 5-2)
///  - 스캔 주석: 배경+주석 평탄화 PNG 생성 (첨부/미리보기, 기획서 5)
class CanvasExporter {
  CanvasExporter._();

  static Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 2.0,
  }) async {
    final ctx = boundaryKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
