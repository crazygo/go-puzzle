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
  ///
  /// The list is treated as immutable; replace the [GoScenePreset] instance
  /// rather than mutating the list to trigger a repaint.
  final List<GoSceneStone> stones;

  /// 0–1 colour warmth multiplier applied to wood-grain and board tones.
  final double warmth;

  /// 0–1 depth-of-field strength.
  final double depthOfField;

  /// Default 9×9 board with a sparse scattering of stones.
  static const GoScenePreset defaultPreset = GoScenePreset(
    boardSize: 9,
    stones: [
      GoSceneStone(col: 4, row: 2, isBlack: true),
      GoSceneStone(col: 6, row: 2, isBlack: false),
      GoSceneStone(col: 5, row: 3, isBlack: false),
      GoSceneStone(col: 3, row: 4, isBlack: true),
      GoSceneStone(col: 6, row: 4, isBlack: true),
      GoSceneStone(col: 4, row: 5, isBlack: false),
      GoSceneStone(col: 7, row: 5, isBlack: true),
      GoSceneStone(col: 5, row: 6, isBlack: false),
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
    this.contentFadeStart = 0.82,
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
    return SizedBox.expand(
      child: CustomPaint(
        painter: GoParticleScenePainter(
          preset: preset,
          intensity: intensity,
          blurStrength: blurStrength,
          contentFadeStart: contentFadeStart,
        ),
      ),
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
    this.contentFadeStart = 0.82,
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

  // ── Real 3-D perspective camera ───────────────────────────────────────────
  // World axes: X = right, Y = into scene, Z = up.
  // Board top surface occupies [0,1]×[0,1] in XY at Z = _kThick.
  // Camera is upper-left: negative X offset, in front (negative Y), elevated Z.
  //
  // _CamBasis is built once per paint() call and passed to every draw method.

  static const _kThick  = 0.065;                      // board thickness (world units)
  static const _kCamPos = _Vec3(-0.15, -0.55, 0.72);  // camera position
  static const _kCamTgt = _Vec3(0.50,  0.50,  _kThick); // look-at target
  static const _kFovY   = 1.012;                       // 58° vertical FoV (radians)

  /// Project board-surface fraction (c, r) → screen Offset via real camera.
  Offset _p(double c, double r, _CamBasis cam) =>
      cam.project(_Vec3(c, r, _kThick)) ??
      Offset(cam.size.width * c, cam.size.height);

  // ── 3-D Lambertian lighting ───────────────────────────────────────────────
  // Light direction (unit vector FROM surface TOWARD light): upper-left overhead.
  static const _kLx = -0.38, _kLy = -0.44, _kLz = 0.82;
  static const _kAmbient = 0.28;

  /// Lambertian brightness for a face with outward world-space normal (nx,ny,nz).
  static double _lit(double nx, double ny, double nz) {
    final d = (nx * _kLx + ny * _kLy + nz * _kLz).clamp(0.0, 1.0);
    return _kAmbient + (1.0 - _kAmbient) * d;
  }

  /// Scale a [Color]'s RGB channels by brightness [b] ∈ [0, 1].
  static Color _dim(Color c, double b) => Color.fromARGB(
        c.alpha,
        (c.red   * b).round().clamp(0, 255),
        (c.green * b).round().clamp(0, 255),
        (c.blue  * b).round().clamp(0, 255),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final cam = _CamBasis.build(
      pos: _kCamPos,
      target: _kCamTgt,
      fovY: _kFovY,
      size: size,
    );
    _drawWarmBase(canvas, size);
    _drawBoardPlane(canvas, size, cam);
    _drawWoodParticles(canvas, size, cam);
    _drawGridLines(canvas, size, cam);
    _drawStoneSplats(canvas, size, cam);
    _drawLeafSplats(canvas, size);
    _drawBowlSplats(canvas, size);
    _drawLowerFade(canvas, size);
  }

  // ── 1. Warm base gradient ──────────────────────────────────────────────────

  void _drawWarmBase(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // warmth 1.0 → full amber tint; 0.0 → neutral grey-white
    final warmAlpha = (0.06 * preset.warmth).clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [
          Color.lerp(const Color(0xFFF8F8F8), const Color(0xFFFFFCF7),
              preset.warmth)!,
          Color.lerp(const Color(0xFFECECEC), const Color(0xFFF5EBD8),
              preset.warmth)!,
        ],
      );
    canvas.drawRect(rect, paint);
    // Extra amber glow at the top when warmth > 0
    if (warmAlpha > 0.0) {
      final glowPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height * 0.4),
          [
            const Color(0xFFF5C87A).withValues(alpha: warmAlpha),
            const Color(0x00F5C87A),
          ],
        );
      canvas.drawRect(rect, glowPaint);
    }
  }

  // ── 2. Board box — real 3-D ────────────────────────────────────────────────

  void _drawBoardPlane(Canvas canvas, Size size, _CamBasis cam) {
    final t = _kThick;

    // 8 vertices of the board box in world space.
    // Indices 0-3: bottom face; 4-7: top face.
    final v = [
      _Vec3(0, 0, 0), _Vec3(1, 0, 0), _Vec3(1, 1, 0), _Vec3(0, 1, 0),
      _Vec3(0, 0, t), _Vec3(1, 0, t), _Vec3(1, 1, t), _Vec3(0, 1, t),
    ];

    // Project all 8 vertices.
    final sv = [for (final w in v) cam.project(w)];

    // Six faces: (vertex-index list, outward world-space normal).
    final faces = <(List<int>, _Vec3)>[
      ([7, 6, 5, 4], const _Vec3( 0,  0,  1)),  // top
      ([0, 1, 2, 3], const _Vec3( 0,  0, -1)),  // bottom
      ([4, 5, 1, 0], const _Vec3( 0, -1,  0)),  // front
      ([6, 7, 3, 2], const _Vec3( 0,  1,  0)),  // back
      ([7, 4, 0, 3], const _Vec3(-1,  0,  0)),  // left
      ([5, 6, 2, 1], const _Vec3( 1,  0,  0)),  // right
    ];

    // Back-face culling: a face is visible when the camera is on the side the
    // outward normal points toward, i.e. dot(n, cam.pos - faceCenter) > 0.
    final visible = <(List<int>, _Vec3, double)>[];
    for (final (vi, n) in faces) {
      var cx = 0.0, cy = 0.0, cz = 0.0;
      for (final i in vi) { cx += v[i].x; cy += v[i].y; cz += v[i].z; }
      final cnt = vi.length.toDouble();
      final center = _Vec3(cx / cnt, cy / cnt, cz / cnt);
      if (n.dot(cam.pos - center) > 0) {
        visible.add((vi, n, cam.depth(center)));
      }
    }

    // Painter's algorithm: draw farthest faces first.
    visible.sort((a, b) => b.$3.compareTo(a.$3));

    const base = Color(0xFFEEC060);

    for (final (vi, n, _) in visible) {
      final pts = [for (final i in vi) sv[i]].whereType<Offset>().toList();
      if (pts.length < 3) continue;

      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (final pt in pts.skip(1)) path.lineTo(pt.dx, pt.dy);
      path.close();

      final bright = _lit(n.x, n.y, n.z);

      if (n.z > 0.5) {
        // ── Top surface: far (dim) → near (bright) gradient ─────────────────
        final pFar  = cam.project(_Vec3(0.5, 1.0, t));
        final pNear = cam.project(_Vec3(0.5, 0.0, t));
        if (pFar != null && pNear != null) {
          canvas.drawPath(
            path,
            Paint()
              ..shader = ui.Gradient.linear(pFar, pNear, [
                _dim(base, bright * 0.88).withValues(alpha: intensity),
                _dim(base, bright * 1.05).withValues(alpha: intensity),
              ]),
          );
        } else {
          canvas.drawPath(
            path,
            Paint()..color = _dim(base, bright).withValues(alpha: intensity),
          );
        }
        // Subtle overhead light hotspot.
        final lp = cam.project(_Vec3(0.38, 0.45, t));
        if (lp != null) {
          canvas.drawOval(
            Rect.fromCenter(
                center: lp,
                width: size.width * 0.44,
                height: size.height * 0.09),
            Paint()
              ..shader = ui.Gradient.radial(lp, size.width * 0.23, [
                const Color(0xFFFFFFFF).withValues(alpha: 0.13 * intensity),
                const Color(0x00FFFFFF),
              ]),
          );
        }
      } else {
        // ── Side face: top-edge (brighter) → bottom-edge (darker) gradient ──
        final topY = pts.map((p) => p.dy).reduce(math.min);
        final botY = pts.map((p) => p.dy).reduce(math.max);
        final midX = pts.fold(0.0, (a, p) => a + p.dx) / pts.length;
        canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(midX, topY),
              Offset(midX, botY),
              [
                _dim(base, bright).withValues(alpha: intensity),
                _dim(base, bright * 0.68).withValues(alpha: intensity),
              ],
            ),
        );
      }
    }
  }

  // ── 3. Wood grain particles ────────────────────────────────────────────────

  void _drawWoodParticles(Canvas canvas, Size size, _CamBasis cam) {
    const particleCount = 340;
    // Grain is slightly lighter and darker than the top surface.
    final topBright = _lit(0, 0, 1);
    const base = Color(0xFFEEC060);
    final woodColors = [
      _dim(base, topBright * 1.08),
      _dim(base, topBright * 0.95),
      _dim(base, topBright * 1.12),
      _dim(base, topBright * 0.88),
    ];

    // Reference depth at the near edge — used to normalize depthScale.
    final czRef = cam.depth(_Vec3(0.5, 0.0, _kThick));

    // Clip particles to the board surface.
    final boardPath = Path()
      ..moveTo(_p(0.0, 1.0, cam).dx, _p(0.0, 1.0, cam).dy)
      ..lineTo(_p(1.0, 1.0, cam).dx, _p(1.0, 1.0, cam).dy)
      ..lineTo(_p(1.0, 0.0, cam).dx, _p(1.0, 0.0, cam).dy)
      ..lineTo(_p(0.0, 0.0, cam).dx, _p(0.0, 0.0, cam).dy)
      ..close();

    canvas.save();
    canvas.clipPath(boardPath);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < particleCount; i++) {
      final nx = _noise(i * 3 + 1); // c fraction
      final ny = _noise(i * 7 + 2); // r fraction: 0=near, 1=far

      final center = _p(nx, ny, cam);

      // Real perspective depth for this particle.
      final cz = cam.depth(_Vec3(nx, ny, _kThick));
      final depthScale = czRef / cz.clamp(0.001, double.infinity);

      final dof = ny * blurStrength * preset.depthOfField;
      final length = size.width *
          (0.018 + 0.032 * (1.0 - ny) + 0.014 * _noise(i * 13)) *
          depthScale;
      final strokeWidth = (0.35 + 1.0 * (1.0 - ny)).clamp(0.35, 1.4) * depthScale;
      final alpha = (0.10 + 0.22 * (1.0 - ny)) * intensity;
      // Grain runs roughly horizontal with slight perspective convergence.
      final angle = -0.06 + 0.16 * _noise(i * 19) + 0.04 * ny;
      final colorIdx =
          (_noise(i * 11) * woodColors.length).floor() % woodColors.length;

      final dx = math.cos(angle) * length * 0.5;
      final dy = math.sin(angle) * length * 0.5;

      if (dof > 0.08) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, dof * 2.0);
      } else {
        paint.maskFilter = null;
      }

      paint
        ..color = woodColors[colorIdx].withValues(alpha: alpha.clamp(0.04, 0.32))
        ..strokeWidth = strokeWidth;

      canvas.drawLine(
        Offset(center.dx - dx, center.dy - dy),
        Offset(center.dx + dx, center.dy + dy),
        paint,
      );
    }
    paint.maskFilter = null;
    canvas.restore();
  }

  // ── 4. Grid lines ──────────────────────────────────────────────────────────

  void _drawGridLines(Canvas canvas, Size size, _CamBasis cam) {
    final n = preset.boardSize;
    if (n < 2) return;

    final linePaint = Paint()..style = PaintingStyle.stroke;

    // Horizontal lines — row 0 is near (bold/dark), row n-1 is far (faint).
    for (int r = 0; r < n; r++) {
      final rowFrac = r / (n - 1).toDouble();
      final alpha = _lerpd(0.72, 0.22, rowFrac) * intensity;
      final sw = _lerpd(1.4, 0.50, rowFrac);
      linePaint
        ..color = const Color(0xFF3C2808).withValues(alpha: alpha)
        ..strokeWidth = sw;
      canvas.drawLine(_p(0.0, rowFrac, cam), _p(1.0, rowFrac, cam), linePaint);
    }

    // Vertical lines — clearly visible on warm board.
    for (int c = 0; c < n; c++) {
      final colFrac = c / (n - 1).toDouble();
      final centerBias = 1.0 - (colFrac - 0.5).abs() * 1.6;
      final alpha = (0.38 + 0.14 * centerBias.clamp(0.0, 1.0)) * intensity;
      linePaint
        ..color = const Color(0xFF3C2808).withValues(alpha: alpha)
        ..strokeWidth = 0.7;
      canvas.drawLine(_p(colFrac, 0.0, cam), _p(colFrac, 1.0, cam), linePaint);
    }
  }

  static double _lerpd(double a, double b, double t) => a + (b - a) * t;

  // ── 5. Stones — 3-D biconvex lens, smooth Phong shading ──────────────────

  void _drawStoneSplats(Canvas canvas, Size size, _CamBasis cam) {
    final n = preset.boardSize;
    if (n < 2) return;

    // World-space radii. Go stone ≈ oblate ellipsoid (biconvex lens).
    final Rxy = 0.44 / (n - 1); // horizontal radius
    final Rz  = Rxy * 0.30;     // vertical  radius (≈ 30% of horizontal)

    // Painter's algorithm: far stones first.
    final stones = [...preset.stones];
    stones.sort((a, b) {
      final da = cam.depth(_Vec3(
          a.col.clamp(0, n - 1) / (n - 1), a.row.clamp(0, n - 1) / (n - 1), _kThick));
      final db = cam.depth(_Vec3(
          b.col.clamp(0, n - 1) / (n - 1), b.row.clamp(0, n - 1) / (n - 1), _kThick));
      return db.compareTo(da);
    });

    for (final stone in stones) {
      final cf = stone.col.clamp(0, n - 1) / (n - 1).toDouble();
      final rf = stone.row.clamp(0, n - 1) / (n - 1).toDouble();
      // Centre sits at board surface + Rz so bottom touches board at Z=_kThick.
      _drawStonePhong(canvas, cam, _Vec3(cf, rf, _kThick + Rz), Rxy, Rz,
          stone.isBlack);
    }
  }

  /// Smooth 3-D Go stone using:
  ///   • Projected equatorial ring as silhouette outline
  ///   • Analytically derived Phong specular peak projected to screen
  ///   • Smooth radial gradient fill (Lambertian + Phong model, no faceting)
  ///   • Contact shadow with correct light-direction offset
  void _drawStonePhong(Canvas canvas, _CamBasis cam, _Vec3 center,
      double Rxy, double Rz, bool isBlack) {
    const lightDir = _Vec3(_kLx, _kLy, _kLz);

    // ── Silhouette: project the equatorial ring + top pole ──────────────────
    // Equatorial ring (theta=π/2) is the widest cross-section of the lens.
    // The top pole adds the dome height above it.
    const nEq = 24;
    final eqPts = <Offset>[];
    for (int i = 0; i < nEq; i++) {
      final phi = 2.0 * math.pi * i / nEq;
      final p = cam.project(_Vec3(
        center.x + Rxy * math.cos(phi),
        center.y + Rxy * math.sin(phi),
        center.z, // equatorial Z = stone centre Z
      ));
      if (p != null) eqPts.add(p);
    }
    if (eqPts.length < 3) return;

    // Top pole: the highest point of the stone (Z = centre + Rz).
    final topPole = cam.project(_Vec3(center.x, center.y, center.z + Rz));

    // Build outline: equatorial polygon, then replace the screen-topmost arc
    // with the top pole to correctly represent the dome's visible tip.
    //
    // Strategy: split equatorial points into left/right halves relative to the
    // topmost equatorial screen point; insert top-pole between them.
    int topIdx = 0;
    for (int i = 1; i < eqPts.length; i++) {
      if (eqPts[i].dy < eqPts[topIdx].dy) topIdx = i;
    }
    int botIdx = 0;
    for (int i = 1; i < eqPts.length; i++) {
      if (eqPts[i].dy > eqPts[botIdx].dy) botIdx = i;
    }

    final outline = Path();
    if (topPole != null && topPole.dy < eqPts[topIdx].dy) {
      // Walk from botIdx → topIdx (one direction) through topPole, back via other.
      final n2 = eqPts.length;
      outline.moveTo(eqPts[botIdx].dx, eqPts[botIdx].dy);
      // Arc from botIdx to topIdx going forward (increasing index).
      int i = (botIdx + 1) % n2;
      while (i != topIdx) {
        outline.lineTo(eqPts[i].dx, eqPts[i].dy);
        i = (i + 1) % n2;
      }
      // Insert top pole.
      outline.lineTo(eqPts[topIdx].dx, eqPts[topIdx].dy);
      outline.lineTo(topPole.dx, topPole.dy);
      // Continue from topIdx back to botIdx via the other arc.
      i = (topIdx + 1) % n2;
      while (i != botIdx) {
        outline.lineTo(eqPts[i].dx, eqPts[i].dy);
        i = (i + 1) % n2;
      }
    } else {
      outline.moveTo(eqPts[0].dx, eqPts[0].dy);
      for (final p in eqPts.skip(1)) outline.lineTo(p.dx, p.dy);
    }
    outline.close();

    // ── Contact shadow on board surface ─────────────────────────────────────
    // Light comes from (_kLx, _kLy, _kLz). Shadow offset is opposite XY component.
    final shadowC = cam.project(_Vec3(
      center.x - _kLx * Rz * 0.55,
      center.y - _kLy * Rz * 0.55,
      _kThick,
    ));
    if (shadowC != null) {
      final se = cam.project(_Vec3(center.x + Rxy, center.y, _kThick));
      final sw = cam.project(_Vec3(center.x - Rxy, center.y, _kThick));
      final sn = cam.project(_Vec3(center.x, center.y - Rxy, _kThick));
      final ss = cam.project(_Vec3(center.x, center.y + Rxy, _kThick));
      if (se != null && sw != null) {
        final srx = (se.dx - sw.dx).abs() * 0.55;
        final sry = (sn != null && ss != null)
            ? (ss.dy - sn.dy).abs() * 0.30
            : srx * 0.42;
        canvas.drawOval(
          Rect.fromCenter(center: shadowC, width: srx * 2, height: sry * 2),
          Paint()
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, (srx * 0.32).clamp(1.5, 9.0))
            ..color =
                const Color(0xFF000000).withValues(alpha: 0.46 * intensity),
        );
      }
    }

    // ── Phong specular peak position ─────────────────────────────────────────
    // H = normalize(L + V) is the halfway vector. The specular peak lies at
    // the surface point whose outward normal equals H.
    // For ellipsoid (x/Rxy)^2+(y/Rxy)^2+(z/Rz)^2=1, the surface point with
    // normal proportional to (Hx,Hy,Hz) is:
    //   P = center + normalize(Hx, Hy, Hz*Rxy/Rz) * Rxy  (scaled to surface).
    final viewDir = (cam.pos - center).normalized();
    final halfVec = (lightDir + viewDir).normalized();
    final hScaled = _Vec3(halfVec.x, halfVec.y, halfVec.z * (Rxy / Rz));
    final hNorm   = hScaled.normalized();
    final specPt  = _Vec3(
      center.x + hNorm.x * Rxy,
      center.y + hNorm.y * Rxy,
      center.z + hNorm.z * Rz,
    );
    final specScreen = cam.project(specPt);

    // ── Gradient parameters ──────────────────────────────────────────────────
    // Gradient centre = specular peak on screen; radius spans stone + rim.
    final cxS = eqPts.fold(0.0, (s, p) => s + p.dx) / eqPts.length;
    final cyS = eqPts.fold(0.0, (s, p) => s + p.dy) / eqPts.length;
    final screenCtr = Offset(cxS, cyS);
    final maxR = eqPts.map((p) => (p - screenCtr).distance).reduce(math.max);
    final gradCtr = specScreen ?? screenCtr;

    // ── Stone body — smooth Phong radial gradient ────────────────────────────
    canvas.drawPath(
      outline,
      Paint()
        ..shader = ui.Gradient.radial(
          gradCtr,
          maxR * 2.1, // extends beyond edge → rim stays dark
          isBlack
              ? const [
                  Color(0xFF9E948A), // lit dome
                  Color(0xFF302A24), // diffuse charcoal
                  Color(0xFF0D0B09), // dark rim
                ]
              : const [
                  Color(0xFFFFFFFF), // specular white
                  Color(0xFFEBE8E2), // ivory diffuse
                  Color(0xFFB4B0A8), // shadowed rim
                ],
          [0.0, 0.36, 1.0],
        ),
    );

    // ── Specular highlight — crisp Phong hot-spot ────────────────────────────
    if (specScreen != null) {
      final hlR = maxR * (isBlack ? 0.26 : 0.40);
      canvas.drawOval(
        Rect.fromCenter(
            center: specScreen, width: hlR * 2.0, height: hlR * 1.55),
        Paint()
          ..shader = ui.Gradient.radial(specScreen, hlR, [
            isBlack ? const Color(0x5CFFFFFF) : const Color(0xF2FFFFFF),
            const Color(0x00FFFFFF),
          ])
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, isBlack ? 1.8 : 0.4),
      );
    }

    // ── Edge ring — white stones need subtle grey boundary ───────────────────
    if (!isBlack) {
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color =
              const Color(0xFF484840).withValues(alpha: 0.20 * intensity),
      );
    }
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

// ── 3-D math helpers ──────────────────────────────────────────────────────────

class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);

  double dot(_Vec3 o) => x * o.x + y * o.y + z * o.z;
  _Vec3 cross(_Vec3 o) =>
      _Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get len => math.sqrt(x * x + y * y + z * z);
  _Vec3 normalized() {
    final l = len;
    return l < 1e-9 ? this : this * (1.0 / l);
  }
}

class _CamBasis {
  _CamBasis._({
    required this.pos,
    required this.fwd,
    required this.right,
    required this.up,
    required this.tanHalfFov,
    required this.size,
  });

  factory _CamBasis.build({
    required _Vec3 pos,
    required _Vec3 target,
    required double fovY,
    required Size size,
  }) {
    const worldUp = _Vec3(0, 0, 1);
    final fwd = (target - pos).normalized();
    final right = fwd.cross(worldUp).normalized();
    final up = right.cross(fwd);
    return _CamBasis._(
      pos: pos,
      fwd: fwd,
      right: right,
      up: up,
      tanHalfFov: math.tan(fovY / 2),
      size: size,
    );
  }

  final _Vec3 pos, fwd, right, up;
  final double tanHalfFov;
  final Size size;

  /// Projects a world-space point to canvas [Offset]. Returns null if behind
  /// the camera (cz ≤ 0).
  Offset? project(_Vec3 p) {
    final d = p - pos;
    final cz = d.dot(fwd);
    if (cz <= 0.001) return null;
    final cx = d.dot(right);
    final cy = d.dot(up);
    final aspect = size.width / size.height;
    final nx = cx / (cz * tanHalfFov * aspect);
    final ny = cy / (cz * tanHalfFov);
    return Offset(size.width * (0.5 + nx * 0.5), size.height * (0.5 - ny * 0.5));
  }

  /// Camera-space depth of a world-space point (distance along look direction).
  double depth(_Vec3 p) => (p - pos).dot(fwd);
}
