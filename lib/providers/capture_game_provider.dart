import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/ai_search_runner.dart';
import '../game/capture_ai.dart';
import '../game/difficulty_level.dart';
import '../game/game_mode.dart';
import '../game/go_engine.dart';
import '../game/mcts_engine.dart';
import '../game/territory_ai.dart';
import '../models/board_position.dart';
import '../models/game_state.dart';

export '../game/ai_search_runner.dart' show AiSearchRunner;
export '../game/difficulty_level.dart';

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
      ? CaptureAiRegistry.create(style: aiStyle, difficulty: difficulty)
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
    suggestions.add([move.row, move.col]);
    if (move == territoryPassMove) {
      sim.applyPass();
    } else if (!sim.applyMove(move.row, move.col)) {
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

class CaptureGameProvider extends ChangeNotifier {
  static const Duration _defaultMinMoveDelay = Duration(milliseconds: 1280);
  static const Duration _defaultMaxMoveDelay = Duration(milliseconds: 2500);
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
    this.minMoveDelay = _defaultMinMoveDelay,
    this.maxMoveDelay = _defaultMaxMoveDelay,
    AiSearchRunner? runner,
  })  : assert(
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
    if (initialBoardOverride != null &&
        !_isValidBoardShape(initialBoardOverride, boardSize)) {
      throw ArgumentError.value(
        initialBoardOverride,
        'initialBoardOverride',
        '棋盘尺寸与 boardSize 不一致。',
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

  late final AiSearchRunner _runner;

  /// Monotonically-increasing counter used to build unique request IDs.
  /// Unlike [_gameGeneration], this is never reset so each [_doAiMove] call
  /// gets a distinct identifier even within the same game.
  /// Dart's int is 64-bit; overflow is not a practical concern for a game app
  /// (would require ~9.2 × 10¹⁸ AI turns).
  int _requestCounter = 0;

  /// The request ID for the currently in-flight AI move search, or null.
  AiSearchRequestId? _pendingAiRequestId;

  late GameState _gameState;
  CaptureGameResult _result = CaptureGameResult.none;
  bool _isAiThinking = false;
  bool _disposed = false;
  Timer? _aiMoveTimer;

  /// Incremented every time a new game starts. In-flight [_doAiMove] tasks
  /// capture this value on entry and bail out if it has changed by the time
  /// the delay elapses, preventing stale moves from being applied to a new game.
  int _gameGeneration = 0;

  final List<GameState> _undoStack = [];

  /// Every move played in the current game, in order: each entry is [row, col].
  final List<List<int>> _moveLog = [];

  GameState get gameState => _gameState;
  CaptureGameResult get result => _result;
  bool get isAiThinking => _isAiThinking;
  bool get canUndo => _undoStack.isNotEmpty && !_isAiThinking;
  CaptureAiStyle get aiStyle => _aiStyle;
  GameMode get mode => gameMode;
  bool get isTerritoryMode => gameMode == GameMode.territory;
  bool get isPlacementMode => initialMode == CaptureInitialMode.setup;

  /// An unmodifiable view of the current game's move sequence.
  List<List<int>> get moveLog => List.unmodifiable(_moveLog);

  CaptureAiAgent get _activeAgent {
    return _cachedAgent ??=
        CaptureAiRegistry.create(style: _aiStyle, difficulty: difficulty);
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
    _runner.dispose();
    super.dispose();
  }

  void setAiStyle(CaptureAiStyle style) {
    if (isTerritoryMode) return;
    if (_aiStyle == style) return;
    _aiStyle = style;
    _cachedAgent = null;
    notifyListeners();
  }

  Future<bool> placeStone(int row, int col) async {
    if (_isAiThinking || _result != CaptureGameResult.none) return false;
    if (!isPlacementMode && _gameState.currentPlayer != humanColor) {
      return false;
    }

    final newState = GoEngine.placeStone(_gameState, row, col);
    if (newState == null) return false;

    _undoStack.add(_gameState);
    _gameState = newState;
    _moveLog.add([row, col]);
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
        _gameState.currentPlayer != humanColor) {
      return false;
    }
    final newState = GoEngine.passTurn(_gameState);
    if (newState == null) return false;
    _undoStack.add(_gameState);
    _gameState = newState;
    _moveLog.add(const [-1, -1]);
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
      suggestions.add(BoardPosition(move.row, move.col));

      if (move == territoryPassMove) {
        sim.applyPass();
      } else if (!sim.applyMove(move.row, move.col)) {
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
    final params = <String, dynamic>{
      'cells': sim.cells.toList(),
      'boardSize': sim.size,
      'captureTarget': sim.captureTarget,
      'capturedByBlack': sim.capturedByBlack,
      'capturedByWhite': sim.capturedByWhite,
      'currentPlayer': sim.currentPlayer,
      'aiStyle': _aiStyle.name,
      'difficulty': difficulty.name,
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
    _result = CaptureGameResult.none;
    _isAiThinking = false;
    _gameGeneration++;
    _undoStack.clear();
    _moveLog.clear();
    notifyListeners();
  }

  void _scheduleAiMove() {
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
      final params = <String, dynamic>{
        'boardSize': _gameState.boardSize,
        'captureTarget': captureTarget,
        'cells':
            _gameState.board.expand((row) => row.map((s) => s.index)).toList(),
        'capturedByBlack': _gameState.capturedByBlack.length,
        'capturedByWhite': _gameState.capturedByWhite.length,
        'currentPlayer': _gameState.currentPlayer.index,
        'aiStyle':
            isTerritoryMode ? CaptureAiStyle.adaptive.name : _aiStyle.name,
        'difficulty': difficulty.name,
        'gameMode': gameMode.storageKey,
        'consecutivePasses': _gameState.consecutivePasses,
        'legalMoves': simBoard.getLegalMoves(),
      };
      final result = await _runner.search(
        AiSearchRequest(id: requestId, params: params),
      );

      // Clear the pending ID if it still matches (it may have been reset by
      // a cancel in _startNewGame / dispose).
      if (_pendingAiRequestId == requestId) _pendingAiRequestId = null;

      final move = result.move;
      final bestMove = move == null ? null : BoardPosition(move[0], move[1]);

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

      if (bestMove != null && !result.hasError) {
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
