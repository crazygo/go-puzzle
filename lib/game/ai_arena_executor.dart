import 'dart:math' as math;

import '../models/board_position.dart' show StoneColor;
import 'ai_algorithm_framework.dart';
import 'capture_ai.dart';
import 'ai_arena_ladder.dart';
import 'difficulty_level.dart';
import 'katago_model_adapter.dart';
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
    this.openingPolicy = 'empty_cross_twist_cross_random_v1',
    this.decisionTimeout = const Duration(seconds: 5),
    this.katagoModelAdapter,
  });

  final int boardSize;
  final int captureTarget;
  final int rounds;
  final int maxMoves;
  final String openingPolicy;
  final Duration decisionTimeout;
  final KatagoModelAdapter? katagoModelAdapter;

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
        decisionTimeout: decisionTimeout,
        initialBoard: _buildOpeningBoard(
          opening,
          pairSeed: pairSeed,
          variant: openingVariant,
        ),
      );

      final winnerLabel = _winnerLabelForResult(result, aIsBlack);

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
        illegalMove: result.endReason == CaptureAiMatchEndReason.invalidMove,
        timedOut: _isTimeout(result.endReason),
        maxDecisionMillis: result.maxDecisionMillis,
        failureReason: _failureReason(result.endReason),
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

  AiMatchResult runFrameworkMatch({
    required AiAlgorithmConfig configA,
    required AiAlgorithmConfig configB,
    required int matchSeed,
    required int openingSeed,
    bool alternateColors = true,
  }) {
    final legacyConfigA = _legacyBattleConfig(configA);
    final legacyConfigB = _legacyBattleConfig(configB);
    final games = <AiGameRecord>[];
    var aWins = 0;
    var bWins = 0;
    var draws = 0;

    for (var i = 0; i < rounds; i++) {
      final aIsBlack = alternateColors ? i.isEven : true;
      final gameSeed = matchSeed * 1000 + i;
      final pairSeed = matchSeed * 1000 + (i ~/ 2);
      final opening = _openingForGame(i, openingSeed);
      final openingVariant = _openingVariantForGame(i);

      final blackAgent = AiAlgorithmRegistry.createAgent(
        aIsBlack ? configA : configB,
        seedOverride: gameSeed * 2,
        katagoModelAdapter:
            katagoModelAdapter ?? const UnavailableKatagoOnnxModelAdapter(),
      );
      final blackConfig = aIsBlack ? configA : configB;
      final whiteAgent = AiAlgorithmRegistry.createAgent(
        aIsBlack ? configB : configA,
        seedOverride: gameSeed * 2 + 1,
        katagoModelAdapter:
            katagoModelAdapter ?? const UnavailableKatagoOnnxModelAdapter(),
      );
      final whiteConfig = aIsBlack ? configB : configA;

      final result = CaptureAiArena.playMatch(
        blackAgent: blackAgent,
        whiteAgent: whiteAgent,
        boardSize: boardSize,
        captureTarget: captureTarget,
        maxMoves: maxMoves,
        decisionTimeout: decisionTimeout,
        blackDecisionTimeout: _decisionTimeoutForConfig(
          blackConfig,
          defaultTimeout: decisionTimeout,
        ),
        whiteDecisionTimeout: _decisionTimeoutForConfig(
          whiteConfig,
          defaultTimeout: decisionTimeout,
        ),
        initialBoard: _buildOpeningBoard(
          opening,
          pairSeed: pairSeed,
          variant: openingVariant,
        ),
      );

      final winnerLabel = _winnerLabelForResult(result, aIsBlack);

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
        openingIndex: opening.index,
        opening: _openingName(opening, openingVariant),
        black: aIsBlack ? 'a' : 'b',
        winner: winnerLabel,
        moves: result.totalMoves,
        blackCaptures: result.blackCaptures,
        whiteCaptures: result.whiteCaptures,
        endReason: result.endReason.name,
        illegalMove: result.endReason == CaptureAiMatchEndReason.invalidMove,
        timedOut: _isTimeout(result.endReason),
        fallbackUsed:
            configA.reportsFallbackPath || configB.reportsFallbackPath,
        maxDecisionMillis: result.maxDecisionMillis,
        failureReason: _frameworkFailureReason(
          result.endReason,
          configA,
          configB,
          configAFailureMode: katagoModelAdapter == null
              ? _katagoUnavailableFailureMode(configA)
              : null,
          configBFailureMode: katagoModelAdapter == null
              ? _katagoUnavailableFailureMode(configB)
              : null,
        ),
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
      configA: legacyConfigA,
      configB: legacyConfigB,
      aWins: aWins,
      bWins: bWins,
      draws: draws,
      games: games,
    );
  }

  Future<AiMatchResult> runFrameworkMatchAsync({
    required AiAlgorithmConfig configA,
    required AiAlgorithmConfig configB,
    required int matchSeed,
    required int openingSeed,
    bool alternateColors = true,
    AsyncKatagoModelAdapter? asyncKatagoModelAdapter,
  }) async {
    final adapter = _resolveAsyncKatagoAdapter(
      [configA, configB],
      asyncKatagoModelAdapter,
    );
    await adapter.preload(_katagoRequestsFor(
      [configA, configB],
      boardSize: boardSize,
      captureTarget: captureTarget,
    ));
    final legacyConfigA = _legacyBattleConfig(configA);
    final legacyConfigB = _legacyBattleConfig(configB);
    final games = <AiGameRecord>[];
    var aWins = 0;
    var bWins = 0;
    var draws = 0;

    for (var i = 0; i < rounds; i++) {
      final aIsBlack = alternateColors ? i.isEven : true;
      final gameSeed = matchSeed * 1000 + i;
      final pairSeed = matchSeed * 1000 + (i ~/ 2);
      final opening = _openingForGame(i, openingSeed);
      final openingVariant = _openingVariantForGame(i);
      final blackConfig = aIsBlack ? configA : configB;
      final whiteConfig = aIsBlack ? configB : configA;
      final blackAgent = AiAlgorithmRegistry.createAsyncAgent(
        blackConfig,
        seedOverride: gameSeed * 2,
        katagoModelAdapter: adapter,
      );
      final whiteAgent = AiAlgorithmRegistry.createAsyncAgent(
        whiteConfig,
        seedOverride: gameSeed * 2 + 1,
        katagoModelAdapter: adapter,
      );

      final result = await _playAsyncMatch(
        blackAgent: blackAgent,
        whiteAgent: whiteAgent,
        initialBoard: _buildOpeningBoard(
          opening,
          pairSeed: pairSeed,
          variant: openingVariant,
        ),
        maxMoves: maxMoves,
        blackDecisionTimeout: _decisionTimeoutForConfig(
          blackConfig,
          defaultTimeout: decisionTimeout,
        ),
        whiteDecisionTimeout: _decisionTimeoutForConfig(
          whiteConfig,
          defaultTimeout: decisionTimeout,
        ),
      );

      final winnerLabel = _winnerLabelForResult(result, aIsBlack);
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
        openingIndex: opening.index,
        opening: _openingName(opening, openingVariant),
        black: aIsBlack ? 'a' : 'b',
        winner: winnerLabel,
        moves: result.totalMoves,
        blackCaptures: result.blackCaptures,
        whiteCaptures: result.whiteCaptures,
        endReason: result.endReason.name,
        illegalMove: result.endReason == CaptureAiMatchEndReason.invalidMove,
        timedOut: _isTimeout(result.endReason),
        fallbackUsed:
            configA.reportsFallbackPath || configB.reportsFallbackPath,
        maxDecisionMillis: result.maxDecisionMillis,
        failureReason: result.failureReason ??
            (result.endReason == CaptureAiMatchEndReason.noLegalMove
                ? null
                : _frameworkFailureReason(
                    result.endReason,
                    configA,
                    configB,
                  )),
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
      configA: legacyConfigA,
      configB: legacyConfigB,
      aWins: aWins,
      bWins: bWins,
      draws: draws,
      games: games,
    );
  }

  Future<AiArenaEvaluationSummary> runFrameworkEvaluationAsync({
    required List<AiAlgorithmConfig> configs,
    required int matchSeed,
    required int openingSeed,
    AsyncKatagoModelAdapter? asyncKatagoModelAdapter,
  }) async {
    if (configs.length < 2) {
      throw ArgumentError.value(
        configs.length,
        'configs.length',
        'At least two configs are required for pairwise evaluation.',
      );
    }
    final adapter =
        _resolveAsyncKatagoAdapter(configs, asyncKatagoModelAdapter);
    await adapter.preload(_katagoRequestsFor(
      configs,
      boardSize: boardSize,
      captureTarget: captureTarget,
    ));
    final matches = <AiMatchResult>[];
    var pairIndex = 0;
    for (var i = 0; i < configs.length - 1; i++) {
      for (var j = i + 1; j < configs.length; j++) {
        matches.add(await runFrameworkMatchAsync(
          configA: configs[i],
          configB: configs[j],
          matchSeed: matchSeed + pairIndex * 7919,
          openingSeed: openingSeed + pairIndex * 1337,
          asyncKatagoModelAdapter: adapter,
        ));
        pairIndex++;
      }
    }
    return AiArenaEvaluationSummary.fromMatches(matches);
  }

  /// Runs every selected framework config against every other selected config
  /// exactly once and returns aggregate evaluation output.
  AiArenaEvaluationSummary runFrameworkEvaluation({
    required List<AiAlgorithmConfig> configs,
    required int matchSeed,
    required int openingSeed,
  }) {
    if (configs.length < 2) {
      throw ArgumentError.value(
        configs.length,
        'configs.length',
        'At least two configs are required for pairwise evaluation.',
      );
    }

    final matches = <AiMatchResult>[];
    var pairIndex = 0;
    for (var i = 0; i < configs.length - 1; i++) {
      for (var j = i + 1; j < configs.length; j++) {
        matches.add(runFrameworkMatch(
          configA: configs[i],
          configB: configs[j],
          matchSeed: matchSeed + pairIndex * 7919,
          openingSeed: openingSeed + pairIndex * 1337,
        ));
        pairIndex++;
      }
    }
    return AiArenaEvaluationSummary.fromMatches(matches);
  }

  _AiArenaOpening _openingForGame(int gameIndex, int openingSeed) {
    if (openingPolicy == 'empty_v1') return _AiArenaOpening.empty;
    if (openingPolicy == 'cross_v1') return _AiArenaOpening.cross;
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
    } else if (opening == _AiArenaOpening.cross) {
      _applyCrossOpening(board);
    } else if (opening == _AiArenaOpening.random) {
      _applyRandomOpening(board, pairSeed);
    }
    return board;
  }

  void _applyCrossOpening(SimBoard board) {
    final center = boardSize ~/ 2;
    if (boardSize < 3) {
      board.currentPlayer = SimBoard.black;
      return;
    }
    board.cells[board.idx(center - 1, center)] = SimBoard.black;
    board.cells[board.idx(center + 1, center)] = SimBoard.black;
    board.cells[board.idx(center, center - 1)] = SimBoard.white;
    board.cells[board.idx(center, center + 1)] = SimBoard.white;
    board.currentPlayer = SimBoard.black;
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
  cross,
  twistCross,
  random,
}

const int _openingSeedSalt = 0x5eed;

AiBattleConfig _legacyBattleConfig(AiAlgorithmConfig config) {
  return AiBattleConfig(
    id: config.id,
    style: config.frameworkId.name,
    difficulty: config.strengthTier.name,
    profileVersion: 'ai_algorithm_framework_v1',
    parameters: config.toJson(),
  );
}

String? _failureReason(CaptureAiMatchEndReason endReason) {
  return switch (endReason) {
    CaptureAiMatchEndReason.captureTargetReached => null,
    CaptureAiMatchEndReason.noLegalMove => null,
    CaptureAiMatchEndReason.invalidMove => 'agent_returned_invalid_move',
    CaptureAiMatchEndReason.maxMovesReached => null,
    CaptureAiMatchEndReason.decisionTimeout => 'decision_timeout',
  };
}

String _winnerLabelForResult(CaptureAiArenaResult result, bool aIsBlack) {
  final winner = result.winner;
  if (winner == StoneColor.black) return aIsBlack ? 'a' : 'b';
  if (winner == StoneColor.white) return aIsBlack ? 'b' : 'a';
  if (result.endReason == CaptureAiMatchEndReason.noLegalMove &&
      result.blackCaptures != result.whiteCaptures) {
    final captureLeader = result.blackCaptures > result.whiteCaptures
        ? StoneColor.black
        : StoneColor.white;
    return captureLeader == StoneColor.black
        ? (aIsBlack ? 'a' : 'b')
        : (aIsBlack ? 'b' : 'a');
  }
  return 'draw';
}

Duration _decisionTimeoutForConfig(
  AiAlgorithmConfig config, {
  required Duration defaultTimeout,
}) {
  if (config.frameworkId != AiAlgorithmFrameworkId.katago &&
      config.frameworkId != AiAlgorithmFrameworkId.capture5) {
    return defaultTimeout;
  }
  return switch (config.parameters['timeBudgetMillis']) {
    final int value => Duration(milliseconds: value),
    _ => const Duration(seconds: 10),
  };
}

AsyncKatagoModelAdapter _resolveAsyncKatagoAdapter(
  List<AiAlgorithmConfig> configs,
  AsyncKatagoModelAdapter? adapter,
) {
  final requiresOnnxAdapter = configs.any(
    (config) =>
        config.frameworkId == AiAlgorithmFrameworkId.katago ||
        config.frameworkId == AiAlgorithmFrameworkId.capture5,
  );
  if (requiresOnnxAdapter && adapter == null) {
    throw StateError(
      'asyncKatagoModelAdapter is required for ONNX-backed AI configs.',
    );
  }
  return adapter ?? const UnavailableAsyncKatagoOnnxModelAdapter();
}

List<KatagoModelRequest> _katagoRequestsFor(
  List<AiAlgorithmConfig> configs, {
  required int boardSize,
  required int captureTarget,
}) {
  final requests = <KatagoModelRequest>[];
  for (final config in configs) {
    if (config.frameworkId != AiAlgorithmFrameworkId.katago &&
        config.frameworkId != AiAlgorithmFrameworkId.capture5) {
      continue;
    }
    requests.add(KatagoModelRequest(
      board: SimBoard(boardSize, captureTarget: captureTarget),
      modelAsset: _configStringParameter(config, 'modelAsset'),
      timeBudgetMillis: _configIntParameter(config, 'timeBudgetMillis'),
      policyTemperature: _configDoubleParameter(config, 'policyTemperature'),
      candidateLimit: _configIntParameter(config, 'candidateLimit'),
      policyPlane: _configIntParameter(config, 'policyPlane'),
    ));
  }
  return requests;
}

Future<CaptureAiArenaResult> _playAsyncMatch({
  required AsyncCaptureAiAgent blackAgent,
  required AsyncCaptureAiAgent whiteAgent,
  required SimBoard initialBoard,
  required Duration blackDecisionTimeout,
  required Duration whiteDecisionTimeout,
  required int maxMoves,
}) async {
  final board = SimBoard.copy(initialBoard);
  var totalMoves = 0;
  var endReason = CaptureAiMatchEndReason.maxMovesReached;
  var maxDecisionMillis = 0;
  String? failureReason;

  while (!board.isTerminal && totalMoves < maxMoves) {
    if (!_hasLegalMove(board)) {
      endReason = CaptureAiMatchEndReason.noLegalMove;
      break;
    }
    final agent =
        board.currentPlayer == SimBoard.black ? blackAgent : whiteAgent;
    final timeout = board.currentPlayer == SimBoard.black
        ? blackDecisionTimeout
        : whiteDecisionTimeout;
    final stopwatch = Stopwatch()..start();
    CaptureAiMove? move;
    try {
      move = await agent.chooseMove(board);
    } catch (error) {
      stopwatch.stop();
      maxDecisionMillis = math.max(
        maxDecisionMillis,
        stopwatch.elapsedMilliseconds,
      );
      endReason = CaptureAiMatchEndReason.noLegalMove;
      final color = board.currentPlayer == SimBoard.black ? 'black' : 'white';
      failureReason = '$color:$error';
      break;
    }
    stopwatch.stop();
    maxDecisionMillis = math.max(
      maxDecisionMillis,
      stopwatch.elapsedMilliseconds,
    );
    if (stopwatch.elapsed > timeout) {
      endReason = CaptureAiMatchEndReason.decisionTimeout;
      break;
    }
    if (move == null) {
      endReason = CaptureAiMatchEndReason.noLegalMove;
      final color = board.currentPlayer == SimBoard.black ? 'black' : 'white';
      failureReason = '$color:agent_returned_no_legal_move';
      break;
    }
    if (!board.applyMove(move.position.row, move.position.col)) {
      endReason = CaptureAiMatchEndReason.invalidMove;
      break;
    }
    totalMoves++;
  }

  if (board.isTerminal) {
    endReason = CaptureAiMatchEndReason.captureTargetReached;
  } else if (totalMoves >= maxMoves &&
      endReason == CaptureAiMatchEndReason.maxMovesReached) {
    endReason = CaptureAiMatchEndReason.maxMovesReached;
  }

  final winner = switch (board.winner) {
    SimBoard.black => StoneColor.black,
    SimBoard.white => StoneColor.white,
    _ => StoneColor.empty,
  };

  return CaptureAiArenaResult(
    winner: winner,
    totalMoves: totalMoves,
    blackCaptures: board.capturedByBlack,
    whiteCaptures: board.capturedByWhite,
    endReason: endReason,
    maxDecisionMillis: maxDecisionMillis,
    failureReason: failureReason,
  );
}

bool _hasLegalMove(SimBoard board) {
  for (final moveIndex in board.getLegalMoves()) {
    if (board
        .analyzeMove(moveIndex ~/ board.size, moveIndex % board.size)
        .isLegal) {
      return true;
    }
  }
  return false;
}

bool _isTimeout(CaptureAiMatchEndReason endReason) {
  return endReason == CaptureAiMatchEndReason.decisionTimeout;
}

String? _frameworkFailureReason(
  CaptureAiMatchEndReason endReason,
  AiAlgorithmConfig configA,
  AiAlgorithmConfig configB, {
  String? configAFailureMode,
  String? configBFailureMode,
}) {
  final fallbackReasons = [
    if ((configAFailureMode ?? configA.failureMode) != null)
      'a:${configAFailureMode ?? configA.failureMode}',
    if ((configBFailureMode ?? configB.failureMode) != null)
      'b:${configBFailureMode ?? configB.failureMode}',
  ];
  final base = _failureReason(endReason);
  if (base == null) {
    return fallbackReasons.isEmpty ? null : fallbackReasons.join(';');
  }
  return [
    base,
    ...fallbackReasons,
  ].join(';');
}

String? _katagoUnavailableFailureMode(AiAlgorithmConfig config) {
  if (config.frameworkId != AiAlgorithmFrameworkId.katago) return null;
  if (_configStringParameter(config, 'backend') != 'onnx') return null;
  return 'katago_onnx_model_unavailable';
}

String _configStringParameter(AiAlgorithmConfig config, String key) {
  return switch (config.parameters[key]) {
    final String value => value,
    _ => '',
  };
}

int _configIntParameter(AiAlgorithmConfig config, String key) {
  return switch (config.parameters[key]) {
    final int value => value,
    _ => 0,
  };
}

double _configDoubleParameter(AiAlgorithmConfig config, String key) {
  return switch (config.parameters[key]) {
    final int value => value.toDouble(),
    final double value => value,
    _ => 0,
  };
}
