import 'dart:typed_data';

import 'mcts_engine.dart';

class KatagoOnnxFeatures {
  const KatagoOnnxFeatures({
    required this.binInput,
    required this.globalInput,
    required this.binShape,
    required this.globalShape,
  });

  final Float32List binInput;
  final Float32List globalInput;
  final List<int> binShape;
  final List<int> globalShape;
}

class KatagoOnnxFeatureEncoder {
  const KatagoOnnxFeatureEncoder();

  KatagoOnnxFeatures encode(SimBoard board) {
    final size = board.size;
    final currentPlayer = board.currentPlayer;
    final opponent =
        currentPlayer == SimBoard.black ? SimBoard.white : SimBoard.black;
    final binInput = Float32List(1 * 22 * size * size);
    final globalInput = Float32List(19);

    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        _setPlane(binInput, size, 0, row, col, 1);
      }
    }
    for (var index = 0; index < board.cells.length; index++) {
      final row = index ~/ size;
      final col = index % size;
      final value = board.cells[index];
      if (value == currentPlayer) {
        _setPlane(binInput, size, 1, row, col, 1);
      } else if (value == opponent) {
        _setPlane(binInput, size, 2, row, col, 1);
      } else {
        _setPlane(binInput, size, 3, row, col, 1);
      }
    }

    globalInput[0] = 1;
    globalInput[1] = currentPlayer == SimBoard.black ? 1 : -1;
    globalInput[2] = size.toDouble();

    return KatagoOnnxFeatures(
      binInput: binInput,
      globalInput: globalInput,
      binShape: [1, 22, size, size],
      globalShape: const [1, 19],
    );
  }

  void _setPlane(
    Float32List input,
    int size,
    int plane,
    int row,
    int col,
    double value,
  ) {
    input[plane * size * size + row * size + col] = value;
  }
}
