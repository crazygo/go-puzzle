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

class CaptureGameProvider extends ChangeNotifier {
  CaptureGameProvider({
    required this.boardSize,
    required this.captureTarget,
    required this.difficulty,
  })  : assert(
          boardSize == 9 || boardSize == 13 || boardSize == 19,
          'boardSize must be 9, 13, or 19.',
        ),
        assert(captureTarget > 0, 'captureTarget must be greater than 0.') {
    _startNewGame();
  }

  final int boardSize;
  final int captureTarget;
  final DifficultyLevel difficulty;
  CaptureAiStyle _aiStyle = CaptureAiStyle.hunter;
  CaptureAiAgent? _cachedAgent;

  late GameState _gameState;
  CaptureGameResult _result = CaptureGameResult.none;
  bool _isAiThinking = false;
  final List<GameState> _undoStack = [];

  GameState get gameState => _gameState;
  CaptureGameResult get result => _result;
  bool get isAiThinking => _isAiThinking;
  bool get canUndo => _undoStack.isNotEmpty && !_isAiThinking;
  CaptureAiStyle get aiStyle => _aiStyle;

  CaptureAiAgent get _activeAgent {
    return _cachedAgent ??=
        CaptureAiRegistry.create(style: _aiStyle, difficulty: difficulty);
  }

  void newGame() => _startNewGame();

  void setAiStyle(CaptureAiStyle style) {
    if (_aiStyle == style) return;
    _aiStyle = style;
    _cachedAgent = null;
    notifyListeners();
  }

  Future<bool> placeStone(int row, int col) async {
    if (_isAiThinking || _result != CaptureGameResult.none) return false;
    if (_gameState.currentPlayer != StoneColor.black) return false;

    final newState = GoEngine.placeStone(_gameState, row, col);
    if (newState == null) return false;

    _undoStack.add(_gameState);
    _gameState = newState;
    _checkWinCondition();
    notifyListeners();

    if (_result == CaptureGameResult.none) {
      await _doAiMove();
    }
    return true;
  }

  void undoMove() {
    if (!canUndo) return;
    _gameState = _undoStack.removeLast();
    _result = CaptureGameResult.none;
    notifyListeners();
  }

  List<BoardPosition> suggestMoves({int count = 3}) {
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
  Future<List<BoardPosition>> suggestMovesAsync({int count = 3}) async {
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
    _gameState = GameState(
      boardSize: boardSize,
      board: emptyBoard,
      currentPlayer: StoneColor.black,
    );
    _result = CaptureGameResult.none;
    _isAiThinking = false;
    _undoStack.clear();
    notifyListeners();
  }

  Future<void> _doAiMove() async {
    _isAiThinking = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 80));

    final simBoard =
        SimBoard.fromGameState(_gameState, captureTarget: captureTarget);
    final bestMove = _activeAgent.chooseMove(simBoard)?.position;

    if (bestMove != null) {
      _undoStack.add(_gameState);
      final newState =
          GoEngine.placeStone(_gameState, bestMove.row, bestMove.col);
      if (newState != null) {
        _gameState = newState;
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
