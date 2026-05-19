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
    return _TacticalAnalyzerAgent(
      config: config,
      inner: agent,
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
      'mctsPlayouts': 4,
      'mctsRolloutDepth': 4,
      'mctsCandidateLimit': 5,
      'rolloutTemperature': 2.0,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.intermediate,
    ).copyWith(
      engine: CaptureAiEngine.mcts,
      mctsPlayouts: 4,
      mctsRolloutDepth: 4,
      mctsCandidateLimit: 5,
      rolloutTemperature: 2.0,
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
      'mctsPlayouts': 24,
      'mctsRolloutDepth': 14,
      'randomLegalMoveRate': 0.20,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.intermediate,
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
    failureMode: 'katago_onnx_model_unavailable',
    parameters: const {
      'backend': 'onnx',
      'modelAsset': 'assets/models/katago_capture_weak.onnx',
      'visits': 4,
      'timeBudgetMillis': 1000,
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
    failureMode: 'katago_onnx_model_unavailable',
    parameters: const {
      'backend': 'onnx',
      'modelAsset': 'assets/models/katago_capture_standard.onnx',
      'visits': 32,
      'timeBudgetMillis': 1000,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.intermediate,
    ),
  );
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
      ),
    );
    final move = evaluation.move;
    if (move != null && board.analyzeMove(move.row, move.col).isLegal) {
      return CaptureAiMove(position: move, score: 100000);
    }
    return null;
  }
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

int _boardFingerprint(SimBoard board) {
  var hash = board.currentPlayer * 31 + board.capturedByBlack * 17;
  hash = hash * 31 + board.capturedByWhite * 19;
  for (var i = 0; i < board.cells.length; i++) {
    hash = 0x1fffffff & (hash * 33 + board.cells[i] * (i + 1));
  }
  return hash;
}
