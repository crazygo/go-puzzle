import 'board_position.dart';

enum PuzzleCategory {
  beginner,   // 入门
  rules,      // 规则
  capture,    // 断吃
  ko,         // 造劫
  ladder,     // 征子
  net,        // 网
  doubleAtari // 双吃
}

extension PuzzleCategoryExt on PuzzleCategory {
  String get displayName {
    switch (this) {
      case PuzzleCategory.beginner:
        return '入门';
      case PuzzleCategory.rules:
        return '规则';
      case PuzzleCategory.capture:
        return '断吃';
      case PuzzleCategory.ko:
        return '造劫';
      case PuzzleCategory.ladder:
        return '征子';
      case PuzzleCategory.net:
        return '网';
      case PuzzleCategory.doubleAtari:
        return '双吃';
    }
  }

  String get description {
    switch (this) {
      case PuzzleCategory.beginner:
        return '学习基本的围棋规则和吃子方法';
      case PuzzleCategory.rules:
        return '理解打劫、禁入点等围棋规则';
      case PuzzleCategory.capture:
        return '通过断开对方棋子的联系来吃棋';
      case PuzzleCategory.ko:
        return '创造并利用打劫的局面';
      case PuzzleCategory.ladder:
        return '利用征子连续追击对方棋子';
      case PuzzleCategory.net:
        return '用网状包围圈住对方棋子';
      case PuzzleCategory.doubleAtari:
        return '同时打两个方向的叫吃';
    }
  }
}

enum PuzzleDifficulty { easy, medium, hard }

extension PuzzleDifficultyExt on PuzzleDifficulty {
  String get displayName {
    switch (this) {
      case PuzzleDifficulty.easy:
        return '简单';
      case PuzzleDifficulty.medium:
        return '中等';
      case PuzzleDifficulty.hard:
        return '困难';
    }
  }
}

class Puzzle {
  final String id;
  final String title;
  final String description;
  final int boardSize;
  final List<Stone> initialStones;
  final List<BoardPosition> targetCaptures; // stones that need to be captured
  final List<List<BoardPosition>> solutions; // list of valid solution sequences
  final PuzzleCategory category;
  final PuzzleDifficulty difficulty;
  final String? hint;

  const Puzzle({
    required this.id,
    required this.title,
    required this.description,
    required this.boardSize,
    required this.initialStones,
    required this.targetCaptures,
    required this.solutions,
    required this.category,
    this.difficulty = PuzzleDifficulty.easy,
    this.hint,
  });
}
