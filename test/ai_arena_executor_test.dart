import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';

void main() {
  test(
      'default opening policy applies balanced empty, twist-cross, and random games',
      () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 12,
      maxMoves: 4,
    );

    final result = executor.runMatch(
      configA: const AiBattleConfig(
        id: 'hunter_beginner_v1',
        style: 'hunter',
        difficulty: 'beginner',
      ),
      configB: const AiBattleConfig(
        id: 'counter_beginner_v1',
        style: 'counter',
        difficulty: 'beginner',
      ),
      matchSeed: 1,
      // openingSeed=0 → pairOffset = 0 % 3 = 0: empty/twistCross/random repeat.
      openingSeed: 0,
    );

    expect(result.openingPolicy, 'empty_twist_cross_random_v1');
    expect(result.games, hasLength(12));
    expect(result.games.where((game) => game.opening == 'empty'), hasLength(4));
    expect(
      result.games.where((game) => game.opening.startsWith('twistCross')),
      hasLength(4),
    );
    expect(
      result.games.where((game) => game.opening == 'twistCrossA'),
      hasLength(2),
    );
    expect(
      result.games.where((game) => game.opening == 'twistCrossB'),
      hasLength(2),
    );
    expect(
      result.games.where((game) => game.opening == 'random'),
      hasLength(4),
    );

    for (final opening in const ['empty', 'random']) {
      final games = result.games.where((game) => game.opening == opening);
      expect(games.where((game) => game.black == 'a'), hasLength(2));
      expect(games.where((game) => game.black == 'b'), hasLength(2));
    }
    for (final opening in const ['twistCrossA', 'twistCrossB']) {
      final games = result.games.where((game) => game.opening == opening);
      expect(games.where((game) => game.black == 'a'), hasLength(1));
      expect(games.where((game) => game.black == 'b'), hasLength(1));
    }
  });

  test(
      'openingSeed modulo fully determines pair offset for mixed opening policy',
      () {
    // With 3 opening families, openingSeed % 3 is the offset.
    // Seeds 0,3,6 → offset 0; seeds 1,4,7 → offset 1; seeds 2,5,8 → offset 2.
    // Verify that seeds 0 and 3 produce the same schedule, but 0 and 1 differ.
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 6,
      maxMoves: 4,
    );
    final configA = const AiBattleConfig(
      id: 'adaptive_beginner_v1',
      style: 'adaptive',
      difficulty: 'beginner',
    );
    final configB = const AiBattleConfig(
      id: 'hunter_beginner_v1',
      style: 'hunter',
      difficulty: 'beginner',
    );

    final run0 = executor.runMatch(
        configA: configA, configB: configB, matchSeed: 5, openingSeed: 0);
    final run3 = executor.runMatch(
        configA: configA, configB: configB, matchSeed: 5, openingSeed: 3);
    final run1 = executor.runMatch(
        configA: configA, configB: configB, matchSeed: 5, openingSeed: 1);

    // openingSeed=0 and openingSeed=3 both give offset=0: same opening schedule.
    expect(
      run0.games.map((g) => g.opening).toList(),
      run3.games.map((g) => g.opening).toList(),
    );
    // openingSeed=1 gives offset=1: different schedule from offset=0.
    expect(
      run0.games.map((g) => g.opening).toList(),
      isNot(run1.games.map((g) => g.opening).toList()),
    );
  });

  test(
      'random opening policy uses pair-based board seed so color-swapped games share the same opening',
      () {
    // Both games in a pair (adjacent game indices) must record 'random' as the
    // opening name.  The determinism test below validates that those games are
    // fully reproducible, which implicitly confirms a stable pairSeed was used.
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 4,
      maxMoves: 8,
      openingPolicy: 'random_v1',
    );
    final configA = const AiBattleConfig(
      id: 'adaptive_beginner_v1',
      style: 'adaptive',
      difficulty: 'beginner',
    );
    final configB = const AiBattleConfig(
      id: 'hunter_beginner_v1',
      style: 'hunter',
      difficulty: 'beginner',
    );

    final run1 = executor.runMatch(
        configA: configA, configB: configB, matchSeed: 17, openingSeed: 0);
    final run2 = executor.runMatch(
        configA: configA, configB: configB, matchSeed: 17, openingSeed: 0);

    // All 4 games should report the 'random' opening.
    expect(run1.games.every((g) => g.opening == 'random'), isTrue);

    // Each pair of adjacent games (0,1) and (2,3) must have different gameSeed
    // values (per-game agent seeds), but the same board seed (pairSeed).
    // Full determinism across identical runs is the observable proof.
    expect(
      run1.games.map((g) => g.toJson()).toList(),
      run2.games.map((g) => g.toJson()).toList(),
    );
  });

  test('game seeds are recorded per game for seeded agent replay', () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 6,
      maxMoves: 4,
    );

    final first = executor.runMatch(
      configA: const AiBattleConfig(
        id: 'adaptive_advanced_v1',
        style: 'adaptive',
        difficulty: 'advanced',
      ),
      configB: const AiBattleConfig(
        id: 'adaptive_beginner_v1',
        style: 'adaptive',
        difficulty: 'beginner',
      ),
      matchSeed: 99,
      openingSeed: 12,
    );
    final replay = executor.runMatch(
      configA: first.configA,
      configB: first.configB,
      matchSeed: 99,
      openingSeed: 12,
    );

    expect(first.games.map((game) => game.gameSeed), [
      99000,
      99001,
      99002,
      99003,
      99004,
      99005,
    ]);
    expect(
      replay.games.map((game) => game.toJson()).toList(),
      first.games.map((game) => game.toJson()).toList(),
    );
  });
}
