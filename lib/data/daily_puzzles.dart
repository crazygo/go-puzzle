import '../models/board_position.dart';
import '../models/puzzle.dart';

/// Daily puzzle data – one puzzle per day, cycling through the list.
class DailyPuzzles {
  static const List<Puzzle> puzzles = [
    // Day 1: Simple atari – capture one stone
    Puzzle(
      id: 'daily_001',
      title: '初学叫吃',
      description: '黑棋落子，吃掉白棋。',
      boardSize: 9,
      initialStones: [
        Stone(position: BoardPosition(4, 4), color: StoneColor.white),
        Stone(position: BoardPosition(4, 3), color: StoneColor.black),
        Stone(position: BoardPosition(3, 4), color: StoneColor.black),
        Stone(position: BoardPosition(5, 4), color: StoneColor.black),
      ],
      targetCaptures: [BoardPosition(4, 4)],
      solutions: [
        [BoardPosition(4, 5)],
      ],
      category: PuzzleCategory.beginner,
      difficulty: PuzzleDifficulty.easy,
      hint: '找到白棋唯一的气',
    ),

    // Day 2: Two-stone capture
    Puzzle(
      id: 'daily_002',
      title: '吃两子',
      description: '黑棋一步，同时吃掉两颗白棋。',
      boardSize: 9,
      initialStones: [
        Stone(position: BoardPosition(3, 4), color: StoneColor.white),
        Stone(position: BoardPosition(3, 5), color: StoneColor.white),
        Stone(position: BoardPosition(2, 4), color: StoneColor.black),
        Stone(position: BoardPosition(2, 5), color: StoneColor.black),
        Stone(position: BoardPosition(4, 4), color: StoneColor.black),
        Stone(position: BoardPosition(4, 5), color: StoneColor.black),
        Stone(position: BoardPosition(3, 3), color: StoneColor.black),
      ],
      targetCaptures: [BoardPosition(3, 4), BoardPosition(3, 5)],
      solutions: [
        [BoardPosition(3, 6)],
      ],
      category: PuzzleCategory.beginner,
      difficulty: PuzzleDifficulty.easy,
      hint: '封住白棋最后一口气',
    ),

    // Day 3: Corner capture
    Puzzle(
      id: 'daily_003',
      title: '角上吃子',
      description: '利用角的边界，吃掉白棋。',
      boardSize: 9,
      initialStones: [
        Stone(position: BoardPosition(0, 0), color: StoneColor.white),
        Stone(position: BoardPosition(1, 0), color: StoneColor.black),
      ],
      targetCaptures: [BoardPosition(0, 0)],
      solutions: [
        [BoardPosition(0, 1)],
      ],
      category: PuzzleCategory.beginner,
      difficulty: PuzzleDifficulty.easy,
      hint: '白棋在角上只有两口气，封住右边就能吃掉',
    ),

    // Day 4: Double atari
    Puzzle(
      id: 'daily_004',
      title: '双叫吃',
      description: '黑棋一步棋同时叫吃两处白棋。',
      boardSize: 9,
      initialStones: [
        Stone(position: BoardPosition(3, 3), color: StoneColor.white),
        Stone(position: BoardPosition(5, 5), color: StoneColor.white),
        Stone(position: BoardPosition(3, 5), color: StoneColor.black),
        Stone(position: BoardPosition(5, 3), color: StoneColor.black),
        Stone(position: BoardPosition(2, 3), color: StoneColor.black),
        Stone(position: BoardPosition(3, 2), color: StoneColor.black),
        Stone(position: BoardPosition(6, 5), color: StoneColor.black),
        Stone(position: BoardPosition(5, 6), color: StoneColor.black),
      ],
      targetCaptures: [BoardPosition(3, 3), BoardPosition(5, 5)],
      solutions: [
        [BoardPosition(4, 4)],
      ],
      category: PuzzleCategory.doubleAtari,
      difficulty: PuzzleDifficulty.medium,
      hint: '找到一颗棋子可以同时威胁两处',
    ),

    // Day 5: Ladder introduction
    Puzzle(
      id: 'daily_005',
      title: '征子入门',
      description: '用征子的方式追击白棋。',
      boardSize: 9,
      initialStones: [
        Stone(position: BoardPosition(1, 1), color: StoneColor.white),
        Stone(position: BoardPosition(0, 1), color: StoneColor.black),
        Stone(position: BoardPosition(1, 0), color: StoneColor.black),
        Stone(position: BoardPosition(1, 2), color: StoneColor.black),
      ],
      targetCaptures: [BoardPosition(1, 1)],
      solutions: [
        [BoardPosition(2, 1)],
      ],
      category: PuzzleCategory.ladder,
      difficulty: PuzzleDifficulty.easy,
      hint: '封住白棋逃跑的路线',
    ),

    // Day 6: Net (Geta)
    Puzzle(
      id: 'daily_006',
      title: '扑网',
      description: '用网的方式困住白棋，使其无法逃脱。',
      boardSize: 9,
      initialStones: [
        Stone(position: BoardPosition(4, 4), color: StoneColor.white),
        Stone(position: BoardPosition(3, 3), color: StoneColor.black),
        Stone(position: BoardPosition(3, 5), color: StoneColor.black),
        Stone(position: BoardPosition(5, 3), color: StoneColor.black),
      ],
      targetCaptures: [BoardPosition(4, 4)],
      solutions: [
        [BoardPosition(5, 5)],
        [BoardPosition(6, 4)],
      ],
      category: PuzzleCategory.net,
      difficulty: PuzzleDifficulty.medium,
      hint: '不要直接叫吃，而是截断逃路',
    ),

    // Day 7: Ko creation
    Puzzle(
      id: 'daily_007',
      title: '造劫',
      description: '黑棋制造一个打劫局面。',
      boardSize: 9,
      initialStones: [
        Stone(position: BoardPosition(3, 3), color: StoneColor.white),
        Stone(position: BoardPosition(3, 4), color: StoneColor.white),
        Stone(position: BoardPosition(4, 3), color: StoneColor.white),
        Stone(position: BoardPosition(2, 3), color: StoneColor.black),
        Stone(position: BoardPosition(2, 4), color: StoneColor.black),
        Stone(position: BoardPosition(3, 2), color: StoneColor.black),
        Stone(position: BoardPosition(4, 4), color: StoneColor.black),
        Stone(position: BoardPosition(5, 3), color: StoneColor.black),
      ],
      targetCaptures: [BoardPosition(4, 3)],
      solutions: [
        [BoardPosition(4, 2)],
      ],
      category: PuzzleCategory.ko,
      difficulty: PuzzleDifficulty.hard,
      hint: '从侧面切断，制造劫争',
    ),
  ];

  /// Returns the puzzle for a given date.
  /// Cycles through the list of puzzles based on the day of year.
  static Puzzle getPuzzleForDate(DateTime date) {
    final dayOfYear = _dayOfYear(date);
    final index = dayOfYear % puzzles.length;
    return puzzles[index];
  }

  /// Returns puzzles for the past N days (for the date timeline).
  static List<({DateTime date, Puzzle puzzle})> getPuzzlesForDateRange({
    required DateTime endDate,
    int count = 30,
  }) {
    final result = <({DateTime date, Puzzle puzzle})>[];
    for (int i = count - 1; i >= 0; i--) {
      final date = endDate.subtract(Duration(days: i));
      result.add((date: date, puzzle: getPuzzleForDate(date)));
    }
    return result;
  }

  static int _dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays;
  }
}
