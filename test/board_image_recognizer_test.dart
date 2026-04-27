import 'dart:io';
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

    expect(result.boardSize, equals(9));
    expect(result.confidence, greaterThan(0.05));
    expect(_extractStoneSet(result.board, StoneColor.black), {
      const _Pos(4, 4),
      const _Pos(4, 5),
      const _Pos(5, 5),
    });
    expect(_extractStoneSet(result.board, StoneColor.white), {
      const _Pos(3, 4),
      const _Pos(5, 4),
    });
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

    expect(result.boardSize, equals(13));
    expect(result.confidence, greaterThan(0.05));
    expect(_extractStoneSet(result.board, StoneColor.black), {
      const _Pos(3, 7),
      const _Pos(6, 6),
      const _Pos(10, 2),
    });
    expect(_extractStoneSet(result.board, StoneColor.white), {
      const _Pos(2, 2),
      const _Pos(6, 7),
      const _Pos(11, 11),
    });
  });

  test('real screenshot dataset pass rate is 100%', () {
    final sampleDir = Directory('test/assets/recognition_samples');
    final txtFiles = sampleDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    expect(txtFiles, isNotEmpty, reason: 'Recognition sample txt files are required');

    var passed = 0;
    final details = <String>[];

    for (final txt in txtFiles) {
      final base = txt.path.substring(0, txt.path.length - 4);
      final png = File('$base.png');
      expect(png.existsSync(), isTrue, reason: 'Missing png for ${txt.path}');

      final expected = _parseGroundTruth(txt.readAsStringSync());
      final result = BoardImageRecognizer.recognize(png.readAsBytesSync());

      final actualBlack = _extractStoneSet(result.board, StoneColor.black);
      final actualWhite = _extractStoneSet(result.board, StoneColor.white);

      final passedOne = result.boardSize == expected.boardSize &&
          _unorderedSetEquals(actualBlack, expected.black) &&
          _unorderedSetEquals(actualWhite, expected.white);

      if (passedOne) {
        passed++;
      } else {
        details.add(
          '${png.uri.pathSegments.last}: expected size=${expected.boardSize}, '
          'black=${expected.black.length}, white=${expected.white.length}; '
          'actual size=${result.boardSize}, black=${actualBlack.length}, '
          'white=${actualWhite.length}',
        );
      }
    }

    final passRate = passed / txtFiles.length;
    expect(
      passRate,
      equals(1.0),
      reason:
          'pass=$passed/${txtFiles.length}. failed details: ${details.join(' | ')}',
    );
  });
}

class _ExpectedBoard {
  const _ExpectedBoard({
    required this.boardSize,
    required this.black,
    required this.white,
  });

  final int boardSize;
  final Set<_Pos> black;
  final Set<_Pos> white;
}

_ExpectedBoard _parseGroundTruth(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final sizeLine = lines.firstWhere(
    (l) => l.toLowerCase().startsWith('size '),
    orElse: () => throw FormatException('Missing `Size N` line'),
  );
  final boardSize = int.parse(sizeLine.substring(5).trim());

  final black = <_Pos>{};
  final white = <_Pos>{};

  for (final line in lines.skip(1)) {
    final parts = line.split(',');
    if (parts.length != 2) continue;

    final color = parts[0].trim().toUpperCase();
    final coord = parts[1].trim().toUpperCase();
    if (coord.length < 2) continue;

    final colChar = coord[0];
    final rowNum = int.tryParse(coord.substring(1));
    if (rowNum == null) continue;

    final col = _columnIndex(colChar);
    final row = boardSize - rowNum;
    if (col < 0 || row < 0 || col >= boardSize || row >= boardSize) continue;

    final pos = _Pos(row, col);
    if (color == 'B') {
      black.add(pos);
    } else if (color == 'W') {
      white.add(pos);
    }
  }

  return _ExpectedBoard(boardSize: boardSize, black: black, white: white);
}

int _columnIndex(String col) {
  const letters = 'ABCDEFGHJKLMNOPQRST';
  return letters.indexOf(col);
}

Set<_Pos> _extractStoneSet(List<List<StoneColor>> board, StoneColor color) {
  final res = <_Pos>{};
  for (int r = 0; r < board.length; r++) {
    for (int c = 0; c < board[r].length; c++) {
      if (board[r][c] == color) res.add(_Pos(r, c));
    }
  }
  return res;
}

bool _unorderedSetEquals(Set<_Pos> a, Set<_Pos> b) {
  if (a.length != b.length) return false;
  for (final p in a) {
    if (!b.contains(p)) return false;
  }
  return true;
}

class _Pos {
  const _Pos(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Pos && runtimeType == other.runtimeType && row == other.row && col == other.col;

  @override
  int get hashCode => Object.hash(row, col);
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
