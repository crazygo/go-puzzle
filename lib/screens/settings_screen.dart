import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_context.dart';
import '../widgets/go_three_board_background.dart';
import '../widgets/page_hero_banner.dart';

/// Settings tab screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: Stack(
          children: [
            // Hero as full-bleed background layer
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PageHeroBanner(title: '设置', showOrbitalArt: false),
            ),
            // Scrollable content floats over hero
            SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  // Transparent spacer that reveals the hero behind
                  const SliverToBoxAdapter(
                    child: SizedBox(height: kPageHeroContentOffset),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),
                      _buildAppearanceSection(context),
                      const SizedBox(height: 24),
                      _buildGameSection(context),
                      const SizedBox(height: 24),
                      _buildFeedbackSection(context),
                      const SizedBox(height: 24),
                      _buildAboutSection(context),
                      const SizedBox(height: 24),
                      _buildDeveloperSection(context),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return _Section(
          title: '外观',
          children: [
            _ThemeSegmentedRow(
              value: settings.appTheme,
              onChanged: settings.setAppTheme,
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return _Section(
          title: '游戏选项',
          children: [
            _SwitchRow(
              title: '显示提示',
              subtitle: '在解题时允许查看提示',
              value: settings.showHints,
              onChanged: settings.setShowHints,
            ),
            _SwitchRow(
              title: '显示手数',
              subtitle: '在棋子上显示落子顺序',
              value: settings.showMoveNumbers,
              onChanged: settings.setShowMoveNumbers,
            ),
            _SwitchRow(
              title: '吃子预警',
              subtitle: '在棋盘上标记被打吃的棋子',
              value: settings.showCaptureWarning,
              onChanged: settings.setShowCaptureWarning,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeedbackSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return _Section(
          title: '反馈',
          children: [
            _SwitchRow(
              title: '音效',
              subtitle: '落子和提子时播放音效',
              value: settings.soundEnabled,
              onChanged: settings.setSoundEnabled,
            ),
            _SwitchRow(
              title: '触感反馈',
              subtitle: '落子时触发震动反馈',
              value: settings.hapticEnabled,
              onChanged: settings.setHapticEnabled,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _Section(
      title: '关于',
      children: [
        const _InfoRow(title: '版本', value: '1.0.0'),
        _SettingRow(
          title: '围棋规则参考',
          subtitle: 'online-go.com',
          trailing: const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: CupertinoColors.systemGrey2,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            '本应用题目参考 online-go.com 的围棋教程设计，适合想学习围棋基础的玩家。',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeveloperSection(BuildContext context) {
    return _Section(
      title: '开发者',
      children: [
        _TapRow(
          title: 'Three 3D 棋盘预览',
          subtitle: '实验 three_js 真 3D 背景',
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              CupertinoPageRoute<void>(
                builder: (_) => const _ThreeBoardDebugScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Debug: Three board background preview screen ─────────────────────────────

class _ThreeBoardDebugScreen extends StatefulWidget {
  const _ThreeBoardDebugScreen();

  @override
  State<_ThreeBoardDebugScreen> createState() => _ThreeBoardDebugScreenState();
}

class _ThreeBoardDebugScreenState extends State<_ThreeBoardDebugScreen> {
  static const double _sceneYOffsetFactor = -0.38;

  final int _boardSize = 19;
  bool _controlsCollapsed = true;
  double _sceneScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Three 3D 棋盘预览'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: const _ThreePreviewBackdropPainter(),
                  child: Transform.translate(
                    offset:
                        Offset(0, constraints.maxHeight * _sceneYOffsetFactor),
                    child: GoThreeBoardBackground(
                      boardSize: _boardSize,
                      stones: kGoThreeDemoStones,
                      animate: true,
                      particles: false,
                      sceneScale: _sceneScale,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    if (!_controlsCollapsed)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground
                                .resolveFrom(context)
                                .withOpacity(0.88),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x18000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'three_js · $_boardSize路 · ${kGoThreeDemoStones.length} stones · particles off · s=${_sceneScale.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ScaleHandle(
                                scale: _sceneScale,
                                onDrag: _handleScaleDrag,
                                onReset: _resetScale,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(32, 32),
                        color: CupertinoColors.systemGrey6
                            .resolveFrom(context)
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () => setState(
                          () => _controlsCollapsed = !_controlsCollapsed,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _controlsCollapsed
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 16,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _controlsCollapsed ? '展开' : '收起',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleScaleDrag(DragUpdateDetails details) {
    final delta = (details.delta.dx - details.delta.dy) / 260;
    setState(() {
      _sceneScale = (_sceneScale + delta).clamp(0.45, 1.60);
    });
  }

  void _resetScale() {
    setState(() => _sceneScale = 1.0);
  }
}

class _ScaleHandle extends StatelessWidget {
  const _ScaleHandle({
    required this.scale,
    required this.onDrag,
    required this.onReset,
  });

  final double scale;
  final GestureDragUpdateCallback onDrag;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final value = ((scale - 0.45) / (1.60 - 0.45)).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: onDrag,
            child: SizedBox(
              height: 36,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    top: 16,
                    bottom: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey4
                            .resolveFrom(context)
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB87936),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(-1 + value * 2, 0),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: const Color(0xFFB87936).withValues(alpha: 0.5),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x24000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.arrow_up_left_arrow_down_right,
                        size: 15,
                        color: Color(0xFF9A642B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          's=${scale.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(34, 30),
          borderRadius: BorderRadius.circular(8),
          color: CupertinoColors.systemGrey6
              .resolveFrom(context)
              .withValues(alpha: 0.9),
          onPressed: onReset,
          child: Text(
            '重置',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreePreviewBackdropPainter extends CustomPainter {
  const _ThreePreviewBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8EEE6),
            Color(0xFFF2E2D3),
            Color(0xFFF2E2D3),
          ],
          stops: [0.0, 0.44, 1.0],
        ).createShader(rect),
    );

    _drawWallGlow(canvas, size);
    _drawSoftPlant(canvas, size);
    _drawBlurredTeaCup(canvas, size);
    _drawTableWarmth(canvas, size);
  }

  void _drawWallGlow(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.56, size.height * 0.22);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 1.20,
        height: size.height * 0.64,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.58),
            const Color(0x00F2E2D3),
          ],
        ).createShader(
          Rect.fromCenter(
            center: center,
            width: size.width * 1.20,
            height: size.height * 0.64,
          ),
        ),
    );
  }

  void _drawSoftPlant(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF59631F).withValues(alpha: 0.40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final stem = Paint()
      ..color = const Color(0xFF6A6D2B).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final base = Offset(size.width * -0.03, size.height * 0.52);
    canvas.drawLine(
      base,
      Offset(size.width * 0.18, size.height * 0.47),
      stem,
    );
    final leaves = [
      (Offset(size.width * 0.04, size.height * 0.48), 32.0, 18.0, -0.8),
      (Offset(size.width * 0.10, size.height * 0.45), 36.0, 16.0, -0.45),
      (Offset(size.width * 0.15, size.height * 0.49), 28.0, 13.0, -0.65),
      (Offset(size.width * 0.03, size.height * 0.55), 30.0, 16.0, 0.52),
      (Offset(size.width * 0.20, size.height * 0.53), 24.0, 12.0, 0.20),
    ];
    for (final leaf in leaves) {
      canvas.save();
      canvas.translate(leaf.$1.dx, leaf.$1.dy);
      canvas.rotate(leaf.$4);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: leaf.$2, height: leaf.$3),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawBlurredTeaCup(Canvas canvas, Size size) {
    final cupRect = Rect.fromCenter(
      center: Offset(size.width * 0.82, size.height * 0.43),
      width: size.width * 0.19,
      height: size.height * 0.060,
    );
    final cupPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFD0944C).withValues(alpha: 0.50),
          const Color(0xFFB97830).withValues(alpha: 0.34),
        ],
      ).createShader(cupRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cupRect, const Radius.circular(24)),
      cupPaint,
    );
    canvas.drawOval(
      cupRect.shift(Offset(0, -cupRect.height * 0.44)).inflate(4),
      Paint()
        ..color = const Color(0xFFF2C58B).withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _drawTableWarmth(Canvas canvas, Size size) {
    final table = Rect.fromLTWH(0, size.height * 0.63, size.width, size.height);
    canvas.drawRect(
      table,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00D8A15E),
            const Color(0xFFD8A15E).withValues(alpha: 0.24),
          ],
        ).createShader(table),
    );
  }

  @override
  bool shouldRepaint(covariant _ThreePreviewBackdropPainter oldDelegate) =>
      false;
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
              ],
            ),
          ),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ThemeSegmentedRow extends StatelessWidget {
  const _ThemeSegmentedRow({
    required this.value,
    required this.onChanged,
  });

  final AppVisualTheme value;
  final ValueChanged<AppVisualTheme> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Text('主题', style: TextStyle(fontSize: 16)),
          ),
          SizedBox(
            width: 184,
            child: CupertinoSlidingSegmentedControl<AppVisualTheme>(
              groupValue: value,
              backgroundColor: palette.segmentTrack,
              thumbColor: palette.segmentSelected,
              onValueChanged: (theme) {
                if (theme != null) onChanged(theme);
              },
              children: {
                for (final theme in AppVisualTheme.values)
                  theme: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      theme.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: value == theme
                            ? palette.segmentSelectedText
                            : palette.segmentText,
                      ),
                    ),
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SettingRow({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _TapRow({required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, color: CupertinoColors.label)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.systemGrey2,
            ),
          ],
        ),
      ),
    );
  }
}
