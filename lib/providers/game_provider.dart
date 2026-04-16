import 'package:flutter/foundation.dart';

import '../game/go_engine.dart';
import '../models/board_position.dart';
import '../models/game_state.dart';
import '../models/puzzle.dart';

enum PuzzleResult { none, solved, failed }

class GameProvider extends ChangeNotifier {
  Puzzle? _currentPuzzle;
  GameState? _gameState;
  PuzzleResult _result = PuzzleResult.none;
  List<BoardPosition> _playerMoves = [];
  bool _showingHint = false;
  BoardPosition? _hintPosition;

  Puzzle? get currentPuzzle => _currentPuzzle;
  GameState? get gameState => _gameState;
  PuzzleResult get result => _result;
  List<BoardPosition> get playerMoves => List.unmodifiable(_playerMoves);
  bool get showingHint => _showingHint;
  BoardPosition? get hintPosition => _hintPosition;

  void loadPuzzle(Puzzle puzzle) {
    _currentPuzzle = puzzle;
    _gameState = GameState.initial(
      boardSize: puzzle.boardSize,
      initialStones: puzzle.initialStones,
      targetCaptures: puzzle.targetCaptures,
    );
    _result = PuzzleResult.none;
    _playerMoves = [];
    _showingHint = false;
    _hintPosition = null;
    notifyListeners();
  }

  void resetPuzzle() {
    if (_currentPuzzle != null) {
      loadPuzzle(_currentPuzzle!);
    }
  }

  bool placeStone(int row, int col) {
    if (_gameState == null || _result != PuzzleResult.none) return false;

    final newState = GoEngine.placeStone(_gameState!, row, col);
    if (newState == null) return false; // invalid move

    _gameState = newState;
    _playerMoves.add(BoardPosition(row, col));
    _showingHint = false;
    _hintPosition = null;

    if (newState.status == GameStatus.solved) {
      _result = PuzzleResult.solved;
    }

    notifyListeners();
    return true;
  }

  void undoMove() {
    if (_gameState == null) return;
    final newState = GoEngine.undoMove(_gameState!);
    if (newState == null) return;
    _gameState = newState;
    if (_playerMoves.isNotEmpty) {
      _playerMoves.removeLast();
    }
    _result = PuzzleResult.none;
    notifyListeners();
  }

  void showHint() {
    if (_currentPuzzle == null || _gameState == null) return;
    if (_currentPuzzle!.solutions.isEmpty) return;

    // Find the first solution that matches moves played so far
    for (final solution in _currentPuzzle!.solutions) {
      if (_playerMoves.length < solution.length) {
        bool isPrefix = true;
        for (int i = 0; i < _playerMoves.length; i++) {
          if (_playerMoves[i] != solution[i]) {
            isPrefix = false;
            break;
          }
        }
        if (isPrefix) {
          _hintPosition = solution[_playerMoves.length];
          _showingHint = true;
          notifyListeners();
          return;
        }
      }
    }

    // If no matching solution, show first move of first solution
    if (_currentPuzzle!.solutions.isNotEmpty) {
      resetPuzzle();
      _hintPosition = _currentPuzzle!.solutions.first.first;
      _showingHint = true;
      notifyListeners();
    }
  }

  void dismissHint() {
    _showingHint = false;
    _hintPosition = null;
    notifyListeners();
  }
}
