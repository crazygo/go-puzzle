import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture5_onnx_features.dart';
import 'package:go_puzzle/game/mcts_engine.dart';

void main() {
  group('Capture5FeatureEncoder', () {
    test(
        'encodes the 11-plane input shapes and globals for a 13x13 capture board',
        () {
      final board = SimBoard(13, captureTarget: 5);
      board.cells[board.idx(6, 6)] = SimBoard.black;
      board.cells[board.idx(6, 7)] = SimBoard.white;
      board.currentPlayer = SimBoard.white;
      board.capturedByBlack = 2;
      board.capturedByWhite = 1;

      final encoded = const Capture5FeatureEncoder().encode(board);

      expect(encoded.featuresShape, [1, 11, 13, 13]);
      expect(encoded.features.length, 11 * 13 * 13);
      expect(encoded.globalsShape, [1, 6]);
      expect(encoded.globals, [
        13 / 19,
        0.5,
        0.4,
        0.2,
        -1.0,
        5 / (13 * 13 * 2),
      ]);
      expect(encoded.features[board.idx(6, 6)], 1);
      expect(encoded.features[13 * 13 + board.idx(6, 7)], 1);
      expect(encoded.features[2 * 13 * 13], -1);
      expect(encoded.features.skip(9 * 13 * 13), everyElement(0));
    });

    test('marks all legal board moves but never includes the pass output', () {
      final board = SimBoard(13, captureTarget: 5);
      final legalMoves = Capture5FeatureEncoder.legalBoardMoveIndices(board);

      expect(legalMoves, hasLength(13 * 13));
      expect(legalMoves, isNot(contains(Capture5FeatureEncoder.passMoveIndex)));

      final encoded = const Capture5FeatureEncoder().encode(board);
      const legalPlaneOffset = 4 * 13 * 13;
      expect(encoded.features[legalPlaneOffset], 1);
      expect(encoded.features[legalPlaneOffset + 168], 1);
    });

    test(
        'adds own and opponent ladder group planes without changing legacy planes',
        () {
      final board = SimBoard(13, captureTarget: 5);
      void setStone(int row, int col, int color) {
        board.cells[board.idx(row, col)] = color;
      }

      setStone(5, 1, SimBoard.black);
      setStone(6, 0, SimBoard.black);
      setStone(6, 2, SimBoard.black);
      setStone(7, 0, SimBoard.black);
      setStone(7, 3, SimBoard.black);
      setStone(8, 2, SimBoard.black);
      setStone(6, 1, SimBoard.white);
      setStone(7, 1, SimBoard.white);
      setStone(7, 2, SimBoard.white);
      board.currentPlayer = SimBoard.black;

      final encoded = const Capture5FeatureEncoder().encode(board);
      const total = 13 * 13;

      expect(encoded.features[10 * total + board.idx(6, 1)], 1);
      expect(encoded.features[10 * total + board.idx(7, 1)], 1);
      expect(encoded.features[10 * total + board.idx(7, 2)], 1);
      expect(encoded.features[9 * total + board.idx(6, 1)], 0);
      expect(encoded.features.take(9 * total).length, 9 * total);
    });

    test('rejects unsupported board sizes', () {
      expect(
        () => const Capture5FeatureEncoder().encode(SimBoard(9)),
        throwsArgumentError,
      );
    });
  });
}
