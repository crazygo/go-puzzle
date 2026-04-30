import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_rank_level.dart';
import 'package:go_puzzle/models/game_record.dart';
import 'package:go_puzzle/services/player_rank_repository.dart';

int _idCounter = 0;

/// Builds a minimal [GameRecord] with the given [playerWon] flag and a
/// non-null [aiRank] so it counts toward rank computation.
GameRecord _record(bool playerWon, {int aiRank = 3}) {
  final outcome = playerWon ? GameOutcome.humanWins : GameOutcome.aiWins;
  return GameRecord(
    id: 'r${_idCounter++}',
    playedAt: DateTime(2024),
    boardSize: 9,
    captureTarget: 5,
    difficulty: 'beginner',
    humanColorIndex: 1,
    initialMode: 'twistCross',
    moves: const [],
    outcome: outcome,
    aiRank: aiRank,
  );
}

/// Builds a [GameRecord] with a null [aiRank] (legacy record).
GameRecord _legacyRecord(bool playerWon) {
  final outcome = playerWon ? GameOutcome.humanWins : GameOutcome.aiWins;
  return GameRecord(
    id: 'r${_idCounter++}',
    playedAt: DateTime(2024),
    boardSize: 9,
    captureTarget: 5,
    difficulty: 'beginner',
    humanColorIndex: 1,
    initialMode: 'twistCross',
    moves: const [],
    outcome: outcome,
  );
}

void main() {
  group('PlayerRankRepository.computeCurrentRank', () {
    test('returns defaultRank for empty history', () {
      expect(
        PlayerRankRepository.computeCurrentRank([]),
        AiRankLevel.defaultRank,
      );
    });

    test('returns defaultRank when all records have null aiRank (legacy)', () {
      final records = [
        _legacyRecord(true),
        _legacyRecord(true),
        _legacyRecord(true),
      ];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank,
      );
    });

    test('skips legacy (null aiRank) records when mixed with ranked records',
        () {
      // 2 ranked wins + 1 legacy record: window only has 2 items after 3
      // records, so no promotion yet.
      final records = [
        _record(true),
        _legacyRecord(false),
        _record(true),
      ];
      // Window has only [true, true] — exactly 2 items; promotion needs
      // window.length == 3 so rank stays at defaultRank.
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank,
      );
    });

    test('no rank change after only 2 ranked games (window not full yet)', () {
      // 2 consecutive wins are NOT enough — need a full 3-game window.
      final records = [_record(true), _record(true)];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank,
      );
    });

    test('no rank change after only 2 ranked losses (window not full yet)', () {
      final records = [_record(false), _record(false)];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank,
      );
    });

    test('promotes after 3 wins in window', () {
      final records = [_record(true), _record(true), _record(true)];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank + 1,
      );
    });

    test('demotes after 3 losses in window', () {
      final records = [_record(false), _record(false), _record(false)];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank - 1,
      );
    });

    test('promotes after 2 wins + 1 loss in 3-game window', () {
      // W W L → 2 wins, promotion.
      final records = [_record(true), _record(true), _record(false)];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank + 1,
      );
    });

    test('demotes after 2 losses + 1 win in 3-game window', () {
      // L L W → 2 losses, demotion.
      final records = [_record(false), _record(false), _record(true)];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank - 1,
      );
    });

    test('demotes for W L L sequence (2 losses in 3-game window)', () {
      // W L L: window = [W, L, L] → 2 losses → demotion.
      final records = [_record(true), _record(false), _record(false)];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank - 1,
      );
    });

    test('window resets after promotion, allowing next promotion independently',
        () {
      // 3 wins → promote (window clears), then 3 more wins → promote again.
      final records = [
        _record(true), _record(true), _record(true), // +1
        _record(true), _record(true), _record(true), // +1
      ];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank + 2,
      );
    });

    test('window resets after demotion, allowing next demotion independently',
        () {
      final records = [
        _record(false), _record(false), _record(false), // −1
        _record(false), _record(false), _record(false), // −1
      ];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank - 2,
      );
    });

    test('rank is clamped at max and does not overflow', () {
      // Start at max-1 (rank 27), promote to 28, then try to promote again.
      final startRank = AiRankLevel.max - 1;
      // First 3 wins promote to max.
      final records = [
        _record(true, aiRank: startRank),
        _record(true, aiRank: startRank),
        _record(true, aiRank: startRank),
        // Another 3 wins: rank is already max, should not exceed.
        _record(true, aiRank: AiRankLevel.max),
        _record(true, aiRank: AiRankLevel.max),
        _record(true, aiRank: AiRankLevel.max),
      ];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.max,
      );
    });

    test('rank is clamped at min and does not underflow', () {
      final startRank = AiRankLevel.min + 1;
      final records = [
        _record(false, aiRank: startRank),
        _record(false, aiRank: startRank),
        _record(false, aiRank: startRank),
        // Another 3 losses: rank is already min.
        _record(false, aiRank: AiRankLevel.min),
        _record(false, aiRank: AiRankLevel.min),
        _record(false, aiRank: AiRankLevel.min),
      ];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.min,
      );
    });

    test('sliding window discards oldest result after 3 records (no reset)',
        () {
      // L W W → 2 wins → promotion (window clears).
      // If window were NOT sliding, 4 games WLWW would not promote in 2nd pass.
      // Verify that the 4th game triggers a new 3-game window evaluation.
      // Game sequence: L W W → promote (window clears), then W W → 2 games,
      // not enough for next promotion.
      final records = [
        _record(false), // L
        _record(true), // W
        _record(true), // W  → window [L,W,W]: 2 wins → +1, window clears
        _record(true), // W  → window [W], no change yet
        _record(true), // W  → window [W, W], still < 3
      ];
      expect(
        PlayerRankRepository.computeCurrentRank(records),
        AiRankLevel.defaultRank + 1,
      );
    });
  });
}
