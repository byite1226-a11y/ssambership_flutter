import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../models/ink_stroke.dart';
import '../models/ink_sketch.dart';

/// 필기 입력의 모든 상태를 들고 있는 컨트롤러.
///
/// 연결노트 필기와 스캔 주석이 **이 컨트롤러를 그대로 공유**합니다
/// (기술기획서 2-2 "입력 모듈 공유"). 스캔 주석은 좌표를 이미지 정규화
/// 좌표로 넘겨주는 변환만 추가로 끼웁니다.
class HandwritingController extends ChangeNotifier {
  HandwritingController({
    InkSketch? initial,
    this.authorRole,
  }) : _strokes = List<InkStroke>.from(initial?.strokes ?? const []) {
    if (initial != null) {
      _template = initial.template;
    }
  }

  // ---- 현재 도구 상태 ----
  InkTool _tool = InkTool.pen;
  EraserMode _eraserMode = EraserMode.stroke;
  int _color = 0xFF111827; // 기본 검정
  double _width = 4.0; // 3단(2/4/8) 중 중간
  bool _penOnlyMode = true; // 태블릿 기본: 펜만 그리기(팜 리젝션)
  PaperTemplate _template = PaperTemplate.blank;

  /// 작성자 역할 — 새 획에 색 구분 메타로 붙음 (연결노트 9-3).
  final String? authorRole;

  InkTool get tool => _tool;
  EraserMode get eraserMode => _eraserMode;
  int get color => _color;
  double get width => _width;
  bool get penOnlyMode => _penOnlyMode;
  PaperTemplate get template => _template;

  // ---- 데이터 ----
  final List<InkStroke> _strokes;
  final List<List<InkStroke>> _undoStack = [];
  final List<List<InkStroke>> _redoStack = [];
  InkStroke? _active; // 그리는 중인 획

  List<InkStroke> get strokes => List.unmodifiable(_strokes);
  InkStroke? get activeStroke => _active;
  bool get isEmpty => _strokes.isEmpty && _active == null;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  bool _dirty = false;
  bool get isDirty => _dirty;
  void markSaved() => _dirty = false;

  // =========================================================================
  // 도구 설정
  // =========================================================================
  void setTool(InkTool t) {
    _tool = t;
    notifyListeners();
  }

  void setEraserMode(EraserMode m) {
    _eraserMode = m;
    notifyListeners();
  }

  void setColor(int argb) {
    _color = argb;
    if (_tool == InkTool.eraser) _tool = InkTool.pen;
    notifyListeners();
  }

  void setWidth(double w) {
    _width = w;
    notifyListeners();
  }

  void togglePenOnly() {
    _penOnlyMode = !_penOnlyMode;
    notifyListeners();
  }

  void setTemplate(PaperTemplate t) {
    _template = t;
    notifyListeners();
  }

  // =========================================================================
  // 팜 리젝션 — 핵심.
  // 펜 전용 모드면 stylus만 그리기로 처리하고, touch(손가락)는 그리지 않음
  // → 손가락은 상위 InteractiveViewer의 줌/팬으로 흘러감.
  // (기술기획서 3 "스타일러스 입력만 스트로크로 처리")
  // =========================================================================
  bool acceptsInput(PointerDeviceKind kind) {
    if (!_penOnlyMode) return true; // 손가락 그리기 토글 ON
    return kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
  }

  // =========================================================================
  // 그리기 (좌표는 호출부가 캔버스/정규화 좌표로 변환해 전달)
  // =========================================================================
  void startStroke(Offset p, {double pressure = 0.5}) {
    if (_tool == InkTool.eraser && _eraserMode == EraserMode.stroke) {
      _eraseStrokeAt(p);
      return;
    }
    _active = InkStroke(
      tool: _tool,
      color: _tool == InkTool.highlighter ? _withAlpha(_color, 0x66) : _color,
      width: _tool == InkTool.highlighter ? _width * 3 : _width,
      authorRole: authorRole,
      points: [InkPoint(p.dx, p.dy, pressure)],
    );
    notifyListeners();
  }

  void appendPoint(Offset p, {double pressure = 0.5}) {
    if (_tool == InkTool.eraser && _eraserMode == EraserMode.stroke) {
      _eraseStrokeAt(p);
      return;
    }
    final a = _active;
    if (a == null) return;
    a.points.add(InkPoint(p.dx, p.dy, pressure));
    notifyListeners();
  }

  void endStroke() {
    final a = _active;
    _active = null;
    if (a == null || a.isEmpty) {
      notifyListeners();
      return;
    }
    _pushUndoSnapshot();
    _strokes.add(a);
    _redoStack.clear();
    _dirty = true;
    notifyListeners();
  }

  // =========================================================================
  // 지우개(획 단위) — 히트 테스트로 해당 획 제거.
  // =========================================================================
  void _eraseStrokeAt(Offset p) {
    final hitRadius = math.max(_width * 2, 12.0);
    for (int i = _strokes.length - 1; i >= 0; i--) {
      if (_strokeHit(_strokes[i], p, hitRadius)) {
        _pushUndoSnapshot();
        _strokes.removeAt(i);
        _redoStack.clear();
        _dirty = true;
        notifyListeners();
        return;
      }
    }
  }

  bool _strokeHit(InkStroke s, Offset p, double r) {
    for (final pt in s.points) {
      if ((pt.offset - p).distanceSquared <= r * r) return true;
    }
    return false;
  }

  // =========================================================================
  // Undo / Redo / Clear
  // =========================================================================
  void _pushUndoSnapshot() {
    _undoStack.add(List<InkStroke>.from(_strokes));
    if (_undoStack.length > 100) _undoStack.removeAt(0);
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List<InkStroke>.from(_strokes));
    final prev = _undoStack.removeLast();
    _strokes
      ..clear()
      ..addAll(prev);
    _dirty = true;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List<InkStroke>.from(_strokes));
    final next = _redoStack.removeLast();
    _strokes
      ..clear()
      ..addAll(next);
    _dirty = true;
    notifyListeners();
  }

  /// 전체 지우기 — 호출 전 확인 다이얼로그 필요(기획서 5-3 "확인 단계").
  void clearAll() {
    if (_strokes.isEmpty) return;
    _pushUndoSnapshot();
    _strokes.clear();
    _active = null;
    _dirty = true;
    notifyListeners();
  }

  // =========================================================================
  // 직렬화
  // =========================================================================
  InkSketch toSketch({double canvasWidth = 0, double canvasHeight = 0}) =>
      InkSketch(
        strokes: List<InkStroke>.from(_strokes),
        template: _template,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
      );

  int _withAlpha(int argb, int alpha) => (argb & 0x00FFFFFF) | (alpha << 24);
}
