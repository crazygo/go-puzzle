import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';
import 'package:go_puzzle/game/ai_arena_scheduler.dart';

/// Minimal fake executor that returns a fixed result without running real games.
class _FakeExecutor {
  _FakeExecutor({required this.fixedAWins, required this.fixedBWins});

  final int fixedAWins;
  final int fixedBWins;

  AiMatchResult runMatch({
    required AiBattleConfig configA,
    required AiBattleConfig configB,
    required int matchSeed,
    required int openingSeed,
  }) {
    final draws = 10 - fixedAWins - fixedBWins;
    final games = List.generate(
      10,
      (i) => AiGameRecord(
        index: i,
        gameSeed: matchSeed * 1000 + i,
        openingIndex: i % 2,
        opening: i.isEven ? 'empty' : 'twistCross',
        black: i.isEven ? 'a' : 'b',
        winner:
            i < fixedAWins ? 'a' : (i < fixedAWins + fixedBWins ? 'b' : 'draw'),
        moves: 40,
        blackCaptures: 5,
        whiteCaptures: 3,
        endReason: 'captureTargetReached',
      ),
    );
    return AiMatchResult(
      matchSeed: matchSeed,
      openingSeed: openingSeed,
      openingPolicy: 'fixed_twist_cross_v1',
      boardSize: 9,
      captureTarget: 5,
      rounds: 10,
      maxMoves: 512,
      configA: configA,
      configB: configB,
      aWins: fixedAWins,
      bWins: fixedBWins,
      draws: draws,
      games: games,
    );
  }
}

/// A [AiArenaScheduler]-like test harness that uses the fake executor.
/// Since [AiArenaScheduler] takes an [AiArenaExecutor], we replicate its
/// ladder logic here using the fake to test scheduling independently.
class _TestScheduler {
  _TestScheduler({
    required List<AiBattleConfig> candidates,
    required _FakeExecutor fakeExecutor,
    this.promotionThreshold = 7,
  }) : _fake = fakeExecutor {
    final sorted = List<AiBattleConfig>.from(candidates)
      ..sort((a, b) => a.id.compareTo(b.id));
    _candidateMap = {for (final c in sorted) c.id: c};
    _ladder = AiLadderSnapshot([]);
    _ladder.insertNewCandidates(sorted.map((c) => c.id).toList());
  }

  final _FakeExecutor _fake;
  final int promotionThreshold;
  late final Map<String, AiBattleConfig> _candidateMap;
  late AiLadderSnapshot _ladder;
  String? _lastMatchId;
  int _matchCounter = 0;
  final List<AiLadderEvent> events = [];

  AiLadderSnapshot get ladder => _ladder;

  AiLadderEvent runMatch(AiBattleConfig configA, AiBattleConfig configB) {
    _candidateMap.putIfAbsent(configA.id, () => configA);
    _candidateMap.putIfAbsent(configB.id, () => configB);
    _ladder.insertNewCandidates([configA.id, configB.id]);

    final initialSnapshot = _ladder.copy();
    final initialHash = initialSnapshot.hash;

    final matchSeed = 12345 + _matchCounter * 7919;
    final openingSeed = 12345 + _matchCounter * 1337;
    _matchCounter++;

    final rawResult = _fake.runMatch(
      configA: configA,
      configB: configB,
      matchSeed: matchSeed,
      openingSeed: openingSeed,
    );

    final decision = _applyLadderRules(rawResult, initialSnapshot);
    final resultHash = _ladder.hash;

    final matchId = 'match_$_matchCounter';
    final event = AiLadderEvent(
      schemaVersion: 1,
      eventType: 'ladder_match',
      matchId: matchId,
      createdAt: '2026-04-30T18:29:00Z',
      previousMatchId: _lastMatchId,
      schedulerVersion: 'ai_arena_scheduler_v1',
      executorVersion: 'ai_arena_executor_v1',
      configVersion: configA.profileVersion,
      matchRules: {'promotionThreshold': promotionThreshold},
      initialLadderHash: initialHash,
      resultLadderHash: resultHash,
      rawResult: rawResult,
      schedulerDecision: decision,
    );
    events.add(event);
    _lastMatchId = matchId;
    return event;
  }

  AiSchedulerDecision _applyLadderRules(
    AiMatchResult result,
    AiLadderSnapshot beforeSnapshot,
  ) {
    final before = beforeSnapshot.ids.toList();
    final aId = result.configA.id;
    final bId = result.configB.id;

    String? winnerId;
    String? loserId;
    String decision;
    String reason;

    if (result.aWins >= promotionThreshold) {
      winnerId = aId;
      loserId = bId;
      reason = 'aWins(${result.aWins}) >= $promotionThreshold';
    } else if (result.bWins >= promotionThreshold) {
      winnerId = bId;
      loserId = aId;
      reason = 'bWins(${result.bWins}) >= $promotionThreshold';
    } else {
      return AiSchedulerDecision(
        winner: null,
        loser: null,
        decision: 'inconclusive',
        reason:
            'aWins(${result.aWins}) and bWins(${result.bWins}) both < $promotionThreshold',
        before: before,
        after: _ladder.ids.toList(),
      );
    }

    final winnerIdx = _ladder.indexOf(winnerId);
    final loserIdx = _ladder.indexOf(loserId);

    if (winnerIdx <= loserIdx) {
      decision = 'no_change_winner_already_higher';
      reason = '$reason; winner already above loser';
      return AiSchedulerDecision(
        winner: winnerId,
        loser: loserId,
        decision: decision,
        reason: reason,
        before: before,
        after: _ladder.ids.toList(),
      );
    }

    _ladder.promoteWinner(winnerId, loserId);
    return AiSchedulerDecision(
      winner: winnerId,
      loser: loserId,
      decision: 'promote_winner',
      reason: reason,
      before: before,
      after: _ladder.ids.toList(),
    );
  }
}

AiBattleConfig _config(String id) => AiBattleConfig(
      id: id,
      style: 'hunter',
      difficulty: 'beginner',
    );

void main() {
  group('AiLadderSnapshot', () {
    test('indexOf returns -1 for absent id', () {
      final snapshot = AiLadderSnapshot(['a', 'b', 'c']);
      expect(snapshot.indexOf('x'), -1);
    });

    test('ensurePresent appends missing id', () {
      final snapshot = AiLadderSnapshot(['a', 'b']);
      snapshot.ensurePresent('c');
      expect(snapshot.ids, ['a', 'b', 'c']);
    });

    test('ensurePresent is no-op for existing id', () {
      final snapshot = AiLadderSnapshot(['a', 'b', 'c']);
      snapshot.ensurePresent('b');
      expect(snapshot.ids, ['a', 'b', 'c']);
    });

    test('promoteWinner moves lower-ranked winner immediately before loser',
        () {
      // Ladder: a (rank 0, strongest) > b (rank 1) > c (rank 2, weakest)
      final snapshot = AiLadderSnapshot(['a', 'b', 'c']);
      // c beats b (c is lower-ranked than b).
      final changed = snapshot.promoteWinner('c', 'b');
      expect(changed, isTrue);
      expect(snapshot.ids, ['a', 'c', 'b']);
    });

    test('promoteWinner is no-op if winner already above loser', () {
      // a (strongest) beats c (weakest).
      final snapshot = AiLadderSnapshot(['a', 'b', 'c']);
      final changed = snapshot.promoteWinner('a', 'c');
      expect(changed, isFalse);
      expect(snapshot.ids, ['a', 'b', 'c']);
    });

    test('promoteWinner does not overshoot — winner only moves before loser',
        () {
      // Ladder: a > b > c > d
      final snapshot = AiLadderSnapshot(['a', 'b', 'c', 'd']);
      // d beats b — d should jump to just before b, not above a.
      snapshot.promoteWinner('d', 'b');
      expect(snapshot.ids, ['a', 'd', 'b', 'c']);
    });

    test('hash is stable and deterministic', () {
      final s1 = AiLadderSnapshot(['x', 'y', 'z']);
      final s2 = AiLadderSnapshot(['x', 'y', 'z']);
      expect(s1.hash, equals(s2.hash));
    });

    test('hash differs for different orderings', () {
      final s1 = AiLadderSnapshot(['x', 'y', 'z']);
      final s2 = AiLadderSnapshot(['z', 'y', 'x']);
      expect(s1.hash, isNot(equals(s2.hash)));
    });
  });

  group('Ladder movement rules', () {
    test(
        'lower-ranked config beats higher-ranked by 7-3 '
        'and moves immediately before the defeated config', () {
      // Initial ladder (strongest → weakest): alpha > beta > gamma
      final candidates = [_config('alpha'), _config('beta'), _config('gamma')];
      final scheduler = _TestScheduler(
        candidates: candidates,
        fakeExecutor: _FakeExecutor(fixedAWins: 7, fixedBWins: 3),
      );
      // Initial (lexical): alpha > beta > gamma
      expect(scheduler.ladder.ids, ['alpha', 'beta', 'gamma']);

      // gamma (configA) beats beta (configB) 7-3.
      final event = scheduler.runMatch(_config('gamma'), _config('beta'));

      expect(event.schedulerDecision.decision, 'promote_winner');
      expect(event.schedulerDecision.winner, 'gamma');
      expect(event.schedulerDecision.loser, 'beta');

      // gamma should now be immediately before beta, not above alpha.
      expect(scheduler.ladder.ids, ['alpha', 'gamma', 'beta']);
    });

    test(
        'higher-ranked config beats lower-ranked by 10-0 '
        'and the ladder remains unchanged', () {
      // Ladder: alpha > beta > gamma
      final candidates = [_config('alpha'), _config('beta'), _config('gamma')];
      final scheduler = _TestScheduler(
        candidates: candidates,
        fakeExecutor: _FakeExecutor(fixedAWins: 10, fixedBWins: 0),
      );
      // alpha beats gamma — alpha is already above gamma.
      final beforeIds = scheduler.ladder.ids.toList();
      final event = scheduler.runMatch(_config('alpha'), _config('gamma'));

      expect(
          event.schedulerDecision.decision, 'no_change_winner_already_higher');
      expect(scheduler.ladder.ids, beforeIds);
    });

    test('6-4 result is inconclusive — ladder unchanged', () {
      final candidates = [_config('alpha'), _config('beta')];
      final scheduler = _TestScheduler(
        candidates: candidates,
        fakeExecutor: _FakeExecutor(fixedAWins: 6, fixedBWins: 4),
      );
      final beforeIds = scheduler.ladder.ids.toList();
      final event = scheduler.runMatch(_config('beta'), _config('alpha'));

      expect(event.schedulerDecision.decision, 'inconclusive');
      expect(scheduler.ladder.ids, beforeIds);
    });

    test('5-5 result is inconclusive — ladder unchanged', () {
      final candidates = [_config('alpha'), _config('beta')];
      final scheduler = _TestScheduler(
        candidates: candidates,
        fakeExecutor: _FakeExecutor(fixedAWins: 5, fixedBWins: 5),
      );
      final beforeIds = scheduler.ladder.ids.toList();
      final event = scheduler.runMatch(_config('beta'), _config('alpha'));

      expect(event.schedulerDecision.decision, 'inconclusive');
      expect(scheduler.ladder.ids, beforeIds);
    });

    test('draw-heavy result without 7-win side is inconclusive', () {
      // 4 wins for A, 3 for B, 3 draws — neither hits threshold.
      final candidates = [_config('a'), _config('b')];
      final scheduler = _TestScheduler(
        candidates: candidates,
        fakeExecutor: _FakeExecutor(fixedAWins: 4, fixedBWins: 3),
      );
      final beforeIds = scheduler.ladder.ids.toList();
      final event = scheduler.runMatch(_config('b'), _config('a'));

      expect(event.schedulerDecision.decision, 'inconclusive');
      expect(scheduler.ladder.ids, beforeIds);
    });

    test('repeated wins over lower-ranked opponents do not change rank', () {
      final candidates = [_config('alpha'), _config('beta'), _config('gamma')];
      // alpha beats gamma repeatedly.
      final scheduler = _TestScheduler(
        candidates: candidates,
        fakeExecutor: _FakeExecutor(fixedAWins: 10, fixedBWins: 0),
      );
      // alpha is already above gamma.
      scheduler.runMatch(_config('alpha'), _config('gamma'));
      scheduler.runMatch(_config('alpha'), _config('gamma'));
      scheduler.runMatch(_config('alpha'), _config('gamma'));

      // All decisions should be no_change.
      for (final e in scheduler.events) {
        expect(e.schedulerDecision.decision, 'no_change_winner_already_higher');
      }
      // Ladder should be unchanged throughout.
      expect(scheduler.ladder.ids, ['alpha', 'beta', 'gamma']);
    });

    test('new candidate is inserted at the weakest end before movement rules',
        () {
      final candidates = [_config('alpha'), _config('beta')];
      final scheduler = _TestScheduler(
        candidates: candidates,
        fakeExecutor: _FakeExecutor(fixedAWins: 0, fixedBWins: 10),
      );
      // Introduce new config 'omega' by running a match.
      // omega (configB) beats alpha (configA) 10-0.
      final event = scheduler.runMatch(_config('alpha'), _config('omega'));

      // 'omega' should have been inserted at the weakest end first, then
      // promoted if it won. Since B wins = 10, omega (B) wins and gets
      // promoted before alpha.
      expect(event.schedulerDecision.decision, 'promote_winner');
      expect(event.schedulerDecision.winner, 'omega');

      // omega is now immediately before alpha.
      final ids = scheduler.ladder.ids;
      expect(ids.indexOf('omega'), lessThan(ids.indexOf('alpha')));
    });
  });

  group('Decision replay', () {
    test('replaying the same log produces the same snapshot and hash', () {
      final candidates = [
        _config('alpha'),
        _config('beta'),
        _config('gamma'),
      ];
      final scheduler = _TestScheduler(
        candidates: candidates,
        fakeExecutor: _FakeExecutor(fixedAWins: 7, fixedBWins: 3),
      );
      final initialLadder = scheduler.ladder.copy();

      // Run a few matches.
      scheduler.runMatch(_config('gamma'), _config('beta'));
      scheduler.runMatch(_config('gamma'), _config('alpha'));

      final finalHash = scheduler.ladder.hash;
      final events = scheduler.events;

      // Replay.
      final result = AiArenaReplayer.replay(
        initialLadder: initialLadder,
        events: events,
      );

      expect(result.passed, isTrue,
          reason: 'Mismatches: ${result.hashMismatches}');
      expect(result.finalLadder.hash, equals(finalHash));
      expect(result.finalLadder.ids, equals(scheduler.ladder.ids));
    });

    test('replay is a no-op for inconclusive events', () {
      final candidates = [_config('alpha'), _config('beta')];
      final scheduler = _TestScheduler(
        candidates: candidates,
        fakeExecutor: _FakeExecutor(fixedAWins: 5, fixedBWins: 5),
      );
      final initialLadder = scheduler.ladder.copy();
      scheduler.runMatch(_config('beta'), _config('alpha'));

      final result = AiArenaReplayer.replay(
        initialLadder: initialLadder,
        events: scheduler.events,
      );
      expect(result.passed, isTrue);
      expect(result.finalLadder.ids, equals(initialLadder.ids));
    });

    test('JSONL round-trip preserves event data', () {
      final configA = _config('alpha');
      final configB = _config('beta');
      final event = AiLadderEvent(
        schemaVersion: 1,
        eventType: 'ladder_match',
        matchId: 'test_match_1',
        createdAt: '2026-04-30T18:29:00Z',
        schedulerVersion: 'ai_arena_scheduler_v1',
        executorVersion: 'ai_arena_executor_v1',
        configVersion: 'capture_ai_profile_v1',
        matchRules: {'promotionThreshold': 7},
        initialLadderHash: 'djb2:abc123',
        resultLadderHash: 'djb2:def456',
        rawResult: AiMatchResult(
          matchSeed: 12345,
          openingSeed: 67890,
          openingPolicy: 'fixed_twist_cross_v1',
          boardSize: 9,
          captureTarget: 5,
          rounds: 10,
          maxMoves: 512,
          configA: configA,
          configB: configB,
          aWins: 7,
          bWins: 3,
          draws: 0,
          games: [],
        ),
        schedulerDecision: const AiSchedulerDecision(
          winner: 'alpha',
          loser: 'beta',
          decision: 'promote_winner',
          reason: 'aWins(7) >= 7',
          before: ['alpha', 'beta'],
          after: ['alpha', 'beta'],
        ),
      );

      final line = event.toJsonLine();
      final restored = AiLadderEvent.fromJsonLine(line);

      expect(restored.schemaVersion, 1);
      expect(restored.matchId, 'test_match_1');
      expect(restored.rawResult.aWins, 7);
      expect(restored.rawResult.configA.id, 'alpha');
      expect(restored.schedulerDecision.decision, 'promote_winner');
    });
  });

  group('computeLadderHash', () {
    test('same list produces same hash', () {
      expect(
        computeLadderHash(['a', 'b', 'c']),
        equals(computeLadderHash(['a', 'b', 'c'])),
      );
    });

    test('different lists produce different hashes', () {
      expect(
        computeLadderHash(['a', 'b', 'c']),
        isNot(equals(computeLadderHash(['c', 'b', 'a']))),
      );
    });

    test('empty list has a defined hash', () {
      expect(computeLadderHash([]), isNotEmpty);
    });
  });
}
