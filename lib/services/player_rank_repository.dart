import '../game/ai_rank_level.dart';
import '../models/game_record.dart';

/// Computes the current player rank from game history using the dojo ladder.
///
/// The rank is **never stored** independently; it is always recomputed from the
/// full [GameRecord] history so the algorithm can be freely changed without
/// migrating stored data.
class PlayerRankRepository {
  PlayerRankRepository._();

  /// Pure function: given [records] in chronological order (oldest first),
  /// returns the player's current rank (1–28).
  ///
  /// ### Dojo ladder rules
  /// - New players start at [AiRankLevel.defaultRank].
  /// - After each game a sliding window of the last 3 results is evaluated.
  ///   - ≥ 2 wins  → rank + 1 (max [AiRankLevel.max]), window resets.
  ///   - ≥ 2 losses → rank − 1 (min [AiRankLevel.min]), window resets.
  ///   - Otherwise  → no change, window slides forward.
  /// - Records with a null [GameRecord.aiRank] (old records) are skipped.
  static int computeCurrentRank(List<GameRecord> records) {
    int rank = AiRankLevel.defaultRank;
    final window = <bool>[];

    for (final record in records) {
      if (record.aiRank == null) continue;

      window.add(record.playerWon);
      if (window.length > 3) window.removeAt(0);

      if (window.length >= 2) {
        final wins = window.where((w) => w).length;
        final losses = window.where((w) => !w).length;

        if (wins >= 2 && rank < AiRankLevel.max) {
          rank++;
          window.clear();
        } else if (losses >= 2 && rank > AiRankLevel.min) {
          rank--;
          window.clear();
        }
      }
    }

    return rank;
  }
}
