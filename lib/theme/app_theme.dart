import 'package:flutter/cupertino.dart';

enum AppVisualTheme {
  agarwood('沉香'),
  classic('經典');

  const AppVisualTheme(this.label);

  final String label;

  AppThemePalette get palette {
    switch (this) {
      case AppVisualTheme.agarwood:
        return AppThemePalette.agarwood;
      case AppVisualTheme.classic:
        return AppThemePalette.classic;
    }
  }

  /// Whether this theme shows the shared 3D hero board background.
  bool get showsSharedBoard => this == AppVisualTheme.agarwood;
}

class AppThemePalette {
  const AppThemePalette({
    required this.primary,
    required this.tabInactive,
    required this.pageBackground,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.segmentTrack,
    required this.segmentSelected,
    required this.segmentSelectedText,
    required this.segmentText,
    required this.boardSideStart,
    required this.boardSideMid,
    required this.boardSideEnd,
    required this.boardTop,
    required this.boardLine,
    required this.coordinateText,
    required this.setupPanelBackground,
    required this.setupPanelBorder,
    required this.setupTitleText,
    required this.setupActionText,
    required this.setupIconBackground,
    required this.setupIconForeground,
    required this.setupLabelText,
    required this.setupValueText,
    required this.setupDivider,
  });

  final Color primary;
  final Color tabInactive;
  final Color pageBackground;
  final Color heroTitle;
  final Color heroSubtitle;
  final Color segmentTrack;
  final Color segmentSelected;
  final Color segmentSelectedText;
  final Color segmentText;
  final Color boardSideStart;
  final Color boardSideMid;
  final Color boardSideEnd;
  final Color boardTop;
  final Color boardLine;
  final Color coordinateText;
  final Color setupPanelBackground;
  final Color setupPanelBorder;
  final Color setupTitleText;
  final Color setupActionText;
  final Color setupIconBackground;
  final Color setupIconForeground;
  final Color setupLabelText;
  final Color setupValueText;
  final Color setupDivider;

  AppThemePalette resolve(BuildContext context) {
    Color resolved(Color color) =>
        CupertinoDynamicColor.maybeResolve(color, context) ?? color;

    return AppThemePalette(
      primary: resolved(primary),
      tabInactive: resolved(tabInactive),
      pageBackground: resolved(pageBackground),
      heroTitle: resolved(heroTitle),
      heroSubtitle: resolved(heroSubtitle),
      segmentTrack: resolved(segmentTrack),
      segmentSelected: resolved(segmentSelected),
      segmentSelectedText: resolved(segmentSelectedText),
      segmentText: resolved(segmentText),
      boardSideStart: resolved(boardSideStart),
      boardSideMid: resolved(boardSideMid),
      boardSideEnd: resolved(boardSideEnd),
      boardTop: resolved(boardTop),
      boardLine: resolved(boardLine),
      coordinateText: resolved(coordinateText),
      setupPanelBackground: resolved(setupPanelBackground),
      setupPanelBorder: resolved(setupPanelBorder),
      setupTitleText: resolved(setupTitleText),
      setupActionText: resolved(setupActionText),
      setupIconBackground: resolved(setupIconBackground),
      setupIconForeground: resolved(setupIconForeground),
      setupLabelText: resolved(setupLabelText),
      setupValueText: resolved(setupValueText),
      setupDivider: resolved(setupDivider),
    );
  }

  static const agarwood = AppThemePalette(
    primary: Color(0xFFB87A3C),
    tabInactive: Color(0xFFAF9C86),
    pageBackground: Color(0xFFF9F4EC),
    heroTitle: Color(0xFF201712),
    heroSubtitle: Color(0xFF8E7C6C),
    segmentTrack: Color(0xFFF8F2E8),
    segmentSelected: Color(0xFFF3E2C9),
    segmentSelectedText: Color(0xFF8A5A2B),
    segmentText: Color(0xFF5A4B3F),
    boardSideStart: Color(0xFFE0B06B),
    boardSideMid: Color(0xFFC98E4F),
    boardSideEnd: Color(0xFF9A6530),
    boardTop: Color(0xFFE8C98E),
    boardLine: Color(0xFF7A5C36),
    coordinateText: Color(0xFF5C3A0A),
    setupPanelBackground: Color(0xFFFFFFFF),
    setupPanelBorder: Color(0x26D8C1A4),
    setupTitleText: Color(0xFF3A2A1F),
    setupActionText: Color(0xFFB68454),
    setupIconBackground: Color(0xFFF8F0E3),
    setupIconForeground: Color(0xFFB68454),
    setupLabelText: Color(0xFF9A8067),
    setupValueText: Color(0xFF36271E),
    setupDivider: Color(0x1ED2B28E),
  );

  static const classic = AppThemePalette(
    primary: CupertinoColors.systemBlue,
    tabInactive: CupertinoColors.systemGrey,
    pageBackground: CupertinoColors.systemGroupedBackground,
    heroTitle: CupertinoColors.label,
    heroSubtitle: CupertinoColors.secondaryLabel,
    segmentTrack: CupertinoColors.tertiarySystemFill,
    segmentSelected: CupertinoColors.secondarySystemGroupedBackground,
    segmentSelectedText: CupertinoColors.systemBlue,
    segmentText: CupertinoColors.label,
    boardSideStart: Color(0xFFD9A85F),
    boardSideMid: Color(0xFFBF843D),
    boardSideEnd: Color(0xFF8F5C28),
    boardTop: Color(0xFFE2B86F),
    boardLine: Color(0xFF4B3420),
    coordinateText: Color(0xFF3F2B18),
    setupPanelBackground: CupertinoColors.secondarySystemGroupedBackground,
    setupPanelBorder: CupertinoColors.separator,
    setupTitleText: CupertinoColors.label,
    setupActionText: CupertinoColors.systemBlue,
    setupIconBackground: CupertinoColors.tertiarySystemFill,
    setupIconForeground: CupertinoColors.secondaryLabel,
    setupLabelText: CupertinoColors.secondaryLabel,
    setupValueText: CupertinoColors.label,
    setupDivider: CupertinoColors.separator,
  );
}
