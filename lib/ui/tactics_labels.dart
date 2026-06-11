/// Shared display-label helpers for tactics categories, tactic types, and
/// player colours. Used by both [SkillsScreen] and [TacticsProblemScreen].

import '../game/capture_ai_tactics.dart';
import '../models/board_position.dart';
import '../providers/settings_provider.dart';
import 'board_coordinates.dart';

String categoryName(String category) {
  return switch (category) {
    'group_fate' => '棋形生死',
    'capture_race' => '對殺',
    'exchange' => '轉換',
    'multi_threat' => '多重威脅',
    'trap' => '陷阱',
    _ => category,
  };
}

String tacticName(String tactic) {
  return switch (tactic) {
    'ladder' => '征子',
    'net_geta' => '枷吃',
    'snapback' => '倒撲',
    'throw_in' => '撲',
    'shortage_of_liberties' => '氣緊',
    'connect_and_die_oiotoshi' => '滾打包收',
    'edge_corner_capture' => '邊角吃子',
    'self_atari_punishment' => '懲罰自緊氣',
    _ => tactic,
  };
}

/// Returns the display name for a board player constant.
/// [player] should be `SimBoard.black` (1) or `SimBoard.white` (2).
String playerName(int player) {
  return switch (player) {
    1 => '黑',
    2 => '白',
    _ => '-',
  };
}

/// Short type + purpose line for the tactics problem screen subtitle.
String tacticsProblemSubtitle(CaptureAiTacticsProblem problem) {
  final tactic = problem.metadata['tactic']?.toString() ?? '';
  final typeLabel = switch (problem.category) {
    'group_fate' => '死活',
    'capture_race' => '對殺',
    'trap' || 'exchange' || 'multi_threat' => '手筋',
    _ => categoryName(problem.category),
  };
  final purposeLabel = tactic.isNotEmpty
      ? tacticName(tactic)
      : switch (problem.category) {
          'group_fate' => '做活',
          'capture_race' => '對殺',
          'trap' => '吃子',
          'exchange' => '轉換',
          'multi_threat' => '多重威脅',
          _ => categoryName(problem.category),
        };
  return '$typeLabel · $purposeLabel';
}

String waitingMoveTitle(StoneColor currentPlayer) {
  return currentPlayer == StoneColor.black ? '等待黑棋落子' : '等待白棋落子';
}

/// Formats a board position as a human-readable coordinate string
/// (e.g. "A9") consistent with the board's bottom-origin row labels.
///
/// [row] is the 0-based row index from the top of the board.
/// [col] is the 0-based column index from the left.
/// [boardSize] is the number of rows/columns on the board.
/// All coordinate systems use bottom-origin row numbering, so row 0 (top)
/// maps to the highest row label (e.g. "9" for a 9×9 board).
String formatPosition(
  int row,
  int col,
  int boardSize, {
  BoardCoordinateSystem coordinateSystem = BoardCoordinateSystem.international,
}) {
  return formatBoardCoordinate(
    row: row,
    col: col,
    boardSize: boardSize,
    coordinateSystem: coordinateSystem,
  );
}
