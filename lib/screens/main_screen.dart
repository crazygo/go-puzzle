import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'capture_game_screen.dart';
import 'daily_puzzle_screen.dart';
import 'settings_screen.dart';

/// Main screen with a Cupertino tab bar at the bottom.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const _MainTabScaffold(),
    );
  }
}

class _MainTabScaffold extends StatelessWidget {
  const _MainTabScaffold();

  static const _inactiveColor = Color(0xFFAF9C86);
  static const _activeColor = Color(0xFFB9783A);

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: const Color(0xFFF9F4EC),
        activeColor: _activeColor,
        inactiveColor: _inactiveColor,
        border: const Border(
          top: BorderSide(
            color: Color(0x1AC19567),
            width: 0.6,
          ),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: _TabGlyph(kind: _TabGlyphKind.home),
            activeIcon: _TabGlyph(kind: _TabGlyphKind.home, active: true),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: _TabGlyph(kind: _TabGlyphKind.match),
            activeIcon: _TabGlyph(kind: _TabGlyphKind.match, active: true),
            label: '谜题',
          ),
          BottomNavigationBarItem(
            icon: _TabGlyph(kind: _TabGlyphKind.review),
            activeIcon: _TabGlyph(kind: _TabGlyphKind.review, active: true),
            label: '复盘',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(
              builder: (_) => const CaptureGameScreen(),
            );
          case 1:
            return CupertinoTabView(
              builder: (_) => const DailyPuzzleScreen(),
            );
          case 2:
            return CupertinoTabView(
              builder: (_) => const SettingsScreen(),
            );
          default:
            return CupertinoTabView(
              builder: (_) => const CaptureGameScreen(),
            );
        }
      },
    );
  }
}

enum _TabGlyphKind { home, match, review }

class _TabGlyph extends StatelessWidget {
  const _TabGlyph({
    required this.kind,
    this.active = false,
  });

  final _TabGlyphKind kind;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFB9783A) : const Color(0xFFAF9C86);
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
      case _TabGlyphKind.review:
        final circleRect = Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.5),
            radius: size.width * 0.3);
        canvas.drawArc(
            circleRect, -math.pi * 0.2, math.pi * 1.45, false, stroke);
        canvas.drawLine(
          Offset(size.width * 0.58, size.height * 0.34),
          Offset(size.width * 0.42, size.height * 0.5),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.42, size.height * 0.5),
          Offset(size.width * 0.66, size.height * 0.62),
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _TabGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.color != color ||
        oldDelegate.active != active;
  }
}
