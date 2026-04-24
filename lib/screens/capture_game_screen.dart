import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/board_position.dart';
import '../models/game_state.dart';
import '../providers/capture_game_provider.dart';
import '../widgets/go_board_widget.dart';

class CaptureGameScreen extends StatefulWidget {
  const CaptureGameScreen({super.key});

  @override
  State<CaptureGameScreen> createState() => _CaptureGameScreenState();
}

class _CaptureGameScreenState extends State<CaptureGameScreen> {
  static const _difficultyKey = 'capture_setup.difficulty';
  static const _boardSizeKey = 'capture_setup.board_size';
  static const _captureTargetKey = 'capture_setup.capture_target';

  DifficultyLevel _difficulty = DifficultyLevel.intermediate;
  int _boardSize = 9;
  int _captureTarget = 5;

  @override
  void initState() {
    super.initState();
    _restoreSelection();
  }

  @override
  Widget build(BuildContext context) {
    final particlePreviewOnly =
        kIsWeb && Uri.base.queryParameters['particlePreview'] == '1';

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F1E9),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFCF7),
              Color(0xFFF7F0E5),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: particlePreviewOnly
              ? const _ParticlePreviewCanvas()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _HeroBanner(),
                            const SizedBox(height: 8),
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionLabel(title: '棋盘'),
                                  const SizedBox(height: 4),
                                  _PillSegmentControl<int>(
                                    selectedValue: _boardSize,
                                    options: const [
                                      _SegmentOption(value: 9, label: '9 路'),
                                      _SegmentOption(value: 13, label: '13 路'),
                                      _SegmentOption(value: 19, label: '19 路'),
                                    ],
                                    onChanged: (value) =>
                                        _updateSelection(boardSize: value),
                                  ),
                                  const SizedBox(height: 20),
                                  const _SectionLabel(title: '难度'),
                                  const SizedBox(height: 8),
                                  _PillSegmentControl<DifficultyLevel>(
                                    selectedValue: _difficulty,
                                    options: const [
                                      _SegmentOption(
                                        value: DifficultyLevel.beginner,
                                        label: '初级',
                                      ),
                                      _SegmentOption(
                                        value: DifficultyLevel.intermediate,
                                        label: '中级',
                                      ),
                                      _SegmentOption(
                                        value: DifficultyLevel.advanced,
                                        label: '高级',
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        _updateSelection(difficulty: value),
                                  ),
                                  const SizedBox(height: 20),
                                  const _SectionLabel(title: 'AI 风格'),
                                  const SizedBox(height: 8),
                                  const _AiStyleTile(),
                                  const SizedBox(height: 24),
                                  _PrimaryActionButton(
                                    title: _CaptureCopy.startButton,
                                    onPressed: _startGame,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const _HomeSectionTitle(
                              title: '今日练习',
                              trailing: null,
                            ),
                            const SizedBox(height: 8),
                            _PracticeCard(
                              title: '围地上攻防练习',
                              subtitle:
                                  '基础练习 · 吃$_captureTarget子 · ${_difficulty.displayName}',
                              onTap: _startGame,
                            ),
                            const SizedBox(height: 10),
                            const _HomeSectionTitle(
                              title: '最近对局',
                              trailing: '查看全部',
                            ),
                            const SizedBox(height: 10),
                            _RecentMatchCard(
                              boardSize: _boardSize,
                              difficulty: _difficulty,
                              captureTarget: _captureTarget,
                              onTap: _startGame,
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _restoreSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedDifficulty = prefs.getString(_difficultyKey);
    final savedBoardSize = prefs.getInt(_boardSizeKey);
    final savedCaptureTarget = prefs.getInt(_captureTargetKey);

    setState(() {
      _difficulty = DifficultyLevel.values.firstWhere(
        (v) => v.name == savedDifficulty,
        orElse: () => _difficulty,
      );
      if (savedBoardSize == 9 || savedBoardSize == 13 || savedBoardSize == 19) {
        _boardSize = savedBoardSize!;
      }
      if (savedCaptureTarget == 5 ||
          savedCaptureTarget == 10 ||
          savedCaptureTarget == 20) {
        _captureTarget = savedCaptureTarget!;
      }
    });
  }

  void _updateSelection({
    DifficultyLevel? difficulty,
    int? boardSize,
    int? captureTarget,
  }) {
    setState(() {
      _difficulty = difficulty ?? _difficulty;
      _boardSize = boardSize ?? _boardSize;
      _captureTarget = captureTarget ?? _captureTarget;
    });
    _saveSelection();
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_difficultyKey, _difficulty.name);
    await prefs.setInt(_boardSizeKey, _boardSize);
    await prefs.setInt(_captureTargetKey, _captureTarget);
  }

  void _startGame() {
    _saveSelection();
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CaptureGameProvider(
            boardSize: _boardSize,
            captureTarget: _captureTarget,
            difficulty: _difficulty,
          ),
          child: CaptureGamePlayScreen(
            difficulty: _difficulty,
            captureTarget: _captureTarget,
          ),
        ),
      ),
    );
  }
}

class _ParticlePreviewCanvas extends StatelessWidget {
  const _ParticlePreviewCanvas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: const _HeroBanner(),
      ),
    );
  }
}

class _CaptureCopy {
  static const pageTitle = '小闲围棋';
  static const pageSubtitle = 'AI 陪你下好每一步';
  static const startButton = '开始对弈';
}

class _SegmentOption<T> {
  const _SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC89257), Color(0xFFA86930)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33A56730),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 14),
          borderRadius: BorderRadius.circular(16),
          onPressed: onPressed,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        height: 268,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFDF9),
              Color(0xFFF3E9D8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 24,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _LandscapePainter()),
            ),
            Positioned(
              top: 36,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    _CaptureCopy.pageTitle,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF201712),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    _CaptureCopy.pageSubtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8E7C6C),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 160,
              child: _HeroOrbitalArt(),
            ),
          ],
        ),
      ),
    );
  }
}

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
        const Positioned(top: 68, child: _StoneDot(isBlack: true, size: 22)),
        // Center black (slightly right)
        const Positioned(top: 110, child: _StoneDot(isBlack: true, size: 24)),
        // Bottom black
        const Positioned(top: 152, child: _StoneDot(isBlack: true, size: 22)),
        // White flanking stones
        const Positioned(left: 30, top: 113, child: _StoneDot(isBlack: false, size: 19)),
        const Positioned(right: 30, top: 113, child: _StoneDot(isBlack: false, size: 19)),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // ── Birds (upper-right, behind stones area) ───────────────────────────
    _drawBirds(canvas, size);

    // ── Distant mountains (3 faint layers) ────────────────────────────────
    _drawDistantMountains(canvas, size);

    // ── Mid mountain with pavilion silhouette ─────────────────────────────
    _drawMidMountain(canvas, size);

    // ── Foreground hills ──────────────────────────────────────────────────
    _drawForegroundHills(canvas, size);

    // ── Horizontal mist bands ─────────────────────────────────────────────
    _drawMist(canvas, size);
  }

  void _drawBirds(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x40756250)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Bird 1 — upper right
    final b1x = size.width * 0.62;
    final b1y = size.height * 0.10;
    final wing = size.width * 0.025;
    final path1 = Path()
      ..moveTo(b1x - wing, b1y)
      ..quadraticBezierTo(b1x, b1y - wing * 0.6, b1x + wing, b1y);
    canvas.drawPath(path1, paint);

    // Bird 2 — slightly lower and further right
    final b2x = size.width * 0.72;
    final b2y = size.height * 0.07;
    final wing2 = size.width * 0.018;
    final path2 = Path()
      ..moveTo(b2x - wing2, b2y)
      ..quadraticBezierTo(b2x, b2y - wing2 * 0.6, b2x + wing2, b2y);
    canvas.drawPath(path2, paint);
  }

  void _drawDistantMountains(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Layer 1 — farthest, lightest
    paint.color = const Color(0x0C8B7A65);
    final far1 = Path()
      ..moveTo(size.width * 0.35, size.height)
      ..lineTo(size.width * 0.48, size.height * 0.38)
      ..quadraticBezierTo(
          size.width * 0.54, size.height * 0.30, size.width * 0.62, size.height * 0.42)
      ..lineTo(size.width * 0.78, size.height * 0.56)
      ..quadraticBezierTo(
          size.width * 0.88, size.height * 0.48, size.width, size.height * 0.58)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(far1, paint);

    // Layer 2 — middle distance
    paint.color = const Color(0x129B8A72);
    final far2 = Path()
      ..moveTo(size.width * 0.4, size.height)
      ..lineTo(size.width * 0.52, size.height * 0.44)
      ..quadraticBezierTo(
          size.width * 0.57, size.height * 0.36, size.width * 0.65, size.height * 0.50)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * 0.58, size.width * 0.85, size.height * 0.52)
      ..lineTo(size.width, size.height * 0.62)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(far2, paint);
  }

  void _drawMidMountain(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x1A9B8A72);

    // Main mid mountain — biased to right half
    final mid = Path()
      ..moveTo(size.width * 0.3, size.height)
      ..lineTo(size.width * 0.44, size.height * 0.52)
      ..quadraticBezierTo(
          size.width * 0.50, size.height * 0.40, size.width * 0.57, size.height * 0.46)
      ..quadraticBezierTo(
          size.width * 0.68, size.height * 0.58, size.width * 0.82, size.height * 0.62)
      ..lineTo(size.width, size.height * 0.68)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(mid, paint);

    // Pavilion silhouette — at peak of mid mountain (~50%, 43%)
    _drawPavilion(canvas, Offset(size.width * 0.50, size.height * 0.42), size.width * 0.028);
  }

  void _drawPavilion(Canvas canvas, Offset base, double scale) {
    final paint = Paint()
      ..color = const Color(0x28756250)
      ..style = PaintingStyle.fill;

    // Roof (curved eave)
    final roof = Path()
      ..moveTo(base.dx - scale * 1.8, base.dy)
      ..quadraticBezierTo(base.dx, base.dy - scale * 1.5, base.dx + scale * 1.8, base.dy)
      ..close();
    canvas.drawPath(roof, paint);

    // Roof ridge line
    final ridgePaint = Paint()
      ..color = const Color(0x28756250)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(base.dx - scale * 1.8, base.dy),
      Offset(base.dx + scale * 1.8, base.dy),
      ridgePaint,
    );

    // Body
    final body = Rect.fromCenter(
      center: Offset(base.dx, base.dy + scale * 0.8),
      width: scale * 2.2,
      height: scale * 1.4,
    );
    canvas.drawRect(body, paint);
  }

  void _drawForegroundHills(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Foreground hill left — very subtle
    paint.color = const Color(0x0FAD9880);
    final hill1 = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
          size.width * 0.22, size.height * 0.72, size.width * 0.5, size.height * 0.80)
      ..quadraticBezierTo(
          size.width * 0.7, size.height * 0.86, size.width, size.height * 0.82)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hill1, paint);

    // Foreground hill — lower band
    paint.color = const Color(0x10AD9880);
    final hill2 = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
          size.width * 0.35, size.height * 0.86, size.width * 0.65, size.height * 0.90)
      ..quadraticBezierTo(
          size.width * 0.82, size.height * 0.87, size.width, size.height * 0.92)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hill2, paint);
  }

  void _drawMist(Canvas canvas, Size size) {
    // Horizontal mist band — between mountain layers
    final mist = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.25, size.height * 0.58),
        Offset(size.width, size.height * 0.58),
        [
          const Color(0x00FFF8F0),
          const Color(0x18FFF8F0),
          const Color(0x10FFF8F0),
          const Color(0x00FFF8F0),
        ],
        [0.0, 0.3, 0.7, 1.0],
      );
    final mistRect = Rect.fromLTWH(
      size.width * 0.25,
      size.height * 0.52,
      size.width * 0.75,
      size.height * 0.14,
    );
    canvas.drawRect(mistRect, mist);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavyLinePainter extends CustomPainter {
  const _WavyLinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x26C4A57C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height / 2)
      ..quadraticBezierTo(
          size.width * 0.25, 0, size.width * 0.5, size.height / 2)
      ..quadraticBezierTo(
          size.width * 0.75, size.height, size.width, size.height / 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

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

    _paintArcDust(
      canvas,
      center,
      frame: frame,
      radiusScale: 1.06,
      opacityScale: 0.38 * breath,
      dotScale: 0.84,
      seedOffset: 0,
    );
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
        orbit.dx * math.cos(frame.rotation) - orbit.dy * math.sin(frame.rotation),
        orbit.dx * math.sin(frame.rotation) + orbit.dy * math.cos(frame.rotation),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFDF9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x26D8C1A4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3A2A1F),
      ),
    );
  }
}

class _PillSegmentControl<T> extends StatelessWidget {
  const _PillSegmentControl({
    required this.selectedValue,
    required this.options,
    required this.onChanged,
  });

  final T selectedValue;
  final List<_SegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        options.indexWhere((option) => option.value == selectedValue);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F2E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: selectedIndex * width,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E2C9),
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        onPressed: () => onChanged(option.value),
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selectedValue == option.value
                                ? const Color(0xFF8A5A2B)
                                : const Color(0xFF5A4B3F),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AiStyleTile extends StatelessWidget {
  const _AiStyleTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33D2B28E)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF7EFE3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CustomPaint(painter: _LotusPainter()),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '均衡雅致',
                  style: TextStyle(
                    fontSize: 16.5,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF36271E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '攻守兼备，着法稳健均衡',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8A7A6B),
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '›',
            style: TextStyle(
              fontSize: 18,
              height: 1,
              color: Color(0xFFB68454),
            ),
          ),
        ],
      ),
    );
  }
}

class _LotusPainter extends CustomPainter {
  const _LotusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFFBC8448)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = const Color(0x22BC8448)
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final petal = Path()
      ..moveTo(center.dx, center.dy - 12)
      ..quadraticBezierTo(
          center.dx - 6, center.dy - 4, center.dx, center.dy + 4)
      ..quadraticBezierTo(
          center.dx + 6, center.dy - 4, center.dx, center.dy - 12);
    final left = Path()
      ..moveTo(center.dx - 10, center.dy - 6)
      ..quadraticBezierTo(
          center.dx - 16, center.dy - 1, center.dx - 10, center.dy + 4)
      ..quadraticBezierTo(
          center.dx - 4, center.dy - 1, center.dx - 10, center.dy - 6);
    final right = Path()
      ..moveTo(center.dx + 10, center.dy - 6)
      ..quadraticBezierTo(
          center.dx + 16, center.dy - 1, center.dx + 10, center.dy + 4)
      ..quadraticBezierTo(
          center.dx + 4, center.dy - 1, center.dx + 10, center.dy - 6);
    final lowerLeft = Path()
      ..moveTo(center.dx - 4, center.dy - 2)
      ..quadraticBezierTo(
          center.dx - 11, center.dy + 4, center.dx - 6, center.dy + 10)
      ..quadraticBezierTo(
          center.dx, center.dy + 5, center.dx - 4, center.dy - 2);
    final lowerRight = Path()
      ..moveTo(center.dx + 4, center.dy - 2)
      ..quadraticBezierTo(
          center.dx + 11, center.dy + 4, center.dx + 6, center.dy + 10)
      ..quadraticBezierTo(
          center.dx, center.dy + 5, center.dx + 4, center.dy - 2);
    for (final path in [petal, left, right, lowerLeft, lowerRight]) {
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
    canvas.drawLine(
      Offset(center.dx - 11, center.dy + 11),
      Offset(center.dx + 11, center.dy + 11),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x46C4A57C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.02, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.18,
        size.width * 0.4,
        size.height * 0.54,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.72,
        size.width * 0.66,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.26,
        size.width * 0.96,
        size.height * 0.56,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({
    required this.title,
    required this.trailing,
  });

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF36271E),
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFB08965),
            ),
          ),
      ],
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF4E7D6),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.game_controller_solid,
                color: Color(0xFFB57B44),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF36271E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF897564),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Color(0xFFC09468),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentMatchCard extends StatelessWidget {
  const _RecentMatchCard({
    required this.boardSize,
    required this.difficulty,
    required this.captureTarget,
    required this.onTap,
  });

  final int boardSize;
  final DifficultyLevel difficulty;
  final int captureTarget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE8DED0), Color(0xFFC1B19C)],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.person_alt_circle_fill,
                color: CupertinoColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '山泉水长',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF36271E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$boardSize 路 · ${difficulty.displayName} · 吃$captureTarget子',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF897564),
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              '胜 62%',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9F7240),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CaptureGamePlayScreen extends StatelessWidget {
  const CaptureGamePlayScreen({
    super.key,
    required this.difficulty,
    required this.captureTarget,
  });

  final DifficultyLevel difficulty;
  final int captureTarget;

  @override
  Widget build(BuildContext context) {
    return Consumer<CaptureGameProvider>(
      builder: (context, provider, _) {
        final rates = provider.winRateEstimate;
        final blackRate = (rates[StoneColor.black]! * 100).toStringAsFixed(0);
        final whiteRate = (rates[StoneColor.white]! * 100).toStringAsFixed(0);

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            previousPageTitle: _CaptureCopy.pageTitle,
            middle: Text('吃$captureTarget子、${difficulty.displayName}'),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _TapBoard(
                        gameState: provider.gameState,
                        enabled: !provider.isAiThinking &&
                            provider.result == CaptureGameResult.none,
                        onTap: provider.placeStone,
                      ),
                    ),
                  ),
                ),
                _InfoRow(provider: provider),
                _MetricRow(
                  title: '吃子信息',
                  value:
                      '黑 ${provider.gameState.capturedByBlack.length}，白 ${provider.gameState.capturedByWhite.length}',
                ),
                _MetricRow(
                  title: '胜率对比',
                  value: '黑 $blackRate%，白 $whiteRate%',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: CupertinoColors.systemGrey4,
                          onPressed:
                              provider.canUndo ? provider.undoMove : null,
                          child: const Text('后退一手'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton.filled(
                          onPressed: () => _showHint(context, provider),
                          child: const Text('提示3手'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHint(BuildContext context, CaptureGameProvider provider) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => _HintDialog(provider: provider),
    );
  }
}

class _HintDialog extends StatefulWidget {
  const _HintDialog({required this.provider});

  final CaptureGameProvider provider;

  @override
  State<_HintDialog> createState() => _HintDialogState();
}

class _HintDialogState extends State<_HintDialog> {
  late final Future<List<BoardPosition>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.provider.suggestMovesAsync();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('提示 3 手'),
      content: FutureBuilder<List<BoardPosition>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('计算提示时出错，请重试。'),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.only(top: 12),
              child: CupertinoActivityIndicator(),
            );
          }
          final hints = snapshot.data ?? [];
          return Text(
            hints.isEmpty
                ? '暂无可用提示'
                : hints
                    .asMap()
                    .entries
                    .map((e) =>
                        '${e.key + 1}. (${e.value.row + 1}, ${e.value.col + 1})')
                    .join('\n'),
          );
        },
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}

class _TapBoard extends StatelessWidget {
  const _TapBoard({
    required this.gameState,
    required this.enabled,
    required this.onTap,
  });

  final GameState gameState;
  final bool enabled;
  final Future<bool> Function(int row, int col) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSizePx = constraints.biggest.shortestSide;
        return GestureDetector(
          onTapUp:
              enabled ? (d) => _handleTap(d.localPosition, boardSizePx) : null,
          child: CustomPaint(
            size: Size.square(boardSizePx),
            painter: GoBoardPainter(gameState: gameState),
          ),
        );
      },
    );
  }

  void _handleTap(Offset localPosition, double size) {
    const padding = 0.5;
    final n = gameState.boardSize;
    final cell = size / (n - 1 + 2 * padding);
    final origin = cell * padding;
    final col = ((localPosition.dx - origin) / cell).round();
    final row = ((localPosition.dy - origin) / cell).round();
    if (row >= 0 && row < n && col >= 0 && col < n) {
      onTap(row, col);
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.provider});

  final CaptureGameProvider provider;

  @override
  Widget build(BuildContext context) {
    String text;
    if (provider.result == CaptureGameResult.blackWins) {
      text = '对局结束：黑方胜';
    } else if (provider.result == CaptureGameResult.whiteWins) {
      text = '对局结束：白方胜';
    } else if (provider.isAiThinking) {
      text = 'AI 白正在思考';
    } else {
      text = provider.gameState.currentPlayer == StoneColor.black
          ? '请你黑落子'
          : '请你白落子';
    }

    return _MetricRow(title: '信息提示', value: text);
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$title：$value'),
      ),
    );
  }
}
