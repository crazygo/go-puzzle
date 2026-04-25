import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../widgets/go_particle_hero_background.dart';
import '../widgets/page_hero_banner.dart';

/// Settings tab screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kPageBackgroundColor,
      child: DecoratedBox(
        decoration: kPageBackgroundDecoration,
        child: Stack(
          children: [
            // Hero as full-bleed background layer
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PageHeroBanner(title: '设置'),
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
                      _buildBoardSizeSection(context),
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

  Widget _buildBoardSizeSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return _Section(
          title: '棋盘设置',
          children: [
            _SettingRow(
              title: '棋盘大小',
              subtitle: '选择默认的棋盘路数',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CupertinoSlidingSegmentedControl<BoardSizeOption>(
                groupValue: settings.boardSize,
                children: {
                  for (final opt in BoardSizeOption.values)
                    opt: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        opt.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                },
                onValueChanged: (v) {
                  if (v != null) settings.setBoardSize(v);
                },
              ),
            ),
            _buildBoardSizeDescription(context, settings.boardSize),
          ],
        );
      },
    );
  }

  Widget _buildBoardSizeDescription(
    BuildContext context,
    BoardSizeOption selected,
  ) {
    String description;
    switch (selected) {
      case BoardSizeOption.nine:
        description = '9路棋盘：适合初学者，以吃子为主要规则。游戏节奏快，是学习围棋的最佳起点。';
        break;
      case BoardSizeOption.thirteen:
        description = '13路棋盘：中级棋盘，比9路更加复杂，有更多战术空间，吃子仍是主要目标。';
        break;
      case BoardSizeOption.nineteen:
        description = '19路棋盘：标准围棋棋盘，以围空为主要规则，是完整围棋体验的棋盘大小。';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
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
        const _InfoRow(title: '棋盘尺寸', value: '9路 / 13路 / 19路'),
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
          title: '粒子背景预览',
          subtitle: '查看 GoParticleHeroBackground 效果',
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              CupertinoPageRoute<void>(
                builder: (_) => const _ParticleBackgroundDebugScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Debug: particle background preview screen ─────────────────────────────────

class _ParticleBackgroundDebugScreen extends StatefulWidget {
  const _ParticleBackgroundDebugScreen();

  @override
  State<_ParticleBackgroundDebugScreen> createState() =>
      _ParticleBackgroundDebugScreenState();
}

class _ParticleBackgroundDebugScreenState
    extends State<_ParticleBackgroundDebugScreen> {
  double _intensity = 1.0;
  double _blur = 1.0;
  double _warmth = 1.0;
  double _dof = 1.0;
  double _fadeStart = 0.58;
  int _boardSize = 9;

  static const List<int> _boardSizes = [9, 13, 19];

  GoScenePreset get _preset => GoScenePreset(
        boardSize: _boardSize,
        warmth: _warmth,
        depthOfField: _dof,
        stones: GoScenePreset.defaultPreset.stones,
      );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('粒子背景预览'),
      ),
      child: Stack(
        children: [
          // Full-bleed background
          Positioned.fill(
            child: GoParticleHeroBackground(
              preset: _preset,
              intensity: _intensity,
              blurStrength: _blur,
              contentFadeStart: _fadeStart,
            ),
          ),
          // Controls panel at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
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
                    _DebugSlider(
                      label: '强度',
                      value: _intensity,
                      onChanged: (v) => setState(() => _intensity = v),
                    ),
                    _DebugSlider(
                      label: '模糊',
                      value: _blur,
                      onChanged: (v) => setState(() => _blur = v),
                    ),
                    _DebugSlider(
                      label: '暖色',
                      value: _warmth,
                      onChanged: (v) => setState(() => _warmth = v),
                    ),
                    _DebugSlider(
                      label: '景深',
                      value: _dof,
                      onChanged: (v) => setState(() => _dof = v),
                    ),
                    _DebugSlider(
                      label: '渐隐',
                      value: _fadeStart,
                      onChanged: (v) => setState(() => _fadeStart = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('棋盘',
                            style: TextStyle(
                                fontSize: 13, color: CupertinoColors.label)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoSlidingSegmentedControl<int>(
                            groupValue: _boardSize,
                            children: {
                              for (final s in _boardSizes)
                                s: Text('${s}路',
                                    style: const TextStyle(fontSize: 12)),
                            },
                            onValueChanged: (v) {
                              if (v != null) setState(() => _boardSize = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugSlider extends StatelessWidget {
  const _DebugSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: CupertinoColors.secondaryLabel)),
        ),
        Expanded(
          child: CupertinoSlider(
            value: value,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
                fontSize: 11, color: CupertinoColors.secondaryLabel),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
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
