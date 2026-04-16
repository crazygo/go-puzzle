import 'package:flutter/cupertino.dart';

import '../models/puzzle.dart';

/// Card displayed in the skills list for a single puzzle.
class PuzzleCard extends StatelessWidget {
  final Puzzle puzzle;
  final VoidCallback onTap;
  final bool isCompleted;

  const PuzzleCard({
    super.key,
    required this.puzzle,
    required this.onTap,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: CupertinoListTile(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: _buildLeading(context),
          title: Text(
            puzzle.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            puzzle.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DifficultyBadge(difficulty: puzzle.difficulty),
              const SizedBox(width: 8),
              if (isCompleted)
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: CupertinoColors.systemGreen,
                  size: 22,
                )
              else
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: CupertinoColors.systemGrey2,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _categoryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        _categoryIcon,
        color: _categoryColor,
        size: 22,
      ),
    );
  }

  Color get _categoryColor {
    switch (puzzle.category) {
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

  IconData get _categoryIcon {
    switch (puzzle.category) {
      case PuzzleCategory.beginner:
        return CupertinoIcons.star_fill;
      case PuzzleCategory.rules:
        return CupertinoIcons.book_fill;
      case PuzzleCategory.capture:
        return CupertinoIcons.scissors;
      case PuzzleCategory.ko:
        return CupertinoIcons.arrow_2_circlepath;
      case PuzzleCategory.ladder:
        return CupertinoIcons.arrow_right_arrow_left;
      case PuzzleCategory.net:
        return CupertinoIcons.grid;
      case PuzzleCategory.doubleAtari:
        return CupertinoIcons.bolt_fill;
    }
  }
}

class _DifficultyBadge extends StatelessWidget {
  final PuzzleDifficulty difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty.displayName,
        style: TextStyle(
          fontSize: 11,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color get _color {
    switch (difficulty) {
      case PuzzleDifficulty.easy:
        return CupertinoColors.systemGreen;
      case PuzzleDifficulty.medium:
        return CupertinoColors.systemOrange;
      case PuzzleDifficulty.hard:
        return CupertinoColors.systemRed;
    }
  }
}
