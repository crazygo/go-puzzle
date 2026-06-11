import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../data/tactics_problem_repository.dart';
import '../game/ai_rank_level.dart';
import '../game/capture_ai_tactics.dart';
import '../game/game_mode.dart';
import '../game/go_engine.dart';
import '../models/board_position.dart';
import '../models/game_record.dart';
import '../models/game_state.dart';
import '../providers/capture_game_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tactics_challenge_provider.dart';
import '../services/game_history_repository.dart';
import '../theme/theme_context.dart';
import '../ui/board_coordinates.dart';
import '../ui/tactics_labels.dart';
import '../widgets/go_board_widget.dart';
import '../widgets/page_hero_banner.dart' show kPageBackgroundColor;
import '../widgets/page_section_card.dart';
import 'capture_game_screen.dart';
import 'screenshot_import_screen.dart';
import 'tactics_problem_screen.dart';

const _heatmapWeeks = 18;

// ─── K-level difficulty ───────────────────────────────────────────────────────

// Represents the player's current K level (1 = strongest, 15 = weakest).
// Problem filtering by K level requires a difficulty field on problems;
// until that metadata exists, all K levels show the same problem pool.
const _kLevelMin = 1;
const _kLevelMax = 15;
const _kLevelDefault = 15;

String _kLevelLabel(int k) => '${k}K';

// ─── SkillsScreen ─────────────────────────────────────────────────────────────

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({
    super.key,
    Future<List<CaptureAiTacticsProblem>>? problemsFuture,
    DateTime? today,
  })  : _problemsFutureOverride = problemsFuture,
        _todayOverride = today;

  final Future<List<CaptureAiTacticsProblem>>? _problemsFutureOverride;
  final DateTime? _todayOverride;

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  late final Future<List<CaptureAiTacticsProblem>> _problemsFuture;
  late final DateTime _today;
  final _historyRepo = GameHistoryRepository();
  List<GameRecord> _history = const [];

  // Local state fallbacks for widget tests where provider is not present
  final Map<DateTime, List<CaptureAiTacticsProblem>> _localSolvedByDay = {};

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(widget._todayOverride ?? DateTime.now());
    _problemsFuture = widget._problemsFutureOverride ??
        const TacticsProblemRepository().loadProblems();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await _historyRepo.loadAll();
    if (!mounted) return;
    setState(() => _history = records);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    // Graceful fallback for tests that do not configure MultiProvider
    final challengeProvider = context.watch<TacticsChallengeProvider?>();

    if (challengeProvider == null) {
      return CupertinoPageScaffold(
        backgroundColor: palette.pageBackground,
        child: FutureBuilder<List<CaptureAiTacticsProblem>>(
          future: _problemsFuture,
          builder: (context, snapshot) {
            final isLoading = snapshot.connectionState != ConnectionState.done;
            final hasError = snapshot.hasError;

            return CustomScrollView(
              slivers: [
                CupertinoSliverNavigationBar(
                  largeTitle: const Text('歷史'),
                  backgroundColor: palette.pageBackground,
                  transitionBetweenRoutes: false,
                ),
                if (isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CupertinoActivityIndicator()),
                  )
                else if (hasError)
                  SliverFillRemaining(
                    child: _ErrorState(error: snapshot.error),
                  )
                else
                  SliverToBoxAdapter(
                    child: _PuzzleHome(
                      solvedByDay: _localSolvedByDay,
                      today: _today,
                      onOpenDay: (day, dayProblems) => _openProblemSet(
                        context,
                        dayProblems,
                        title: _formatDate(day),
                      ),
                      history: _history,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    final problems = challengeProvider.allProblems;
    final hasError = challengeProvider.loadError != null;
    final isLoading = problems == null && !hasError;

    return CupertinoPageScaffold(
      backgroundColor: palette.pageBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('歷史'),
            backgroundColor: palette.pageBackground,
            transitionBetweenRoutes: false,
          ),
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (hasError)
            SliverFillRemaining(
              child: _ErrorState(error: challengeProvider.loadError),
            )
          else
            SliverToBoxAdapter(
              child: _PuzzleHome(
                solvedByDay: challengeProvider.solvedByDay,
                today: _today,
                onOpenDay: (day, dayProblems) => _openProblemSet(
                  context,
                  dayProblems,
                  title: _formatDate(day),
                ),
                history: _history,
              ),
            ),
        ],
      ),
    );
  }

  void _openProblemSet(
    BuildContext context,
    List<CaptureAiTacticsProblem> problems, {
    required String title,
  }) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => _ProblemListScreen(
          title: title,
          problems: problems,
          onOpenProblem: _openProblem,
        ),
      ),
    );
  }

  void _openProblem(
    BuildContext context,
    CaptureAiTacticsProblem problem,
  ) {
    _recordVisited(problem);
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => TacticsProblemScreen(problems: [problem]),
      ),
    );
  }

  void _recordVisited(CaptureAiTacticsProblem problem) {
    final challengeProvider = context.read<TacticsChallengeProvider?>();
    if (challengeProvider != null) {
      challengeProvider.recordSolved(problem);
    } else {
      setState(() {
        final day = _dateOnly(DateTime.now());
        (_localSolvedByDay[day] ??= []).add(problem);
      });
    }
  }
}

// ─── Home layout ──────────────────────────────────────────────────────────────

class _PuzzleHome extends StatelessWidget {
  const _PuzzleHome({
    required this.solvedByDay,
    required this.today,
    required this.onOpenDay,
    required this.history,
  });

  final Map<DateTime, List<CaptureAiTacticsProblem>> solvedByDay;
  final DateTime today;
  final void Function(DateTime, List<CaptureAiTacticsProblem>) onOpenDay;
  final List<GameRecord> history;

  @override
  Widget build(BuildContext context) {
    final sortedDays = solvedByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatsSection(
            solvedByDay: solvedByDay.map((k, v) => MapEntry(k, v.length)),
            today: today,
            onTapDay: (day) {
              final p = solvedByDay[day];
              if (p != null && p.isNotEmpty) onOpenDay(day, p);
            },
          ),
          if (sortedDays.isNotEmpty) ...[
            const SizedBox(height: 14),
            _HistorySection(
              sortedDays: sortedDays,
              solvedByDay: solvedByDay,
              onTapDay: onOpenDay,
            ),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 14),
            _HistorySectionCard(history: history),
          ],
        ],
      ),
    );
  }
}

// ─── 統計 section ─────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.solvedByDay,
    required this.today,
    required this.onTapDay,
  });

  final Map<DateTime, int> solvedByDay;
  final DateTime today;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final total = solvedByDay.values.fold(0, (sum, c) => sum + c);
    return PageSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '解棋記錄'),
          const SizedBox(height: 12),
          _HeatmapCalendar(
            solvedByDay: solvedByDay,
            today: today,
            onTapDay: onTapDay,
          ),
          const SizedBox(height: 10),
          Text(
            total == 0 ? '還沒有記錄，開始解棋吧。' : '共解 $total 題',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 歷史 section ─────────────────────────────────────────────────────────────

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.sortedDays,
    required this.solvedByDay,
    required this.onTapDay,
  });

  final List<DateTime> sortedDays;
  final Map<DateTime, List<CaptureAiTacticsProblem>> solvedByDay;
  final void Function(DateTime, List<CaptureAiTacticsProblem>) onTapDay;

  @override
  Widget build(BuildContext context) {
    return PageSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '歷史記錄'),
          const SizedBox(height: 8),
          for (final day in sortedDays)
            _HistoryDayRow(
              day: day,
              count: solvedByDay[day]!.length,
              onTap: () => onTapDay(day, solvedByDay[day]!),
            ),
        ],
      ),
    );
  }
}

class _HistoryDayRow extends StatelessWidget {
  const _HistoryDayRow({
    required this.day,
    required this.count,
    required this.onTap,
  });

  final DateTime day;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatDate(day),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            Text(
              '$count 題',
              style: TextStyle(fontSize: 13, color: secondary),
            ),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_forward, size: 16, color: secondary),
          ],
        ),
      ),
    );
  }
}

// ─── Heatmap calendar ─────────────────────────────────────────────────────────

class _HeatmapCalendar extends StatelessWidget {
  const _HeatmapCalendar({
    required this.solvedByDay,
    required this.today,
    required this.onTapDay,
  });

  final Map<DateTime, int> solvedByDay;
  final DateTime today;
  final ValueChanged<DateTime> onTapDay;

  static const _cellSize = 12.0;
  static const _cellGap = 2.0;

  @override
  Widget build(BuildContext context) {
    // Align grid to start on Monday, end on Sunday of current week.
    final daysSinceMonday = (today.weekday - 1) % 7;
    final gridEnd = today.add(Duration(days: 6 - daysSinceMonday));
    final gridStart =
        gridEnd.subtract(const Duration(days: _heatmapWeeks * 7 - 1));

    final weeks = <List<DateTime>>[];
    var weekStart = gridStart;
    for (var w = 0; w < _heatmapWeeks; w++) {
      weeks.add(List.generate(7, (d) => weekStart.add(Duration(days: d))));
      weekStart = weekStart.add(const Duration(days: 7));
    }

    final maxCount = solvedByDay.values.isEmpty
        ? 1
        : solvedByDay.values.reduce((a, b) => a > b ? a : b);

    const dayLabels = ['一', '', '三', '', '五', '', '日'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final label in dayLabels)
                SizedBox(
                  width: 12,
                  height: _cellSize + _cellGap,
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 8,
                        color:
                            CupertinoColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          for (final week in weeks)
            Padding(
              padding: const EdgeInsets.only(right: _cellGap),
              child: Column(
                children: [
                  for (final day in week)
                    _HeatmapCell(
                      date: day,
                      count: solvedByDay[day] ?? 0,
                      maxCount: maxCount,
                      isFuture: day.isAfter(today),
                      onTap: () => onTapDay(day),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({
    required this.date,
    required this.count,
    required this.maxCount,
    required this.isFuture,
    required this.onTap,
  });

  final DateTime date;
  final int count;
  final int maxCount;
  final bool isFuture;
  final VoidCallback onTap;

  static const _size = 12.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final Color cellColor;
    if (isFuture) {
      cellColor = CupertinoColors.systemGrey6.resolveFrom(context);
    } else if (count == 0) {
      cellColor = CupertinoColors.systemGrey5.resolveFrom(context);
    } else {
      final intensity = (0.3 + 0.7 * (count / maxCount)).clamp(0.0, 1.0);
      final base = CupertinoColors.activeGreen.resolveFrom(context);
      cellColor = base.withValues(alpha: intensity);
    }

    return GestureDetector(
      onTap: count > 0 && !isFuture ? onTap : null,
      child: Container(
        width: _size,
        height: _size,
        margin: const EdgeInsets.only(bottom: _gap),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─── Problem list screen ──────────────────────────────────────────────────────

class _ProblemListScreen extends StatelessWidget {
  const _ProblemListScreen({
    required this.title,
    required this.problems,
    required this.onOpenProblem,
  });

  final String title;
  final List<CaptureAiTacticsProblem> problems;
  final void Function(BuildContext, CaptureAiTacticsProblem) onOpenProblem;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return CupertinoPageScaffold(
      backgroundColor: palette.pageBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            if (problems.isEmpty)
              const _EmptyState(message: '這個條件下暫時沒有可用題目。')
            else
              for (final problem in problems)
                _TacticsProblemCard(
                  problem: problem,
                  onTap: () => onOpenProblem(context, problem),
                ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared card container ────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: CupertinoColors.label.resolveFrom(context),
      ),
    );
  }
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

// ─── K-level pill row ─────────────────────────────────────────────────────────

// Shows 15K → 1K as a horizontally scrollable row of pills.
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

// ─── Pill segment row ─────────────────────────────────────────────────────────

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

// ─── Problem card ─────────────────────────────────────────────────────────────

class _TacticsProblemCard extends StatelessWidget {
  const _TacticsProblemCard({
    required this.problem,
    required this.onTap,
    this.leading,
  });

  final CaptureAiTacticsProblem problem;
  final VoidCallback onTap;
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final tactic = problem.metadata['tactic']?.toString();
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.setupPanelBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: palette.setupPanelBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                _ProblemIndexBadge(label: leading!),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            problem.id,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: palette.setupTitleText,
                            ),
                          ),
                        ),
                        Text(
                          '${problem.boardSize}路',
                          style: TextStyle(fontSize: 12, color: secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(label: categoryName(problem.category)),
                        if (tactic != null && tactic.isNotEmpty)
                          _Pill(label: tacticName(tactic)),
                        _Pill(label: '先手 ${playerName(problem.currentPlayer)}'),
                        _Pill(
                          label:
                              '提子 ${problem.capturedByBlack}:${problem.capturedByWhite}',
                        ),
                      ],
                    ),
                    if (problem.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        problem.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: secondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProblemIndexBadge extends StatelessWidget {
  const _ProblemIndexBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue
            .resolveFrom(context)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: CupertinoColors.activeBlue.resolveFrom(context),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '題集載入失敗\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CupertinoColors.destructiveRed.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatBoardCoordinate(
  List<int> move,
  int boardSize,
  BoardCoordinateSystem coordinateSystem,
) {
  if (move.length < 2) return '-';
  final row = move[0];
  final col = move[1];
  if (row == -1 && col == -1) return '停一手';
  if (col < 0 || col >= boardSize || row < 0 || row >= boardSize) {
    return '-';
  }
  return formatBoardCoordinate(
    row: row,
    col: col,
    boardSize: boardSize,
    coordinateSystem: coordinateSystem,
  );
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final primaryEnd = isClassic
        ? palette.primary
        : Color.lerp(palette.primary, CupertinoColors.black, 0.20)!;

    return SizedBox(
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
              color: palette.primary.withValues(alpha: isClassic ? 0.20 : 0.24),
              blurRadius: isClassic ? 12 : 18,
              offset: Offset(0, isClassic ? 4 : 8),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySectionCard extends StatelessWidget {
  const _HistorySectionCard({
    required this.history,
  });

  final List<GameRecord> history;

  static const _maxVisible = 5;

  @override
  Widget build(BuildContext context) {
    final visible = history.take(_maxVisible).toList();
    final palette = context.appPalette;
    return PageSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '歷史對局',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.setupTitleText,
                  ),
                ),
              ),
              if (history.length > _maxVisible)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  onPressed: () => _showAllHistory(context),
                  child: Text(
                    '全部 ›',
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.setupActionText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...visible.map(
            (r) => _HistoryRow(
              record: r,
              onTap: () => _showDetailSheet(context, r),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, GameRecord record) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _HistoryDetailSheet(record: record),
    );
  }

  void _showAllHistory(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _FullHistoryScreen(history: history),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.record,
    required this.onTap,
  });

  final GameRecord record;
  final VoidCallback onTap;

  static const _outcomeColors = {
    GameOutcome.humanWins: Color(0xFF4A7C59),
    GameOutcome.aiWins: Color(0xFF8B3A3A),
    GameOutcome.draw: Color(0xFF8C7966),
    GameOutcome.abandoned: Color(0xFF8C7966),
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final date = _formatHistoryDate(record.playedAt);
    final boardLabel = '${record.boardSize} 路';
    final diffLabel = record.difficultyLevel.displayName;
    final modeLabel = record.gameMode.historyLabel;
    final outcomeLabel = record.outcome.displayName;
    final outcomeColor = isClassic
        ? switch (record.outcome) {
            GameOutcome.humanWins =>
              CupertinoColors.systemGreen.resolveFrom(context),
            GameOutcome.aiWins =>
              CupertinoColors.systemRed.resolveFrom(context),
            GameOutcome.draw => CupertinoColors.systemGrey.resolveFrom(context),
            GameOutcome.abandoned =>
              CupertinoColors.systemGrey.resolveFrom(context),
          }
        : _outcomeColors[record.outcome] ?? const Color(0xFF8C7966);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Row(
        children: [
          _StoneCircle(
              isBlack: record.humanColorIndex == StoneColor.black.index),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$boardLabel · $modeLabel · $diffLabel · ${record.totalMoves} 手',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.setupValueText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: palette.setupLabelText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              outcomeLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: outcomeColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_right,
            color: isClassic
                ? CupertinoColors.tertiaryLabel.resolveFrom(context)
                : const Color(0xFFCBAF8C),
            size: 14,
          ),
        ],
      ),
    );
  }

  static String _formatHistoryDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '今天 ${_pad(dt.hour)}:${_pad(dt.minute)}';
    if (diff.inDays == 1) return '昨天 ${_pad(dt.hour)}:${_pad(dt.minute)}';
    return '${dt.month}/${dt.day} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

class _StoneCircle extends StatelessWidget {
  const _StoneCircle({required this.isBlack});

  final bool isBlack;

  @override
  Widget build(BuildContext context) {
    final isClassic = context.isClassicAppTheme;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isBlack
            ? CupertinoColors.label.resolveFrom(context)
            : (isClassic
                ? CupertinoColors.systemBackground.resolveFrom(context)
                : const Color(0xFFF5F0E8)),
        border: Border.all(
          color: isBlack
              ? CupertinoColors.secondaryLabel.resolveFrom(context)
              : (isClassic
                  ? CupertinoColors.separator.resolveFrom(context)
                  : const Color(0xFFBCA88A)),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetailSheet extends StatelessWidget {
  const _HistoryDetailSheet({required this.record});

  final GameRecord record;

  @override
  Widget build(BuildContext context) {
    final boardState = _buildFinalBoardState(record);
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final coordinateSystem =
        context.select<SettingsProvider, BoardCoordinateSystem>(
            (settings) => settings.boardCoordinateSystem);

    return Container(
      decoration: BoxDecoration(
        color: palette.pageBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.setupDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _OutcomeBadge(outcome: record.outcome),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.gameMode == GameMode.territory
                              ? '${record.boardSize} 路 · 圍空 · ${record.difficultyLevel.displayName}'
                              : '${record.boardSize} 路 · 吃${record.captureTarget}子 · ${record.difficultyLevel.displayName}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.setupValueText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFullDate(record.playedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.setupLabelText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '關閉',
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.setupActionText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (boardState != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isClassic
                          ? palette.setupPanelBackground
                          : const Color(0xFFF0DFC9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GoBoardWidget(
                        gameState: boardState,
                        coordinateSystem: coordinateSystem,
                        onTap: null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '共 ${record.totalMoves} 手',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.setupLabelText,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (record.moves.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _PrimaryActionButton(
                  title: '瀏覽棋局',
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => _GameBrowseScreen(record: record),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  static String _formatFullDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static GameState? _buildFinalBoardState(GameRecord record) {
    final fb = record.finalBoard;
    if (fb == null) return null;
    try {
      final board = fb
          .map((row) => row
              .map((i) =>
                  StoneColor.values[i.clamp(0, StoneColor.values.length - 1)])
              .toList())
          .toList();
      return GameState(
        boardSize: record.boardSize,
        board: board,
        currentPlayer: StoneColor.black,
      );
    } catch (_) {
      return null;
    }
  }
}

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({required this.outcome});

  final GameOutcome outcome;

  static const _bgColors = {
    GameOutcome.humanWins: Color(0xFFE6F4EC),
    GameOutcome.aiWins: Color(0xFFF9E6E6),
    GameOutcome.abandoned: Color(0xFFF0EAE2),
  };

  static const _fgColors = {
    GameOutcome.humanWins: Color(0xFF3D7A56),
    GameOutcome.aiWins: Color(0xFF8B3A3A),
    GameOutcome.abandoned: Color(0xFF7A6A5A),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColors[outcome],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        outcome.displayName,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _fgColors[outcome],
        ),
      ),
    );
  }
}

class _FullHistoryScreen extends StatelessWidget {
  const _FullHistoryScreen({required this.history});

  final List<GameRecord> history;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kPageBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('歷史對局'),
        previousPageTitle: '歷史',
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: history.length,
          separatorBuilder: (_, __) => Container(
            height: 0.5,
            color: const Color(0x26D8C1A4),
          ),
          itemBuilder: (ctx, i) {
            final r = history[i];
            return _HistoryRow(
              record: r,
              onTap: () => showCupertinoModalPopup<void>(
                context: ctx,
                builder: (_) => _HistoryDetailSheet(record: r),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GameBrowseScreen extends StatefulWidget {
  const _GameBrowseScreen({required this.record});

  final GameRecord record;

  @override
  State<_GameBrowseScreen> createState() => _GameBrowseScreenState();
}

class _GameBrowseScreenState extends State<_GameBrowseScreen> {
  late final List<GameState> _states;
  int _index = 0;
  bool _onlyMarked = false;

  @override
  void initState() {
    super.initState();
    _states = _buildStates(widget.record);
  }

  static List<GameState> _buildStates(GameRecord record) {
    final emptyBoard = List.generate(
      record.boardSize,
      (_) => List<StoneColor>.filled(record.boardSize, StoneColor.empty),
    );

    if (record.initialBoardCells != null) {
      final cells = record.initialBoardCells!;
      for (int r = 0; r < record.boardSize; r++) {
        for (int c = 0; c < record.boardSize; c++) {
          if (r < cells.length && c < cells[r].length) {
            emptyBoard[r][c] = StoneColor
                .values[cells[r][c].clamp(0, StoneColor.values.length - 1)];
          }
        }
      }
    } else {
      final initialMode = captureInitialModeFromStorageKey(
        record.initialMode,
        fallback: CaptureInitialMode.empty,
      );
      applyCaptureInitialLayout(emptyBoard, initialMode);
    }

    var state = GameState(
      boardSize: record.boardSize,
      board: emptyBoard,
      currentPlayer: record.initialFirstPlayer,
    );

    final states = <GameState>[state];
    for (final move in record.moves) {
      if (move.length < 2) break;
      final next = GoEngine.placeStone(state, move[0], move[1]);
      if (next == null) break;
      state = next;
      states.add(state);
    }
    return states;
  }

  int get _totalMoves => _states.length - 1;
  Set<int> get _markedMoves => widget.record.markedMoveNumbers.toSet();
  List<int> get _sortedMarkedMoves => _markedMoves.toList()..sort();

  String _moveCoordinate(int moveNo, BoardCoordinateSystem coordinateSystem) {
    if (moveNo <= 0 || moveNo > widget.record.moves.length) return '-';
    return _formatBoardCoordinate(
      widget.record.moves[moveNo - 1],
      widget.record.boardSize,
      coordinateSystem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coordinateSystem =
        context.select<SettingsProvider, BoardCoordinateSystem>(
            (settings) => settings.boardCoordinateSystem);
    final markedMoves = _sortedMarkedMoves;
    final hasMarkedMoves = markedMoves.isNotEmpty;
    final markedStart = hasMarkedMoves ? markedMoves.first : 0;
    final markedEnd = hasMarkedMoves ? markedMoves.last : _totalMoves;
    final isAtStart =
        _onlyMarked && hasMarkedMoves ? _index <= markedStart : _index == 0;
    final isAtEnd = _onlyMarked && hasMarkedMoves
        ? _index >= markedEnd
        : _index == _totalMoves;
    final current = _states[_index];

    return CupertinoPageScaffold(
      backgroundColor: kPageBackgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('棋局瀏覽'),
        previousPageTitle: '歷史對局',
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0DFC9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: GoBoardWidget(
                          gameState: current,
                          coordinateSystem: coordinateSystem,
                          onTap: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Text(
                    _index == 0
                        ? '初始局面'
                        : '第 $_index 手 / 共 $_totalMoves 手 · 座標 ${_moveCoordinate(_index, coordinateSystem)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8C7966),
                    ),
                  ),
                  if (_index > 0 && _markedMoves.contains(_index))
                    const Text(
                      '⭐ 已標記手',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB68454)),
                    ),
                ],
              ),
            ),
            if (hasMarkedMoves)
              SizedBox(
                height: 40,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: () =>
                          setState(() => _onlyMarked = !_onlyMarked),
                      child: Text(_onlyMarked ? '只看標記：開' : '只看標記：關'),
                    ),
                    for (final move in markedMoves)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          color: _index == move
                              ? const Color(0xFFB68454)
                              : const Color(0x1AB68454),
                          onPressed: () => setState(
                              () => _index = move.clamp(0, _totalMoves)),
                          child: Text(
                            '第$move手 ${_moveCoordinate(move, coordinateSystem)}',
                            style: TextStyle(
                              color: _index == move
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF7A5A3A),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                children: [
                  _NavIconButton(
                    icon: CupertinoIcons.backward_end_fill,
                    enabled: !isAtStart,
                    onPressed: () => setState(() => _index =
                        (_onlyMarked && hasMarkedMoves) ? markedStart : 0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DecoratedActionButton(
                      text: '上一手',
                      filled: false,
                      onPressed: isAtStart
                          ? null
                          : () => setState(() {
                                if (_onlyMarked) {
                                  final prev = markedMoves
                                      .where((m) => m < _index)
                                      .toList();
                                  if (prev.isNotEmpty) {
                                    _index = prev.last;
                                  }
                                } else {
                                  _index--;
                                }
                              }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DecoratedActionButton(
                      text: '下一手',
                      filled: true,
                      onPressed: isAtEnd
                          ? null
                          : () => setState(() {
                                if (_onlyMarked) {
                                  final next = markedMoves
                                      .where((m) => m > _index)
                                      .toList();
                                  if (next.isNotEmpty) {
                                    _index = next.first;
                                  }
                                } else {
                                  _index++;
                                }
                              }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _NavIconButton(
                    icon: CupertinoIcons.forward_end_fill,
                    enabled: !isAtEnd,
                    onPressed: () => setState(() => _index =
                        (_onlyMarked && hasMarkedMoves)
                            ? markedEnd
                            : _totalMoves),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: enabled ? onPressed : null,
      child: Icon(
        icon,
        size: 22,
        color: enabled
            ? const Color(0xFFB68454)
            : const Color(0xFFB68454).withValues(alpha: 0.35),
      ),
    );
  }
}

class _DecoratedActionButton extends StatelessWidget {
  const _DecoratedActionButton({
    required this.text,
    required this.filled,
    required this.onPressed,
  });

  final String text;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final background =
        filled ? const Color(0xFFC28A56) : const Color(0xFFF2EBE3);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: disabled ? const Color(0xFFDCD4CC) : background,
      borderRadius: BorderRadius.circular(16),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: filled ? CupertinoColors.white : const Color(0xFF8F7359),
        ),
      ),
    );
  }
}
