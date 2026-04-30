import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'capture_game_screen.dart';
import '../theme/app_theme.dart';
import '../theme/theme_context.dart';
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
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return _Section(
          title: '开发者',
          children: [
            _SwitchRow(
              title: '打开开发者模式',
              subtitle: '在首页显示 3D 棋盘调试入口',
              value: settings.developerMode,
              onChanged: settings.setDeveloperMode,
            ),
            if (settings.developerMode)
              _TapRow(
                title: '3D 棋盘调试参数',
                subtitle: '打开单独棋盘调试界面',
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const ThreeBoardDebugScreen(),
                    ),
                  );
                },
              ),
          ],
        );
      },
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
          padding: kPageSectionTitlePadding,
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
          margin: kPageSectionCardMargin,
          decoration: BoxDecoration(
            color: const Color(0xF7FFFDF9),
            borderRadius: BorderRadius.circular(kPageSectionCardRadius),
            border: Border.all(color: const Color(0x26D8C1A4)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 24,
                offset: Offset(0, 10),
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
      padding: kPageSectionRowPadding,
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
      padding: kPageSectionRowPadding,
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
      padding: kPageSectionRowPadding,
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
      padding: kPageSectionRowPadding,
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
        padding: kPageSectionRowPadding,
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
