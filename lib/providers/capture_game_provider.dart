import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/ai_algorithm_framework.dart';
import '../game/ai_search_runner.dart';
import '../game/capture_ai.dart';
import '../game/capture5_flutter_onnx_model_adapter.dart';
import '../game/difficulty_level.dart';
import '../game/game_mode.dart';
import '../game/go_engine.dart';
import '../game/katago_flutter_onnx_model_adapter.dart';
import '../game/katago_model_adapter.dart';
import '../game/mcts_engine.dart';
import '../game/territory_ai.dart';
import '../game/training_suggestion_runner.dart';
import '../models/board_position.dart';
import '../models/game_state.dart';

export '../game/ai_search_runner.dart' show AiSearchRunner;
export '../game/difficulty_level.dart';
export '../game/katago_model_adapter.dart'
    show KatagoPolicyPlane, KatagoPolicyPlaneLabel;

const String _katagoCoachConfigId = 'katago_onnx_standard_v1';

// ---------------------------------------------------------------------------
// Top-level function required by compute() for hint suggestions.
// ---------------------------------------------------------------------------

List<List<int>> _runSuggestMoves(Map<String, dynamic> params) {
  final cells = List<int>.from(params['cells'] as List);
  final boardSize = params['boardSize'] as int;
  final captureTarget = params['captureTarget'] as int;
  final capturedByBlack = params['capturedByBlack'] as int;
  final capturedByWhite = params['capturedByWhite'] as int;
  final currentPlayer = params['currentPlayer'] as int;
  final aiStyle = CaptureAiStyle.values.byName(params['aiStyle'] as String);
  final difficulty =
      DifficultyLevel.values.byName(params['difficulty'] as String);
  final algorithmConfigId = params['algorithmConfigId'] as String?;
  final count = params['count'] as int;
  final gameMode = GameModeExt.fromStorageKey(params['gameMode'] as String?);
  final consecutivePasses = (params['consecutivePasses'] as int?) ?? 0;

  final sim = SimBoard(
    boardSize,
    captureTarget: captureTarget,
    gameMode: gameMode,
  );
  for (int i = 0; i < cells.length; i++) {
    sim.cells[i] = cells[i];
  }
  sim.capturedByBlack = capturedByBlack;
  sim.capturedByWhite = capturedByWhite;
  sim.currentPlayer = currentPlayer;
  sim.consecutivePasses = consecutivePasses;

  final suggestions = <List<int>>[];
  final territoryEngine = TerritoryAiEngine(difficulty: difficulty);
  final primaryAgent = gameMode == GameMode.capture
      ? _captureAgentForProvider(
          algorithmConfigId: algorithmConfigId,
          aiStyle: aiStyle,
          difficulty: difficulty,
        )
      : null;
  final replyAgent = gameMode == GameMode.capture
      ? CaptureAiRegistry.create(
          style: CaptureAiStyle.counter,
          difficulty: DifficultyLevel.beginner,
        )
      : null;
  for (int i = 0; i < count; i++) {
    final move = gameMode == GameMode.capture
        ? primaryAgent?.chooseMove(sim)?.position
        : territoryEngine.chooseMove(sim);
    if (move == null) break;
    if (move == territoryPassMove) break;
    suggestions.add([move.row, move.col]);
    if (!sim.applyMove(move.row, move.col)) {
      break;
    }
    final whiteReply = gameMode == GameMode.capture
        ? replyAgent?.chooseMove(sim)?.position
        : territoryEngine.chooseMove(sim);
    if (whiteReply == null) {
      break;
    }
    if (whiteReply == territoryPassMove) {
      sim.applyPass();
    } else if (!sim.applyMove(whiteReply.row, whiteReply.col)) {
      break;
    }
  }
  return suggestions;
}

String _stringParameter(Map<String, Object?> params, String key) {
  return switch (params[key]) {
    final String value => value,
    _ => '',
  };
}

int _intParameter(Map<String, Object?> params, String key, int fallback) {
  return switch (params[key]) {
    final int value => value,
    final num value => value.toInt(),
    _ => fallback,
  };
}

double _fallbackTrainingWinRate(
  SimBoard board,
  int originalPlayer,
  int captureTarget,
) {
  const floor = 0.05;
  const ceiling = 0.95;
  final myCaps = originalPlayer == SimBoard.black
      ? board.capturedByBlack
      : board.capturedByWhite;
  final oppCaps = originalPlayer == SimBoard.black
      ? board.capturedByWhite
      : board.capturedByBlack;
  final progress = (myCaps - oppCaps) / captureTarget;
  return (0.5 + progress * 0.35).clamp(floor, ceiling).toDouble();
}

CaptureAiAgent _captureAgentForProvider({
  required String? algorithmConfigId,
  required CaptureAiStyle aiStyle,
  required DifficultyLevel difficulty,
}) {
  if (algorithmConfigId != null) {
    return AiAlgorithmRegistry.createAgent(
      AiAlgorithmRegistry.configById(algorithmConfigId),
    );
  }
  return CaptureAiRegistry.create(style: aiStyle, difficulty: difficulty);
}

/// A single training suggestion: a board position paired with the estimated
/// win-rate for the player who would place at that position.
class TrainingSuggestion {
  const TrainingSuggestion({
    required this.position,
    required this.winRate,
    this.policyScore,
    this.policyProbability,
    this.valueDelta,
    this.scoreLead,
    this.scoreUncertainty,
    this.strategyLabel,
    this.explanationSignals = const [],
    this.source = 'fallback',
  });

  final BoardPosition position;

  /// Win-rate in the range [0.05, 0.95] for the player to move.
  final double winRate;

  final double? policyScore;
  final double? policyProbability;
  final double? valueDelta;
  final double? scoreLead;
  final double? scoreUncertainty;
  final String? strategyLabel;
  final List<String> explanationSignals;
  final String source;
}

enum CaptureGameResult { none, blackWins, whiteWins, draw }

enum CaptureInitialMode { cross, twistCross, empty, setup }

String captureInitialModeStorageKey(CaptureInitialMode mode) {
  return switch (mode) {
    CaptureInitialMode.cross => 'twistCross',
    CaptureInitialMode.twistCross => 'twistCross2x2',
    CaptureInitialMode.empty => 'empty',
    CaptureInitialMode.setup => 'setup',
  };
}

CaptureInitialMode captureInitialModeFromStorageKey(
  String? key, {
  CaptureInitialMode fallback = CaptureInitialMode.cross,
}) {
  return switch (key) {
    'twistCross' || 'cross' => CaptureInitialMode.cross,
    'twistCross2x2' => CaptureInitialMode.twistCross,
    'empty' => CaptureInitialMode.empty,
    'setup' => CaptureInitialMode.setup,
    _ => fallback,
  };
}

void applyCaptureInitialLayout(
  List<List<StoneColor>> board,
  CaptureInitialMode mode,
) {
  final boardSize = board.length;
  assert(
    board.every((row) => row.length == boardSize),
    'board must be a square matrix.',
  );
  // Keep a runtime guard for production builds where asserts are disabled.
  if (board.any((row) => row.length != boardSize)) {
    return;
  }

  final center = boardSize ~/ 2;
  if (center <= 0 || center >= boardSize - 1) return;

  switch (mode) {
    case CaptureInitialMode.cross:
      board[center - 1][center] = StoneColor.black;
      board[center + 1][center] = StoneColor.black;
      board[center][center - 1] = StoneColor.white;
      board[center][center + 1] = StoneColor.white;
      break;
    case CaptureInitialMode.twistCross:
      board[center][center] = StoneColor.black;
      board[center][center + 1] = StoneColor.white;
      board[center - 1][center] = StoneColor.white;
      board[center - 1][center + 1] = StoneColor.black;
      break;
    case CaptureInitialMode.empty:
    case CaptureInitialMode.setup:
      break;
  }
}

List<List<int>> orderedCaptureInitialMoves({
  required int boardSize,
  required CaptureInitialMode initialMode,
  List<List<StoneColor>>? initialBoardOverride,
  StoneColor initialPlayer = StoneColor.black,
}) {
  if (initialBoardOverride == null) {
    final center = boardSize ~/ 2;
    if (center <= 0 || center >= boardSize - 1) return const [];
    return switch (initialMode) {
      CaptureInitialMode.cross => [
          [center + 1, center],
          [center, center - 1],
          [center - 1, center],
          [center, center + 1],
        ],
      CaptureInitialMode.twistCross => [
          [center, center],
          [center, center + 1],
          [center + 1, center + 1],
          [center + 1, center],
        ],
      CaptureInitialMode.empty || CaptureInitialMode.setup => const [],
    };
  }

  final blackMoves = <List<int>>[];
  final whiteMoves = <List<int>>[];
  for (var row = 0; row < boardSize; row++) {
    for (var col = 0; col < boardSize; col++) {
      final stone = initialBoardOverride[row][col];
      if (stone == StoneColor.black) {
        blackMoves.add([row, col]);
      } else if (stone == StoneColor.white) {
        whiteMoves.add([row, col]);
      }
    }
  }

  final moves = <List<int>>[];
  final blackQueue = List<List<int>>.from(blackMoves);
  final whiteQueue = List<List<int>>.from(whiteMoves);
  var nextColor = initialPlayer;
  while (blackQueue.isNotEmpty || whiteQueue.isNotEmpty) {
    final queue = nextColor == StoneColor.black ? blackQueue : whiteQueue;
    final fallbackQueue =
        nextColor == StoneColor.black ? whiteQueue : blackQueue;
    if (queue.isNotEmpty) {
      moves.add(queue.removeAt(0));
    } else if (fallbackQueue.isNotEmpty) {
      moves.add(fallbackQueue.removeAt(0));
    }
    nextColor =
        nextColor == StoneColor.black ? StoneColor.white : StoneColor.black;
  }
  return moves;
}

class CaptureGameProvider extends ChangeNotifier {
  static const Duration _defaultMinMoveDelay = Duration(milliseconds: 1280);
  static const Duration _defaultMaxMoveDelay = Duration(milliseconds: 2500);
  // Territory scoring is normalized by board area, then clamped to keep the
  // UI estimate conservative on unfinished positions. 0.45 keeps a large but
  // not-yet-final area lead near ~93% instead of 100%, while the 5% / 95%
  // floor and ceiling avoid certainty spikes from noisy midgame estimates.
  static const double _winRateFloor = 0.05;
  static const double _winRateCeiling = 0.95;
  static const double _territoryWinRateWeight = 0.45;
  // ~2 frames at 60 fps: just long enough for Flutter to render the human
  // stone before the AI starts thinking.
  static const Duration _aiStartRenderDelay = Duration(milliseconds: 32);

  CaptureGameProvider({
    required this.boardSize,
    required this.captureTarget,
    required this.difficulty,
    this.gameMode = GameMode.capture,
    this.humanColor = StoneColor.black,
    this.initialMode = CaptureInitialMode.cross,
    this.initialBoardOverride,
    this.initialPlayerOverride,
    this.initialMoveLog = const [],
    this.minMoveDelay = _defaultMinMoveDelay,
    this.maxMoveDelay = _defaultMaxMoveDelay,
    this.aiAlgorithmConfig,
    AsyncKatagoModelAdapter? katagoModelAdapter,
    AiSearchRunner? runner,
    TrainingSuggestionRunner? trainingSuggestionRunner,
  })  : _katagoModelAdapterOverride = katagoModelAdapter,
        assert(
          boardSize == 9 || boardSize == 13 || boardSize == 19,
          'boardSize must be 9, 13, or 19.',
        ),
        assert(captureTarget > 0, 'captureTarget must be greater than 0.'),
        assert(
          initialBoardOverride == null ||
              _isValidBoardShape(initialBoardOverride, boardSize),
          'initialBoardOverride must match boardSize.',
        ),
        assert(
          minMoveDelay >= Duration.zero,
          'minMoveDelay must not be negative.',
        ),
        assert(
          maxMoveDelay >= Duration.zero,
          'maxMoveDelay must not be negative.',
        ),
        assert(
          maxMoveDelay >= minMoveDelay,
          'maxMoveDelay must be >= minMoveDelay.',
        ) {
    _runner = runner ?? createAiSearchRunner();
    _trainingSuggestionRunner =
        trainingSuggestionRunner ?? createTrainingSuggestionRunner();
    if (initialBoardOverride != null &&
        !_isValidBoardShape(initialBoardOverride, boardSize)) {
      throw ArgumentError.value(
        initialBoardOverride,
        'initialBoardOverride',
        '棋盤尺寸與 boardSize 不一致。',
      );
    }
    _startNewGame();
    if (!isPlacementMode && _gameState.currentPlayer != humanColor) {
      _scheduleAiMove();
    }
  }

  final int boardSize;
  final int captureTarget;
  final DifficultyLevel difficulty;
  final GameMode gameMode;
  final StoneColor humanColor;
  final CaptureInitialMode initialMode;
  final List<List<StoneColor>>? initialBoardOverride;
  final StoneColor? initialPlayerOverride;
  final List<List<int>> initialMoveLog;
  final AiAlgorithmConfig? aiAlgorithmConfig;
  final AsyncKatagoModelAdapter? _katagoModelAdapterOverride;

  /// Minimum time between when the AI starts thinking and when it places its
  /// stone. If the computation finishes before this deadline the provider waits
  /// for the remaining time, keeping [isAiThinking] true so the UI can show a
  /// thinking indicator. Defaults to 1280 ms. Pass [Duration.zero] in tests.
  final Duration minMoveDelay;

  /// Upper bound on the extra wait added after computation completes. Once
  /// total elapsed time (computation + wait) would exceed this value no
  /// additional wait is added. If computation alone already exceeds
  /// [maxMoveDelay], the AI places its stone immediately without further delay.
  /// Defaults to 2500 ms.
  final Duration maxMoveDelay;

  static bool _isValidBoardShape(List<List<StoneColor>>? board, int size) {
    if (board == null) return true;
    return board.length == size && board.every((row) => row.length == size);
  }

  CaptureAiStyle _aiStyle = CaptureAiStyle.adaptive;
  CaptureAiAgent? _cachedAgent;
  AsyncCaptureAiAgent? _cachedAsyncAgent;
  FlutterKatagoOnnxModelAdapter? _ownedKatagoModelAdapter;
  FlutterCapture5OnnxModelAdapter? _ownedCapture5ModelAdapter;

  late final AiSearchRunner _runner;
  late final TrainingSuggestionRunner _trainingSuggestionRunner;

  /// Monotonically-increasing counter used to build unique request IDs.
  /// Unlike [_gameGeneration], this is never reset so each [_doAiMove] call
  /// gets a distinct identifier even within the same game.
  /// Dart's int is 64-bit; overflow is not a practical concern for a game app
  /// (would require ~9.2 × 10¹⁸ AI turns).
  int _requestCounter = 0;

  /// The request ID for the currently in-flight AI move search, or null.
  AiSearchRequestId? _pendingAiRequestId;
  TrainingSuggestionRequestId? _pendingTrainingSuggestionRequestId;

  late GameState _gameState;
  CaptureGameResult _result = CaptureGameResult.none;
  bool _isAiThinking = false;
  String? _aiFailureReason;
  bool _disposed = false;
  Timer? _aiMoveTimer;

  /// Incremented every time a new game starts. In-flight [_doAiMove] tasks
  /// capture this value on entry and bail out if it has changed by the time
  /// the delay elapses, preventing stale moves from being applied to a new game.
  int _gameGeneration = 0;

  final List<GameState> _undoStack = [];

  /// Every move played in the current game, in order: each entry is [row, col].
  final List<List<int>> _moveLog = [];

  bool _trainingMode = false;

  GameState get gameState => _gameState;
  CaptureGameResult get result => _result;
  bool get isAiThinking => _isAiThinking;
  String? get aiFailureReason => _aiFailureReason;
  bool get canUndo => _undoStack.isNotEmpty && !_isAiThinking;
  CaptureAiStyle get aiStyle =>
      aiAlgorithmConfig?.robotConfig.style ?? _aiStyle;
  AiAlgorithmConfig? get activeAlgorithmConfig => aiAlgorithmConfig;
  GameMode get mode => gameMode;
  bool get isTerritoryMode => gameMode == GameMode.territory;
  bool get isPlacementMode => initialMode == CaptureInitialMode.setup;

  /// Whether AI training partner mode is currently active.
  bool get trainingMode => _trainingMode;

  /// An unmodifiable view of the current game's move sequence.
  List<List<int>> get moveLog => List.unmodifiable(_moveLog);

  CaptureAiAgent get _activeAgent {
    return _cachedAgent ??= aiAlgorithmConfig == null
        ? CaptureAiRegistry.create(style: _aiStyle, difficulty: difficulty)
        : AiAlgorithmRegistry.createAgent(aiAlgorithmConfig!);
  }

  AsyncCaptureAiAgent get _activeAsyncAgent {
    return _cachedAsyncAgent ??= AiAlgorithmRegistry.createAsyncAgent(
      aiAlgorithmConfig!,
      katagoModelAdapter: _katagoModelAdapter,
    );
  }

  AsyncKatagoModelAdapter get _katagoModelAdapter {
    final injected = _katagoModelAdapterOverride;
    if (injected != null) return injected;
    if (aiAlgorithmConfig?.frameworkId == AiAlgorithmFrameworkId.capture5) {
      return _ownedCapture5ModelAdapter ??= FlutterCapture5OnnxModelAdapter();
    }
    return _ownedKatagoModelAdapter ??= FlutterKatagoOnnxModelAdapter();
  }

  TerritoryScore get territoryScore =>
      GoEngine.computeTerritoryScore(_gameState);

  void newGame() => _startNewGame();

  @override
  void dispose() {
    _disposed = true;
    _aiMoveTimer?.cancel();
    if (_pendingAiRequestId != null) {
      _runner.cancel(_pendingAiRequestId!);
      _pendingAiRequestId = null;
    }
    if (_pendingTrainingSuggestionRequestId != null) {
      _trainingSuggestionRunner.cancel(_pendingTrainingSuggestionRequestId!);
      _pendingTrainingSuggestionRequestId = null;
    }
    final ownedAdapter = _ownedKatagoModelAdapter;
    if (ownedAdapter != null) {
      unawaited(ownedAdapter.close());
    }
    final ownedCapture5Adapter = _ownedCapture5ModelAdapter;
    if (ownedCapture5Adapter != null) {
      unawaited(ownedCapture5Adapter.close());
    }
    _runner.dispose();
    _trainingSuggestionRunner.dispose();
    super.dispose();
  }

  void setAiStyle(CaptureAiStyle style) {
    if (isTerritoryMode) return;
    if (aiAlgorithmConfig != null) return;
    if (_aiStyle == style) return;
    _aiStyle = style;
    _cachedAgent = null;
    _cachedAsyncAgent = null;
    notifyListeners();
  }

  /// Enters AI training partner mode. Both colours can be placed by the user;
  /// the AI will not auto-play its turn.
  void enterTrainingMode() {
    if (_trainingMode) return;
    if (_result != CaptureGameResult.none) return;
    _trainingMode = true;
    // Cancel any in-flight or pending AI move.
    _aiMoveTimer?.cancel();
    _aiMoveTimer = null;
    if (_pendingAiRequestId != null) {
      _runner.cancel(_pendingAiRequestId!);
      _pendingAiRequestId = null;
    }
    cancelTrainingSuggestions();
    _isAiThinking = false;
    notifyListeners();
  }

  /// Exits AI training partner mode. If it is the AI's turn the AI will
  /// resume play automatically.
  void exitTrainingMode() {
    if (!_trainingMode) return;
    _trainingMode = false;
    notifyListeners();
    // Resume normal play if it is now the AI's turn.
    if (!isPlacementMode &&
        _result == CaptureGameResult.none &&
        _gameState.currentPlayer != humanColor) {
      _scheduleAiMove();
    }
  }

  /// Computes up to [count] candidate training suggestions in a background
  /// isolate and returns them with per-position win-rate estimates.
  Future<List<TrainingSuggestion>> suggestMovesWithWinRateAsync({
    int count = 3,
    KatagoPolicyPlane policyPlane = KatagoPolicyPlane.normal,
  }) async {
    // Spec: docs/specs_map/main_game_flow.yaml#training_coach_katago
    // Spec: docs/specs_map/technical_contracts.yaml#ai_background_execution
    if (count <= 0) return const [];
    if (_result != CaptureGameResult.none) return const [];
    final sim =
        SimBoard.fromGameState(_gameState, captureTarget: captureTarget);
    if (_shouldTryNativeKatagoCoach) {
      final suggestions = await _trySuggestMovesWithKatagoCoach(
        sim: sim,
        count: count,
        policyPlane: policyPlane,
      );
      if (suggestions.isNotEmpty) return suggestions;
    }
    final params = <String, dynamic>{
      'cells': sim.cells.toList(),
      'boardSize': sim.size,
      'captureTarget': sim.captureTarget,
      'capturedByBlack': sim.capturedByBlack,
      'capturedByWhite': sim.capturedByWhite,
      'currentPlayer': sim.currentPlayer,
      'aiStyle': _aiStyle.name,
      'difficulty': difficulty.name,
      if (aiAlgorithmConfig != null) 'algorithmConfigId': aiAlgorithmConfig!.id,
      'gameMode': gameMode.storageKey,
      'consecutivePasses': sim.consecutivePasses,
      'count': count,
      if (_usesKatagoTrainingCoach)
        ..._katagoCoachRunnerParams(
          sim: sim,
          count: count,
          policyPlane: policyPlane,
        ),
    };
    final requestId = 'training_hint_${_gameGeneration}_${++_requestCounter}';
    _pendingTrainingSuggestionRequestId = requestId;
    final result = await _trainingSuggestionRunner.search(
      TrainingSuggestionRequest(id: requestId, params: params),
    );
    if (_pendingTrainingSuggestionRequestId == requestId) {
      _pendingTrainingSuggestionRequestId = null;
    }
    if (result.hasError) return const [];
    final structured = result.structuredSuggestions;
    if (structured != null) {
      return structured.map(_trainingSuggestionFromStructured).toList();
    }
    final raw = result.suggestions ?? const <List<num>>[];
    return raw
        .map(
          (entry) => TrainingSuggestion(
            position: BoardPosition(entry[0].toInt(), entry[1].toInt()),
            winRate: entry[2].toDouble() / 1000.0,
          ),
        )
        .toList();
  }

  List<int> _legalMoveIndices(SimBoard board) {
    return [
      for (final moveIndex in board.getLegalMoves())
        if (board
            .analyzeMove(
              moveIndex ~/ board.size,
              moveIndex % board.size,
            )
            .isLegal)
          moveIndex,
    ];
  }

  Map<String, dynamic> _katagoCoachRunnerParams({
    required SimBoard sim,
    required int count,
    required KatagoPolicyPlane policyPlane,
  }) {
    final params = _katagoCoachConfig.parameters;
    return {
      'coachBackend': 'katago_onnx',
      'modelAsset': _stringParameter(params, 'modelAsset'),
      'timeBudgetMillis': _intParameter(params, 'timeBudgetMillis', 10000),
      'policyTemperature': 0.0,
      'candidateLimit': count,
      'policyPlane': policyPlane.index,
      'legalMoves': _legalMoveIndices(sim),
    };
  }

  TrainingSuggestion _trainingSuggestionFromStructured(
    Map<String, dynamic> entry,
  ) {
    return TrainingSuggestion(
      position: BoardPosition(
        (entry['row'] as num).toInt(),
        (entry['col'] as num).toInt(),
      ),
      winRate: ((entry['winRate'] as num?)?.toDouble() ?? 0.5)
          .clamp(0.05, 0.95)
          .toDouble(),
      policyScore: (entry['policyScore'] as num?)?.toDouble(),
      policyProbability: (entry['policyProbability'] as num?)?.toDouble(),
      valueDelta: (entry['valueDelta'] as num?)?.toDouble(),
      scoreLead: (entry['scoreLead'] as num?)?.toDouble(),
      scoreUncertainty: (entry['scoreUncertainty'] as num?)?.toDouble(),
      strategyLabel: entry['strategyLabel'] as String?,
      explanationSignals: (entry['explanationSignals'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const [],
      source: entry['source'] as String? ?? 'worker',
    );
  }

  Future<List<TrainingSuggestion>> _suggestMovesWithKatagoCoach({
    required SimBoard sim,
    required int count,
    required KatagoPolicyPlane policyPlane,
  }) async {
    final before = await _katagoModelAdapter.chooseMove(
      _katagoCoachRequest(
        board: SimBoard.copy(sim),
        candidateLimit: count,
        policyPlane: policyPlane,
      ),
    );
    if (before.status != KatagoBackendStatus.ready ||
        before.policyCandidates.isEmpty) {
      return const [];
    }

    final suggestions = <TrainingSuggestion>[];
    final beforeWin = before.value?.win;
    for (final candidate in before.policyCandidates.take(count)) {
      final after = SimBoard.copy(sim);
      if (!after.applyMove(candidate.position.row, candidate.position.col)) {
        continue;
      }
      final afterEval = await _katagoModelAdapter.chooseMove(
        _katagoCoachRequest(
          board: after,
          candidateLimit: math.max(1, count),
          policyPlane: policyPlane,
        ),
      );
      final afterWin = afterEval.value?.loss ?? beforeWin;
      final displayWinRate = (afterWin ??
              beforeWin ??
              _fallbackTrainingWinRate(
                after,
                sim.currentPlayer,
                captureTarget,
              ))
          .clamp(0.05, 0.95)
          .toDouble();
      final valueDelta =
          beforeWin == null || afterWin == null ? null : afterWin - beforeWin;
      suggestions.add(
        TrainingSuggestion(
          position: candidate.position,
          winRate: displayWinRate,
          policyScore: candidate.score,
          policyProbability: candidate.probability,
          valueDelta: valueDelta,
          scoreLead: afterEval.scoreBelief?.mean ?? before.scoreBelief?.mean,
          scoreUncertainty:
              afterEval.scoreBelief?.stdev ?? before.scoreBelief?.stdev,
          strategyLabel: policyPlane.explanationLabel,
          explanationSignals: _katagoCoachSignals(
            candidate: candidate,
            valueDelta: valueDelta,
            scoreBelief: afterEval.scoreBelief ?? before.scoreBelief,
            policyPlane: policyPlane,
          ),
          source: 'katago',
        ),
      );
    }
    return suggestions;
  }

  Future<List<TrainingSuggestion>> _trySuggestMovesWithKatagoCoach({
    required SimBoard sim,
    required int count,
    required KatagoPolicyPlane policyPlane,
  }) async {
    try {
      return await _suggestMovesWithKatagoCoach(
        sim: sim,
        count: count,
        policyPlane: policyPlane,
      );
    } catch (_) {
      return const [];
    }
  }

  KatagoModelRequest _katagoCoachRequest({
    required SimBoard board,
    required int candidateLimit,
    required KatagoPolicyPlane policyPlane,
  }) {
    final params = _katagoCoachConfig.parameters;
    return KatagoModelRequest(
      board: board,
      modelAsset: _stringParameter(params, 'modelAsset'),
      timeBudgetMillis: _intParameter(params, 'timeBudgetMillis', 10000),
      policyTemperature: 0,
      candidateLimit: math.max(1, candidateLimit),
      policyPlane: policyPlane.index,
    );
  }

  List<String> _katagoCoachSignals({
    required KatagoPolicyCandidate candidate,
    required double? valueDelta,
    required KatagoScoreBeliefSummary? scoreBelief,
    required KatagoPolicyPlane policyPlane,
  }) {
    final signals = <String>[
      '${policyPlane.explanationLabel}第 ${candidate.rank} 選',
      '策略偏好 ${(candidate.probability * 100).round()}%',
    ];
    if (scoreBelief != null) {
      final lead = scoreBelief.mean;
      final sign = lead >= 0 ? '+' : '';
      signals.add('模型目差 $sign${lead.toStringAsFixed(1)}');
    }
    return signals;
  }

  void cancelTrainingSuggestions() {
    final requestId = _pendingTrainingSuggestionRequestId;
    if (requestId == null) return;
    _trainingSuggestionRunner.cancel(requestId);
    _pendingTrainingSuggestionRequestId = null;
  }

  Future<bool> placeStone(int row, int col) async {
    if (_isAiThinking || _result != CaptureGameResult.none) return false;
    if (!isPlacementMode &&
        !_trainingMode &&
        _gameState.currentPlayer != humanColor) {
      return false;
    }

    final newState = GoEngine.placeStone(_gameState, row, col);
    if (newState == null) return false;

    _undoStack.add(_gameState);
    _gameState = newState;
    _moveLog.add([row, col]);
    _aiFailureReason = null;
    _checkWinCondition();
    notifyListeners();

    if (!isPlacementMode && _result == CaptureGameResult.none) {
      _scheduleAiMove();
    }
    return true;
  }

  Future<bool> passTurn() async {
    if (!isTerritoryMode ||
        _isAiThinking ||
        _result != CaptureGameResult.none ||
        isPlacementMode ||
        (!_trainingMode && _gameState.currentPlayer != humanColor)) {
      return false;
    }
    final newState = GoEngine.passTurn(_gameState);
    if (newState == null) return false;
    _undoStack.add(_gameState);
    _gameState = newState;
    _moveLog.add(const [-1, -1]);
    _aiFailureReason = null;
    _checkWinCondition();
    notifyListeners();
    if (_result == CaptureGameResult.none) {
      _scheduleAiMove();
    }
    return true;
  }

  Future<void> clearSetupBoard() async {
    if (!isPlacementMode) return;
    final emptyBoard = List.generate(
      boardSize,
      (_) => List<StoneColor>.filled(boardSize, StoneColor.empty),
    );
    _gameState = GameState(
      boardSize: boardSize,
      board: emptyBoard,
      currentPlayer: StoneColor.black,
    );
    _undoStack.clear();
    _moveLog.clear();
    notifyListeners();
  }

  void undoMove() {
    if (!canUndo) return;
    final stackSizeBefore = _undoStack.length;
    if (isPlacementMode) {
      // Setup mode: undo one move at a time
      _gameState = _undoStack.removeLast();
    } else {
      // Auto-play mode: skip over AI moves to restore human's last turn
      _gameState = _undoStack.removeLast();
      while (_undoStack.isNotEmpty && _gameState.currentPlayer != humanColor) {
        _gameState = _undoStack.removeLast();
      }
    }
    final movesRemoved = stackSizeBefore - _undoStack.length;
    if (_moveLog.length >= movesRemoved) {
      _moveLog.removeRange(_moveLog.length - movesRemoved, _moveLog.length);
    }
    _result = CaptureGameResult.none;
    notifyListeners();
    // If we exhausted the stack and it's still AI's turn, kick off AI again
    if (!isPlacementMode && _gameState.currentPlayer != humanColor) {
      _scheduleAiMove();
    }
  }

  List<BoardPosition> suggestMoves({int count = 1}) {
    if (count <= 0) return const [];
    if (_usesAsyncAlgorithmAgent) {
      throw StateError('katago_requires_async_model_adapter');
    }

    final suggestions = <BoardPosition>[];
    final sim =
        SimBoard.fromGameState(_gameState, captureTarget: captureTarget);
    final territoryEngine = TerritoryAiEngine(difficulty: difficulty);
    final replyAgent = isTerritoryMode
        ? null
        : CaptureAiRegistry.create(
            style: CaptureAiStyle.counter,
            difficulty: DifficultyLevel.beginner,
          );

    for (int i = 0; i < count; i++) {
      final move = isTerritoryMode
          ? territoryEngine.chooseMove(sim)
          : _activeAgent.chooseMove(sim)?.position;
      if (move == null) break;
      if (move == territoryPassMove) break;
      suggestions.add(BoardPosition(move.row, move.col));

      if (!sim.applyMove(move.row, move.col)) {
        break;
      }
      final whiteReply = isTerritoryMode
          ? territoryEngine.chooseMove(sim)
          : replyAgent?.chooseMove(sim)?.position;
      if (whiteReply == null) {
        break;
      }
      if (whiteReply == territoryPassMove) {
        sim.applyPass();
      } else if (!sim.applyMove(whiteReply.row, whiteReply.col)) {
        break;
      }
    }
    return suggestions;
  }

  /// Computes move suggestions in a background isolate so the UI stays
  /// responsive.
  Future<List<BoardPosition>> suggestMovesAsync({int count = 1}) async {
    if (count <= 0) return const [];

    final sim =
        SimBoard.fromGameState(_gameState, captureTarget: captureTarget);
    if (_usesAsyncAlgorithmAgent) {
      final move = await _activeAsyncAgent.chooseMove(sim);
      final position = move?.position;
      return position == null ? const [] : [position];
    }
    final params = <String, dynamic>{
      'cells': sim.cells.toList(),
      'boardSize': sim.size,
      'captureTarget': sim.captureTarget,
      'capturedByBlack': sim.capturedByBlack,
      'capturedByWhite': sim.capturedByWhite,
      'currentPlayer': sim.currentPlayer,
      'aiStyle': _aiStyle.name,
      'difficulty': difficulty.name,
      if (aiAlgorithmConfig != null) 'algorithmConfigId': aiAlgorithmConfig!.id,
      'gameMode': gameMode.storageKey,
      'consecutivePasses': sim.consecutivePasses,
      'count': count,
    };
    final raw = await compute(_runSuggestMoves, params);
    return raw.map((r) => BoardPosition(r[0], r[1])).toList();
  }

  Map<StoneColor, double> get winRateEstimate {
    if (isTerritoryMode) {
      final diff = territoryScore.blackArea - territoryScore.whiteArea;
      // Formula: blackRate = 0.5 + (areaDiff / boardArea * weight), then clamp.
      final normalized = (diff / (boardSize * boardSize))
          .clamp(-_winRateCeiling, _winRateCeiling)
          .toDouble();
      final blackRate = (0.5 + normalized * _territoryWinRateWeight)
          .clamp(_winRateFloor, _winRateCeiling)
          .toDouble();
      return {
        StoneColor.black: blackRate,
        StoneColor.white: 1 - blackRate,
      };
    }
    final blackCaps = _gameState.capturedByBlack.length;
    final whiteCaps = _gameState.capturedByWhite.length;
    final progress = (blackCaps - whiteCaps) / captureTarget;
    final blackRate = (0.5 + progress * 0.35).clamp(0.05, 0.95).toDouble();
    return {
      StoneColor.black: blackRate,
      StoneColor.white: 1 - blackRate,
    };
  }

  void _startNewGame() {
    _aiMoveTimer?.cancel();
    _aiMoveTimer = null;
    // Cancel any in-flight AI request from the previous game before bumping
    // the generation counter, so stale results are discarded immediately.
    if (_pendingAiRequestId != null) {
      _runner.cancel(_pendingAiRequestId!);
      _pendingAiRequestId = null;
    }
    final emptyBoard = List.generate(
      boardSize,
      (_) => List<StoneColor>.filled(boardSize, StoneColor.empty),
    );
    var initialPlayer = initialPlayerOverride ?? StoneColor.black;

    if (initialBoardOverride != null) {
      final source = initialBoardOverride!;
      final isValidSize = source.length == boardSize &&
          source.every((row) => row.length == boardSize);
      if (!isValidSize) {
        throw ArgumentError(
          'initialBoardOverride must be ${boardSize}x$boardSize, '
          'but received ${source.length}x'
          '${source.isNotEmpty ? source[0].length : 0}.',
        );
      }
      for (int r = 0; r < boardSize; r++) {
        for (int c = 0; c < boardSize; c++) {
          emptyBoard[r][c] = source[r][c];
        }
      }
    } else {
      applyCaptureInitialLayout(emptyBoard, initialMode);
    }

    _gameState = GameState(
      boardSize: boardSize,
      board: emptyBoard,
      currentPlayer: initialPlayer,
      gameMode: gameMode,
    );
    _undoStack.clear();
    _moveLog.clear();
    for (final move in initialMoveLog) {
      if (move.length < 2) {
        throw ArgumentError.value(
            initialMoveLog, 'initialMoveLog', '棋譜包含無效座標。');
      }
      _undoStack.add(_gameState);
      final nextState = move[0] == -1 && move[1] == -1
          ? GoEngine.passTurn(_gameState)
          : GoEngine.placeStone(_gameState, move[0], move[1]);
      if (nextState == null) {
        throw ArgumentError.value(
            initialMoveLog, 'initialMoveLog', '棋譜無法從初始局面重放。');
      }
      _gameState = nextState;
      _moveLog.add(List<int>.from(move));
    }
    _result = CaptureGameResult.none;
    _isAiThinking = false;
    _aiFailureReason = null;
    _gameGeneration++;
    notifyListeners();
  }

  void _scheduleAiMove() {
    if (_trainingMode) return;
    if (_disposed ||
        isPlacementMode ||
        _result != CaptureGameResult.none ||
        _isAiThinking ||
        _aiMoveTimer != null ||
        _gameState.currentPlayer == humanColor) {
      return;
    }

    final generation = _gameGeneration;
    _aiMoveTimer = Timer(_aiStartRenderDelay, () {
      _aiMoveTimer = null;
      if (!_isCurrentGame(generation) ||
          isPlacementMode ||
          _result != CaptureGameResult.none ||
          _isAiThinking ||
          _gameState.currentPlayer == humanColor) {
        return;
      }
      unawaited(_doAiMove());
    });
  }

  Future<void> _doAiMove() async {
    if (_disposed ||
        isPlacementMode ||
        _result != CaptureGameResult.none ||
        _isAiThinking ||
        _gameState.currentPlayer == humanColor) {
      return;
    }

    _isAiThinking = true;
    notifyListeners();

    final generation = _gameGeneration;
    // Use a per-request counter to guarantee a unique ID for every AI turn,
    // even within the same game generation.
    final requestId = 'ai_move_${generation}_${++_requestCounter}';
    _pendingAiRequestId = requestId;
    final thinkingStopwatch = Stopwatch()..start();

    try {
      final simBoard =
          SimBoard.fromGameState(_gameState, captureTarget: captureTarget);
      final legalMoveIndices = [
        for (final moveIndex in simBoard.getLegalMoves())
          if (simBoard
              .analyzeMove(
                moveIndex ~/ _gameState.boardSize,
                moveIndex % _gameState.boardSize,
              )
              .isLegal)
            moveIndex,
      ];
      BoardPosition? bestMove;
      Object? searchError;
      if (_usesAsyncAlgorithmAgent) {
        try {
          bestMove = (await _activeAsyncAgent.chooseMove(simBoard))?.position;
        } catch (error) {
          searchError = error;
        }
      } else {
        final params = <String, dynamic>{
          'boardSize': _gameState.boardSize,
          'captureTarget': captureTarget,
          'cells': _gameState.board
              .expand((row) => row.map((s) => s.index))
              .toList(),
          'capturedByBlack': _gameState.capturedByBlack.length,
          'capturedByWhite': _gameState.capturedByWhite.length,
          'currentPlayer': _gameState.currentPlayer.index,
          'aiStyle':
              isTerritoryMode ? CaptureAiStyle.adaptive.name : _aiStyle.name,
          'difficulty': difficulty.name,
          if (aiAlgorithmConfig != null)
            'algorithmConfigId': aiAlgorithmConfig!.id,
          'gameMode': gameMode.storageKey,
          'consecutivePasses': _gameState.consecutivePasses,
          'legalMoves': legalMoveIndices,
        };
        final result = await _runner.search(
          AiSearchRequest(id: requestId, params: params),
        );
        searchError = result.error;
        final move = result.move;
        bestMove = move == null ? null : BoardPosition(move[0], move[1]);
      }

      // Clear the pending ID if it still matches (it may have been reset by
      // a cancel in _startNewGame / dispose).
      if (_pendingAiRequestId == requestId) _pendingAiRequestId = null;

      // Ensure a minimum thinking time so the AI feels human-like. If
      // computation finished faster than minMoveDelay, wait for the remainder.
      // The extra wait is capped so that elapsed + wait never exceeds
      // maxMoveDelay; if computation alone already took longer, no wait is added.
      final elapsed = thinkingStopwatch.elapsed;
      if (elapsed < minMoveDelay) {
        final remaining = minMoveDelay - elapsed;
        final cap =
            maxMoveDelay > elapsed ? maxMoveDelay - elapsed : Duration.zero;
        await Future.delayed(remaining < cap ? remaining : cap);
      }

      // Bail out if the provider was disposed or a new game started while we
      // were waiting — don't apply a stale move or call notifyListeners().
      if (!_isCurrentGame(generation)) return;

      if (searchError != null) {
        _aiFailureReason = searchError.toString();
      } else if (bestMove != null) {
        _aiFailureReason = null;
        _undoStack.add(_gameState);
        final newState = bestMove == territoryPassMove
            ? GoEngine.passTurn(_gameState)
            : GoEngine.placeStone(_gameState, bestMove.row, bestMove.col);
        if (newState != null) {
          _gameState = newState;
          _moveLog.add([bestMove.row, bestMove.col]);
          _checkWinCondition();
        }
      }
    } finally {
      // Always reset the thinking flag and notify listeners, unless the
      // provider was disposed or superseded by a newer game generation (in
      // which case the bail-out return above already fired and the provider
      // state is either gone or owned by the new game).
      if (_isCurrentGame(generation)) {
        _isAiThinking = false;
        notifyListeners();
      }
    }
  }

  /// Returns true when this provider instance is still alive and [generation]
  /// matches the current game generation — i.e. a move computed for this
  /// generation is still valid to apply.
  bool _isCurrentGame(int generation) =>
      !_disposed && _gameGeneration == generation;

  bool get _usesAsyncAlgorithmAgent =>
      aiAlgorithmConfig?.frameworkId == AiAlgorithmFrameworkId.katago ||
      aiAlgorithmConfig?.frameworkId == AiAlgorithmFrameworkId.capture5;

  AiAlgorithmConfig get _katagoCoachConfig =>
      AiAlgorithmRegistry.configById(_katagoCoachConfigId);

  bool get _usesKatagoTrainingCoach =>
      gameMode == GameMode.territory && isTerritoryMode;

  bool get _shouldTryNativeKatagoCoach =>
      _usesKatagoTrainingCoach &&
      !kIsWeb &&
      (aiAlgorithmConfig != null || _katagoModelAdapterOverride != null);

  void _checkWinCondition() {
    if (isTerritoryMode) {
      if (_gameState.consecutivePasses < 2) return;
      final score = territoryScore;
      if (score.blackArea > score.whiteArea) {
        _result = CaptureGameResult.blackWins;
      } else if (score.whiteArea > score.blackArea) {
        _result = CaptureGameResult.whiteWins;
      } else {
        _result = CaptureGameResult.draw;
      }
      return;
    }
    if (_gameState.capturedByBlack.length >= captureTarget) {
      _result = CaptureGameResult.blackWins;
    } else if (_gameState.capturedByWhite.length >= captureTarget) {
      _result = CaptureGameResult.whiteWins;
    }
  }
}
