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
      openingSeed: 2,
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
