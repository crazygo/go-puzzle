import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/katago_onnx_features.dart';
import 'package:go_puzzle/game/mcts_engine.dart';

void main() {
  test('KataGo ONNX feature encoder produces expected tensor shapes', () {
    final board = SimBoard(9, captureTarget: 5);
    board.applyMove(4, 4);
    board.applyMove(4, 5);

    final features = const KatagoOnnxFeatureEncoder().encode(board);

    expect(features.binShape, [1, 22, 9, 9]);
    expect(features.globalShape, [1, 19]);
    expect(features.binInput.length, 1 * 22 * 9 * 9);
    expect(features.globalInput.length, 19);
    expect(features.globalInput[0], 1);
    expect(features.globalInput[2], 9);
  });
}
