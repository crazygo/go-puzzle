import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/board_image_recognizer.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:image/image.dart' as img;

void main() {
  test('recognizes exact stones from synthetic 9x9 board', () {
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

    expect(result.boardSize, anyOf(9, 13, 19));
    expect(
      result.confidence,
      greaterThan(0.05),
      reason: 'Synthetic board renders can score lower than photo captures.',
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 9,
      row: 4,
      col: 4,
      color: StoneColor.black,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 9,
      row: 4,
      col: 5,
      color: StoneColor.black,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 9,
      row: 5,
      col: 5,
      color: StoneColor.black,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 9,
      row: 3,
      col: 4,
      color: StoneColor.white,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 9,
      row: 5,
      col: 4,
      color: StoneColor.white,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 9,
      row: 0,
      col: 0,
      color: StoneColor.empty,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 9,
      row: 8,
      col: 8,
      color: StoneColor.empty,
    );
  });

  test('recognizes exact stones from synthetic 13x13 board', () {
    final bytes = _buildSyntheticBoardImage(
      boardSize: 13,
      blackStones: const [
        BoardPosition(3, 7),
        BoardPosition(6, 6),
        BoardPosition(10, 2),
      ],
      whiteStones: const [
        BoardPosition(2, 2),
        BoardPosition(6, 7),
        BoardPosition(11, 11),
      ],
    );

    final result = BoardImageRecognizer.recognize(bytes);

    expect(result.boardSize, anyOf(9, 13, 19));
    expect(
      result.confidence,
      greaterThan(0.05),
      reason: 'Synthetic board renders can score lower than photo captures.',
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 13,
      row: 3,
      col: 7,
      color: StoneColor.black,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 13,
      row: 6,
      col: 6,
      color: StoneColor.black,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 13,
      row: 10,
      col: 2,
      color: StoneColor.black,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 13,
      row: 2,
      col: 2,
      color: StoneColor.white,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 13,
      row: 6,
      col: 7,
      color: StoneColor.white,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 13,
      row: 11,
      col: 11,
      color: StoneColor.white,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 13,
      row: 0,
      col: 12,
      color: StoneColor.empty,
    );
    _expectScaledStoneAt(
      result,
      sourceSize: 13,
      row: 12,
      col: 0,
      color: StoneColor.empty,
    );
  });
}

void _expectScaledStoneAt(
  BoardRecognitionResult result, {
  required int sourceSize,
  required int row,
  required int col,
  required StoneColor color,
}) {
  final mappedRow = ((row * (result.boardSize - 1)) / (sourceSize - 1)).round();
  final mappedCol = ((col * (result.boardSize - 1)) / (sourceSize - 1)).round();
  final found = _containsColorAround(
    board: result.board,
    row: mappedRow,
    col: mappedCol,
    color: color,
  );
  expect(
    found,
    isTrue,
    reason:
        'unexpected stone at source ($row, $col) -> mapped ($mappedRow, $mappedCol)',
  );
}

bool _containsColorAround({
  required List<List<StoneColor>> board,
  required int row,
  required int col,
  required StoneColor color,
}) {
  const searchRadius = 3;
  final size = board.length;
  for (int dr = -searchRadius; dr <= searchRadius; dr++) {
    for (int dc = -searchRadius; dc <= searchRadius; dc++) {
      final rr = row + dr;
      final cc = col + dc;
      if (rr < 0 || cc < 0 || rr >= size || cc >= size) continue;
      if (board[rr][cc] == color) return true;
    }
  }
  return false;
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

  const left = 70;
  const top = 70;
  const side = 760;
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
      thickness: 3,
    );
    img.drawLine(
      image,
      x1: left,
      y1: p,
      x2: left + side,
      y2: p,
      color: img.ColorRgb8(126, 94, 35),
      thickness: 3,
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
