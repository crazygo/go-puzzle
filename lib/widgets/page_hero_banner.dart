import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

// ── Hero layout constants (shared across all main tab screens) ───────────────
/// Visible hero height below the status bar.
const double kPageHeroVisibleHeight = 136.0;

/// How much the scrollable content card overlaps the bottom of the hero.
const double kPageHeroCardOverlap = 24.0;

/// Height of the transparent spacer that reveals the hero behind the
/// scroll view (= kPageHeroVisibleHeight - kPageHeroCardOverlap).
const double kPageHeroContentOffset =
    kPageHeroVisibleHeight - kPageHeroCardOverlap; // 112.0

// ── Shared background decoration ─────────────────────────────────────────────
/// Shared page background colour, matching the bottom tab bar.
const Color kPageBackgroundColor = Color(0xFFF9F4EC);

const BoxDecoration kPageBackgroundDecoration = BoxDecoration(
  color: kPageBackgroundColor,
);

/// Hero banner widget shared by all three main tab screens.
///
/// Renders the landscape background painting, optional orbital stone art,
/// a large [title], an optional [subtitle], and an optional [action] button
/// in the top-right corner.
class PageHeroBanner extends StatelessWidget {
  const PageHeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.showOrbitalArt = true,
  });

  final String title;
  final String? subtitle;

  /// Optional widget placed in the top-right of the hero (e.g. a "今天" button).
  final Widget? action;
  final bool showOrbitalArt;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: topPad + kPageHeroVisibleHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: topPad + 12,
            left: 24,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF201712),
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E7C6C),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 12),
                  action!,
                ],
              ],
            ),
          ),
          if (showOrbitalArt)
            Positioned(
              right: 0,
              top: topPad,
              bottom: 0,
              width: 160,
              child: const _HeroOrbitalArt(),
            ),
        ],
      ),
    );
  }
}

// ── Orbital stone art ─────────────────────────────────────────────────────────

class _HeroOrbitalArt extends StatefulWidget {
  const _HeroOrbitalArt();

  @override
  State<_HeroOrbitalArt> createState() => _HeroOrbitalArtState();
}

class _HeroOrbitalArtState extends State<_HeroOrbitalArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double? _fixedProgress;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final raw = Uri.base.queryParameters['particleProgress'];
      final parsed = raw == null ? null : double.tryParse(raw);
      if (parsed != null) {
        _fixedProgress = parsed.clamp(0.0, 0.9999);
      }
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    if (_fixedProgress == null) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _fixedProgress;
    if (progress != null) {
      return _HeroOrbitalStack(progress: progress);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _HeroOrbitalStack(progress: _controller.value);
      },
    );
  }
}

class _HeroOrbitalStack extends StatelessWidget {
  const _HeroOrbitalStack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _OrbitPainter(progress: progress),
          ),
        ),
        // Top black
        const Positioned(top: 28, child: _StoneDot(isBlack: true, size: 18)),
        // Center black
        const Positioned(top: 58, child: _StoneDot(isBlack: true, size: 20)),
        // Bottom black
        const Positioned(top: 88, child: _StoneDot(isBlack: true, size: 18)),
        // White flanking stones
        const Positioned(
            left: 26, top: 60, child: _StoneDot(isBlack: false, size: 16)),
        const Positioned(
            right: 26, top: 60, child: _StoneDot(isBlack: false, size: 16)),
      ],
    );
  }
}

class _StoneDot extends StatelessWidget {
  const _StoneDot({
    required this.isBlack,
    this.size = 28,
  });

  final bool isBlack;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isBlack
            ? const RadialGradient(
                center: Alignment(-0.3, -0.3),
                radius: 0.8,
                colors: [Color(0xFF4A4A4A), Color(0xFF121212)],
              )
            : const RadialGradient(
                center: Alignment(-0.3, -0.3),
                radius: 0.8,
                colors: [Color(0xFFFFFFFF), Color(0xFFE8E8E8)],
              ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
    );
  }
}

// ── Orbit painter ─────────────────────────────────────────────────────────────

class _OrbitPainter extends CustomPainter {
  final double progress;
  const _OrbitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.56, size.height * 0.46);
    final normalized = progress * 4;
    final frameIndex = normalized.floor() % 4;
    final frameT = normalized - frameIndex;
    final from = _OrbitFrame.frames[frameIndex];
    final to = _OrbitFrame.frames[(frameIndex + 1) % _OrbitFrame.frames.length];
    final frame = _OrbitFrame.lerp(from, to, frameT);
    final breath = 0.72 + 0.28 * math.sin(progress * math.pi * 2);

    _paintArcDust(canvas, center,
        frame: frame,
        radiusScale: 1.06,
        opacityScale: 0.38 * breath,
        dotScale: 0.84,
        seedOffset: 0);
    _paintArcDust(
      canvas,
      center,
      frame: frame.copyWith(
        startAngle: frame.startAngle - 0.16,
        sweepAngle: frame.sweepAngle * 0.92,
        eccentricityX: frame.eccentricityX * 0.92,
        eccentricityY: frame.eccentricityY * 0.92,
        rotation: frame.rotation + 0.08,
      ),
      radiusScale: 0.9,
      opacityScale: 0.18 * breath,
      dotScale: 0.58,
      seedOffset: 97,
    );
    _paintGuidingRing(canvas, center, frame, size);
    _paintMist(canvas, center, frame);
  }

  void _paintArcDust(
    Canvas canvas,
    Offset center, {
    required _OrbitFrame frame,
    required double radiusScale,
    required double opacityScale,
    required double dotScale,
    required int seedOffset,
  }) {
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final count = (170 * frame.density).round();
    final radiusX = 62.0 * frame.eccentricityX * radiusScale;
    final radiusY = 48.0 * frame.eccentricityY * radiusScale;

    for (int i = 0; i < count; i++) {
      final unit = i / math.max(1, count - 1);
      final shaped = Curves.easeInOut.transform(unit);
      final flutter = _noise(seedOffset + i * 17);
      final angle = frame.startAngle +
          frame.sweepAngle * shaped +
          flutter * 0.055 +
          math.sin((progress + unit) * math.pi * 2) * 0.01;
      final localRadiusX =
          radiusX * (0.92 + 0.12 * _noise(seedOffset + i * 31));
      final localRadiusY =
          radiusY * (0.92 + 0.12 * _noise(seedOffset + i * 29));
      final orbit = Offset(
        math.cos(angle) * localRadiusX,
        math.sin(angle) * localRadiusY,
      );
      final rotated = Offset(
        orbit.dx * math.cos(frame.rotation) -
            orbit.dy * math.sin(frame.rotation),
        orbit.dx * math.sin(frame.rotation) +
            orbit.dy * math.cos(frame.rotation),
      );
      final drift = Offset(
        (1 - shaped) * -12 + flutter * 4,
        (0.5 - shaped) * 7 + _noise(seedOffset + i * 7) * 3.5,
      );
      final offset = center + rotated + drift;
      final tailFade = math.pow(math.sin(unit * math.pi), 1.18).toDouble();
      final opacity =
          (0.028 + 0.28 * tailFade * opacityScale).clamp(0.015, 0.16);
      final radius = (0.32 + 1.1 * tailFade + flutter * 0.18) * dotScale;
      particlePaint.color = const Color(0xFFC99557).withValues(alpha: opacity);
      canvas.drawCircle(offset, radius, particlePaint);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..color = const Color(0xFFC99557).withValues(alpha: 0.038 * opacityScale);
    final arcRect = Rect.fromCenter(
      center: center,
      width: radiusX * 2,
      height: radiusY * 2,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(frame.rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(arcRect, frame.startAngle, frame.sweepAngle, false, stroke);
    canvas.restore();
    if (frame.sweepAngle > math.pi * 1.55) {
      final closurePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0xFFC99557).withValues(alpha: 0.028);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(frame.rotation + 0.03);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawOval(arcRect.inflate(6), closurePaint);
      canvas.restore();
    }
  }

  void _paintGuidingRing(
    Canvas canvas,
    Offset center,
    _OrbitFrame frame,
    Size size,
  ) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..color = const Color(0xFFC99557).withValues(alpha: 0.024);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(frame.rotation - 0.05);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 146, height: 114),
      frame.startAngle - 0.3,
      frame.sweepAngle * 0.72,
      false,
      ringPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 122, height: 94),
      frame.startAngle + 0.24,
      frame.sweepAngle * 0.46,
      false,
      ringPaint,
    );
    canvas.restore();
  }

  void _paintMist(Canvas canvas, Offset center, _OrbitFrame frame) {
    final mist = Paint()
      ..shader = ui.Gradient.radial(
        center + Offset(frame.trailingGlowX, frame.trailingGlowY),
        44,
        [
          const Color(0x1AF0C996),
          const Color(0x08F0C996),
          const Color(0x00F0C996),
        ],
        const [0.0, 0.42, 1.0],
      );
    canvas.drawCircle(
      center + Offset(frame.trailingGlowX, frame.trailingGlowY),
      44,
      mist,
    );
  }

  double _noise(int seed) {
    final value = math.sin(seed * 12.9898 + progress * 18.37) * 43758.5453;
    return value - value.floor();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _OrbitFrame {
  const _OrbitFrame({
    required this.startAngle,
    required this.sweepAngle,
    required this.rotation,
    required this.density,
    required this.eccentricityX,
    required this.eccentricityY,
    required this.trailingGlowX,
    required this.trailingGlowY,
  });

  final double startAngle;
  final double sweepAngle;
  final double rotation;
  final double density;
  final double eccentricityX;
  final double eccentricityY;
  final double trailingGlowX;
  final double trailingGlowY;

  static const frames = [
    _OrbitFrame(
      startAngle: math.pi * 0.92,
      sweepAngle: math.pi * 1.14,
      rotation: -0.34,
      density: 0.86,
      eccentricityX: 1.08,
      eccentricityY: 1.02,
      trailingGlowX: -18,
      trailingGlowY: -10,
    ),
    _OrbitFrame(
      startAngle: math.pi * 0.6,
      sweepAngle: math.pi * 1.62,
      rotation: -0.16,
      density: 1.04,
      eccentricityX: 1.12,
      eccentricityY: 1.06,
      trailingGlowX: -10,
      trailingGlowY: 14,
    ),
    _OrbitFrame(
      startAngle: math.pi * 0.15,
      sweepAngle: math.pi * 2.08,
      rotation: 0.06,
      density: 1.12,
      eccentricityX: 1.0,
      eccentricityY: 0.98,
      trailingGlowX: 10,
      trailingGlowY: 18,
    ),
    _OrbitFrame(
      startAngle: -math.pi * 0.1,
      sweepAngle: math.pi * 1.48,
      rotation: 0.26,
      density: 0.92,
      eccentricityX: 1.14,
      eccentricityY: 1.04,
      trailingGlowX: 18,
      trailingGlowY: -14,
    ),
  ];

  _OrbitFrame copyWith({
    double? startAngle,
    double? sweepAngle,
    double? rotation,
    double? density,
    double? eccentricityX,
    double? eccentricityY,
    double? trailingGlowX,
    double? trailingGlowY,
  }) {
    return _OrbitFrame(
      startAngle: startAngle ?? this.startAngle,
      sweepAngle: sweepAngle ?? this.sweepAngle,
      rotation: rotation ?? this.rotation,
      density: density ?? this.density,
      eccentricityX: eccentricityX ?? this.eccentricityX,
      eccentricityY: eccentricityY ?? this.eccentricityY,
      trailingGlowX: trailingGlowX ?? this.trailingGlowX,
      trailingGlowY: trailingGlowY ?? this.trailingGlowY,
    );
  }

  static _OrbitFrame lerp(_OrbitFrame a, _OrbitFrame b, double t) {
    return _OrbitFrame(
      startAngle: ui.lerpDouble(a.startAngle, b.startAngle, t)!,
      sweepAngle: ui.lerpDouble(a.sweepAngle, b.sweepAngle, t)!,
      rotation: ui.lerpDouble(a.rotation, b.rotation, t)!,
      density: ui.lerpDouble(a.density, b.density, t)!,
      eccentricityX: ui.lerpDouble(a.eccentricityX, b.eccentricityX, t)!,
      eccentricityY: ui.lerpDouble(a.eccentricityY, b.eccentricityY, t)!,
      trailingGlowX: ui.lerpDouble(a.trailingGlowX, b.trailingGlowX, t)!,
      trailingGlowY: ui.lerpDouble(a.trailingGlowY, b.trailingGlowY, t)!,
    );
  }
}
