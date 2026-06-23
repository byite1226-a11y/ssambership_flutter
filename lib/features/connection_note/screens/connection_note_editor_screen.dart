import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';
import '../../handwriting/input/handwriting_controller.dart';
import '../../handwriting/models/ink_sketch.dart';
import '../../handwriting/widgets/canvas_exporter.dart';
import '../../handwriting/widgets/handwriting_canvas.dart';
import '../../handwriting/widgets/handwriting_toolbar.dart';
import '../../../core/models/note.dart';

/// 저장 결과 묶음 — 데이터 레이어가 Storage에 올릴 재료.
/// (필기 원본 JSON + 목록용 썸네일 PNG + 텍스트/카테고리, 기획서 5-1/5-2)
class NoteSavePayload {
  NoteSavePayload({
    required this.title,
    required this.textBody,
    required this.category,
    required this.sketchJson,
    required this.thumbnailPng,
    required this.hasInk,
  });
  final String title;
  final String textBody;
  final NoteCategory category;
  final String sketchJson;
  final Uint8List? thumbnailPng;
  final bool hasInk;
}

/// 연결노트 필기 에디터 (하이브리드: 텍스트 레이어 + 필기 레이어).
///
/// 기획서 5-2 4영역 구성: 상단 바 / 도구 툴바 / 캔버스 / (페이지 네비 P1).
class ConnectionNoteEditorScreen extends StatefulWidget {
  const ConnectionNoteEditorScreen({
    super.key,
    required this.roomId,
    required this.authorRole, // 'student' | 'mentor'
    this.initialTitle = '',
    this.initialText = '',
    this.initialCategory = NoteCategory.memo,
    this.initialSketch,
    this.onSave,
  });

  final String roomId;
  final String authorRole;
  final String initialTitle;
  final String initialText;
  final NoteCategory initialCategory;
  final InkSketch? initialSketch;

  /// 실제 저장 연결부. null이면 화면 동작만(데이터 레이어 미연결 상태에서도 데모 가능).
  final Future<void> Function(NoteSavePayload payload)? onSave;

  @override
  State<ConnectionNoteEditorScreen> createState() =>
      _ConnectionNoteEditorScreenState();
}

class _ConnectionNoteEditorScreenState
    extends State<ConnectionNoteEditorScreen> {
  late final HandwritingController _ink;
  late final TextEditingController _title;
  late final TextEditingController _body;
  final GlobalKey _canvasKey = GlobalKey();

  late NoteCategory _category;
  Timer? _autosaveTimer;
  _SaveState _saveState = _SaveState.saved;

  @override
  void initState() {
    super.initState();
    _ink = HandwritingController(
      initial: widget.initialSketch,
      authorRole: widget.authorRole,
    )..addListener(_scheduleAutosave);
    _title = TextEditingController(text: widget.initialTitle)
      ..addListener(_scheduleAutosave);
    _body = TextEditingController(text: widget.initialText)
      ..addListener(_scheduleAutosave);
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    // 저장은 _handleClose/PopScope에서 await로 끝낸 뒤 pop. dispose는 정리만.
    _autosaveTimer?.cancel();
    _ink.dispose();
    _title.dispose();
    _body.dispose();
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

  // 자동저장: 변경 후 1.5초 디바운스 (기획서 6 "일정 간격/이탈 시 자동 저장")
  void _scheduleAutosave() {
    if (_saveState != _SaveState.saving) {
      setState(() => _saveState = _SaveState.unsaved);
    }
    _autosaveTimer?.cancel();
    _autosaveTimer =
        Timer(const Duration(milliseconds: 1500), () => _save());
  }

  Future<bool> _save({bool silent = false}) async {
    if (widget.onSave == null) {
      if (mounted && !silent) setState(() => _saveState = _SaveState.saved);
      _ink.markSaved();
      return true;
    }
    if (mounted) setState(() => _saveState = _SaveState.saving);
    try {
      final thumb = _ink.isEmpty
          ? null
          : await CanvasExporter.capturePng(_canvasKey, pixelRatio: 1.5);
      final sketch = _ink.toSketch();
      await widget.onSave!.call(NoteSavePayload(
        title: _title.text.trim(),
        textBody: _body.text.trim(),
        category: _category,
        sketchJson: sketch.encode(),
        thumbnailPng: thumb,
        hasInk: !_ink.isEmpty,
      ));
      _ink.markSaved();
      if (mounted) setState(() => _saveState = _SaveState.saved);
      return true;
    } catch (_) {
      if (mounted) setState(() => _saveState = _SaveState.error);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvas = RepaintBoundary(
      key: _canvasKey,
      child: HandwritingCanvas(controller: _ink),
    );

    final textLayer = _TextLayerField(controller: _body);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildTopBar(context),
        body: context.useWideLayout
            // 태블릿/데스크톱: 측면 툴바 + (캔버스 위, 텍스트 아래)
            ? Row(
                children: [
                  HandwritingToolbar(controller: _ink),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: canvas),
                        const Divider(height: 1),
                        textLayer,
                      ],
                    ),
                  ),
                ],
              )
            // 모바일: 캔버스 → 텍스트 → 하단 툴바
            : Column(
                children: [
                  Expanded(child: canvas),
                  textLayer,
                  HandwritingToolbar(controller: _ink),
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
      titleSpacing: 0,
      title: TextField(
        controller: _title,
        decoration: const InputDecoration(
          hintText: '노트 제목',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
        style:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      actions: [
        _CategoryDropdown(
          value: _category,
          onChanged: (v) {
            setState(() => _category = v);
            _scheduleAutosave();
          },
        ),
        const SizedBox(width: 8),
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

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.value, required this.onChanged});
  final NoteCategory value;
  final ValueChanged<NoteCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NoteCategory>(
      tooltip: '카테고리',
      onSelected: onChanged,
      itemBuilder: (_) => NoteCategory.values
          .map((c) => PopupMenuItem(
                value: c,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    // 9-1: 탭 의미 한 줄 설명 노출
                    Text(c.hint,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ))
          .toList(),
      child: Chip(
        label: Text(value.label),
        avatar: const Icon(Icons.label_outline, size: 16),
      ),
    );
  }
}

/// 텍스트 레이어 — 검색·요약·접근성 대상(기획서 4-1). 캔버스와 공존.
class _TextLayerField extends StatelessWidget {
  const _TextLayerField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      constraints: const BoxConstraints(maxHeight: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: null,
        decoration: const InputDecoration(
          hintText: '텍스트 메모 (검색·요약에 사용돼요)',
          border: InputBorder.none,
          filled: false,
          isDense: true,
        ),
      ),
    );
  }
}
