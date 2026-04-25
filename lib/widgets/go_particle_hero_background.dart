import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

// ── Public data types ─────────────────────────────────────────────────────────

/// Describes a single stone hint in the background scene.
class GoSceneStone {
  const GoSceneStone({
    required this.col,
    required this.row,
    required this.isBlack,
  });

  /// 0-based column index within the board grid.
  final int col;

  /// 0-based row index within the board grid.
  final int row;

  final bool isBlack;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoSceneStone &&
          col == other.col &&
          row == other.row &&
          isBlack == other.isBlack;

  @override
  int get hashCode => Object.hash(col, row, isBlack);
}

/// Configuration preset that drives the particle background scene.
class GoScenePreset {
  const GoScenePreset({
    this.boardSize = 9,
    this.stones = const [],
    this.warmth = 1.0,
    this.depthOfField = 1.0,
  });

  /// Board line count: 9, 13, or 19.
  final int boardSize;

  /// Decorative stone hints drawn on the background board.
  final List<GoSceneStone> stones;

  /// 0–1 colour warmth multiplier.
  final double warmth;

  /// 0–1 depth-of-field strength.
  final double depthOfField;

  /// Default 9×9 board with a sparse scattering of stones.
  static const GoScenePreset defaultPreset = GoScenePreset(
    boardSize: 9,
    stones: [
      GoSceneStone(col: 2, row: 2, isBlack: true),
      GoSceneStone(col: 6, row: 2, isBlack: false),
      GoSceneStone(col: 4, row: 4, isBlack: true),
      GoSceneStone(col: 2, row: 6, isBlack: false),
      GoSceneStone(col: 6, row: 6, isBlack: true),
      GoSceneStone(col: 4, row: 7, isBlack: false),
    ],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoScenePreset &&
          boardSize == other.boardSize &&
          warmth == other.warmth &&
          depthOfField == other.depthOfField &&
          _listEquals(stones, other.stones);

  @override
  int get hashCode => Object.hash(boardSize, warmth, depthOfField,
      Object.hashAll(stones));

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ── Main widget ───────────────────────────────────────────────────────────────

/// A full-bleed background widget that renders a particle-based Go board
/// scene using a [CustomPainter].  It is **completely independent** of any
/// game logic and can be placed behind any UI stack.
///
/// ```dart
/// Stack(
///   children: [
///     Positioned.fill(
///       child: GoParticleHeroBackground(
///         preset: GoScenePreset.defaultPreset,
///       ),
///     ),
///     // … your content …
///   ],
/// )
/// ```
class GoParticleHeroBackground extends StatelessWidget {
  const GoParticleHeroBackground({
    super.key,
    required this.preset,
    this.intensity = 1.0,
    this.blurStrength = 1.0,
    this.contentFadeStart = 0.58,
  });

  final GoScenePreset preset;

  /// Overall visual intensity (0–1).  Values below 1 dim the whole scene.
  final double intensity;

  /// Depth-of-field blur multiplier.
  final double blurStrength;

  /// Normalised Y position (0–1) at which the lower-fade begins to blend
  /// toward the warm-white UI background.
  final double contentFadeStart;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GoParticleScenePainter(
        preset: preset,
        intensity: intensity,
        blurStrength: blurStrength,
        contentFadeStart: contentFadeStart,
      ),
      size: Size.infinite,
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

/// [CustomPainter] that draws the full particle-based Go board scene.
///
/// Render order (back → front):
///   1. Warm base gradient
///   2. Board plane (perspective trapezoid fill)
///   3. Wood grain particles
///   4. Grid lines
///   5. Stone splats
///   6. Leaf splats (left foreground)
///   7. Bowl splats (top-right background)
///   8. Lower fade / information-reduction layer
class GoParticleScenePainter extends CustomPainter {
  const GoParticleScenePainter({
    required this.preset,
    this.intensity = 1.0,
    this.blurStrength = 1.0,
    this.contentFadeStart = 0.58,
  });

  final GoScenePreset preset;
  final double intensity;
  final double blurStrength;
  final double contentFadeStart;

  // Deterministic cheap pseudo-random noise (no dart:math Random state needed).
  static double _noise(int seed) {
    final v = math.sin(seed * 127.1 + seed * 311.7) * 43758.5453;
    return v - v.floor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawWarmBase(canvas, size);
    _drawBoardPlane(canvas, size);
    _drawWoodParticles(canvas, size);
    _drawGridLines(canvas, size);
    _drawStoneSplats(canvas, size);
    _drawLeafSplats(canvas, size);
    _drawBowlSplats(canvas, size);
    _drawLowerFade(canvas, size);
  }

  // ── 1. Warm base gradient ──────────────────────────────────────────────────

  void _drawWarmBase(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [Color(0xFFFFFCF7), Color(0xFFF5EBD8)],
      );
    canvas.drawRect(rect, paint);
  }

  // ── 2. Board plane ─────────────────────────────────────────────────────────

  /// The board is represented as a foreshortened trapezoid: wider/lower at the
  /// bottom (near), narrower/higher at the top (far).
  void _drawBoardPlane(Canvas canvas, Size size) {
    final tl = Offset(size.width * 0.18, size.height * 0.06);
    final tr = Offset(size.width * 0.88, size.height * 0.06);
    final br = Offset(size.width * 0.96, size.height * 0.70);
    final bl = Offset(size.width * 0.04, size.height * 0.70);

    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.5, size.height * 0.06),
        Offset(size.width * 0.5, size.height * 0.70),
        [
          const Color(0xFFDFCBAA).withValues(alpha: 0.55 * intensity),
          const Color(0xFFCCB282).withValues(alpha: 0.40 * intensity),
        ],
      );
    canvas.drawPath(path, paint);
  }

  // ── 3. Wood grain particles ────────────────────────────────────────────────

  void _drawWoodParticles(Canvas canvas, Size size) {
    const particleCount = 320;
    final woodColors = [
      const Color(0xFFD4B882),
      const Color(0xFFCFAF78),
      const Color(0xFFDCC48E),
      const Color(0xFFC8A870),
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < particleCount; i++) {
      final nx = _noise(i * 3 + 1);
      final ny = _noise(i * 7 + 2);
      // Constrain particles to the board area
      final px = size.width * (0.06 + 0.88 * nx);
      final py = size.height * (0.06 + 0.64 * ny);

      // depth: 0 = near (bottom), 1 = far (top)
      final depth = ny;
      final dof = depth * blurStrength * preset.depthOfField;

      final length =
          size.width * (0.04 - 0.026 * depth + 0.012 * _noise(i * 13));
      final strokeWidth = (1.1 - 0.7 * depth).clamp(0.3, 1.1);
      final alpha = (0.18 - 0.12 * depth) * intensity;
      final angle = -0.12 + 0.22 * _noise(i * 19) + math.pi * 0.04 * depth;
      final colorIdx = (_noise(i * 11) * woodColors.length).floor() %
          woodColors.length;
      final color = woodColors[colorIdx];

      final dx = math.cos(angle) * length * 0.5;
      final dy = math.sin(angle) * length * 0.5;

      if (dof > 0.08) {
        paint.maskFilter =
            MaskFilter.blur(BlurStyle.normal, dof * 2.0 * blurStrength);
      } else {
        paint.maskFilter = null;
      }

      paint
        ..color = color.withValues(alpha: alpha.clamp(0.02, 0.22))
        ..strokeWidth = strokeWidth;

      canvas.drawLine(
        Offset(px - dx, py - dy),
        Offset(px + dx, py + dy),
        paint,
      );
    }
    paint.maskFilter = null;
  }

  // ── 4. Grid lines ──────────────────────────────────────────────────────────

  void _drawGridLines(Canvas canvas, Size size) {
    final n = preset.boardSize; // number of lines
    if (n < 2) return;

    // Board trapezoid corners (same as _drawBoardPlane).
    final topLeft = Offset(size.width * 0.18, size.height * 0.06);
    final topRight = Offset(size.width * 0.88, size.height * 0.06);
    final bottomRight = Offset(size.width * 0.96, size.height * 0.70);
    final bottomLeft = Offset(size.width * 0.04, size.height * 0.70);

    // Interpolate a point on a perspective row (t: 0=top, 1=bottom).
    Offset rowLeft(double t) => Offset(
          _lerpd(topLeft.dx, bottomLeft.dx, t),
          _lerpd(topLeft.dy, bottomLeft.dy, t),
        );
    Offset rowRight(double t) => Offset(
          _lerpd(topRight.dx, bottomRight.dx, t),
          _lerpd(topRight.dy, bottomRight.dy, t),
        );
    // Interpolate on a column (s: 0=left, 1=right) at row t.
    Offset colAt(double s, double t) => Offset(
          _lerpd(rowLeft(t).dx, rowRight(t).dx, s),
          _lerpd(rowLeft(t).dy, rowRight(t).dy, s),
        );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    // Horizontal lines (constant row index).
    for (int r = 0; r < n; r++) {
      final t = r / (n - 1).toDouble();
      final depth = t; // 0=near, 1=far — inverted: near is bottom
      final alpha =
          _lerpd(0.32, 0.06, depth) * intensity; // near more visible
      linePaint.color = const Color(0xFF8B7355).withValues(alpha: alpha);
      canvas.drawLine(rowLeft(1.0 - t), rowRight(1.0 - t), linePaint);
    }

    // Vertical lines (constant column index).
    for (int c = 0; c < n; c++) {
      final s = c / (n - 1).toDouble();
      // Draw a short-to-long vertical stripe from top to bottom.
      final topPt = colAt(s, 0.0);
      final botPt = colAt(s, 1.0);
      // Alpha varies with s to give a slight left-right depth cue.
      final alpha = _lerpd(0.28, 0.20, s) * intensity;
      linePaint.color = const Color(0xFF8B7355).withValues(alpha: alpha);
      canvas.drawLine(topPt, botPt, linePaint);
    }
  }

  static double _lerpd(double a, double b, double t) => a + (b - a) * t;

  // ── 5. Stone splats ────────────────────────────────────────────────────────

  void _drawStoneSplats(Canvas canvas, Size size) {
    final n = preset.boardSize;
    if (n < 2) return;

    final topLeft = Offset(size.width * 0.18, size.height * 0.06);
    final topRight = Offset(size.width * 0.88, size.height * 0.06);
    final bottomRight = Offset(size.width * 0.96, size.height * 0.70);
    final bottomLeft = Offset(size.width * 0.04, size.height * 0.70);

    Offset gridPoint(int col, int row) {
      final s = col / (n - 1).toDouble();
      final t = 1.0 - row / (n - 1).toDouble(); // row 0 = bottom (near)
      final left = Offset(
        _lerpd(topLeft.dx, bottomLeft.dx, t),
        _lerpd(topLeft.dy, bottomLeft.dy, t),
      );
      final right = Offset(
        _lerpd(topRight.dx, bottomRight.dx, t),
        _lerpd(topRight.dy, bottomRight.dy, t),
      );
      return Offset(
        _lerpd(left.dx, right.dx, s),
        _lerpd(left.dy, right.dy, s),
      );
    }

    for (final stone in preset.stones) {
      final col = stone.col.clamp(0, n - 1);
      final row = stone.row.clamp(0, n - 1);
      final center = gridPoint(col, row);

      // depth: rows near bottom (row ~0) are near; near top are far
      final depth = 1.0 - row / (n - 1).toDouble();
      final radius = size.width *
          (_lerpd(0.028, 0.016, depth)) *
          (0.9 + 0.2 * _noise(col * 7 + row * 13));
      final blur = depth * 2.8 * blurStrength * preset.depthOfField;
      final alpha = _lerpd(0.82, 0.38, depth) * intensity;

      _drawStone(canvas, center, radius, blur, alpha, stone.isBlack);
    }
  }

  void _drawStone(Canvas canvas, Offset center, double radius, double blur,
      double alpha, bool isBlack) {
    // 1. Contact shadow
    final shadowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8 + 1.0)
      ..color = const Color(0xFF000000).withValues(alpha: 0.22 * alpha);
    canvas.drawOval(
      Rect.fromCenter(
          center: center + Offset(radius * 0.15, radius * 0.4),
          width: radius * 2.2,
          height: radius * 1.1),
      shadowPaint,
    );

    // 2. Body – use saveLayer so alpha applies to the whole stone at once.
    final bodyRect = Rect.fromCenter(
        center: center, width: radius * 2, height: radius * 2);
    canvas.saveLayer(bodyRect.inflate(radius), Paint());
    final gradPaint = Paint()
      ..shader = ui.Gradient.radial(
        center + Offset(-radius * 0.25, -radius * 0.28),
        radius * 1.2,
        isBlack
            ? [
                Color.fromARGB((alpha * 255).round(), 80, 74, 70),
                Color.fromARGB((alpha * 255).round(), 20, 20, 20),
              ]
            : [
                Color.fromARGB((alpha * 255).round(), 252, 250, 246),
                Color.fromARGB((alpha * 255).round(), 224, 219, 210),
              ],
      );
    if (blur > 0.3) {
      gradPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    }
    canvas.drawOval(bodyRect, gradPaint);

    // 3. Highlight
    if (blur < 2.5) {
      final hlRadius = radius * 0.28;
      final hlCenter = center + Offset(-radius * 0.30, -radius * 0.32);
      final hlPaint = Paint()
        ..shader = ui.Gradient.radial(
          hlCenter,
          hlRadius * 1.4,
          [
            isBlack
                ? const Color(0x40FFFFFF)
                : const Color(0xC8FFFFFF),
            const Color(0x00FFFFFF),
          ],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, hlRadius * 0.6);
      canvas.drawCircle(hlCenter, hlRadius * 1.4, hlPaint);
    }

    canvas.restore();
  }

  // ── 6. Leaf splats ─────────────────────────────────────────────────────────

  void _drawLeafSplats(Canvas canvas, Size size) {
    final leaves = [
      _LeafSpec(
        center: Offset(size.width * -0.04, size.height * 0.22),
        width: size.width * 0.34,
        height: size.height * 0.14,
        angle: -0.55,
        color: const Color(0xFF8FA882),
        alpha: 0.28 * intensity,
        blur: 14.0,
      ),
      _LeafSpec(
        center: Offset(size.width * 0.08, size.height * 0.34),
        width: size.width * 0.28,
        height: size.height * 0.10,
        angle: -0.30,
        color: const Color(0xFF7A9870),
        alpha: 0.22 * intensity,
        blur: 18.0,
      ),
      _LeafSpec(
        center: Offset(size.width * -0.02, size.height * 0.44),
        width: size.width * 0.22,
        height: size.height * 0.08,
        angle: -0.70,
        color: const Color(0xFF6B8C64),
        alpha: 0.18 * intensity,
        blur: 20.0,
      ),
      _LeafSpec(
        center: Offset(size.width * 0.14, size.height * 0.15),
        width: size.width * 0.18,
        height: size.height * 0.07,
        angle: 0.10,
        color: const Color(0xFF8FA882),
        alpha: 0.15 * intensity,
        blur: 22.0,
      ),
    ];

    for (final leaf in leaves) {
      final rect = Rect.fromCenter(
          center: leaf.center, width: leaf.width, height: leaf.height);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          leaf.center,
          math.max(leaf.width, leaf.height) * 0.6,
          [
            leaf.color.withValues(alpha: leaf.alpha),
            leaf.color.withValues(alpha: 0.0),
          ],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, leaf.blur * blurStrength);

      canvas.save();
      canvas.translate(leaf.center.dx, leaf.center.dy);
      canvas.rotate(leaf.angle);
      canvas.translate(-leaf.center.dx, -leaf.center.dy);
      canvas.drawOval(rect, paint);
      canvas.restore();
    }
  }

  // ── 7. Bowl splats ─────────────────────────────────────────────────────────

  void _drawBowlSplats(Canvas canvas, Size size) {
    final bowlCenter = Offset(size.width * 0.88, size.height * 0.12);
    final bowlW = size.width * 0.26;
    final bowlH = size.height * 0.14;

    // Outer wall
    _drawBlurEllipse(
      canvas,
      center: bowlCenter,
      width: bowlW,
      height: bowlH,
      color: const Color(0xFFA08560),
      alpha: 0.30 * intensity,
      blur: 16.0 * blurStrength,
    );

    // Inner shadow
    _drawBlurEllipse(
      canvas,
      center: bowlCenter + Offset(0, bowlH * 0.08),
      width: bowlW * 0.72,
      height: bowlH * 0.5,
      color: const Color(0xFF3A2A18),
      alpha: 0.20 * intensity,
      blur: 10.0 * blurStrength,
    );

    // Right specular
    _drawBlurEllipse(
      canvas,
      center: bowlCenter + Offset(bowlW * 0.24, -bowlH * 0.14),
      width: bowlW * 0.30,
      height: bowlH * 0.22,
      color: const Color(0xFFFFEDD4),
      alpha: 0.22 * intensity,
      blur: 8.0 * blurStrength,
    );

    // Contact shadow below bowl
    _drawBlurEllipse(
      canvas,
      center: bowlCenter + Offset(0, bowlH * 0.52),
      width: bowlW * 0.70,
      height: bowlH * 0.20,
      color: const Color(0xFF5C4022),
      alpha: 0.12 * intensity,
      blur: 14.0 * blurStrength,
    );
  }

  void _drawBlurEllipse(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color color,
    required double alpha,
    required double blur,
  }) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        math.max(width, height) * 0.6,
        [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0.0),
        ],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      paint,
    );
  }

  // ── 8. Lower fade ──────────────────────────────────────────────────────────

  void _drawLowerFade(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fadeStart = contentFadeStart;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * fadeStart),
        Offset(0, size.height),
        [
          const Color(0x00F9F3EA),
          const Color(0xB8F9F3EA),
          const Color(0xFFFBF7F0),
        ],
        [0.0, 0.55, 1.0],
      );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant GoParticleScenePainter oldDelegate) {
    return oldDelegate.preset != preset ||
        oldDelegate.intensity != intensity ||
        oldDelegate.blurStrength != blurStrength ||
        oldDelegate.contentFadeStart != contentFadeStart;
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _LeafSpec {
  const _LeafSpec({
    required this.center,
    required this.width,
    required this.height,
    required this.angle,
    required this.color,
    required this.alpha,
    required this.blur,
  });

  final Offset center;
  final double width;
  final double height;
  final double angle;
  final Color color;
  final double alpha;
  final double blur;
}
