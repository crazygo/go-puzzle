import 'package:flutter/cupertino.dart';

enum AppVisualTheme {
  agarwood('Agarwood'),
  classic('Classic');

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
  );

  static const classic = AppThemePalette(
    primary: Color(0xFF007AFF),
    tabInactive: Color(0xFF8E8E93),
    pageBackground: Color(0xFFF2F2F7),
    heroTitle: Color(0xFF111827),
    heroSubtitle: Color(0xFF6B7280),
    segmentTrack: Color(0xFFE5E5EA),
    segmentSelected: Color(0xFFFFFFFF),
    segmentSelectedText: Color(0xFF007AFF),
    segmentText: Color(0xFF3A3A3C),
    boardSideStart: Color(0xFFD9A85F),
    boardSideMid: Color(0xFFBF843D),
    boardSideEnd: Color(0xFF8F5C28),
    boardTop: Color(0xFFE2B86F),
    boardLine: Color(0xFF4B3420),
    coordinateText: Color(0xFF3F2B18),
  );
}
