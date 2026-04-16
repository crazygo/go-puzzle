import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// Settings tab screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('设置')),
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
              const SizedBox(height: 32),
            ]),
          ),
        ],
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
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
