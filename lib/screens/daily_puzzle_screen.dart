import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../data/daily_puzzles.dart';
import '../models/puzzle.dart';
import '../providers/game_provider.dart';
import '../widgets/date_timeline.dart';
import '../widgets/go_board_widget.dart';
import '../widgets/page_hero_banner.dart';
import 'puzzle_screen.dart';

/// Today's puzzle tab – shows date timeline + interactive preview board.
class DailyPuzzleScreen extends StatefulWidget {
  const DailyPuzzleScreen({super.key});

  @override
  State<DailyPuzzleScreen> createState() => _DailyPuzzleScreenState();
}

class _DailyPuzzleScreenState extends State<DailyPuzzleScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _dates;
  late Puzzle _selectedPuzzle;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    final dateRange = DailyPuzzles.getPuzzlesForDateRange(
      endDate: DateTime.now(),
      count: 30,
    );
    _dates = dateRange.map((e) => e.date).toList();
    _selectedPuzzle = DailyPuzzles.getPuzzleForDate(_selectedDate);
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedPuzzle = DailyPuzzles.getPuzzleForDate(date);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kPageBackgroundColor,
      child: DecoratedBox(
        decoration: kPageBackgroundDecoration,
        child: Stack(
          children: [
            // Hero as full-bleed background layer
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PageHeroBanner(
                title: '谜题',
                action: _buildTodayButton(context),
              ),
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
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        DateTimeline(
                          dates: _dates,
                          selectedDate: _selectedDate,
                          onDateSelected: _onDateSelected,
                        ),
                        const SizedBox(height: 16),
                        _buildDayHeader(context),
                        const SizedBox(height: 16),
                        _buildPuzzlePreview(context),
                        const SizedBox(height: 16),
                        _buildPuzzleInfo(context),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayButton(BuildContext context) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    if (isToday) return const SizedBox.shrink();
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _onDateSelected(DateTime.now()),
      child: const Text('今天'),
    );
  }

  Widget _buildDayHeader(BuildContext context) {
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    final isYesterday = _isSameDay(
      _selectedDate,
      now.subtract(const Duration(days: 1)),
    );

    String dateLabel;
    if (isToday) {
      dateLabel = '今天 · ${_formatDate(_selectedDate)}';
    } else if (isYesterday) {
      dateLabel = '昨天 · ${_formatDate(_selectedDate)}';
    } else {
      dateLabel = _formatDate(_selectedDate);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedPuzzle.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzlePreview(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider()..loadPuzzle(_selectedPuzzle),
      builder: (context, _) {
        return Consumer<GameProvider>(
          builder: (context, gameProvider, _) {
            final gameState = gameProvider.gameState;
            if (gameState == null) return const CupertinoActivityIndicator();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AspectRatio(
                aspectRatio: 1,
                child: GestureDetector(
                  onTap: () => _openPuzzle(context),
                  child: Stack(
                    children: [
                      GoBoardWidget(
                        gameState: gameState,
                        onTap: null, // preview only; tapping opens puzzle
                      ),
                      // "Tap to play" overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.play_fill,
                                    color: CupertinoColors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '开始解题',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPuzzleInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          children: [
            Text(
              _selectedPuzzle.description,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _InfoChip(
                  icon: CupertinoIcons.tag_fill,
                  label: _selectedPuzzle.category.displayName,
                  color: CupertinoColors.systemBlue,
                ),
                _InfoChip(
                  icon: CupertinoIcons.chart_bar_fill,
                  label: _selectedPuzzle.difficulty.displayName,
                  color: _difficultyColor(_selectedPuzzle.difficulty),
                ),
                _InfoChip(
                  icon: CupertinoIcons.grid,
                  label: '${_selectedPuzzle.boardSize}路',
                  color: CupertinoColors.systemGrey,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(14),
                onPressed: () => _openPuzzle(context),
                child: const Text('开始解题'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPuzzle(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => GameProvider(),
          child: PuzzleScreen(puzzle: _selectedPuzzle),
        ),
      ),
    );
  }

  Color _difficultyColor(PuzzleDifficulty difficulty) {
    switch (difficulty) {
      case PuzzleDifficulty.easy:
        return CupertinoColors.systemGreen;
      case PuzzleDifficulty.medium:
        return CupertinoColors.systemOrange;
      case PuzzleDifficulty.hard:
        return CupertinoColors.systemRed;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
