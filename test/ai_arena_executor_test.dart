import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';

void main() {
  test('default opening policy applies balanced empty and twist-cross games',
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

    expect(result.openingPolicy, 'empty_twist_cross_v1');
    expect(result.games, hasLength(12));
    expect(result.games.where((game) => game.opening == 'empty'), hasLength(6));
    expect(
      result.games.where((game) => game.opening == 'twistCross'),
      hasLength(6),
    );

    for (final opening in const ['empty', 'twistCross']) {
      final games = result.games.where((game) => game.opening == opening);
      expect(games.where((game) => game.black == 'a'), hasLength(3));
      expect(games.where((game) => game.black == 'b'), hasLength(3));
    }
  });
}
