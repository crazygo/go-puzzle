import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/providers/settings_provider.dart';
import 'package:go_puzzle/ui/board_coordinates.dart';

void main() {
  group('board coordinates', () {
    test('korean columns use baduk syllables', () {
      expect(
        boardAxisColumnLabel(
          col: 0,
          boardSize: 19,
          coordinateSystem: BoardCoordinateSystem.korean,
        ),
        '가',
      );
      expect(
        boardAxisColumnLabel(
          col: 13,
          boardSize: 19,
          coordinateSystem: BoardCoordinateSystem.korean,
        ),
        '하',
      );
      expect(
        boardAxisColumnLabel(
          col: 14,
          boardSize: 19,
          coordinateSystem: BoardCoordinateSystem.korean,
        ),
        '가2',
      );
    });

    test('korean coordinate format stays valid beyond 14 columns', () {
      expect(
        formatBoardCoordinate(
          row: 0,
          col: 18,
          boardSize: 19,
          coordinateSystem: BoardCoordinateSystem.korean,
        ),
        '마21',
      );
    });

    test('chinese row labels use bottom-origin (boardSize - row)', () {
      // Top row (row=0) on a 9x9 board should show 九 (9), not 一 (1).
      expect(
        boardAxisRowLabel(
          row: 0,
          boardSize: 9,
          coordinateSystem: BoardCoordinateSystem.chinese,
        ),
        '九',
      );
      // Bottom row (row=8) should show 一 (1).
      expect(
        boardAxisRowLabel(
          row: 8,
          boardSize: 9,
          coordinateSystem: BoardCoordinateSystem.chinese,
        ),
        '一',
      );
    });

    test('chinese formatBoardCoordinate uses boardAxisRowLabel for row', () {
      // Top-left on 9x9: col=0 -> "1", row=0 -> "九" (bottom-origin).
      expect(
        formatBoardCoordinate(
          row: 0,
          col: 0,
          boardSize: 9,
          coordinateSystem: BoardCoordinateSystem.chinese,
        ),
        '1九',
      );
    });
  });
}
