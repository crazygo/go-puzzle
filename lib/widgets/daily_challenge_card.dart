import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../game/capture_ai_tactics.dart';
import '../providers/tactics_challenge_provider.dart';
import '../theme/theme_context.dart';
import '../ui/tactics_labels.dart';
import 'page_section_card.dart';
import '../screens/tactics_problem_screen.dart';

const _kLevelMin = 1;
const _kLevelMax = 15;

String _kLevelLabel(int k) => '${k}K';

/// Returns a short summary of a problem set's composition.
String _problemOptionLabel(CaptureAiTacticsProblem p) {
  final tactic = p.metadata['tactic']?.toString() ?? '';
  if (const [
    'throw_in',
    'snapback',
    'shortage_of_liberties',
    'net_geta',
    'ladder',
  ].contains(tactic)) {
    return '手筋';
  }
  if (p.category == 'group_fate') {
    return '死活';
  }
  if (p.category == 'capture_race') {
    return '對殺';
  }
  if (const ['trap', 'exchange', 'multi_threat'].contains(p.category)) {
    return '吃子';
  }
  return '吃子';
}

class DailyChallengeCard extends StatelessWidget {
  const DailyChallengeCard({super.key});

  @override
  Widget build(BuildContext context) {
    TacticsChallengeProvider? localProvider;
    try {
      localProvider = context.watch<TacticsChallengeProvider>();
    } catch (_) {}

    if (localProvider == null) {
      return const PageSectionCard(
        child: SizedBox(
          height: 100,
          child: Center(
            child: Text(
              '無可用挑戰數據',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
      );
    }

    final provider = localProvider;

    final allProblems = provider.allProblems;
    if (allProblems == null) {
      if (provider.loadError != null) {
        return PageSectionCard(
          child: SizedBox(
            height: 100,
            child: Center(
              child: Text(
                '挑戰加載失敗:\n${provider.loadError}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CupertinoColors.destructiveRed.resolveFrom(context),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }
      return const PageSectionCard(
        child: SizedBox(
          height: 100,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    final todayProblems = provider.todayProblems ?? [];
    final today = DateTime.now();
    final dateKey = DateTime(today.year, today.month, today.day);
    final completedToday = provider.solvedByDay[dateKey]?.length ?? 0;

    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final primaryEnd = isClassic
        ? palette.primary
        : Color.lerp(palette.primary, CupertinoColors.black, 0.20)!;

    final total = todayProblems.length;
    final progress = total == 0 ? 0.0 : completedToday / total;
    final typeText = provider.typeFilter == TacticsTypeFilter.all
        ? '全部'
        : (todayProblems.isEmpty
            ? provider.typeFilter.label
            : todayProblems.map(_problemOptionLabel).toSet().join('、'));
    final composition = todayProblems.isEmpty
        ? ''
        : '級別 ${_kLevelLabel(provider.kLevel)}\n類型 $typeText';

    return PageSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '今日挑戰',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DailyRing(
                      progress: progress,
                      label: '$completedToday/$total',
                      trackColor:
                          CupertinoColors.systemFill.resolveFrom(context),
                      progressColor: palette.setupActionText,
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                minimumSize: const Size(44, 44),
                onPressed: provider.toggleAdjust,
                child: Text(
                  provider.isAdjusting ? '完成' : '調整 ›',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.setupActionText,
                  ),
                ),
              ),
            ],
          ),
          if (composition.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              composition,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
          if (provider.isAdjusting) ...[
            const SizedBox(height: 12),
            const _RowLabel(label: '級別'),
            const SizedBox(height: 6),
            _KLevelPillRow(
              selected: provider.kLevel,
              onSelect: provider.setKLevel,
            ),
            const SizedBox(height: 12),
            const _RowLabel(label: '類型'),
            const SizedBox(height: 6),
            _PillSegmentRow<TacticsTypeFilter>(
              options: TacticsTypeFilter.values,
              selected: provider.typeFilter,
              labelOf: (t) => t.label,
              onSelect: provider.setTypeFilter,
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.primary, primaryEnd],
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary
                        .withValues(alpha: isClassic ? 0.20 : 0.24),
                    blurRadius: isClassic ? 12 : 18,
                    offset: Offset(0, isClassic ? 4 : 8),
                  ),
                ],
              ),
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(16),
                onPressed: todayProblems.isEmpty
                    ? null
                    : () => _startTodayChallenge(
                          context,
                          todayProblems,
                          provider.solvedByDay,
                          dateKey,
                          provider,
                        ),
                child: Text(
                  '開始解棋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startTodayChallenge(
    BuildContext context,
    List<CaptureAiTacticsProblem> problems,
    Map<DateTime, List<CaptureAiTacticsProblem>> solvedByDay,
    DateTime dateKey,
    TacticsChallengeProvider provider,
  ) {
    // Pick first unsolved. If all solved today, start from the beginning
    // so the ring-full button still allows more attempts.
    final solvedToday = solvedByDay[dateKey] ?? [];
    final solvedIds = solvedToday.map((p) => p.id).toSet();
    final next = problems.firstWhere(
      (p) => !solvedIds.contains(p.id),
      orElse: () => problems.first,
    );

    // Build queue: start at [next], then remaining problems in original order.
    final queue = [
      next,
      ...problems.where((p) => p.id != next.id),
    ];

    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => TacticsProblemScreen(
          problems: queue,
          dailyChallengeMode: true,
          onProblemPassed: (passed) => provider.recordSolved(passed),
        ),
      ),
    );
  }
}

class _DailyRing extends StatelessWidget {
  const _DailyRing({
    required this.progress,
    required this.label,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final String label;
  final Color trackColor;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CustomPaint(
            painter: _RingPainter(
              progress: progress,
              trackColor: trackColor,
              progressColor: progressColor,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}

class _KLevelPillRow extends StatelessWidget {
  const _KLevelPillRow({
    required this.selected,
    required this.onSelect,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var k = _kLevelMax; k >= _kLevelMin; k--) ...[
            _PillButton(
              label: _kLevelLabel(k),
              isSelected: k == selected,
              onTap: () => onSelect(k),
            ),
            if (k > _kLevelMin) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _PillSegmentRow<T> extends StatelessWidget {
  const _PillSegmentRow({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in options)
          _PillButton(
            label: labelOf(option),
            isSelected: option == selected,
            onTap: () => onSelect(option),
          ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primary
              : CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? CupertinoColors.white
                : CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
