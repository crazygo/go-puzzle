import '../models/board_position.dart';
import '../models/game_state.dart';

class TerritoryScore {
  const TerritoryScore({
    required this.blackArea,
    required this.whiteArea,
    required this.blackTerritory,
    required this.whiteTerritory,
    required this.blackStones,
    required this.whiteStones,
    required this.neutralPoints,
  });

  final int blackArea;
  final int whiteArea;
  final int blackTerritory;
  final int whiteTerritory;
  final int blackStones;
  final int whiteStones;
  final int neutralPoints;

  int marginFor(StoneColor color) {
    return switch (color) {
      StoneColor.black => blackArea - whiteArea,
      StoneColor.white => whiteArea - blackArea,
      StoneColor.empty => 0,
    };
  }
}

/// Core Go game engine implementing the rules of Go.
/// Handles stone placement, group detection, liberty counting, and captures.
class GoEngine {
  static bool _isWithinBoard(int row, int col, int boardSize) {
    return row >= 0 && row < boardSize && col >= 0 && col < boardSize;
  }

  /// Returns all adjacent positions (up, down, left, right) within board bounds.
  static List<BoardPosition> adjacentPositions(
    int row,
    int col,
    int boardSize,
  ) {
    final positions = <BoardPosition>[];
    if (row > 0) positions.add(BoardPosition(row - 1, col));
    if (row < boardSize - 1) positions.add(BoardPosition(row + 1, col));
    if (col > 0) positions.add(BoardPosition(row, col - 1));
    if (col < boardSize - 1) positions.add(BoardPosition(row, col + 1));
    return positions;
  }

  /// Finds all stones in the same group as (row, col) using flood-fill BFS.
  static Set<BoardPosition> findGroup(
    List<List<StoneColor>> board,
    int row,
    int col,
    int boardSize,
  ) {
    final color = board[row][col];
    if (color == StoneColor.empty) return {};

    final group = <BoardPosition>{};
    final queue = [BoardPosition(row, col)];
    group.add(BoardPosition(row, col));

    while (queue.isNotEmpty) {
      final pos = queue.removeLast();
      for (final adj in adjacentPositions(pos.row, pos.col, boardSize)) {
        if (!group.contains(adj) && board[adj.row][adj.col] == color) {
          group.add(adj);
          queue.add(adj);
        }
      }
    }
    return group;
  }

  /// Counts the liberties (empty adjacent points) for a group.
  static int countLiberties(
    List<List<StoneColor>> board,
    Set<BoardPosition> group,
    int boardSize,
  ) {
    final liberties = <BoardPosition>{};
    for (final pos in group) {
      for (final adj in adjacentPositions(pos.row, pos.col, boardSize)) {
        if (board[adj.row][adj.col] == StoneColor.empty) {
          liberties.add(adj);
        }
      }
    }
    return liberties.length;
  }

  /// Returns true if placing a stone at (row, col) would be suicide
  /// (the placed stone's group would have 0 liberties after captures).
  static bool isSuicide(
    List<List<StoneColor>> board,
    int row,
    int col,
    StoneColor color,
    int boardSize,
  ) {
    // Simulate placement
    final testBoard = _copyBoard(board, boardSize);
    testBoard[row][col] = color;

    // Check if any opponent groups are captured
    final opponent = color.opponent;
    bool capturesOpponent = false;
    for (final adj in adjacentPositions(row, col, boardSize)) {
      if (testBoard[adj.row][adj.col] == opponent) {
        final group = findGroup(testBoard, adj.row, adj.col, boardSize);
        if (countLiberties(testBoard, group, boardSize) == 0) {
          capturesOpponent = true;
          // Remove the captured group to properly evaluate liberties
          for (final p in group) {
            testBoard[p.row][p.col] = StoneColor.empty;
          }
        }
      }
    }

    if (capturesOpponent) return false;

    // Check if own group has no liberties
    final ownGroup = findGroup(testBoard, row, col, boardSize);
    return countLiberties(testBoard, ownGroup, boardSize) == 0;
  }

  /// Validates a move and returns the resulting game state, or null if invalid.
  static GameState? placeStone(GameState state, int row, int col) {
    final board = state.board;
    final boardSize = state.boardSize;

    if (state.status != GameStatus.playing) return null;
    if (!_isWithinBoard(row, col, boardSize)) return null;

    // Check if position is occupied
    if (board[row][col] != StoneColor.empty) return null;

    final color = state.currentPlayer;

    // Check Ko rule: would this recreate the previous board state?
    // We'll check after applying the move

    // Check suicide rule
    if (isSuicide(board, row, col, color, boardSize)) return null;

    // Apply the move
    final newBoard = _copyBoard(board, boardSize);
    newBoard[row][col] = color;

    // Capture opponent groups with 0 liberties
    final opponent = color.opponent;
    final captured = <BoardPosition>[];
    for (final adj in adjacentPositions(row, col, boardSize)) {
      if (newBoard[adj.row][adj.col] == opponent) {
        final group = findGroup(newBoard, adj.row, adj.col, boardSize);
        if (countLiberties(newBoard, group, boardSize) == 0) {
          for (final p in group) {
            newBoard[p.row][p.col] = StoneColor.empty;
            captured.add(p);
          }
        }
      }
    }

    // Check Ko rule: new board state must not equal ko state
    if (state.koState != null &&
        _boardsEqual(newBoard, state.koState!, boardSize)) {
      return null;
    }

    // Determine ko state: if exactly 1 stone was captured, save previous board
    List<List<StoneColor>>? newKoState;
    if (captured.length == 1) {
      newKoState = board;
    }

    // Update captured lists
    final newCapturedByBlack = List<BoardPosition>.from(state.capturedByBlack);
    final newCapturedByWhite = List<BoardPosition>.from(state.capturedByWhite);
    if (color == StoneColor.black) {
      newCapturedByBlack.addAll(captured);
    } else {
      newCapturedByWhite.addAll(captured);
    }

    // Save current board to history
    final newHistory = List<List<List<StoneColor>>>.from(state.history)
      ..add(_copyBoard(board, boardSize));

    // Find stones in atari after this move
    final atariStones = _findAtariStones(newBoard, boardSize);

    // Determine game status
    GameStatus newStatus = state.status;
    if (state.targetCaptures.isNotEmpty) {
      final allTargetsCaptured = state.targetCaptures.every(
        (pos) => newBoard[pos.row][pos.col] == StoneColor.empty,
      );
      if (allTargetsCaptured) {
        newStatus = GameStatus.solved;
      }
    }

    return state.copyWith(
      board: newBoard,
      currentPlayer: opponent,
      capturedByBlack: newCapturedByBlack,
      capturedByWhite: newCapturedByWhite,
      history: newHistory,
      lastMove: BoardPosition(row, col),
      koState: newKoState,
      status: newStatus,
      atariStones: atariStones,
      consecutivePasses: 0,
    );
  }

  /// Passes the turn without changing the board.
  static GameState? passTurn(GameState state) {
    if (state.status != GameStatus.playing) return null;
    final newHistory = List<List<List<StoneColor>>>.from(state.history)
      ..add(_copyBoard(state.board, state.boardSize));
    return state.copyWith(
      currentPlayer: state.currentPlayer.opponent,
      history: newHistory,
      koState: null,
      status: GameStatus.playing,
      atariStones: _findAtariStones(state.board, state.boardSize),
      consecutivePasses: state.consecutivePasses + 1,
    );
  }

  /// Undoes the last move by restoring the previous board from history.
  static GameState? undoMove(GameState state) {
    if (state.history.isEmpty) return null;

    final previousBoard = state.history.last;
    final newHistory = List<List<List<StoneColor>>>.from(state.history)
      ..removeLast();

    // Recalculate captures based on board differences
    // Simply recalculate atari stones
    final atariStones = _findAtariStones(previousBoard, state.boardSize);

    return state.copyWith(
      board: previousBoard,
      currentPlayer: state.currentPlayer.opponent,
      history: newHistory,
      koState: null,
      status: GameStatus.playing,
      atariStones: atariStones,
      consecutivePasses: 0,
    );
  }

  static TerritoryScore computeTerritoryScore(GameState state) {
    final board = state.board;
    final boardSize = state.boardSize;
    final visited = <BoardPosition>{};
    var blackStones = 0;
    var whiteStones = 0;
    var blackTerritory = 0;
    var whiteTerritory = 0;
    var neutralPoints = 0;

    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final color = board[r][c];
        if (color == StoneColor.black) {
          blackStones++;
          continue;
        }
        if (color == StoneColor.white) {
          whiteStones++;
          continue;
        }

        final origin = BoardPosition(r, c);
        if (visited.contains(origin)) continue;
        final region = <BoardPosition>{};
        final borderColors = <StoneColor>{};
        final queue = <BoardPosition>[origin];
        visited.add(origin);
        region.add(origin);

        while (queue.isNotEmpty) {
          final pos = queue.removeLast();
          for (final adj in adjacentPositions(pos.row, pos.col, boardSize)) {
            final adjacentColor = board[adj.row][adj.col];
            if (adjacentColor == StoneColor.empty) {
              if (visited.add(adj)) {
                region.add(adj);
                queue.add(adj);
              }
            } else {
              borderColors.add(adjacentColor);
            }
          }
        }

        if (borderColors.length == 1) {
          if (borderColors.contains(StoneColor.black)) {
            blackTerritory += region.length;
          } else if (borderColors.contains(StoneColor.white)) {
            whiteTerritory += region.length;
          }
        } else {
          neutralPoints += region.length;
        }
      }
    }

    return TerritoryScore(
      blackArea: blackStones + blackTerritory,
      whiteArea: whiteStones + whiteTerritory,
      blackTerritory: blackTerritory,
      whiteTerritory: whiteTerritory,
      blackStones: blackStones,
      whiteStones: whiteStones,
      neutralPoints: neutralPoints,
    );
  }

  /// Returns positions of all stones that are in atari (1 liberty).
  static List<BoardPosition> _findAtariStones(
    List<List<StoneColor>> board,
    int boardSize,
  ) {
    final atari = <BoardPosition>[];
    final visited = <BoardPosition>{};

    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] != StoneColor.empty) {
          final pos = BoardPosition(r, c);
          if (!visited.contains(pos)) {
            final group = findGroup(board, r, c, boardSize);
            visited.addAll(group);
            if (countLiberties(board, group, boardSize) == 1) {
              atari.addAll(group);
            }
          }
        }
      }
    }
    return atari;
  }

  static List<List<StoneColor>> _copyBoard(
    List<List<StoneColor>> board,
    int boardSize,
  ) {
    return List.generate(
      boardSize,
      (r) => List<StoneColor>.from(board[r]),
    );
  }

  static bool _boardsEqual(
    List<List<StoneColor>> a,
    List<List<StoneColor>> b,
    int boardSize,
  ) {
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
  }
}
