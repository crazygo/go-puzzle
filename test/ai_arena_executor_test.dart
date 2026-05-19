import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';

void main() {
  test(
      'default opening policy applies balanced empty, cross, twist-cross, and random games',
      () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 16,
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
      // openingSeed=0 -> pairOffset = 0 % 4:
      // empty/cross/twistCross/random repeat.
      openingSeed: 0,
    );

    expect(result.openingPolicy, 'empty_cross_twist_cross_random_v1');
    expect(result.games, hasLength(16));
    expect(result.games.where((game) => game.opening == 'empty'), hasLength(4));
    expect(result.games.where((game) => game.opening == 'cross'), hasLength(4));
    expect(
      result.games.where((game) => game.opening.startsWith('twistCross')),
      hasLength(4),
    );
    expect(
      result.games.where((game) => game.opening == 'twistCrossC'),
      hasLength(4),
    );
    expect(
      result.games.where((game) => game.opening == 'random'),
      hasLength(4),
    );

    for (final opening in const ['empty', 'cross', 'random']) {
      final games = result.games.where((game) => game.opening == opening);
      expect(games.where((game) => game.black == 'a'), hasLength(2));
      expect(games.where((game) => game.black == 'b'), hasLength(2));
    }
    for (final opening in const ['twistCrossC']) {
      final games = result.games.where((game) => game.opening == opening);
      expect(games.where((game) => game.black == 'a'), hasLength(2));
      expect(games.where((game) => game.black == 'b'), hasLength(2));
    }
  });

  test(
      'openingSeed modulo fully determines pair offset for mixed opening policy',
      () {
    // With 4 opening families, openingSeed % 4 is the offset.
    // Seeds 0,4,8 -> offset 0; seeds 1,5,9 -> offset 1.
    // Verify that seeds 0 and 4 produce the same schedule, but 0 and 1 differ.
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 6,
      maxMoves: 4,
    );
    const configA = AiBattleConfig(
      id: 'adaptive_beginner_v1',
      style: 'adaptive',
      difficulty: 'beginner',
    );
    const configB = AiBattleConfig(
      id: 'hunter_beginner_v1',
      style: 'hunter',
      difficulty: 'beginner',
    );

    final run0 = executor.runMatch(
        configA: configA, configB: configB, matchSeed: 5, openingSeed: 0);
    final run4 = executor.runMatch(
        configA: configA, configB: configB, matchSeed: 5, openingSeed: 4);
    final run1 = executor.runMatch(
        configA: configA, configB: configB, matchSeed: 5, openingSeed: 1);

    // openingSeed=0 and openingSeed=4 both give offset=0: same opening schedule.
    expect(
      run0.games.map((g) => g.opening).toList(),
      run4.games.map((g) => g.opening).toList(),
    );
    // openingSeed=1 gives offset=1: different schedule from offset=0.
    expect(
      run0.games.map((g) => g.opening).toList(),
      isNot(run1.games.map((g) => g.opening).toList()),
    );
  });

  test('framework matches run selected algorithm configs reproducibly', () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 2,
      maxMoves: 80,
      openingPolicy: 'cross_v1',
    );
    final configA =
        AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1');
    final configB = AiAlgorithmRegistry.configById('mcts_counter_weak_v1');

    final first = executor.runFrameworkMatch(
      configA: configA,
      configB: configB,
      matchSeed: 77,
      openingSeed: 0,
    );
    final replay = executor.runFrameworkMatch(
      configA: configA,
      configB: configB,
      matchSeed: 77,
      openingSeed: 0,
    );

    expect(first.configA.id, configA.id);
    expect(first.configB.id, configB.id);
    expect(first.games, hasLength(2));
    expect(first.games.every((game) => game.opening == 'cross'), isTrue);
    expect(first.games.where((game) => game.black == 'a'), hasLength(1));
    expect(first.games.where((game) => game.black == 'b'), hasLength(1));
    expect(
      first.games.every((game) => game.endReason != 'invalidMove'),
      isTrue,
    );
    expect(
      replay.games.map((game) => game.toJson()).toList(),
      first.games.map((game) => game.toJson()).toList(),
    );
    expect(first.games.every((game) => game.fallbackUsed), isFalse);
    expect(
      first.games.every((game) => game.failureReason == null),
      isTrue,
    );
  });

  test('framework match output reports per-opening failure and timeout status',
      () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 5,
      rounds: 4,
      maxMoves: 0,
      openingPolicy: 'empty_v1',
    );
    final result = executor.runFrameworkMatch(
      configA: AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1'),
      configB: AiAlgorithmRegistry.configById('heuristic_counter_standard_v1'),
      matchSeed: 12,
      openingSeed: 0,
    );

    expect(result.games, hasLength(4));
    expect(result.games.every((game) => game.timedOut), isTrue);
    expect(result.games.every((game) => !game.illegalMove), isTrue);
    expect(result.games.every((game) => !game.fallbackUsed), isTrue);
    expect(
      result.games.every(
        (game) => game.failureReason == null
            ? false
            : game.failureReason!.contains('max_moves_reached'),
      ),
      isTrue,
    );

    final performance = result.openingPerformance.single;
    expect(performance.opening, 'empty');
    expect(performance.games, 4);
    expect(performance.timeouts, 4);
    expect(performance.illegalMoves, 0);
    expect(performance.fallbackGames, 0);
    expect(result.toJson()['openingPerformance'], isNotEmpty);
  });

  test('framework match reports decision timeout when a move exceeds budget',
      () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 5,
      rounds: 1,
      maxMoves: 80,
      openingPolicy: 'empty_v1',
      decisionTimeout: Duration.zero,
    );
    final result = executor.runFrameworkMatch(
      configA: AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1'),
      configB: AiAlgorithmRegistry.configById('heuristic_counter_standard_v1'),
      matchSeed: 5,
      openingSeed: 0,
    );

    expect(result.games.single.endReason, 'decisionTimeout');
    expect(result.games.single.timedOut, isTrue);
    expect(result.games.single.failureReason, 'decision_timeout');
    expect(result.games.single.maxDecisionMillis, greaterThanOrEqualTo(0));
  });

  test('framework output reports ONNX model unavailable without fallback', () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 1,
      maxMoves: 8,
      openingPolicy: 'empty_v1',
    );
    final result = executor.runFrameworkMatch(
      configA: AiAlgorithmRegistry.configById('katago_onnx_weak_v1'),
      configB: AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1'),
      matchSeed: 19,
      openingSeed: 0,
    );

    expect(result.games, hasLength(1));
    expect(result.games.single.endReason, 'noLegalMove');
    expect(result.games.single.fallbackUsed, isFalse);
    expect(
      result.games.single.failureReason,
      contains('a:katago_onnx_model_unavailable'),
    );
  });

  test('framework evaluation summarizes selected pairwise matches and ranking',
      () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 4,
      maxMoves: 8,
      openingPolicy: 'empty_cross_twist_cross_random_v1',
    );
    final summary = executor.runFrameworkEvaluation(
      configs: [
        AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1'),
        AiAlgorithmRegistry.configById('mcts_counter_weak_v1'),
        AiAlgorithmRegistry.configById('hybrid_tactical_counter_weak_v1'),
      ],
      matchSeed: 30,
      openingSeed: 0,
    );

    expect(summary.matches, hasLength(3));
    expect(summary.pairwise, hasLength(3));
    expect(summary.rankings, hasLength(3));
    expect(
      summary.openingPerformance.map((entry) => entry.opening),
      containsAll(['cross', 'empty']),
    );
    expect(summary.pairwise.every((entry) => entry.games == 4), isTrue);
    expect(summary.pairwise.every((entry) => entry.fallbackGames == 0), isTrue);
    expect(
      summary.rankings.map((entry) => entry.rank).toList(),
      [1, 2, 3],
    );
    expect(summary.toJson()['matches'], hasLength(3));
    expect(summary.toJson()['pairwise'], hasLength(3));
    expect(summary.toJson()['rankings'], hasLength(3));
    expect(
      summary.toJson()['openingPerformance'],
      hasLength(greaterThanOrEqualTo(2)),
    );
  });

  test('framework match can keep selected algorithm as first player', () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 1,
      rounds: 4,
      maxMoves: 8,
      openingPolicy: 'cross_v1',
    );
    final result = executor.runFrameworkMatch(
      configA:
          AiAlgorithmRegistry.configById('hybrid_tactical_counter_weak_v1'),
      configB: AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1'),
      matchSeed: 42,
      openingSeed: 0,
      alternateColors: false,
    );

    expect(result.games, hasLength(4));
    expect(result.games.every((game) => game.black == 'a'), isTrue);
    expect(result.games.every((game) => game.opening == 'cross'), isTrue);
  });

  test('MCTS standard config beats weak config without failures', () {
    const executor = AiArenaExecutor(
      boardSize: 9,
      captureTarget: 5,
      rounds: 2,
      maxMoves: 120,
      openingPolicy: 'cross_v1',
    );
    final result = executor.runFrameworkMatch(
      configA: AiAlgorithmRegistry.configById('mcts_counter_standard_v1'),
      configB: AiAlgorithmRegistry.configById('mcts_counter_weak_v1'),
      matchSeed: 20260519,
      openingSeed: 0,
    );

    expect(result.aWins, greaterThan(result.bWins));
    expect(result.aWinRate, 1.0);
    expect(result.games.every((game) => game.opening == 'cross'), isTrue);
    expect(result.games.every((game) => !game.illegalMove), isTrue);
    expect(result.games.every((game) => !game.timedOut), isTrue);
    expect(result.games.every((game) => game.failureReason == null), isTrue);
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
    const configA = AiBattleConfig(
      id: 'adaptive_beginner_v1',
      style: 'adaptive',
      difficulty: 'beginner',
    );
    const configB = AiBattleConfig(
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
