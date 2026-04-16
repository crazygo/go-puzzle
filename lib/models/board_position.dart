enum StoneColor { empty, black, white }

extension StoneColorExt on StoneColor {
  StoneColor get opponent {
    switch (this) {
      case StoneColor.black:
        return StoneColor.white;
      case StoneColor.white:
        return StoneColor.black;
      case StoneColor.empty:
        return StoneColor.empty;
    }
  }
}

class BoardPosition {
  final int row;
  final int col;

  const BoardPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is BoardPosition && other.row == row && other.col == col;

  @override
  int get hashCode => row * 100 + col;

  @override
  String toString() => '($row, $col)';
}

class Stone {
  final BoardPosition position;
  final StoneColor color;

  const Stone({required this.position, required this.color});
}
