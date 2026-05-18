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
  });
}
