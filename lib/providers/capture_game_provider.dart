import 'package:flutter/foundation.dart';

import '../game/go_engine.dart';
import '../game/mcts_engine.dart';
import '../models/game_state.dart';

enum CaptureGameResult { none, blackWins, whiteWins }

enum DifficultyLevel {
  beginner, // 200 playouts
  advanced, // 2000 playouts
}

extension DifficultyLevelExt on DifficultyLevel {
  String get displayName {
    switch (this) {
      case DifficultyLevel.beginner:
        return '入门';
      case DifficultyLevel.advanced:
        return '进阶';
    }
  }

  int get maxPlayouts {
    switch (this) {
      case DifficultyLevel.beginner:
        return 200;
      case DifficultyLevel.advanced:
        return 2000;
    }
  }
}

/// Manages state for the "capture 5 stones" (吃5子) game mode.
///
/// The human plays Black, the MCTS AI plays White.
/// First side to capture ≥ 5 opponent stones wins.
class CaptureGameProvider extends ChangeNotifier {
  static const int captureTarget = 5;
  static const int boardSize = 19;

  late GameState _gameState;
  CaptureGameResult _result = CaptureGameResult.none;
  bool _isAiThinking = false;
  DifficultyLevel _difficulty = DifficultyLevel.beginner;

  /// Each entry is the full game state saved *before* a human move.
  /// Undoing restores to the last saved entry (undoing both the human move
  /// and the AI response in one step).
  final List<GameState> _undoStack = [];

  CaptureGameProvider() {
    _startNewGame();
  }

  GameState get gameState => _gameState;
  CaptureGameResult get result => _result;
  bool get isAiThinking => _isAiThinking;
  DifficultyLevel get difficulty => _difficulty;
  bool get canUndo => _undoStack.isNotEmpty && !_isAiThinking;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  void newGame() => _startNewGame();

  void setDifficulty(DifficultyLevel level) {
    if (_difficulty == level) return;
    _difficulty = level;
    notifyListeners();
  }

  /// Called when the human taps an intersection.
  /// Returns true if the move was accepted.
  Future<bool> placeStone(int row, int col) async {
    if (_isAiThinking || _result != CaptureGameResult.none) return false;
    if (_gameState.currentPlayer != StoneColor.black) return false;

    final newState = GoEngine.placeStone(_gameState, row, col);
    if (newState == null) return false;

    // Save state *before* the human move so undo can restore it.
    _undoStack.add(_gameState);

    _gameState = newState;
    _checkWinCondition();
    notifyListeners();

    if (_result == CaptureGameResult.none) {
      await _doAiMove();
    }

    return true;
  }

  /// Undoes the last human move together with the AI response.
  void undoMove() {
    if (!canUndo) return;
    _gameState = _undoStack.removeLast();
    _result = CaptureGameResult.none;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

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

    // Yield to the UI thread so the "thinking" indicator appears.
    await Future.delayed(const Duration(milliseconds: 80));

    final simBoard = SimBoard.fromGameState(_gameState);
    final engine = MctsEngine(maxPlayouts: _difficulty.maxPlayouts);
    final bestMove = engine.getBestMove(simBoard);

    if (bestMove != null) {
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
