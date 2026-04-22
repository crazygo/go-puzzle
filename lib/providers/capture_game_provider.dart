import 'package:flutter/foundation.dart';

import '../game/go_engine.dart';
import '../game/mcts_engine.dart';
import '../models/board_position.dart';
import '../models/game_state.dart';

enum CaptureGameResult { none, blackWins, whiteWins }

enum DifficultyLevel {
  beginner,
  intermediate,
  advanced,
}

extension DifficultyLevelExt on DifficultyLevel {
  String get displayName {
    switch (this) {
      case DifficultyLevel.beginner:
        return '初级';
      case DifficultyLevel.intermediate:
        return '中级';
      case DifficultyLevel.advanced:
        return '高级';
    }
  }

  int get maxPlayouts {
    switch (this) {
      case DifficultyLevel.beginner:
        return 250;
      case DifficultyLevel.intermediate:
        return 900;
      case DifficultyLevel.advanced:
        return 2200;
    }
  }
}

class CaptureGameProvider extends ChangeNotifier {
  CaptureGameProvider({
    required this.boardSize,
    required this.captureTarget,
    required this.difficulty,
  }) {
    _startNewGame();
  }

  final int boardSize;
  final int captureTarget;
  final DifficultyLevel difficulty;

  late GameState _gameState;
  CaptureGameResult _result = CaptureGameResult.none;
  bool _isAiThinking = false;
  final List<GameState> _undoStack = [];

  GameState get gameState => _gameState;
  CaptureGameResult get result => _result;
  bool get isAiThinking => _isAiThinking;
  bool get canUndo => _undoStack.isNotEmpty && !_isAiThinking;

  void newGame() => _startNewGame();

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
    final suggestions = <BoardPosition>[];
    var sim = SimBoard.fromGameState(_gameState);

    for (int i = 0; i < count; i++) {
      final engine = MctsEngine(maxPlayouts: difficulty.maxPlayouts ~/ 3);
      final move = engine.getBestMove(sim);
      if (move == null) break;
      suggestions.add(BoardPosition(move.row, move.col));

      // apply as black suggestion then let white respond lightly for diversity
      if (!sim.applyMove(move.row, move.col)) break;
      final whiteReply = MctsEngine(maxPlayouts: 120).getBestMove(sim);
      if (whiteReply == null || !sim.applyMove(whiteReply.row, whiteReply.col)) {
        break;
      }
    }
    return suggestions;
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

    final simBoard = SimBoard.fromGameState(_gameState);
    final engine = MctsEngine(maxPlayouts: difficulty.maxPlayouts);
    final bestMove = engine.getBestMove(simBoard);

    if (bestMove != null) {
      _undoStack.add(_gameState);
      final newState = GoEngine.placeStone(_gameState, bestMove.row, bestMove.col);
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
