/// Shared display-label helpers for tactics categories, tactic types, and
/// player colours. Used by both [SkillsScreen] and [TacticsProblemScreen].

String categoryName(String category) {
  return switch (category) {
    'group_fate' => '棋形生死',
    'capture_race' => '对杀',
    'exchange' => '转换',
    'multi_threat' => '多重威胁',
    'trap' => '陷阱',
    _ => category,
  };
}

String tacticName(String tactic) {
  return switch (tactic) {
    'ladder' => '征子',
    'net_geta' => '枷吃',
    'snapback' => '倒扑',
    'throw_in' => '扑',
    'shortage_of_liberties' => '气紧',
    'connect_and_die_oiotoshi' => '滚打包收',
    'edge_corner_capture' => '边角吃子',
    'self_atari_punishment' => '惩罚自紧气',
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

/// Formats a board position as a human-readable coordinate string
/// (e.g. "A9") consistent with the board's bottom-origin row labels.
///
/// [row] is the 0-based row index from the top of the board.
/// [col] is the 0-based column index from the left.
/// [boardSize] is the number of rows/columns on the board.
String formatPosition(int row, int col, int boardSize) {
  const columns = 'ABCDEFGHJKLMNOPQRST';
  final colLabel = col >= 0 && col < columns.length ? columns[col] : '?';
  return '$colLabel${boardSize - row}';
}
