import '../providers/settings_provider.dart';

const _internationalColumns = 'ABCDEFGHJKLMNOPQRST';
const _koreanColumns = [
  'ㄱ',
  'ㄲ',
  'ㄴ',
  'ㄷ',
  'ㄸ',
  'ㄹ',
  'ㅁ',
  'ㅂ',
  'ㅃ',
  'ㅅ',
  'ㅆ',
  'ㅇ',
  'ㅈ',
  'ㅉ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
];

String boardAxisColumnLabel({
  required int col,
  required int boardSize,
  required BoardCoordinateSystem coordinateSystem,
}) {
  if (col < 0 || col >= boardSize) return '?';
  return switch (coordinateSystem) {
    BoardCoordinateSystem.international =>
      col < _internationalColumns.length ? _internationalColumns[col] : '?',
    BoardCoordinateSystem.chinese => '${col + 1}',
    BoardCoordinateSystem.korean =>
      col < _koreanColumns.length ? _koreanColumns[col] : '?',
  };
}

String boardAxisRowLabel({
  required int row,
  required int boardSize,
  required BoardCoordinateSystem coordinateSystem,
}) {
  if (row < 0 || row >= boardSize) return '?';
  return switch (coordinateSystem) {
    BoardCoordinateSystem.international => '${boardSize - row}',
    BoardCoordinateSystem.chinese => _toChineseNumber(row + 1),
    BoardCoordinateSystem.korean => '${row + 1}',
  };
}

String formatBoardCoordinate({
  required int row,
  required int col,
  required int boardSize,
  required BoardCoordinateSystem coordinateSystem,
}) {
  if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) return '-';
  final column = boardAxisColumnLabel(
    col: col,
    boardSize: boardSize,
    coordinateSystem: coordinateSystem,
  );
  final rowLabel = switch (coordinateSystem) {
    BoardCoordinateSystem.international => '${boardSize - row}',
    BoardCoordinateSystem.chinese => _toChineseNumber(row + 1),
    BoardCoordinateSystem.korean => '${row + 1}',
  };
  return '$column$rowLabel';
}

String _toChineseNumber(int value) {
  const digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  if (value <= 0) return '$value';
  if (value < 10) return digits[value];
  if (value == 10) return '十';
  if (value < 20) return '十${digits[value - 10]}';
  final tens = value ~/ 10;
  final ones = value % 10;
  final tensLabel = '${digits[tens]}十';
  if (ones == 0) return tensLabel;
  return '$tensLabel${digits[ones]}';
}
