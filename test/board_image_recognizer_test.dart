import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/board_image_recognizer.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:image/image.dart' as img;

void main() {
  test('recognizes board size and major stones from synthetic 9x9 board', () {
    final bytes = _buildSyntheticBoardImage(
      boardSize: 9,
      blackStones: const [
        BoardPosition(4, 4),
        BoardPosition(4, 5),
        BoardPosition(5, 5),
      ],
      whiteStones: const [
        BoardPosition(3, 4),
        BoardPosition(5, 4),
      ],
    );

    final result = BoardImageRecognizer.recognize(bytes);

    expect(result.boardSize, 9);
    expect(
        _countStones(result.board, StoneColor.black), greaterThanOrEqualTo(1));
    expect(
        _countStones(result.board, StoneColor.white), greaterThanOrEqualTo(1));
  });
}

int _countStones(List<List<StoneColor>> board, StoneColor color) {
  var count = 0;
  for (final row in board) {
    for (final cell in row) {
      if (cell == color) count++;
    }
  }
  return count;
}

Uint8List _buildSyntheticBoardImage({
  required int boardSize,
  required List<BoardPosition> blackStones,
  required List<BoardPosition> whiteStones,
}) {
  const width = 900;
  const height = 900;
  final image = img.Image(width: width, height: height);

  final bgColor = img.ColorRgb8(236, 228, 208);
  img.fill(image, color: bgColor);

  const left = 120;
  const top = 120;
  const side = 660;
  final step = side / (boardSize - 1);

  img.fillRect(
    image,
    x1: left,
    y1: top,
    x2: left + side,
    y2: top + side,
    color: img.ColorRgb8(226, 189, 125),
  );

  for (int i = 0; i < boardSize; i++) {
    final p = (left + i * step).round();
    img.drawLine(
      image,
      x1: p,
      y1: top,
      x2: p,
      y2: top + side,
      color: img.ColorRgb8(126, 94, 35),
      thickness: 2,
    );
    img.drawLine(
      image,
      x1: left,
      y1: p,
      x2: left + side,
      y2: p,
      color: img.ColorRgb8(126, 94, 35),
      thickness: 2,
    );
  }

  final radius = (step * 0.44).round();
  for (final pos in blackStones) {
    final cx = (left + pos.col * step).round();
    final cy = (top + pos.row * step).round();
    img.fillCircle(
      image,
      x: cx,
      y: cy,
      radius: radius,
      color: img.ColorRgb8(32, 32, 32),
    );
  }

  for (final pos in whiteStones) {
    final cx = (left + pos.col * step).round();
    final cy = (top + pos.row * step).round();
    img.fillCircle(
      image,
      x: cx,
      y: cy,
      radius: radius,
      color: img.ColorRgb8(236, 236, 236),
    );
  }

  return Uint8List.fromList(img.encodePng(image));
}
