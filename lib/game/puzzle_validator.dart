import '../models/board_position.dart';
import '../models/game_state.dart';
import '../models/puzzle.dart';

/// Validates whether a player's sequence of moves solves a puzzle.
class PuzzleValidator {
  /// Checks if the given game state represents a solved puzzle.
  static bool isSolved(GameState state, Puzzle puzzle) {
    if (state.status == GameStatus.solved) return true;

    // Check if all target stones have been captured
    for (final target in puzzle.targetCaptures) {
      if (state.board[target.row][target.col] != StoneColor.empty) {
        return false;
      }
    }
    return puzzle.targetCaptures.isNotEmpty;
  }

  /// Returns a hint: the first move in the first valid solution that matches
  /// the moves already made by the player.
  static BoardPosition? getHint(
    GameState state,
    Puzzle puzzle,
    List<BoardPosition> movesPlayed,
  ) {
    for (final solution in puzzle.solutions) {
      if (_isPrefix(movesPlayed, solution)) {
        if (movesPlayed.length < solution.length) {
          return solution[movesPlayed.length];
        }
      }
    }
    return null;
  }

  static bool _isPrefix(
    List<BoardPosition> played,
    List<BoardPosition> solution,
  ) {
    if (played.length > solution.length) return false;
    for (int i = 0; i < played.length; i++) {
      if (played[i] != solution[i]) return false;
    }
    return true;
  }
}
