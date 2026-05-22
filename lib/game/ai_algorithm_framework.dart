import 'dart:math' as math;

import '../models/board_position.dart';
import 'capture_ai.dart';
import 'difficulty_level.dart';
import 'katago_model_adapter.dart';
import 'mcts_engine.dart';

enum AiAlgorithmFrameworkId {
  heuristic,
  mcts,
  hybridTactical,
  katago,
}

enum AiAlgorithmStrengthTier {
  weak,
  standard,
  strong,
}

enum AiAlgorithmRuntimeMode {
  native,
  fallback,
}

enum TacticalSignal {
  neutral,
  ladderRisk,
  twistClampRisk,
  lossCuttingRisk,
}

class TacticalAnalysis {
  const TacticalAnalysis({
    required this.signal,
    required this.confidence,
    this.recommendedMove,
    this.reason,
  });

  const TacticalAnalysis.neutral()
      : signal = TacticalSignal.neutral,
        confidence = 0,
        recommendedMove = null,
        reason = null;

  final TacticalSignal signal;
  final double confidence;
  final BoardPosition? recommendedMove;
  final String? reason;

  bool get canForceMove =>
      signal != TacticalSignal.neutral &&
      confidence >= 0.95 &&
      recommendedMove != null;
}

abstract class TacticalAnalyzer {
  TacticalAnalysis analyze({
    required SimBoard board,
    required AiAlgorithmConfig config,
  });
}

class NeutralTacticalAnalyzer implements TacticalAnalyzer {
  const NeutralTacticalAnalyzer();

  @override
  TacticalAnalysis analyze({
    required SimBoard board,
    required AiAlgorithmConfig config,
  }) {
    return const TacticalAnalysis.neutral();
  }
}

class AiAlgorithmFramework {
  const AiAlgorithmFramework({
    required this.id,
    required this.displayName,
    required this.summary,
  });

  final AiAlgorithmFrameworkId id;
  final String displayName;
  final String summary;

  String get storageKey => id.name;
}

class AiAlgorithmConfig {
  const AiAlgorithmConfig({
    required this.id,
    required this.frameworkId,
    required this.displayName,
    required this.strengthTier,
    required this.runtimeMode,
    required this.parameters,
    required CaptureAiRobotConfig robotConfig,
    this.failureMode,
  }) : _robotConfig = robotConfig;

  final String id;
  final AiAlgorithmFrameworkId frameworkId;
  final String displayName;
  final AiAlgorithmStrengthTier strengthTier;
  final AiAlgorithmRuntimeMode runtimeMode;
  final Map<String, Object> parameters;
  final String? failureMode;
  final CaptureAiRobotConfig _robotConfig;

  CaptureAiRobotConfig get robotConfig => _robotConfig;

  bool get usesFallback => runtimeMode == AiAlgorithmRuntimeMode.fallback;

  bool get reportsFallbackPath =>
      usesFallback || (failureMode?.contains('uses_legal') ?? false);

  Map<String, Object?> toJson() => {
        'id': id,
        'frameworkId': frameworkId.name,
        'displayName': displayName,
        'strengthTier': strengthTier.name,
        'runtimeMode': runtimeMode.name,
        'parameters': parameters,
        if (failureMode != null) 'failureMode': failureMode,
        'robotConfig': {
          'style': robotConfig.style.name,
          'difficulty': robotConfig.difficulty.name,
          'engine': robotConfig.engine.name,
          'heuristicPlayouts': robotConfig.heuristicPlayouts,
          'mctsPlayouts': robotConfig.mctsPlayouts,
          'mctsRolloutDepth': robotConfig.mctsRolloutDepth,
          'mctsCandidateLimit': robotConfig.mctsCandidateLimit,
          'mctsExploration': robotConfig.mctsExploration,
          'rolloutTemperature': robotConfig.rolloutTemperature,
          'seed': robotConfig.seed,
        },
      };
}

class AiAlgorithmRegistry {
  const AiAlgorithmRegistry._();

  static const frameworks = [
    AiAlgorithmFramework(
      id: AiAlgorithmFrameworkId.heuristic,
      displayName: 'Heuristic',
      summary: 'Weighted tactical heuristics with lightweight playout scoring.',
    ),
    AiAlgorithmFramework(
      id: AiAlgorithmFrameworkId.mcts,
      displayName: 'MCTS',
      summary: 'Pure Monte Carlo tree search with bounded rollout budgets.',
    ),
    AiAlgorithmFramework(
      id: AiAlgorithmFrameworkId.hybridTactical,
      displayName: 'Hybrid Tactical',
      summary: 'Heuristic safety checks combined with MCTS tactical search.',
    ),
    AiAlgorithmFramework(
      id: AiAlgorithmFrameworkId.katago,
      displayName: 'KataGo',
      summary:
          'KataGo framework with ONNX adapter and explicit unavailable status.',
    ),
  ];

  static List<AiAlgorithmConfig> get configs => [
        _heuristicWeak,
        _heuristicStandard,
        _mctsWeak,
        _mctsStandard,
        _hybridWeak,
        _hybridStandard,
        _katagoOnnxWeak,
        _katagoOnnxStandard,
      ];

  static List<AiAlgorithmConfig> configsFor(
      AiAlgorithmFrameworkId frameworkId) {
    return configs
        .where((config) => config.frameworkId == frameworkId)
        .toList(growable: false);
  }

  static AiAlgorithmConfig configById(String id) {
    return configs.firstWhere((config) => config.id == id);
  }

  static CaptureAiAgent createAgent(
    AiAlgorithmConfig config, {
    int? seedOverride,
    TacticalAnalyzer tacticalAnalyzer = const NeutralTacticalAnalyzer(),
    KatagoModelAdapter katagoModelAdapter =
        const UnavailableKatagoOnnxModelAdapter(),
  }) {
    final robotConfig = seedOverride == null
        ? config.robotConfig
        : config.robotConfig.copyWith(seed: seedOverride);
    CaptureAiAgent agent;
    if (_katagoBackend(config) == 'onnx') {
      agent = _KatagoOnnxAgent(
        config: config,
        style: robotConfig.style,
        modelAdapter: katagoModelAdapter,
      );
    } else {
      agent = CaptureAiRegistry.createFromConfig(robotConfig);
    }
    if (_randomLegalMoveRate(config) > 0) {
      agent = _RandomizedLegalAgent(
        inner: agent,
        randomLegalMoveRate: _randomLegalMoveRate(config),
        seed: seedOverride ?? config.robotConfig.seed,
      );
    }
    if (_katagoBackend(config) != 'onnx' &&
        _intParameter(config, 'captureSearchDepth') > 0) {
      agent = _ConfigCaptureSearchAgent(
        config: config,
        inner: agent,
      );
    }
    return _TacticalAnalyzerAgent(
      config: config,
      inner: agent,
      tacticalAnalyzer: tacticalAnalyzer,
    );
  }

  static AsyncCaptureAiAgent createAsyncAgent(
    AiAlgorithmConfig config, {
    int? seedOverride,
    TacticalAnalyzer tacticalAnalyzer = const NeutralTacticalAnalyzer(),
    required AsyncKatagoModelAdapter katagoModelAdapter,
  }) {
    final robotConfig = seedOverride == null
        ? config.robotConfig
        : config.robotConfig.copyWith(seed: seedOverride);
    if (_katagoBackend(config) == 'onnx') {
      return _AsyncTacticalAnalyzerAgent(
        config: config,
        inner: _AsyncKatagoOnnxAgent(
          config: config,
          style: robotConfig.style,
          modelAdapter: katagoModelAdapter,
        ),
        tacticalAnalyzer: tacticalAnalyzer,
      );
    }
    CaptureAiAgent agent = CaptureAiRegistry.createFromConfig(robotConfig);
    if (_randomLegalMoveRate(config) > 0) {
      agent = _RandomizedLegalAgent(
        inner: agent,
        randomLegalMoveRate: _randomLegalMoveRate(config),
        seed: seedOverride ?? config.robotConfig.seed,
      );
    }
    if (_katagoBackend(config) != 'onnx' &&
        _intParameter(config, 'captureSearchDepth') > 0) {
      agent = _ConfigCaptureSearchAgent(
        config: config,
        inner: agent,
      );
    }
    return _AsyncTacticalAnalyzerAgent(
      config: config,
      inner: _SyncAsyncCaptureAiAgent(agent),
      tacticalAnalyzer: tacticalAnalyzer,
    );
  }

  static final AiAlgorithmConfig _heuristicWeak = AiAlgorithmConfig(
    id: 'heuristic_adaptive_weak_v1',
    frameworkId: AiAlgorithmFrameworkId.heuristic,
    displayName: 'Heuristic Weak',
    strengthTier: AiAlgorithmStrengthTier.weak,
    runtimeMode: AiAlgorithmRuntimeMode.native,
    parameters: const {
      'style': 'adaptive',
      'difficulty': 'beginner',
      'heuristicPlayouts': 12,
      'mctsPlayouts': 0,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.adaptive,
      difficulty: DifficultyLevel.beginner,
    ),
  );

  static final AiAlgorithmConfig _heuristicStandard = AiAlgorithmConfig(
    id: 'heuristic_counter_standard_v1',
    frameworkId: AiAlgorithmFrameworkId.heuristic,
    displayName: 'Heuristic Standard',
    strengthTier: AiAlgorithmStrengthTier.standard,
    runtimeMode: AiAlgorithmRuntimeMode.native,
    parameters: const {
      'style': 'counter',
      'difficulty': 'beginner',
      'heuristicPlayouts': 20,
      'mctsPlayouts': 0,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.beginner,
    ).copyWith(heuristicPlayouts: 20),
  );

  static final AiAlgorithmConfig _mctsWeak = AiAlgorithmConfig(
    id: 'mcts_counter_weak_v1',
    frameworkId: AiAlgorithmFrameworkId.mcts,
    displayName: 'MCTS Weak',
    strengthTier: AiAlgorithmStrengthTier.weak,
    runtimeMode: AiAlgorithmRuntimeMode.native,
    parameters: const {
      'style': 'adaptive',
      'difficulty': 'beginner',
      'mctsPlayouts': 1,
      'mctsRolloutDepth': 2,
      'mctsCandidateLimit': 3,
      'rolloutTemperature': 30.0,
      'randomLegalMoveRate': 0.25,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.adaptive,
      difficulty: DifficultyLevel.beginner,
    ).copyWith(
      engine: CaptureAiEngine.mcts,
      mctsPlayouts: 1,
      mctsRolloutDepth: 2,
      mctsCandidateLimit: 3,
      rolloutTemperature: 30.0,
    ),
  );

  static final AiAlgorithmConfig _mctsStandard = AiAlgorithmConfig(
    id: 'mcts_counter_standard_v1',
    frameworkId: AiAlgorithmFrameworkId.mcts,
    displayName: 'MCTS Standard',
    strengthTier: AiAlgorithmStrengthTier.standard,
    runtimeMode: AiAlgorithmRuntimeMode.native,
    parameters: const {
      'style': 'counter',
      'difficulty': 'intermediate',
      'mctsPlayouts': 12,
      'mctsRolloutDepth': 6,
      'mctsCandidateLimit': 7,
      'rolloutTemperature': 1.25,
      'captureSearchDepth': 2,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.intermediate,
    ).copyWith(
      engine: CaptureAiEngine.mcts,
      mctsPlayouts: 12,
      mctsRolloutDepth: 6,
      mctsCandidateLimit: 7,
      rolloutTemperature: 1.25,
    ),
  );

  static final AiAlgorithmConfig _hybridWeak = AiAlgorithmConfig(
    id: 'hybrid_tactical_counter_weak_v1',
    frameworkId: AiAlgorithmFrameworkId.hybridTactical,
    displayName: 'Hybrid Tactical Weak',
    strengthTier: AiAlgorithmStrengthTier.weak,
    runtimeMode: AiAlgorithmRuntimeMode.native,
    parameters: const {
      'style': 'counter',
      'difficulty': 'intermediate',
      'heuristicPlayouts': 12,
      'mctsPlayouts': 4,
      'mctsRolloutDepth': 4,
      'mctsCandidateLimit': 4,
      'rolloutTemperature': 8.0,
      'randomLegalMoveRate': 0.20,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.intermediate,
    ).copyWith(
      heuristicPlayouts: 12,
      mctsPlayouts: 4,
      mctsRolloutDepth: 4,
      mctsCandidateLimit: 4,
      rolloutTemperature: 8.0,
    ),
  );

  static final AiAlgorithmConfig _hybridStandard = AiAlgorithmConfig(
    id: 'hybrid_tactical_counter_standard_v1',
    frameworkId: AiAlgorithmFrameworkId.hybridTactical,
    displayName: 'Hybrid Tactical Standard',
    strengthTier: AiAlgorithmStrengthTier.standard,
    runtimeMode: AiAlgorithmRuntimeMode.native,
    parameters: const {
      'style': 'counter',
      'difficulty': 'intermediate',
      'heuristicPlayouts': 24,
      'mctsPlayouts': 8,
      'mctsRolloutDepth': 6,
      'mctsCandidateLimit': 6,
      'rolloutTemperature': 3.0,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.intermediate,
    ).copyWith(
      heuristicPlayouts: 24,
      mctsPlayouts: 8,
      mctsRolloutDepth: 6,
      mctsCandidateLimit: 6,
      rolloutTemperature: 3.0,
    ),
  );

  static final AiAlgorithmConfig _katagoOnnxWeak = AiAlgorithmConfig(
    id: 'katago_onnx_weak_v1',
    frameworkId: AiAlgorithmFrameworkId.katago,
    displayName: 'KataGo ONNX Weak',
    strengthTier: AiAlgorithmStrengthTier.weak,
    runtimeMode: AiAlgorithmRuntimeMode.native,
    parameters: const {
      'backend': 'onnx',
      'modelAsset': 'assets/models/katago_capture_weak.onnx',
      'visits': 4,
      'timeBudgetMillis': 10000,
      'policyTemperature': 1.35,
      'candidateLimit': 12,
      'captureSearchDepth': 1,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.adaptive,
      difficulty: DifficultyLevel.beginner,
    ),
  );

  static final AiAlgorithmConfig _katagoOnnxStandard = AiAlgorithmConfig(
    id: 'katago_onnx_standard_v1',
    frameworkId: AiAlgorithmFrameworkId.katago,
    displayName: 'KataGo ONNX Standard',
    strengthTier: AiAlgorithmStrengthTier.standard,
    runtimeMode: AiAlgorithmRuntimeMode.native,
    parameters: const {
      'backend': 'onnx',
      'modelAsset': 'assets/models/katago_capture_standard.onnx',
      'visits': 32,
      'timeBudgetMillis': 10000,
      'policyTemperature': 0.0,
      'candidateLimit': 1,
      'captureSearchDepth': 2,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.intermediate,
    ),
  );
}

abstract class AsyncCaptureAiAgent {
  CaptureAiStyle get style;

  Future<CaptureAiMove?> chooseMove(SimBoard board);
}

String _katagoBackend(AiAlgorithmConfig config) {
  return switch (config.parameters['backend']) {
    final String value => value,
    _ => '',
  };
}

class _TacticalAnalyzerAgent implements CaptureAiAgent {
  const _TacticalAnalyzerAgent({
    required this.config,
    required CaptureAiAgent inner,
    required TacticalAnalyzer tacticalAnalyzer,
  })  : _inner = inner,
        _tacticalAnalyzer = tacticalAnalyzer;

  final AiAlgorithmConfig config;
  final CaptureAiAgent _inner;
  final TacticalAnalyzer _tacticalAnalyzer;

  @override
  CaptureAiStyle get style => _inner.style;

  @override
  CaptureAiMove? chooseMove(SimBoard board) {
    final analysis = _tacticalAnalyzer.analyze(
      board: SimBoard.copy(board),
      config: config,
    );
    if (analysis.canForceMove) {
      final move = analysis.recommendedMove!;
      if (board.analyzeMove(move.row, move.col).isLegal) {
        return CaptureAiMove(position: move, score: 100000);
      }
    }
    return _inner.chooseMove(board);
  }
}

class _AsyncTacticalAnalyzerAgent implements AsyncCaptureAiAgent {
  const _AsyncTacticalAnalyzerAgent({
    required this.config,
    required AsyncCaptureAiAgent inner,
    required TacticalAnalyzer tacticalAnalyzer,
  })  : _inner = inner,
        _tacticalAnalyzer = tacticalAnalyzer;

  final AiAlgorithmConfig config;
  final AsyncCaptureAiAgent _inner;
  final TacticalAnalyzer _tacticalAnalyzer;

  @override
  CaptureAiStyle get style => _inner.style;

  @override
  Future<CaptureAiMove?> chooseMove(SimBoard board) async {
    final analysis = _tacticalAnalyzer.analyze(
      board: SimBoard.copy(board),
      config: config,
    );
    if (analysis.canForceMove) {
      final move = analysis.recommendedMove!;
      if (board.analyzeMove(move.row, move.col).isLegal) {
        return CaptureAiMove(position: move, score: 100000);
      }
    }
    return _inner.chooseMove(board);
  }
}

class _ConfigCaptureSearchAgent implements CaptureAiAgent {
  const _ConfigCaptureSearchAgent({
    required this.config,
    required CaptureAiAgent inner,
  }) : _inner = inner;

  final AiAlgorithmConfig config;
  final CaptureAiAgent _inner;

  @override
  CaptureAiStyle get style => _inner.style;

  @override
  CaptureAiMove? chooseMove(SimBoard board) {
    final baseMove = _inner.chooseMove(board);
    if (baseMove == null) return null;
    final position = baseMove.position;
    if (!board.analyzeMove(position.row, position.col).isLegal) {
      return baseMove;
    }
    final searchedMove = _captureSearchMove(
      board,
      depth: _intParameter(config, 'captureSearchDepth'),
      baseMove: position,
    );
    if (searchedMove == null) return baseMove;
    return CaptureAiMove(
      position: searchedMove,
      score: baseMove.score + 1000,
    );
  }
}

class _SyncAsyncCaptureAiAgent implements AsyncCaptureAiAgent {
  const _SyncAsyncCaptureAiAgent(this._inner);

  final CaptureAiAgent _inner;

  @override
  CaptureAiStyle get style => _inner.style;

  @override
  Future<CaptureAiMove?> chooseMove(SimBoard board) async {
    return _inner.chooseMove(board);
  }
}

double _randomLegalMoveRate(AiAlgorithmConfig config) {
  return switch (config.parameters['randomLegalMoveRate']) {
    final int value => value.toDouble(),
    final double value => value,
    _ => 0,
  };
}

class _RandomizedLegalAgent implements CaptureAiAgent {
  const _RandomizedLegalAgent({
    required CaptureAiAgent inner,
    required this.randomLegalMoveRate,
    required this.seed,
  }) : _inner = inner;

  final CaptureAiAgent _inner;
  final double randomLegalMoveRate;
  final int seed;

  @override
  CaptureAiStyle get style => _inner.style;

  @override
  CaptureAiMove? chooseMove(SimBoard board) {
    final legalMoves = board.getLegalMoves().where((moveIndex) {
      return board
          .analyzeMove(
            moveIndex ~/ board.size,
            moveIndex % board.size,
          )
          .isLegal;
    }).toList(growable: false);
    if (legalMoves.isEmpty) return null;
    final rng = math.Random(seed ^ _boardFingerprint(board));
    if (rng.nextDouble() < randomLegalMoveRate.clamp(0, 1)) {
      final moveIndex = legalMoves[rng.nextInt(legalMoves.length)];
      return CaptureAiMove(
        position:
            BoardPosition(moveIndex ~/ board.size, moveIndex % board.size),
        score: 0,
      );
    }
    return _inner.chooseMove(board);
  }
}

class _KatagoOnnxAgent implements CaptureAiAgent {
  const _KatagoOnnxAgent({
    required this.config,
    required CaptureAiStyle style,
    required KatagoModelAdapter modelAdapter,
  })  : _style = style,
        _modelAdapter = modelAdapter;

  final AiAlgorithmConfig config;
  final CaptureAiStyle _style;
  final KatagoModelAdapter _modelAdapter;

  @override
  CaptureAiStyle get style => _style;

  @override
  CaptureAiMove? chooseMove(SimBoard board) {
    final evaluation = _modelAdapter.chooseMove(
      KatagoModelRequest(
        board: SimBoard.copy(board),
        modelAsset: _stringParameter(config, 'modelAsset'),
        visits: _intParameter(config, 'visits'),
        timeBudgetMillis: _intParameter(config, 'timeBudgetMillis'),
        policyTemperature: _doubleParameter(config, 'policyTemperature'),
        candidateLimit: _intParameter(config, 'candidateLimit'),
      ),
    );
    final move = evaluation.move;
    if (move != null && board.analyzeMove(move.row, move.col).isLegal) {
      final tacticalMove = _captureSearchMove(
        board,
        depth: _intParameter(config, 'captureSearchDepth'),
        baseMove: move,
      );
      return CaptureAiMove(position: tacticalMove ?? move, score: 100000);
    }
    return null;
  }
}

class _AsyncKatagoOnnxAgent implements AsyncCaptureAiAgent {
  const _AsyncKatagoOnnxAgent({
    required this.config,
    required CaptureAiStyle style,
    required AsyncKatagoModelAdapter modelAdapter,
  })  : _style = style,
        _modelAdapter = modelAdapter;

  final AiAlgorithmConfig config;
  final CaptureAiStyle _style;
  final AsyncKatagoModelAdapter _modelAdapter;

  @override
  CaptureAiStyle get style => _style;

  @override
  Future<CaptureAiMove?> chooseMove(SimBoard board) async {
    final evaluation = await _modelAdapter.chooseMove(
      KatagoModelRequest(
        board: SimBoard.copy(board),
        modelAsset: _stringParameter(config, 'modelAsset'),
        visits: _intParameter(config, 'visits'),
        timeBudgetMillis: _intParameter(config, 'timeBudgetMillis'),
        policyTemperature: _doubleParameter(config, 'policyTemperature'),
        candidateLimit: _intParameter(config, 'candidateLimit'),
      ),
    );
    final move = evaluation.move;
    if (move != null && board.analyzeMove(move.row, move.col).isLegal) {
      final tacticalMove = _captureSearchMove(
        board,
        depth: _intParameter(config, 'captureSearchDepth'),
        baseMove: move,
      );
      return CaptureAiMove(position: tacticalMove ?? move, score: 100000);
    }
    throw KatagoModelException(
      evaluation.failureReason ?? 'katago_onnx_returned_no_legal_move',
    );
  }
}

BoardPosition? _captureSearchMove(
  SimBoard board, {
  required int depth,
  required BoardPosition baseMove,
}) {
  if (depth <= 0) return null;
  final baseIndex = baseMove.row * board.size + baseMove.col;
  final baseScore = _captureSearchScore(board, baseIndex, depth: depth);
  var bestMove = baseIndex;
  var bestScore = baseScore;
  for (final moveIndex in board.getLegalMoves()) {
    final analysis = board.analyzeMove(
      moveIndex ~/ board.size,
      moveIndex % board.size,
    );
    if (!analysis.isLegal) continue;
    final ownCaptureDelta = board.currentPlayer == SimBoard.black
        ? analysis.blackCaptureDelta
        : analysis.whiteCaptureDelta;
    final capturesNeeded = board.currentPlayer == SimBoard.black
        ? board.captureTarget - board.capturedByBlack
        : board.captureTarget - board.capturedByWhite;
    if (ownCaptureDelta >= capturesNeeded) {
      return BoardPosition(moveIndex ~/ board.size, moveIndex % board.size);
    }
    final score = _captureSearchScore(board, moveIndex, depth: depth);
    if (score > bestScore) {
      bestScore = score;
      bestMove = moveIndex;
    }
  }
  if (bestMove == baseIndex) return null;
  return BoardPosition(bestMove ~/ board.size, bestMove % board.size);
}

double _captureSearchScore(
  SimBoard board,
  int moveIndex, {
  required int depth,
}) {
  final analysis = board.analyzeMove(
    moveIndex ~/ board.size,
    moveIndex % board.size,
  );
  if (!analysis.isLegal) return double.negativeInfinity;
  final ownCaptureDelta = board.currentPlayer == SimBoard.black
      ? analysis.blackCaptureDelta
      : analysis.whiteCaptureDelta;
  var score = ownCaptureDelta * 1200.0 +
      analysis.opponentAtariStones * 80.0 +
      analysis.ownRescuedStones * 35.0 +
      scoreCriticalOwnGroupDefense(board, moveIndex, analysis) -
      scoreDoomedAtariExtensionPenalty(board, moveIndex, analysis) -
      scoreImmediateOpponentCapturePenalty(board, moveIndex, analysis) +
      analysis.adjacentOpponentStones * 12.0 +
      analysis.libertiesAfterMove * 4.0 +
      analysis.centerProximityScore.toDouble();
  if (depth < 2) return score;

  final probe = SimBoard.copy(board);
  if (!probe.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return double.negativeInfinity;
  }
  if (probe.isTerminal) return score + 100000;

  var opponentBestCapture = 0;
  var opponentBestAtari = 0;
  final opponentCapturesNeeded = probe.currentPlayer == SimBoard.black
      ? probe.captureTarget - probe.capturedByBlack
      : probe.captureTarget - probe.capturedByWhite;
  for (final replyIndex in probe.getLegalMoves()) {
    final reply = probe.analyzeMove(
      replyIndex ~/ probe.size,
      replyIndex % probe.size,
    );
    if (!reply.isLegal) continue;
    final replyCaptureDelta = probe.currentPlayer == SimBoard.black
        ? reply.blackCaptureDelta
        : reply.whiteCaptureDelta;
    if (replyCaptureDelta >= opponentCapturesNeeded) {
      return score - 100000;
    }
    opponentBestCapture = math.max(opponentBestCapture, replyCaptureDelta);
    opponentBestAtari = math.max(opponentBestAtari, reply.opponentAtariStones);
  }
  score -= opponentBestCapture * 950.0;
  score -= opponentBestAtari * 45.0;
  return score;
}

String _stringParameter(AiAlgorithmConfig config, String key) {
  return switch (config.parameters[key]) {
    final String value => value,
    _ => '',
  };
}

int _intParameter(AiAlgorithmConfig config, String key) {
  return switch (config.parameters[key]) {
    final int value => value,
    _ => 0,
  };
}

double _doubleParameter(AiAlgorithmConfig config, String key) {
  return switch (config.parameters[key]) {
    final int value => value.toDouble(),
    final double value => value,
    _ => 0,
  };
}

int _boardFingerprint(SimBoard board) {
  var hash = board.currentPlayer * 31 + board.capturedByBlack * 17;
  hash = hash * 31 + board.capturedByWhite * 19;
  for (var i = 0; i < board.cells.length; i++) {
    hash = 0x1fffffff & (hash * 33 + board.cells[i] * (i + 1));
  }
  return hash;
}
