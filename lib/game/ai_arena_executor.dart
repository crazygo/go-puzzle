import 'dart:math' as math;

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
    this.openingPolicy = 'empty_twist_cross_random_v1',
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
      // Pair-based seed: both games in a color-swapped pair share the same
      // opening board so that the random opening does not bias the result.
      final pairSeed = matchSeed * 1000 + (i ~/ 2);
      final opening = _openingForGame(i, openingSeed);
      final openingIndex = opening.index;
      final openingVariant = _openingVariantForGame(i);

      final blackAgent = _buildAgent(blackConfig, seed: gameSeed * 2);
      final whiteAgent = _buildAgent(whiteConfig, seed: gameSeed * 2 + 1);

      final result = CaptureAiArena.playMatch(
        blackAgent: blackAgent,
        whiteAgent: whiteAgent,
        boardSize: boardSize,
        captureTarget: captureTarget,
        maxMoves: maxMoves,
        initialBoard: _buildOpeningBoard(
          opening,
          pairSeed: pairSeed,
          variant: openingVariant,
        ),
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
        opening: _openingName(opening, openingVariant),
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
    if (openingPolicy == 'random_v1') return _AiArenaOpening.random;

    // Default mixed policy: each adjacent pair shares an opening, so A and B
    // both get one black game for that opening before moving to the next pair.
    final pairIndex = gameIndex ~/ 2;
    final pairOffset = openingSeed % _AiArenaOpening.values.length;
    final openingIndex =
        (pairIndex + pairOffset) % _AiArenaOpening.values.length;
    return _AiArenaOpening.values[openingIndex];
  }

  int _openingVariantForGame(int gameIndex) {
    return (gameIndex ~/ 2) % 4;
  }

  String _openingName(_AiArenaOpening opening, int variant) {
    if (opening == _AiArenaOpening.twistCross) {
      return 'twistCross${String.fromCharCode(65 + variant % 4)}';
    }
    return opening.name;
  }

  SimBoard _buildOpeningBoard(
    _AiArenaOpening opening, {
    required int pairSeed,
    required int variant,
  }) {
    final board = SimBoard(boardSize, captureTarget: captureTarget);
    if (opening == _AiArenaOpening.twistCross) {
      const arm = 3;
      if (boardSize < arm * 2 + 1) {
        // Board too small for the fixed arm length. The executor falls back to
        // an empty opening rather than throwing so that arena ladder runs stay
        // robust even when an unsupported board size is configured.  The
        // capture_ai_strength_probe tool validates board size up front and throws
        // an ArgumentError instead, which is the right behaviour for a
        // user-facing CLI that can report the problem clearly before running.
        board.currentPlayer = SimBoard.black;
        return board;
      }
      final center = boardSize ~/ 2;
      final points = switch (variant % 4) {
        0 => (
            black: [(center - arm, center), (center + arm, center)],
            white: [(center, center - arm), (center, center + arm)],
          ),
        1 => (
            black: [(center, center - arm), (center, center + arm)],
            white: [(center - arm, center), (center + arm, center)],
          ),
        2 => (
            black: [(center - arm, center - arm), (center + arm, center + arm)],
            white: [(center - arm, center + arm), (center + arm, center - arm)],
          ),
        _ => (
            black: [(center - arm, center + arm), (center + arm, center - arm)],
            white: [(center - arm, center - arm), (center + arm, center + arm)],
          ),
      };
      for (final (row, col) in points.black) {
        board.cells[board.idx(row, col)] = SimBoard.black;
      }
      for (final (row, col) in points.white) {
        board.cells[board.idx(row, col)] = SimBoard.white;
      }
      board.currentPlayer = SimBoard.black;
    } else if (opening == _AiArenaOpening.random) {
      _applyRandomOpening(board, pairSeed);
    }
    return board;
  }

  void _applyRandomOpening(SimBoard board, int pairSeed) {
    final rng = math.Random(pairSeed ^ (_openingSeedSalt * boardSize));
    final center = boardSize ~/ 2;
    final radius = math.max(2, boardSize ~/ 3);
    final pairCount = boardSize <= 9 ? 2 : (boardSize <= 13 ? 3 : 4);
    var placedPairs = 0;
    var attempts = 0;

    while (placedPairs < pairCount && attempts < boardSize * boardSize * 4) {
      attempts++;
      final row = (center - radius) + rng.nextInt(radius * 2 + 1);
      final col = (center - radius) + rng.nextInt(radius * 2 + 1);
      if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) {
        continue;
      }
      final mirrorRow = boardSize - 1 - row;
      final mirrorCol = boardSize - 1 - col;
      if (row == mirrorRow && col == mirrorCol) continue;

      final blackIndex = board.idx(row, col);
      final whiteIndex = board.idx(mirrorRow, mirrorCol);
      if (board.cells[blackIndex] != SimBoard.empty ||
          board.cells[whiteIndex] != SimBoard.empty) {
        continue;
      }

      board.cells[blackIndex] = SimBoard.black;
      board.cells[whiteIndex] = SimBoard.white;
      placedPairs++;
    }
    board.currentPlayer = SimBoard.black;
  }

  CaptureAiAgent _buildAgent(AiBattleConfig config, {required int seed}) {
    final style = CaptureAiStyle.values.firstWhere(
      (s) => s.name == config.style,
      orElse: () => CaptureAiStyle.adaptive,
    );
    final difficulty = DifficultyLevel.values.firstWhere(
      (d) => d.name == config.difficulty,
      orElse: () => DifficultyLevel.beginner,
    );
    return CaptureAiRegistry.create(
      style: style,
      difficulty: difficulty,
      seed: seed,
    );
  }
}

enum _AiArenaOpening {
  empty,
  twistCross,
  random,
}

const int _openingSeedSalt = 0x5eed;
