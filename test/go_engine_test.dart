import 'package:flutter_test/flutter_test.dart';

import 'package:go_puzzle/game/go_engine.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:go_puzzle/models/game_state.dart';
import 'package:go_puzzle/models/puzzle.dart';

void main() {
  group('GoEngine', () {
    test('adjacentPositions returns correct neighbors for interior point', () {
      final adj = GoEngine.adjacentPositions(4, 4, 9);
      expect(adj.length, 4);
      expect(adj, containsAll([
        const BoardPosition(3, 4),
        const BoardPosition(5, 4),
        const BoardPosition(4, 3),
        const BoardPosition(4, 5),
      ]));
    });

    test('adjacentPositions returns 2 neighbors for corner', () {
      final adj = GoEngine.adjacentPositions(0, 0, 9);
      expect(adj.length, 2);
    });

    test('adjacentPositions returns 3 neighbors for edge', () {
      final adj = GoEngine.adjacentPositions(0, 4, 9);
      expect(adj.length, 3);
    });

    test('findGroup finds connected stones', () {
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      board[3][3] = StoneColor.black;
      board[3][4] = StoneColor.black;
      board[3][5] = StoneColor.black;
      board[4][5] = StoneColor.black; // L-shaped group

      final group = GoEngine.findGroup(board, 3, 3, 9);
      expect(group.length, 4);
      expect(group, contains(const BoardPosition(3, 3)));
      expect(group, contains(const BoardPosition(3, 4)));
      expect(group, contains(const BoardPosition(3, 5)));
      expect(group, contains(const BoardPosition(4, 5)));
    });

    test('countLiberties counts empty adjacent points', () {
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      board[4][4] = StoneColor.black;
      final group = GoEngine.findGroup(board, 4, 4, 9);
      expect(GoEngine.countLiberties(board, group, 9), 4);
    });

    test('isSuicide returns true for suicidal move', () {
      // Surround a point so playing there would be suicidal
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      board[0][1] = StoneColor.white;
      board[1][0] = StoneColor.white;
      // Corner at (0,0) is surrounded by white on two sides → suicide for black
      final suicide = GoEngine.isSuicide(board, 0, 0, StoneColor.black, 9);
      expect(suicide, isTrue);
    });

    test('isSuicide returns false for capture move', () {
      // White stone surrounded by black, placing black captures it (not suicide)
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      board[0][0] = StoneColor.white;
      board[0][1] = StoneColor.black;
      board[1][0] = StoneColor.black;
      // Placing black at (0,0) would capture white, not suicide
      final suicide = GoEngine.isSuicide(board, 0, 1, StoneColor.black, 9);
      // (0,1) already has a stone, so test a different scenario:
      // White at (4,4), surrounded by black on 3 sides, black plays to capture
      board[4][4] = StoneColor.white;
      board[3][4] = StoneColor.black;
      board[4][3] = StoneColor.black;
      board[5][4] = StoneColor.black;
      // Playing (4,5) captures white → not suicide
      expect(GoEngine.isSuicide(board, 4, 5, StoneColor.black, 9), isFalse);
    });

    test('placeStone captures opponent with no liberties', () {
      final puzzle = Puzzle(
        id: 'test',
        title: 'Test',
        description: '',
        boardSize: 9,
        initialStones: [
          const Stone(position: BoardPosition(0, 0), color: StoneColor.white),
          const Stone(position: BoardPosition(0, 1), color: StoneColor.black),
          const Stone(position: BoardPosition(1, 0), color: StoneColor.black),
        ],
        targetCaptures: [const BoardPosition(0, 0)],
        solutions: [],
        category: PuzzleCategory.beginner,
      );

      final state = GameState.initial(
        boardSize: 9,
        initialStones: puzzle.initialStones,
        targetCaptures: puzzle.targetCaptures,
      );

      // White at (0,0) has liberties at... nothing (corner surrounded by black)
      // Place black somewhere valid that captures white
      // Actually (0,0) already only has black neighbors, so placing black anywhere
      // won't capture since white isn't surrounded yet. Let's test proper capture:

      // New state: white at (4,4), black at (3,4),(4,3),(5,4) - 3 libs captured
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      board[4][4] = StoneColor.white;
      board[3][4] = StoneColor.black;
      board[4][3] = StoneColor.black;
      board[5][4] = StoneColor.black;

      final gameState = GameState(
        boardSize: 9,
        board: board,
        currentPlayer: StoneColor.black,
        targetCaptures: [const BoardPosition(4, 4)],
      );

      final newState = GoEngine.placeStone(gameState, 4, 5);
      expect(newState, isNotNull);
      expect(newState!.board[4][4], StoneColor.empty); // white captured
      expect(newState.capturedByBlack.length, 1);
      expect(newState.status, GameStatus.solved); // puzzle solved
    });

    test('undoMove restores previous board state', () {
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      final initialState = GameState(
        boardSize: 9,
        board: board,
        currentPlayer: StoneColor.black,
      );

      final afterMove = GoEngine.placeStone(initialState, 4, 4);
      expect(afterMove, isNotNull);
      expect(afterMove!.board[4][4], StoneColor.black);

      final undone = GoEngine.undoMove(afterMove);
      expect(undone, isNotNull);
      expect(undone!.board[4][4], StoneColor.empty);
    });
  });
}
