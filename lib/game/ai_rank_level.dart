import 'difficulty_level.dart';

/// Utility constants and helpers for the 28-level AI rank system.
///
/// Ranks 1–28 map directly to player-facing display names:
///   rank  1–22  →  22級–1級  (kyu, most-beginner to near-amateur-dan)
///   rank 23–28  →  1段–6段   (dan grades)
class AiRankLevel {
  AiRankLevel._();

  /// Minimum rank value.
  static const int min = 1;

  /// Maximum rank value.
  static const int max = 28;

  /// Starting rank for players with no history.
  static const int defaultRank = 3;

  /// Human-readable display name shown to players.
  ///
  /// - Rank 1 → "22級", rank 2 → "21級", …, rank 22 → "1級"
  /// - Rank 23 → "1段", rank 24 → "2段", …, rank 28 → "6段"
  static String displayName(int rank) {
    assert(rank >= min && rank <= max, 'rank must be between $min and $max');
    if (rank <= 22) return '${23 - rank}級';
    return '${rank - 22}段';
  }

  /// Returns the [DifficultyLevel]-equivalent zone for backward compatibility.
  ///
  /// Mapping (Phase F):
  ///   rank  1–9   → beginner   (beginner midpoint = rank 3)
  ///   rank 10–19  → intermediate (intermediate midpoint = rank 12)
  ///   rank 20–28  → advanced   (advanced midpoint = rank 20)
  static DifficultyLevel difficultyZone(int rank) {
    if (rank <= 9) return DifficultyLevel.beginner;
    if (rank <= 19) return DifficultyLevel.intermediate;
    return DifficultyLevel.advanced;
  }
}
