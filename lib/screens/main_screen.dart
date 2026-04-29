import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/theme_context.dart';
import '../widgets/go_three_board_background.dart';
import 'capture_game_screen.dart';
import 'daily_puzzle_screen.dart';
import 'settings_screen.dart';

/// Main screen with a Cupertino tab bar at the bottom.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      context.read<SettingsProvider>();
      return const _MainTabScaffold();
    } on ProviderNotFoundException {
      return ChangeNotifierProvider(
        create: (_) => SettingsProvider(),
        child: const _MainTabScaffold(),
      );
    }
  }
}

class _MainTabScaffold extends StatefulWidget {
  const _MainTabScaffold();

  @override
  State<_MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<_MainTabScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final showSharedBoard =
        context.select<SettingsProvider, bool>((s) => s.appTheme.showsSharedBoard);
    final tabBarBottomInset = MediaQuery.paddingOf(context).bottom + 50.0;

    return DecoratedBox(
      decoration: BoxDecoration(color: palette.pageBackground),
      child: Stack(
        children: [
          if (showSharedBoard) const _SharedHeroBoardBackground(),
          Padding(
            padding: EdgeInsets.only(bottom: tabBarBottomInset),
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                CaptureGameScreen(),
                DailyPuzzleScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CupertinoTabBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              backgroundColor: palette.pageBackground,
              activeColor: palette.primary,
              inactiveColor: palette.tabInactive,
              border: Border(
                top: BorderSide(
                  color: palette.primary.withValues(alpha: 0.16),
                  width: 0.6,
                ),
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: _TabGlyph(kind: _TabGlyphKind.home),
                  activeIcon: _TabGlyph(kind: _TabGlyphKind.home, active: true),
                  label: '下棋',
                ),
                BottomNavigationBarItem(
                  icon: _TabGlyph(kind: _TabGlyphKind.match),
                  activeIcon:
                      _TabGlyph(kind: _TabGlyphKind.match, active: true),
                  label: '谜题',
                ),
                BottomNavigationBarItem(
                  icon: _TabGlyph(kind: _TabGlyphKind.settings),
                  activeIcon:
                      _TabGlyph(kind: _TabGlyphKind.settings, active: true),
                  label: '设置',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedHeroBoardBackground extends StatelessWidget {
  const _SharedHeroBoardBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                top: constraints.maxHeight * 0.06,
                left: 0,
                right: 0,
                height: constraints.maxHeight * 0.62,
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, -128),
                    child: const GoThreeBoardBackground(
                      boardSize: 19,
                      stones: kGoThreeDemoStones,
                      particles: false,
                      sceneScale: 0.88,
                      cameraLift: 0.01,
                      cameraDepth: 17.2,
                      targetZOffset: 0.0,
                      cinematicFov: 28.0,
                      boardRotationY: -0.62,
                      leafShadowOpacity: 0.16,
                      stoneExtraOverlayEnabled: true,
                      boardTopBrightness: 1.0,
                      boardWoodColor: 0xd0b39c,
                      toneMappingExposure: 0.44,
                      keyLightPosition: Offset3(5.5, 5.5, 5.5),
                      fillLightPosition: Offset3(-4.8, 2.2, 3.2),
                      keyLightIntensity: 1.44,
                      fillLightIntensity: 0.09,
                      ambientLightIntensity: 0.15,
                      sheenLightIntensity: 0.14,
                      keyLightColor: 0xfff0d2,
                      fillLightColor: 0xf4e8d8,
                      ambientLightColor: 0xffeddc,
                      sheenLightColor: 0xfffaed,
                      windowCenterU: 0.89,
                      windowCenterV: 0.43,
                      windowSpreadU: 1.17,
                      windowSpreadV: 3.64,
                      windowPlateau: 0.73,
                      windowFalloff: 0.97,
                      windowRotation: 0.39,
                      gridBaseOpacity: 0.78,
                      gridFadeMult: 0.00,
                      gridFadePower: 0.66,
                      gridFadeMin: 0.20,
                      lightMapFloor: 0.12,
                      lightMapIntensity: 1.49,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _TabGlyphKind { home, match, settings }

class _TabGlyph extends StatelessWidget {
  const _TabGlyph({
    required this.kind,
    this.active = false,
  });

  final _TabGlyphKind kind;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final color = active ? palette.primary : palette.tabInactive;
    return SizedBox(
      width: 19,
      height: 19,
      child: CustomPaint(
        painter: _TabGlyphPainter(
          kind: kind,
          color: color,
          active: active,
        ),
      ),
    );
  }
}

class _TabGlyphPainter extends CustomPainter {
  const _TabGlyphPainter({
    required this.kind,
    required this.color,
    required this.active,
  });

  final _TabGlyphKind kind;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color =
          active ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _TabGlyphKind.home:
        final roof = Path()
          ..moveTo(size.width * 0.18, size.height * 0.45)
          ..lineTo(size.width * 0.5, size.height * 0.16)
          ..lineTo(size.width * 0.82, size.height * 0.45);
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.24, size.height * 0.42,
              size.width * 0.52, size.height * 0.36),
          const Radius.circular(2.5),
        );
        canvas.drawPath(roof, stroke);
        canvas.drawRRect(body, fill);
        canvas.drawRRect(body, stroke);
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.78),
          Offset(size.width * 0.5, size.height * 0.56),
          stroke,
        );
      case _TabGlyphKind.match:
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(size.width * 0.34, size.height * 0.36),
            size.width * 0.13, active ? paint : stroke);
        canvas.drawCircle(Offset(size.width * 0.66, size.height * 0.64),
            size.width * 0.13, active ? paint : stroke);
        canvas.drawLine(
          Offset(size.width * 0.43, size.height * 0.43),
          Offset(size.width * 0.57, size.height * 0.57),
          stroke,
        );
      case _TabGlyphKind.settings:
        final cx = size.width * 0.5;
        final cy = size.height * 0.5;
        final r = size.width * 0.16;
        canvas.drawCircle(Offset(cx, cy), r, active ? fill : stroke);
        canvas.drawCircle(Offset(cx, cy), r, stroke);
        // 6 tick marks around the gear
        for (int i = 0; i < 6; i++) {
          final angle = math.pi / 3 * i;
          final inner = size.width * 0.28;
          final outer = size.width * 0.39;
          canvas.drawLine(
            Offset(cx + inner * math.cos(angle), cy + inner * math.sin(angle)),
            Offset(cx + outer * math.cos(angle), cy + outer * math.sin(angle)),
            stroke,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _TabGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.color != color ||
        oldDelegate.active != active;
  }
}
