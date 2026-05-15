import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';
import '../services/app_log_store.dart';
import 'capture_game_screen.dart';
import '../theme/app_theme.dart';
import '../theme/theme_context.dart';
import '../widgets/page_hero_banner.dart';

const EdgeInsets _settingsRowPadding =
    EdgeInsets.symmetric(horizontal: 18, vertical: 6);
const TextStyle _settingsTitleStyle = TextStyle(fontSize: 16, height: 1.15);
const TextStyle _settingsSubtitleBaseStyle =
    TextStyle(fontSize: 13, height: 1.2);
const double _settingsSingleLineContentHeight = 32;
const double _settingsTwoLineContentHeight = 46;
const double _settingsTrailingReservedWidth = 64;

/// Settings tab screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return CupertinoPageScaffold(
      backgroundColor: palette.pageBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('設定'),
            backgroundColor: palette.pageBackground,
            transitionBetweenRoutes: false,
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
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return _Section(
          title: '外觀',
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
          title: '遊戲選項',
          children: [
            _SwitchRow(
              title: '顯示提示',
              subtitle: '解題時允許查看提示',
              value: settings.showHints,
              onChanged: settings.setShowHints,
            ),
            _SwitchRow(
              title: '顯示手數',
              subtitle: '在棋子上顯示落子順序',
              value: settings.showMoveNumbers,
              onChanged: settings.setShowMoveNumbers,
            ),
            _SwitchRow(
              title: '吃子預警',
              subtitle: '在棋盤上標記被叫吃的棋子',
              value: settings.showCaptureWarning,
              onChanged: settings.setShowCaptureWarning,
            ),
            _SwitchRow(
              title: '显示棋谱',
              subtitle: '新对局开始时默认显示棋谱',
              value: settings.showMoveLog,
              onChanged: settings.setShowMoveLog,
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
          title: '回饋',
          children: [
            _SwitchRow(
              title: '音效',
              subtitle: '落子和提子時播放音效',
              value: settings.soundEnabled,
              onChanged: settings.setSoundEnabled,
            ),
            _SwitchRow(
              title: '觸覺回饋',
              subtitle: '落子時觸發震動回饋',
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
      title: '關於',
      children: [
        const _VersionInfoRow(),
        _TapRow(
          title: '圍棋規則參考',
          subtitle: 'online-go.com',
          onTap: _openOnlineGoReference,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            '本應用題目參考 online-go.com 的圍棋教程設計，適合想學習圍棋基礎的玩家。',
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
        final logs = context.watch<AppLogStore>();
        final latest = logs.latest;
        return _Section(
          title: '開發者',
          children: [
            _SwitchRow(
              title: '開啟開發者模式',
              subtitle: '在首頁顯示 3D 棋盤除錯入口',
              value: settings.developerMode,
              onChanged: settings.setDeveloperMode,
            ),
            if (settings.developerMode) ...[
              _RecognitionAlgorithmSegmentedRow(
                value: settings.screenshotRecognitionAlgorithm,
                onChanged: settings.setScreenshotRecognitionAlgorithm,
              ),
              _TapRow(
                title: '查看日志',
                subtitle: latest == null
                    ? '尚無日志'
                    : '${latest.category.label} · ${latest.level.label} · ${latest.message}',
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const _AppLogScreen(),
                    ),
                  );
                },
              ),
              _TapRow(
                title: '3D 棋盤除錯參數',
                subtitle: '開啟獨立棋盤除錯畫面',
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const ThreeBoardDebugScreen(),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openOnlineGoReference() async {
    final uri = Uri.https('online-go.com', '/learn-to-play-go');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AppLogScreen extends StatelessWidget {
  const _AppLogScreen();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final logs = context.watch<AppLogStore>();
    return CupertinoPageScaffold(
      backgroundColor: palette.pageBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('日志'),
        trailing: logs.entries.isEmpty
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: logs.clear,
                child: const Text('清空'),
              ),
      ),
      child: SafeArea(
        child: logs.entries.isEmpty
            ? Center(
                child: Text(
                  '尚無日志',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 16,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: logs.entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _LogEntryCard(entry: logs.entries[index]);
                },
              ),
      ),
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final isError = entry.level == AppLogLevel.error;
    final borderColor =
        isError ? CupertinoColors.systemRed : const Color(0x26D8C1A4);
    final levelColor = isError
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoDynamicColor.resolve(borderColor, context),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.category.label,
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                entry.level.label,
                style: TextStyle(
                  color: levelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatLogTime(entry.timestamp),
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.message,
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 15,
              height: 1.25,
            ),
          ),
          if (entry.details != null && entry.details!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.details!,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 12,
                height: 1.25,
                fontFamily: 'Menlo',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatLogTime(DateTime timestamp) {
  final local = timestamp.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isClassic = context.select<SettingsProvider, bool>(
      (settings) => settings.appTheme == AppVisualTheme.classic,
    );
    final cardColor = isClassic
        ? CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
        : const Color(0xF7FFFDF9);

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
            color: cardColor,
            borderRadius: BorderRadius.circular(kPageSectionCardRadius),
            border:
                isClassic ? null : Border.all(color: const Color(0x26D8C1A4)),
            boxShadow: isClassic
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const _SectionDivider(),
              ],
            ],
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
    final rowHeight = subtitle == null
        ? _settingsSingleLineContentHeight
        : _settingsTwoLineContentHeight;

    return Padding(
      padding: _settingsRowPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: rowHeight),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              right: _settingsTrailingReservedWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SettingsLabel(title: title, subtitle: subtitle),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoSwitch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = _settingsTitleStyle.copyWith(
      color: CupertinoColors.label.resolveFrom(context),
    );

    if (subtitle == null) {
      return Text(
        title,
        style: titleStyle,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: titleStyle,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _settingsSubtitleBaseStyle.copyWith(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 18),
      child: Container(
        height: 0.5,
        color: context.appPalette.setupDivider,
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
      padding: _settingsRowPadding,
      child: SizedBox(
        height: _settingsSingleLineContentHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SettingsLabel(title: '主題'),
              ),
            ),
            SizedBox(
              width: 164,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
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
      ),
    );
  }
}

class _RecognitionAlgorithmSegmentedRow extends StatelessWidget {
  const _RecognitionAlgorithmSegmentedRow({
    required this.value,
    required this.onChanged,
  });

  final ScreenshotRecognitionAlgorithm value;
  final ValueChanged<ScreenshotRecognitionAlgorithm> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: _settingsRowPadding,
      child: SizedBox(
        height: _settingsSingleLineContentHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SettingsLabel(title: '截圖識別'),
              ),
            ),
            SizedBox(
              width: 184,
              child: CupertinoSlidingSegmentedControl<
                  ScreenshotRecognitionAlgorithm>(
                groupValue: value,
                backgroundColor: palette.segmentTrack,
                thumbColor: palette.segmentSelected,
                onValueChanged: (algorithm) {
                  if (algorithm != null) onChanged(algorithm);
                },
                children: {
                  for (final algorithm in ScreenshotRecognitionAlgorithm.values)
                    algorithm: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        algorithm.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: value == algorithm
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
      ),
    );
  }
}

class _VersionInfoRow extends StatefulWidget {
  const _VersionInfoRow();

  @override
  State<_VersionInfoRow> createState() => _VersionInfoRowState();
}

class _VersionInfoRowState extends State<_VersionInfoRow> {
  late final Future<String> _versionTextFuture = _loadVersionText();

  Future<String> _loadVersionText() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.buildNumber.isEmpty) return info.version;
      return '${info.version} (${info.buildNumber})';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _versionTextFuture,
      builder: (context, snapshot) {
        return _InfoRow(
          title: '版本',
          value: snapshot.data ?? '...',
        );
      },
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
      padding: _settingsRowPadding,
      child: SizedBox(
        height: _settingsSingleLineContentHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: _settingsTitleStyle.copyWith(
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            Text(
              value,
              style: _settingsTitleStyle.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
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
    final rowHeight = subtitle == null
        ? _settingsSingleLineContentHeight
        : _settingsTwoLineContentHeight;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: _settingsRowPadding,
        child: SizedBox(
          height: rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SettingsLabel(title: title, subtitle: subtitle),
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
      ),
    );
  }
}
