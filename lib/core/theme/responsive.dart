import 'package:flutter/material.dart';

/// 디바이스 폼팩터. 기획서(연결노트 4-3 / 스캔주석 6)의 디바이스별 전략을
/// 코드 한 곳에서 판단하도록 모읍니다.
///
/// - mobile  : 손가락 입력, 바텀시트형 간이 에디터
/// - tablet  : 스타일러스 핵심, 전체화면 캔버스 + 측면 툴바 (★ 주 사용처)
/// - desktop : 마우스/키보드, 텍스트 우선 + 보조 캔버스 (Flutter 데스크톱/웹 대비)
enum FormFactor { mobile, tablet, desktop }

class Breakpoints {
  Breakpoints._();
  static const double tablet = 600; // dp 폭 600 이상 → 태블릿
  static const double desktop = 1100; // dp 폭 1100 이상 → 데스크톱
}

extension ResponsiveContext on BuildContext {
  double get _w => MediaQuery.sizeOf(this).width;

  FormFactor get formFactor {
    final w = _w;
    if (w >= Breakpoints.desktop) return FormFactor.desktop;
    if (w >= Breakpoints.tablet) return FormFactor.tablet;
    return FormFactor.mobile;
  }

  bool get isMobile => formFactor == FormFactor.mobile;
  bool get isTablet => formFactor == FormFactor.tablet;
  bool get isDesktop => formFactor == FormFactor.desktop;

  /// 태블릿 이상(태블릿+데스크톱)에서 측면 툴바/2단 레이아웃을 쓸지 여부.
  bool get useWideLayout => formFactor != FormFactor.mobile;

  /// 콘텐츠 최대 폭 — 큰 화면에서 본문이 과하게 늘어지지 않게 제한.
  double get contentMaxWidth => switch (formFactor) {
        FormFactor.mobile => double.infinity,
        FormFactor.tablet => 880,
        FormFactor.desktop => 1120,
      };

  /// 화면 공통 가로 패딩.
  double get gutter => switch (formFactor) {
        FormFactor.mobile => 16,
        FormFactor.tablet => 24,
        FormFactor.desktop => 32,
      };
}

/// 폼팩터별로 다른 위젯을 반환하는 빌더.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    switch (context.formFactor) {
      case FormFactor.desktop:
        return (desktop ?? tablet ?? mobile)(context);
      case FormFactor.tablet:
        return (tablet ?? mobile)(context);
      case FormFactor.mobile:
        return mobile(context);
    }
  }
}

/// 큰 화면에서 본문을 가운데로 모으고 최대폭을 제한하는 래퍼.
class ContentContainer extends StatelessWidget {
  const ContentContainer({super.key, required this.child, this.padded = true});

  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: Padding(
          padding: padded
              ? EdgeInsets.symmetric(horizontal: context.gutter)
              : EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
