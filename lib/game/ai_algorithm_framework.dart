import 'capture_ai.dart';
import 'difficulty_level.dart';

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
      summary: 'KataGo-style framework slot with legal fallback behavior.',
    ),
  ];

  static List<AiAlgorithmConfig> get configs => [
        _heuristicWeak,
        _heuristicStandard,
        _mctsWeak,
        _mctsStandard,
        _hybridWeak,
        _hybridStandard,
        _katagoFallbackWeak,
        _katagoFallbackStandard,
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
  }) {
    final robotConfig = seedOverride == null
        ? config.robotConfig
        : config.robotConfig.copyWith(seed: seedOverride);
    return CaptureAiRegistry.createFromConfig(robotConfig);
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
      'style': 'counter',
      'difficulty': 'intermediate',
      'mctsPlayouts': 16,
      'mctsRolloutDepth': 10,
      'mctsCandidateLimit': 8,
      'rolloutTemperature': 10.0,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.intermediate,
    ).copyWith(
      engine: CaptureAiEngine.mcts,
      mctsPlayouts: 16,
      mctsRolloutDepth: 10,
      mctsCandidateLimit: 8,
      rolloutTemperature: 10.0,
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
      'difficulty': 'advanced',
      'mctsPlayouts': 64,
      'mctsRolloutDepth': 18,
      'mctsCandidateLimit': 12,
      'rolloutTemperature': 6.0,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.advanced,
    ).copyWith(
      engine: CaptureAiEngine.mcts,
      mctsPlayouts: 64,
      mctsRolloutDepth: 18,
      mctsCandidateLimit: 12,
      rolloutTemperature: 6.0,
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
      'difficulty': 'advanced',
      'heuristicPlayouts': 40,
      'mctsPlayouts': 72,
      'mctsRolloutDepth': 20,
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.advanced,
    ),
  );

  static final AiAlgorithmConfig _katagoFallbackWeak = AiAlgorithmConfig(
    id: 'katago_fallback_weak_v1',
    frameworkId: AiAlgorithmFrameworkId.katago,
    displayName: 'KataGo Fallback Weak',
    strengthTier: AiAlgorithmStrengthTier.weak,
    runtimeMode: AiAlgorithmRuntimeMode.fallback,
    failureMode: 'native_backend_unavailable_uses_legal_heuristic_fallback',
    parameters: const {
      'backend': 'fallback',
      'model': 'katago_capture_placeholder_small',
      'fallbackStyle': 'adaptive',
      'fallbackDifficulty': 'beginner',
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.adaptive,
      difficulty: DifficultyLevel.beginner,
    ),
  );

  static final AiAlgorithmConfig _katagoFallbackStandard = AiAlgorithmConfig(
    id: 'katago_fallback_standard_v1',
    frameworkId: AiAlgorithmFrameworkId.katago,
    displayName: 'KataGo Fallback Standard',
    strengthTier: AiAlgorithmStrengthTier.standard,
    runtimeMode: AiAlgorithmRuntimeMode.fallback,
    failureMode: 'native_backend_unavailable_uses_legal_hybrid_fallback',
    parameters: const {
      'backend': 'fallback',
      'model': 'katago_capture_placeholder_standard',
      'fallbackStyle': 'counter',
      'fallbackDifficulty': 'intermediate',
    },
    robotConfig: CaptureAiRegistry.resolveConfig(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.intermediate,
    ),
  );
}
