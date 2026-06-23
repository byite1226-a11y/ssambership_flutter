import 'dart:convert';
import 'ink_stroke.dart';

/// 배경 템플릿 (연결노트 5-2 / 6) — P1.
enum PaperTemplate { blank, lined, grid, dotted }

/// 한 필기 노트(캔버스)의 전체 데이터.
/// 이 객체를 JSON으로 직렬화해 Storage에 "필기 원본"으로 저장합니다.
/// (scribble의 sketch JSON과 동일한 역할 — 기술기획서 5-2)
class InkSketch {
  InkSketch({
    List<InkStroke>? strokes,
    this.template = PaperTemplate.blank,
    this.canvasWidth = 0,
    this.canvasHeight = 0,
    this.version = 1,
  }) : strokes = strokes ?? <InkStroke>[];

  final List<InkStroke> strokes;
  final PaperTemplate template;

  /// 작성 당시 캔버스 논리 크기(좌표 복원 정합용).
  final double canvasWidth;
  final double canvasHeight;
  final int version;

  bool get isEmpty => strokes.isEmpty;

  Map<String, dynamic> toJson() => {
        'v': version,
        'tpl': template.name,
        'cw': canvasWidth,
        'ch': canvasHeight,
        'strokes': strokes.map((s) => s.toJson()).toList(growable: false),
      };

  String encode() => jsonEncode(toJson());

  factory InkSketch.fromJson(Map<String, dynamic> j) => InkSketch(
        version: (j['v'] as num?)?.toInt() ?? 1,
        template: PaperTemplate.values.firstWhere(
          (t) => t.name == j['tpl'],
          orElse: () => PaperTemplate.blank,
        ),
        canvasWidth: (j['cw'] as num?)?.toDouble() ?? 0,
        canvasHeight: (j['ch'] as num?)?.toDouble() ?? 0,
        strokes: ((j['strokes'] as List?) ?? const [])
            .map((e) => InkStroke.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory InkSketch.decode(String source) =>
      InkSketch.fromJson(jsonDecode(source) as Map<String, dynamic>);

  InkSketch copyWith({
    List<InkStroke>? strokes,
    PaperTemplate? template,
    double? canvasWidth,
    double? canvasHeight,
  }) =>
      InkSketch(
        strokes: strokes ?? this.strokes,
        template: template ?? this.template,
        canvasWidth: canvasWidth ?? this.canvasWidth,
        canvasHeight: canvasHeight ?? this.canvasHeight,
        version: version,
      );
}
