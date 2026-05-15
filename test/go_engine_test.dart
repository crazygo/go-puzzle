import 'package:flutter_test/flutter_test.dart';

import 'package:go_puzzle/game/game_mode.dart';
import 'package:go_puzzle/game/go_engine.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:go_puzzle/models/game_state.dart';

void main() {
  group('GoEngine', () {
    test('adjacentPositions returns correct neighbors for interior point', () {
      final adj = GoEngine.adjacentPositions(4, 4, 9);
      expect(adj.length, 4);
      expect(
          adj,
          containsAll([
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
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      // White at (4,4), surrounded by black on 3 sides, black plays to capture
      board[4][4] = StoneColor.white;
      board[3][4] = StoneColor.black;
      board[4][3] = StoneColor.black;
      board[5][4] = StoneColor.black;
      // Playing (4,5) captures white → not suicide
      expect(GoEngine.isSuicide(board, 4, 5, StoneColor.black, 9), isFalse);
    });

    test('placeStone captures opponent with no liberties', () {
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

    test('passTurn increments consecutive passes and flips player', () {
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      final state = GameState(
        boardSize: 9,
        board: board,
        currentPlayer: StoneColor.black,
        gameMode: GameMode.territory,
      );

      final passed = GoEngine.passTurn(state);
      expect(passed, isNotNull);
      expect(passed!.currentPlayer, StoneColor.white);
      expect(passed.consecutivePasses, 1);
    });

    test('computeTerritoryScore counts surrounded empty points', () {
      final board = List.generate(5, (_) => List.filled(5, StoneColor.empty));
      for (final (row, col) in [
        (1, 1),
        (1, 2),
        (1, 3),
        (2, 1),
        (2, 3),
        (3, 1),
        (3, 2),
        (3, 3),
      ]) {
        board[row][col] = StoneColor.black;
      }
      board[0][0] = StoneColor.white;

      final state = GameState(
        boardSize: 5,
        board: board,
        currentPlayer: StoneColor.black,
        gameMode: GameMode.territory,
      );

      final score = GoEngine.computeTerritoryScore(state);
      expect(score.blackTerritory, 1);
      expect(score.whiteTerritory, 0);
      expect(score.blackArea, 9);
    });
  });
}
