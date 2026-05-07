import 'package:flutter/foundation.dart';

import '../game/capture_ai.dart';
import '../game/difficulty_level.dart';
import '../game/go_engine.dart';
import '../game/mcts_engine.dart';
import '../models/board_position.dart';
import '../models/game_state.dart';

export '../game/difficulty_level.dart';

// ---------------------------------------------------------------------------
// Top-level function required by compute() – runs in a background isolate.
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

  final sim = SimBoard(boardSize, captureTarget: captureTarget);
  for (int i = 0; i < cells.length; i++) {
    sim.cells[i] = cells[i];
  }
  sim.capturedByBlack = capturedByBlack;
  sim.capturedByWhite = capturedByWhite;
  sim.currentPlayer = currentPlayer;

  final suggestions = <List<int>>[];
  final primaryAgent =
      CaptureAiRegistry.create(style: aiStyle, difficulty: difficulty);
  final replyAgent = CaptureAiRegistry.create(
    style: CaptureAiStyle.counter,
    difficulty: DifficultyLevel.beginner,
  );
  for (int i = 0; i < count; i++) {
    final move = primaryAgent.chooseMove(sim)?.position;
    if (move == null) break;
    suggestions.add([move.row, move.col]);
    if (!sim.applyMove(move.row, move.col)) break;
    final whiteReply = replyAgent.chooseMove(sim)?.position;
    if (whiteReply == null || !sim.applyMove(whiteReply.row, whiteReply.col)) {
      break;
    }
  }
  return suggestions;
}

enum CaptureGameResult { none, blackWins, whiteWins }

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
  static const Duration _defaultMinMoveDelay = Duration(milliseconds: 800);
  static const Duration _defaultMaxMoveDelay = Duration(milliseconds: 2500);

  CaptureGameProvider({
    required this.boardSize,
    required this.captureTarget,
    required this.difficulty,
    this.humanColor = StoneColor.black,
    this.initialMode = CaptureInitialMode.cross,
    this.initialBoardOverride,
    this.initialPlayerOverride,
    this.minMoveDelay = _defaultMinMoveDelay,
    this.maxMoveDelay = _defaultMaxMoveDelay,
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
      Future<void>.microtask(_doAiMove);
    }
  }

  final int boardSize;
  final int captureTarget;
  final DifficultyLevel difficulty;
  final StoneColor humanColor;
  final CaptureInitialMode initialMode;
  final List<List<StoneColor>>? initialBoardOverride;
  final StoneColor? initialPlayerOverride;

  /// Minimum time between when the AI starts thinking and when it places its
  /// stone. If the computation finishes before this deadline the provider waits
  /// for the remaining time, keeping [isAiThinking] true so the UI can show a
  /// thinking indicator. Defaults to 800 ms. Pass [Duration.zero] in tests.
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

  late GameState _gameState;
  CaptureGameResult _result = CaptureGameResult.none;
  bool _isAiThinking = false;
  bool _disposed = false;

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
  bool get isPlacementMode => initialMode == CaptureInitialMode.setup;

  /// An unmodifiable view of the current game's move sequence.
  List<List<int>> get moveLog => List.unmodifiable(_moveLog);

  CaptureAiAgent get _activeAgent {
    return _cachedAgent ??=
        CaptureAiRegistry.create(style: _aiStyle, difficulty: difficulty);
  }

  void newGame() => _startNewGame();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void setAiStyle(CaptureAiStyle style) {
    if (_aiStyle == style) return;
    _aiStyle = style;
    _cachedAgent = null;
    notifyListeners();
  }

  Future<bool> placeStone(int row, int col) async {
    if (_isAiThinking || _result != CaptureGameResult.none) return false;
    if (!isPlacementMode && _gameState.currentPlayer != humanColor)
      return false;

    final newState = GoEngine.placeStone(_gameState, row, col);
    if (newState == null) return false;

    _undoStack.add(_gameState);
    _gameState = newState;
    _moveLog.add([row, col]);
    _checkWinCondition();
    notifyListeners();

    if (!isPlacementMode && _result == CaptureGameResult.none) {
      await _doAiMove();
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
      Future<void>.microtask(_doAiMove);
    }
  }

  List<BoardPosition> suggestMoves({int count = 1}) {
    if (count <= 0) return const [];

    final suggestions = <BoardPosition>[];
    final sim =
        SimBoard.fromGameState(_gameState, captureTarget: captureTarget);
    final replyAgent = CaptureAiRegistry.create(
      style: CaptureAiStyle.counter,
      difficulty: DifficultyLevel.beginner,
    );

    for (int i = 0; i < count; i++) {
      final move = _activeAgent.chooseMove(sim)?.position;
      if (move == null) break;
      suggestions.add(BoardPosition(move.row, move.col));

      // apply as black suggestion then let white respond lightly for diversity
      if (!sim.applyMove(move.row, move.col)) break;
      final whiteReply = replyAgent.chooseMove(sim)?.position;
      if (whiteReply == null ||
          !sim.applyMove(whiteReply.row, whiteReply.col)) {
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
      'count': count,
    };
    final raw = await compute(_runSuggestMoves, params);
    return raw.map((r) => BoardPosition(r[0], r[1])).toList();
  }

  Map<StoneColor, double> get winRateEstimate {
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
    );
    _result = CaptureGameResult.none;
    _isAiThinking = false;
    _gameGeneration++;
    _undoStack.clear();
    _moveLog.clear();
    notifyListeners();
  }

  Future<void> _doAiMove() async {
    _isAiThinking = true;
    notifyListeners();

    final generation = _gameGeneration;
    final thinkingStopwatch = Stopwatch()..start();

    final simBoard =
        SimBoard.fromGameState(_gameState, captureTarget: captureTarget);
    final bestMove = _activeAgent.chooseMove(simBoard)?.position;

    // Ensure a minimum thinking time so the AI feels human-like. If
    // computation finished faster than minMoveDelay, wait for the remainder.
    // The extra wait is capped so that elapsed + wait never exceeds
    // maxMoveDelay; if computation alone already took longer, no wait is added.
    final elapsed = thinkingStopwatch.elapsed;
    if (elapsed < minMoveDelay) {
      final remaining = minMoveDelay - elapsed;
      final cap = maxMoveDelay > elapsed ? maxMoveDelay - elapsed : Duration.zero;
      await Future.delayed(remaining < cap ? remaining : cap);
    }

    // Bail out if the provider was disposed or a new game started while we
    // were waiting — don't apply a stale move or call notifyListeners().
    if (_disposed || _gameGeneration != generation) return;

    if (bestMove != null) {
      _undoStack.add(_gameState);
      final newState =
          GoEngine.placeStone(_gameState, bestMove.row, bestMove.col);
      if (newState != null) {
        _gameState = newState;
        _moveLog.add([bestMove.row, bestMove.col]);
        _checkWinCondition();
      }
    }

    _isAiThinking = false;
    notifyListeners();
  }

  void _checkWinCondition() {
    if (_gameState.capturedByBlack.length >= captureTarget) {
      _result = CaptureGameResult.blackWins;
    } else if (_gameState.capturedByWhite.length >= captureTarget) {
      _result = CaptureGameResult.whiteWins;
    }
  }
}
