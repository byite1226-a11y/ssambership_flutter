import 'dart:ui';

/// 필기 도구 종류. (연결노트 기술기획서 6 / 스캔주석 6)
/// v1(P0): pen, highlighter, eraser, text  ·  P1: lasso, shape
enum InkTool { pen, highlighter, eraser, lasso, shape, text }

/// 지우개 방식: 획 단위(스트로크 통째) vs 표준(부분).
enum EraserMode { stroke, partial }

/// 한 획(stroke)의 한 점. 좌표 + 필압.
///
/// ★ 스캔 주석에서는 이 좌표를 "원본 이미지 기준 정규화 좌표(0~1)"로 저장합니다
///   (스캔주석 기획서 2-2 — 가장 흔한 버그 지점). 연결노트 캔버스에서는
///   캔버스 로컬 좌표를 그대로 씁니다.
class InkPoint {
  const InkPoint(this.x, this.y, [this.pressure = 0.5]);

  final double x;
  final double y;
  final double pressure;

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() => {
        'x': _round(x),
        'y': _round(y),
        'p': _round(pressure),
      };

  factory InkPoint.fromJson(Map<String, dynamic> j) => InkPoint(
        (j['x'] as num).toDouble(),
        (j['y'] as num).toDouble(),
        (j['p'] as num?)?.toDouble() ?? 0.5,
      );
}

/// 하나의 획. 벡터(점 목록) + 스타일(색·굵기·도구).
/// "벡터 우선 저장" 원칙(기술기획서 1-3): 래스터 이미지가 아니라 좌표로 저장.
class InkStroke {
  InkStroke({
    required this.tool,
    required this.color,
    required this.width,
    List<InkPoint>? points,
    this.authorRole,
    this.widthNorm,
  }) : points = points ?? <InkPoint>[];

  final InkTool tool;
  final int color; // ARGB int (Color.value)
  final double width; // 기준 굵기 (size, px)
  final List<InkPoint> points;

  /// 작성자 구분(멘토/학생) — 색 자동 구분에 사용 (연결노트 9-3).
  final String? authorRole;

  /// 스캔 주석 정규화 저장용 굵기(박스 너비 대비 비율). 픽셀 캔버스에선 null.
  final double? widthNorm;

  bool get isEmpty => points.isEmpty;

  InkStroke copyWith({
    InkTool? tool,
    int? color,
    double? width,
    List<InkPoint>? points,
    String? authorRole,
    double? widthNorm,
  }) =>
      InkStroke(
        tool: tool ?? this.tool,
        color: color ?? this.color,
        width: width ?? this.width,
        points: points ?? this.points,
        authorRole: authorRole ?? this.authorRole,
        widthNorm: widthNorm ?? this.widthNorm,
      );

  Map<String, dynamic> toJson() => {
        't': tool.name,
        'c': color,
        'w': _round(width),
        if (widthNorm != null) 'wn': _round(widthNorm!),
        if (authorRole != null) 'r': authorRole,
        'pts': points.map((p) => p.toJson()).toList(growable: false),
      };

  factory InkStroke.fromJson(Map<String, dynamic> j) => InkStroke(
        tool: InkTool.values.firstWhere(
          (t) => t.name == j['t'],
          orElse: () => InkTool.pen,
        ),
        color: (j['c'] as num).toInt(),
        width: (j['w'] as num).toDouble(),
        widthNorm: (j['wn'] as num?)?.toDouble(),
        authorRole: j['r'] as String?,
        points: (j['pts'] as List)
            .map((e) => InkPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

double _round(double v) => (v * 1000).roundToDouble() / 1000;
