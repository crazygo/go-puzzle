import '../models/board_position.dart' show StoneColor;
import 'capture_ai.dart';
import 'ai_arena_ladder.dart';
import 'difficulty_level.dart';

const String _executorVersion = 'ai_arena_executor_v1';

/// Runs 10-game head-to-head matches between two [AiBattleConfig] values.
///
/// The executor:
/// - Alternates colors: configA plays black in even-indexed games (0,2,4,6,8)
///   and white in odd-indexed games (1,3,5,7,9).
/// - Derives per-game [gameSeed] and [openingIndex] values from [matchSeed] /
///   [openingSeed] and records them in each [AiGameRecord] for auditability,
///   but the current [CaptureAiArena.playMatch] API does not consume seeds, so
///   game play is NOT deterministic from these values today.
/// - Returns an [AiMatchResult] with no ranking interpretation.
class AiArenaExecutor {
  const AiArenaExecutor({
    this.boardSize = 9,
    this.captureTarget = 5,
    this.rounds = 10,
    this.maxMoves = 512,
    this.openingPolicy = 'fixed_twist_cross_v1',
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
      final openingIndex = (openingSeed + i) % 9;

      final blackAgent = _buildAgent(blackConfig);
      final whiteAgent = _buildAgent(whiteConfig);

      final result = CaptureAiArena.playMatch(
        blackAgent: blackAgent,
        whiteAgent: whiteAgent,
        boardSize: boardSize,
        captureTarget: captureTarget,
        maxMoves: maxMoves,
      );

      final winnerLabel = switch (result.winner) {
        final w when w == StoneColor.black =>
          aIsBlack ? 'a' : 'b',
        final w when w == StoneColor.white =>
          aIsBlack ? 'b' : 'a',
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
