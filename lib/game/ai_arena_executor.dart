import '../models/board_position.dart' show StoneColor;
import 'capture_ai.dart';
import 'ai_arena_ladder.dart';
import 'difficulty_level.dart';
import 'mcts_engine.dart';

const String _executorVersion = 'ai_arena_executor_v1';

/// Runs head-to-head matches between two [AiBattleConfig] values.
///
/// The executor:
/// - Alternates colors: configA plays black in even-indexed games and white in
///   odd-indexed games.
/// - Applies deterministic opening boards from [openingPolicy]. The default
///   policy alternates opening pairs so both configs play black and white under
///   each opening family.
/// - Returns an [AiMatchResult] with no ranking interpretation.
class AiArenaExecutor {
  const AiArenaExecutor({
    this.boardSize = 9,
    this.captureTarget = 5,
    this.rounds = 12,
    this.maxMoves = 512,
    this.openingPolicy = 'empty_twist_cross_v1',
  });

  final int boardSize;
  final int captureTarget;
  final int rounds;
  final int maxMoves;
  final String openingPolicy;

  String get executorVersion => _executorVersion;

  /// Runs [rounds] games between [configA] and [configB].
  ///
  /// [matchSeed] is used as the base seed; each game derives its own seed
  /// by combining matchSeed with the game index to give deterministic results.
  AiMatchResult runMatch({
    required AiBattleConfig configA,
    required AiBattleConfig configB,
    required int matchSeed,
    required int openingSeed,
  }) {
    final games = <AiGameRecord>[];
    var aWins = 0;
    var bWins = 0;
    var draws = 0;

    for (var i = 0; i < rounds; i++) {
      // Alternate colors: A plays black in even games, white in odd games.
      final aIsBlack = i.isEven;
      final blackConfig = aIsBlack ? configA : configB;
      final whiteConfig = aIsBlack ? configB : configA;

      final gameSeed = matchSeed * 1000 + i;
      final opening = _openingForGame(i, openingSeed);
      final openingIndex = opening.index;

      final blackAgent = _buildAgent(blackConfig);
      final whiteAgent = _buildAgent(whiteConfig);

      final result = CaptureAiArena.playMatch(
        blackAgent: blackAgent,
        whiteAgent: whiteAgent,
        boardSize: boardSize,
        captureTarget: captureTarget,
        maxMoves: maxMoves,
        initialBoard: _buildOpeningBoard(opening),
      );

      final winnerLabel = switch (result.winner) {
        final w when w == StoneColor.black => aIsBlack ? 'a' : 'b',
        final w when w == StoneColor.white => aIsBlack ? 'b' : 'a',
        _ => 'draw',
      };

      if (winnerLabel == 'a') {
        aWins++;
      } else if (winnerLabel == 'b') {
        bWins++;
      } else {
        draws++;
      }

      games.add(AiGameRecord(
        index: i,
        gameSeed: gameSeed,
        openingIndex: openingIndex,
        opening: opening.name,
        black: aIsBlack ? 'a' : 'b',
        winner: winnerLabel,
        moves: result.totalMoves,
        blackCaptures: result.blackCaptures,
        whiteCaptures: result.whiteCaptures,
        endReason: result.endReason.name,
      ));
    }

    return AiMatchResult(
      matchSeed: matchSeed,
      openingSeed: openingSeed,
      openingPolicy: openingPolicy,
      boardSize: boardSize,
      captureTarget: captureTarget,
      rounds: rounds,
      maxMoves: maxMoves,
      configA: configA,
      configB: configB,
      aWins: aWins,
      bWins: bWins,
      draws: draws,
      games: games,
    );
  }

  _AiArenaOpening _openingForGame(int gameIndex, int openingSeed) {
    if (openingPolicy == 'empty_v1') return _AiArenaOpening.empty;
    if (openingPolicy == 'twist_cross_v1' ||
        openingPolicy == 'fixed_twist_cross_v1') {
      return _AiArenaOpening.twistCross;
    }

    // Default mixed policy: each adjacent pair shares an opening, so A and B
    // both get one black game for that opening before moving to the next pair.
    final pairIndex = gameIndex ~/ 2;
    final pairOffset = openingSeed.isEven ? 0 : 1;
    final openingIndex =
        (pairIndex + pairOffset) % _AiArenaOpening.values.length;
    return _AiArenaOpening.values[openingIndex];
  }

  SimBoard _buildOpeningBoard(_AiArenaOpening opening) {
    final board = SimBoard(boardSize, captureTarget: captureTarget);
    if (opening == _AiArenaOpening.twistCross) {
      final center = boardSize ~/ 2;
      board.cells[board.idx(center - 1, center)] = SimBoard.black;
      board.cells[board.idx(center + 1, center)] = SimBoard.black;
      board.cells[board.idx(center, center - 1)] = SimBoard.white;
      board.cells[board.idx(center, center + 1)] = SimBoard.white;
      board.currentPlayer = SimBoard.black;
    }
    return board;
  }

  CaptureAiAgent _buildAgent(AiBattleConfig config) {
    final style = CaptureAiStyle.values.firstWhere(
      (s) => s.name == config.style,
      orElse: () => CaptureAiStyle.adaptive,
    );
    final difficulty = DifficultyLevel.values.firstWhere(
      (d) => d.name == config.difficulty,
      orElse: () => DifficultyLevel.beginner,
    );
    return CaptureAiRegistry.create(style: style, difficulty: difficulty);
  }
}

enum _AiArenaOpening {
  empty,
  twistCross,
}
