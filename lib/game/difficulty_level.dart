enum DifficultyLevel {
  beginner,
  intermediate,
  advanced,
}

extension DifficultyLevelExt on DifficultyLevel {
  String get displayName {
    switch (this) {
      case DifficultyLevel.beginner:
        return '初级';
      case DifficultyLevel.intermediate:
        return '中级';
      case DifficultyLevel.advanced:
        return '高级';
    }
  }

  int get maxPlayouts {
    switch (this) {
      case DifficultyLevel.beginner:
        return 250;
      case DifficultyLevel.intermediate:
        return 900;
      case DifficultyLevel.advanced:
        return 2200;
    }
  }
}
