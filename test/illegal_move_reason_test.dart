import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/go_engine.dart';
import 'package:go_puzzle/game/illegal_move_reason.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:go_puzzle/models/game_state.dart';

void main() {
  group('illegalMoveToastMessage', () {
    test('maps suicide reason', () {
      expect(
        illegalMoveToastMessage(IllegalMoveReason.suicide),
        '該手無氣，不能落子',
      );
    });
  });

  group('GoEngine.invalidMoveReason', () {
    test('detects occupied intersection', () {
      final board = List.generate(
        9,
        (_) => List.filled(9, StoneColor.empty),
      );
      board[4][4] = StoneColor.black;
      final state = GameState(
        boardSize: 9,
        board: board,
        currentPlayer: StoneColor.white,
      );

      expect(
        GoEngine.invalidMoveReason(state, 4, 4),
        IllegalMoveReason.occupied,
      );
    });

    test('detects suicide move', () {
      final board = List.generate(
        9,
        (_) => List.filled(9, StoneColor.empty),
      );
      board[0][1] = StoneColor.white;
      board[1][0] = StoneColor.white;
      final state = GameState(
        boardSize: 9,
        board: board,
        currentPlayer: StoneColor.black,
      );

      expect(
        GoEngine.invalidMoveReason(state, 0, 0),
        IllegalMoveReason.suicide,
      );
    });
  });

  group('SimBoard.illegalMoveReason', () {
    test('detects occupied intersection', () {
      final board = SimBoard(9, captureTarget: 5);
      board.cells[board.idx(4, 4)] = SimBoard.black;

      expect(
        board.illegalMoveReason(4, 4),
        IllegalMoveReason.occupied,
      );
    });

    test('detects suicide move', () {
      final board = SimBoard(9, captureTarget: 5);
      board.cells[board.idx(0, 1)] = SimBoard.white;
      board.cells[board.idx(1, 0)] = SimBoard.white;

      expect(
        board.illegalMoveReason(0, 0),
        IllegalMoveReason.suicide,
      );
    });
  });
}
