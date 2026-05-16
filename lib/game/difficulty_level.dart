enum DifficultyLevel {
  beginner,
  intermediate,
  advanced,
}

extension DifficultyLevelExt on DifficultyLevel {
  String get displayName {
    switch (this) {
      case DifficultyLevel.beginner:
        return '初級';
      case DifficultyLevel.intermediate:
        return '中級';
      case DifficultyLevel.advanced:
        return '高級';
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
