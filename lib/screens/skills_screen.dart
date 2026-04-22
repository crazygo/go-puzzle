import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../data/skill_puzzles.dart';
import '../models/puzzle.dart';
import '../providers/game_provider.dart';
import '../widgets/puzzle_card.dart';
import 'puzzle_screen.dart';

/// Skills/training tab with categorized puzzle lists.
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  // Map of puzzle ID → completed status (in-memory for now)
  final Set<String> _completedPuzzleIds = {};

  // Top-level groups for segmented control
  static const List<String> _groups = ['入门', '规则', '技巧'];
  int _selectedGroupIndex = 0;

  // Skills sub-categories
  static const List<PuzzleCategory> _skillCategories = [
    PuzzleCategory.capture,
    PuzzleCategory.ko,
    PuzzleCategory.ladder,
    PuzzleCategory.net,
    PuzzleCategory.doubleAtari,
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('技巧训练'),
            backgroundColor: CupertinoColors.systemBackground,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedGroupIndex,
                children: {
                  for (int i = 0; i < _groups.length; i++) i: Text(_groups[i]),
                },
                onValueChanged: (v) {
                  if (v != null) setState(() => _selectedGroupIndex = v);
                },
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildContent(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_selectedGroupIndex) {
      case 0:
        return _buildPuzzleList(
          context,
          SkillPuzzles.beginnerPuzzles,
          PuzzleCategory.beginner,
        );
      case 1:
        return _buildPuzzleList(
          context,
          SkillPuzzles.rulesPuzzles,
          PuzzleCategory.rules,
        );
      case 2:
        return _buildSkillsContent(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSkillsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in _skillCategories)
          _buildCategorySection(
            context,
            category,
            SkillPuzzles.allByCategory[category] ?? [],
          ),
      ],
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    PuzzleCategory category,
    List<Puzzle> puzzles,
  ) {
    final completedCount =
        puzzles.where((p) => _completedPuzzleIds.contains(p.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, category, completedCount, puzzles.length),
        _buildPuzzleList(context, puzzles, category),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    PuzzleCategory category,
    int completed,
    int total,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _categoryColor(category).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              category.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _categoryColor(category),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.description,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: completed == total && total > 0
                  ? CupertinoColors.systemGreen
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleList(
    BuildContext context,
    List<Puzzle> puzzles,
    PuzzleCategory category,
  ) {
    if (puzzles.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('暂无题目', style: TextStyle(color: CupertinoColors.systemGrey)),
        ),
      );
    }

    return Column(
      children: [
        for (final puzzle in puzzles)
          PuzzleCard(
            puzzle: puzzle,
            isCompleted: _completedPuzzleIds.contains(puzzle.id),
            onTap: () => _openPuzzle(context, puzzle),
          ),
      ],
    );
  }

  void _openPuzzle(BuildContext context, Puzzle puzzle) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => GameProvider(),
          child: PuzzleScreen(puzzle: puzzle),
        ),
      ),
    ).then((_) {
      // Check if the puzzle was solved (via game provider result)
      // For simplicity, mark any visited puzzle as "in progress"
      // In a real app this would be persisted
    });
  }

  Color _categoryColor(PuzzleCategory category) {
    switch (category) {
      case PuzzleCategory.beginner:
        return CupertinoColors.systemGreen;
      case PuzzleCategory.rules:
        return CupertinoColors.systemBlue;
      case PuzzleCategory.capture:
        return CupertinoColors.systemOrange;
      case PuzzleCategory.ko:
        return CupertinoColors.systemPurple;
      case PuzzleCategory.ladder:
        return CupertinoColors.systemRed;
      case PuzzleCategory.net:
        return CupertinoColors.systemTeal;
      case PuzzleCategory.doubleAtari:
        return CupertinoColors.systemIndigo;
    }
  }
}
