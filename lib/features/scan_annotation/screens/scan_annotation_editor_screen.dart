import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../handwriting/input/handwriting_controller.dart';
import '../../handwriting/models/ink_sketch.dart';
import '../../handwriting/widgets/canvas_exporter.dart';
import '../../handwriting/widgets/handwriting_toolbar.dart';
import '../models/scan_annotation.dart';
import '../widgets/scan_annotation_canvas.dart';

/// 스캔 이미지 주석 에디터.
///
/// 흐름(기술기획서 7): 스캔 이미지 로드 → 주석 진입(배경=원본) →
/// 스타일러스 첨삭 → 저장(정규화 주석 JSON + 평탄화 PNG).
///
/// 연결노트 에디터와 동일한 HandwritingController/툴바/캔버스를 **공유**하고,
/// 저장 경계에서만 좌표를 0~1로 정규화합니다(ScanCoordMapper).
class ScanAnnotationEditorScreen extends StatefulWidget {
  const ScanAnnotationEditorScreen({
    super.key,
    required this.image,
    required this.authorRole, // 'student' | 'mentor'
    this.title = '첨삭',
    this.initialAnnotation, // 정규화된 기존 주석(있으면 복원)
    this.onSave,
  });

  final ImageProvider image;
  final String authorRole;
  final String title;
  final InkSketch? initialAnnotation;
  final Future<void> Function(ScanAnnotationPayload payload)? onSave;

  @override
  State<ScanAnnotationEditorScreen> createState() =>
      _ScanAnnotationEditorScreenState();
}

class _ScanAnnotationEditorScreenState
    extends State<ScanAnnotationEditorScreen> {
  HandwritingController? _ink;
  final GlobalKey _captureKey = GlobalKey(); // 평탄화 PNG 캡처 경계
  final GlobalKey _boxKey = GlobalKey(); // 캔버스 박스 크기 측정(정규화 분모)

  double? _imageAspect; // width / height
  bool _showAnnotations = true;
  Timer? _autosaveTimer;
  _SaveState _saveState = _SaveState.saved;
  bool _denormPending = false; // 박스 크기 확보 후 초기 주석 복원 대기

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
    // 작성자 역할에 따라 펜 기본색 자동 지정(9-3 작성자 색 구분).
    final role = widget.authorRole;
    _ink = HandwritingController(authorRole: role)
      ..setColor(role == 'mentor'
          ? AppColors.inkMentor.value
          : AppColors.inkStudent.value);
    if (widget.initialAnnotation != null &&
        !widget.initialAnnotation!.isEmpty) {
      _denormPending = true; // 박스 크기 측정 후 1프레임 뒤 복원
    }
    _ink!.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    // 저장은 닫기 핸들러(_handleClose)/PopScope에서 await로 끝낸 뒤 pop하므로,
    // dispose에서는 타이머만 정리한다. (여기서 비동기 저장 시 캡처 경계가 이미
    // 사라져 PNG가 누락되던 경합을 제거.)
    _autosaveTimer?.cancel();
    _ink?.dispose();
    super.dispose();
  }

  // 닫기(뒤로가기/X/완료) 공통 처리: 트리가 살아있는 동안 저장을 끝낸 뒤 pop.
  bool _closing = false;
  Future<void> _handleClose() async {
    if (_closing) return;
    _closing = true;
    final ok = await _save();
    if (!ok) {
      _closing = false; // 저장 실패 → 닫지 않고 재시도 가능하게
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('저장에 실패했어요. 다시 시도해 주세요.'),
            action: SnackBarAction(label: '재시도', onPressed: _handleClose),
          ),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  // 이미지의 실제 비율을 디코드해서 캔버스 박스 비율을 맞춤.
  void _resolveAspectRatio() {
    final stream = widget.image.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final ui.Image img = info.image;
      if (mounted) {
        setState(() => _imageAspect = img.width / img.height);
        // 박스가 그려진 다음 프레임에 초기 주석 복원.
        if (_denormPending) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _restoreInitial());
        }
      }
      stream.removeListener(listener);
    }, onError: (Object e, _) {
      if (mounted) setState(() => _imageAspect = 0.7071); // A4 폴백
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  Size? get _boxSize {
    final ctx = _boxKey.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) return ro.size;
    return null;
  }

  // 정규화 주석(0~1) → 현재 박스 픽셀로 복원해 컨트롤러에 로드.
  void _restoreInitial() {
    final box = _boxSize;
    final init = widget.initialAnnotation;
    if (box == null || init == null) return;
    final px = ScanCoordMapper.denormalize(
      init,
      boxWidth: box.width,
      boxHeight: box.height,
    );
    setState(() {
      _ink?.removeListener(_scheduleAutosave);
      _ink?.dispose();
      _ink = HandwritingController(initial: px, authorRole: widget.authorRole)
        ..setColor(widget.authorRole == 'mentor'
            ? AppColors.inkMentor.value
            : AppColors.inkStudent.value)
        ..addListener(_scheduleAutosave);
      _ink?.markSaved();
      _denormPending = false;
    });
  }

  void _scheduleAutosave() {
    if (_saveState != _SaveState.saving) {
      setState(() => _saveState = _SaveState.unsaved);
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 1500), () => _save());
  }

  Future<bool> _save({bool silent = false}) async {
    final ink = _ink;
    if (ink == null) return true;
    if (widget.onSave == null) {
      if (mounted && !silent) setState(() => _saveState = _SaveState.saved);
      ink.markSaved();
      return true;
    }
    if (mounted) setState(() => _saveState = _SaveState.saving);
    try {
      final box = _boxSize;
      // 평탄화 PNG: 원본만 보기 토글이 꺼져 있어도 저장 PNG엔 주석 포함이 자연스러움.
      Uint8List? png;
      if (!ink.isEmpty) {
        png = await CanvasExporter.capturePng(_captureKey, pixelRatio: 2.0);
      }
      // ★ 저장 직전 0~1 정규화 (좌표 정합 핵심)
      final boxLocal = ink.toSketch(
        canvasWidth: box?.width ?? 0,
        canvasHeight: box?.height ?? 0,
      );
      final normalized = (box != null)
          ? ScanCoordMapper.normalize(
              boxLocal,
              boxWidth: box.width,
              boxHeight: box.height,
            )
          : boxLocal;

      await widget.onSave!.call(ScanAnnotationPayload(
        annotationJson: normalized.encode(),
        flattenedPng: png,
        hasAnnotations: !ink.isEmpty,
      ));
      ink.markSaved();
      if (mounted) setState(() => _saveState = _SaveState.saved);
      return true;
    } catch (_) {
      if (mounted) setState(() => _saveState = _SaveState.error);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = _ink;
    final aspect = _imageAspect;
    if (ink == null || aspect == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 캔버스: 어두운 매트 위에 스캔지가 떠 있는 형태(첨삭에 집중되는 배경).
    // ★ 측정 key(_boxKey)와 캡처 key(_captureKey)는 캔버스 내부의 실제 이미지
    //   박스(AspectRatio)에 붙습니다 → 정규화 분모/캡처가 이미지와 1:1로 일치.
    final canvas = Container(
      color: const Color(0xFF1F2430),
      padding: const EdgeInsets.all(12),
      child: ScanAnnotationCanvas(
        controller: ink,
        image: widget.image,
        imageAspectRatio: aspect,
        showAnnotations: _showAnnotations,
        boxKey: _boxKey,
        captureKey: _captureKey,
      ),
    );

    return PopScope(
      // 항상 가로채서 _handleClose에서 저장을 끝낸 뒤 직접 pop(중복 호출은 _closing으로 차단).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildTopBar(context),
        body: context.useWideLayout
            // 태블릿/데스크톱: 측면 툴바 + 캔버스
            ? Row(
                children: [
                  HandwritingToolbar(controller: ink),
                  const VerticalDivider(width: 1),
                  Expanded(child: canvas),
                ],
              )
            // 모바일: 캔버스 → 하단 툴바
            : Column(
                children: [
                  Expanded(child: canvas),
                  HandwritingToolbar(controller: ink),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _handleClose,
      ),
      title: Text(widget.title),
      actions: [
        // 원본만 보기 토글 (기획서 6 "원본만 보기")
        IconButton(
          tooltip: _showAnnotations ? '원본만 보기' : '주석 보기',
          icon: Icon(
              _showAnnotations ? Icons.visibility : Icons.visibility_off),
          onPressed: () =>
              setState(() => _showAnnotations = !_showAnnotations),
        ),
        _SaveIndicator(state: _saveState),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _handleClose,
          child: const Text('완료'),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

enum _SaveState { saved, unsaved, saving, error }

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.state});
  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    final (text, color, icon) = switch (state) {
      _SaveState.saved => ('저장됨', AppColors.success, Icons.cloud_done),
      _SaveState.unsaved => ('변경됨', AppColors.textSecondary, Icons.edit),
      _SaveState.saving => ('저장 중…', AppColors.secondary, Icons.sync),
      _SaveState.error => ('저장 실패', AppColors.danger, Icons.error_outline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
