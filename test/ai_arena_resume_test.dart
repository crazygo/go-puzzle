import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';
import 'package:go_puzzle/game/ai_arena_scheduler.dart';

// ---------------------------------------------------------------------------
// Shared test helpers
// ---------------------------------------------------------------------------

/// Minimal fake executor that returns deterministic results without real games.
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
    final totalGames = fixedAWins + fixedBWins;
    final draws = 10 - totalGames;
    final games = List.generate(
      10,
      (i) => AiGameRecord(
        index: i,
        gameSeed: matchSeed * 1000 + i,
        openingIndex: i % 2,
        opening: i.isEven ? 'empty' : 'twistCross',
        black: i.isEven ? 'a' : 'b',
        winner: i < fixedAWins ? 'a' : (i < totalGames ? 'b' : 'draw'),
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

/// Minimal scheduler wrapper that uses a fake executor so tests stay fast.
class _TestScheduler {
  _TestScheduler({
    required List<AiBattleConfig> candidates,
    required _FakeExecutor fakeExecutor,
    int matchCounterOffset = 0,
  })  : _fake = fakeExecutor,
        _matchCounter = matchCounterOffset {
    final sorted = List<AiBattleConfig>.from(candidates)
      ..sort((a, b) => a.id.compareTo(b.id));
    _candidateMap = {for (final c in sorted) c.id: c};
    _ladder = AiLadderSnapshot([]);
    _ladder.insertNewCandidates(sorted.map((c) => c.id).toList());
  }

  final _FakeExecutor _fake;
  final int promotionThreshold = 7;
  late final Map<String, AiBattleConfig> _candidateMap;
  late AiLadderSnapshot _ladder;
  String? _lastMatchId;
  int _matchCounter;
  final List<AiLadderEvent> events = [];

  AiLadderSnapshot get ladder => _ladder;

  /// Restore ladder to [snapshot] — mirrors [AiArenaScheduler.restoreLadder].
  void restoreLadder(AiLadderSnapshot snapshot) {
    _ladder = snapshot.copy();
  }

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
        reason: 'aWins(${result.aWins}) and bWins(${result.bWins}) '
            'both < $promotionThreshold',
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

/// Produces a JSONL string from a list of events.
String _toJsonl(List<AiLadderEvent> events) =>
    events.map((e) => e.toJsonLine()).join('\n');

AiBattleConfig _config(String id) => AiBattleConfig(
      id: id,
      style: 'hunter',
      difficulty: 'beginner',
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Scenario 1: Interruption / resume
  // -------------------------------------------------------------------------
  group('Scenario 1 — Interruption and resume', () {
    // Three candidates: alpha, beta, gamma.
    // Initial ladder (lexical): [alpha, beta, gamma] (index 0 = strongest).
    //
    // Match plan for the sweep:
    //   Match 1: runMatch(configA=gamma, configB=alpha)
    //     → gamma (A, weaker index 2) beats alpha (B, stronger index 0) 7-3
    //     → gamma is promoted above alpha → ladder: [gamma, alpha, beta]
    //   Match 2: runMatch(configA=beta, configB=gamma)
    //     → beta (A, now index 2) beats gamma (B, index 0) 7-3
    //     → beta is promoted above gamma → ladder: [beta, gamma, alpha]
    //
    // The test interrupts after match 1 and verifies that resuming from the
    // saved event produces the same final state as running both matches
    // uninterrupted.  This is a meaningful test: if the resume does NOT
    // restore the ladder state correctly, match 2 would see the wrong initial
    // order and produce a different (wrong) result.

    final candidates = [
      _config('alpha'),
      _config('beta'),
      _config('gamma'),
    ];
    // A always wins 7-3 → the lower-ranked challenger wins when passed as A.
    final fake = _FakeExecutor(fixedAWins: 7, fixedBWins: 3);

    test('partial event log reconstructs the correct intermediate ladder', () {
      // Full uninterrupted run.
      final full = _TestScheduler(candidates: candidates, fakeExecutor: fake);
      // Match 1: gamma (weaker) beats alpha (stronger) → promotion.
      full.runMatch(_config('gamma'), _config('alpha'));
      // Match 2: beta (now weakest) beats gamma (now strongest) → promotion.
      full.runMatch(_config('beta'), _config('gamma'));
      final fullHash = full.ladder.hash;

      // "Interrupted" run: only the first event was persisted.
      final partialEvents = full.events.sublist(0, 1);
      final partialJsonl = _toJsonl(partialEvents);

      final sortedIds = (['alpha', 'beta', 'gamma']..sort());
      final manifest = AiArenaRunManifest(
        candidateIds: sortedIds,
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 12345,
      );
      final resumeState = buildResumeState(
        currentManifest: manifest,
        savedManifest: manifest,
        savedJsonl: partialJsonl,
        initialLadderIds: sortedIds,
      );

      expect(resumeState.loadedEvents.length, 1,
          reason: 'Should have loaded exactly 1 prior event');
      expect(resumeState.matchCounterOffset, 1);

      // The reconstructed ladder should reflect the promotion from match 1.
      expect(
        resumeState.reconstructedLadder.hash,
        full.events.first.resultLadderHash,
        reason: 'Reconstructed ladder hash should equal the hash after match 1',
      );
      // After match 1, gamma should be above alpha.
      final ids = resumeState.reconstructedLadder.ids;
      expect(ids.indexOf('gamma'), lessThan(ids.indexOf('alpha')),
          reason: 'Gamma should have been promoted above alpha after match 1');

      // Resume: continue from match counter = 1.
      final resumed = _TestScheduler(
        candidates: candidates,
        fakeExecutor: fake,
        matchCounterOffset: resumeState.matchCounterOffset,
      );
      resumed.restoreLadder(resumeState.reconstructedLadder);

      // Run only the remaining match (using the same seed offset as the full run).
      resumed.runMatch(_config('beta'), _config('gamma'));

      expect(resumed.ladder.hash, fullHash,
          reason: 'Resumed run should reach same final state as full run');
    });

    test('resumed run produces the same final ladder order as a full run', () {
      final full = _TestScheduler(candidates: candidates, fakeExecutor: fake);
      full.runMatch(_config('gamma'), _config('alpha'));
      full.runMatch(_config('beta'), _config('gamma'));

      // Interrupt after match 1.
      final saved = full.events.sublist(0, 1);
      final sortedIds = (['alpha', 'beta', 'gamma']..sort());
      final manifest = AiArenaRunManifest(
        candidateIds: sortedIds,
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 12345,
      );
      final resumeState = buildResumeState(
        currentManifest: manifest,
        savedManifest: manifest,
        savedJsonl: _toJsonl(saved),
        initialLadderIds: sortedIds,
      );

      final resumed = _TestScheduler(
        candidates: candidates,
        fakeExecutor: fake,
        matchCounterOffset: resumeState.matchCounterOffset,
      );
      resumed.restoreLadder(resumeState.reconstructedLadder);
      resumed.runMatch(_config('beta'), _config('gamma'));

      expect(resumed.ladder.ids, full.ladder.ids,
          reason: 'Ladder order must be identical whether or not interrupted');
    });

    test(
        'starting fresh without restoring ladder state produces wrong result '
        '— validating that restoreLadder is required', () {
      // This test verifies the negative case: skipping restoreLadder causes
      // match 2 to see the wrong ladder state and produce a different outcome.
      final full = _TestScheduler(candidates: candidates, fakeExecutor: fake);
      full.runMatch(_config('gamma'), _config('alpha')); // promotion occurs
      full.runMatch(_config('beta'), _config('gamma'));
      final correctFinalHash = full.ladder.hash;

      // Wrong resume: start fresh scheduler (ladder not restored), just
      // advance the match counter offset without restoring the ladder.
      final wrong = _TestScheduler(
        candidates: candidates,
        fakeExecutor: fake,
        matchCounterOffset: 1, // skip counter but do NOT restoreLadder
      );
      // wrong.ladder is still the initial [alpha, beta, gamma].
      wrong.runMatch(_config('beta'), _config('gamma'));

      expect(wrong.ladder.hash, isNot(correctFinalHash),
          reason: 'Without restoreLadder, match 2 sees wrong initial state and '
              'produces a different (incorrect) final ladder');
    });
  });

  // -------------------------------------------------------------------------
  // Scenario 2: Identical configuration replay (result reuse)
  // -------------------------------------------------------------------------
  group('Scenario 2 — Identical configuration replay', () {
    // Running the same candidates + rules twice with the same base seed
    // produces bitwise-identical events, so a second invocation that loads the
    // first run's JSONL can skip all matches and produce the same final ladder.

    test('identical config yields identical matchSeed values', () {
      final candidates = [_config('x'), _config('y'), _config('z')];
      final fake = _FakeExecutor(fixedAWins: 7, fixedBWins: 3);

      final run1 = _TestScheduler(candidates: candidates, fakeExecutor: fake);
      run1.runMatch(_config('x'), _config('y'));
      run1.runMatch(_config('y'), _config('z'));

      final run2 = _TestScheduler(candidates: candidates, fakeExecutor: fake);
      run2.runMatch(_config('x'), _config('y'));
      run2.runMatch(_config('y'), _config('z'));

      for (var i = 0; i < run1.events.length; i++) {
        expect(
          run1.events[i].rawResult.matchSeed,
          run2.events[i].rawResult.matchSeed,
          reason: 'Match $i: seeds must be identical for same counter offset',
        );
        expect(
          run1.events[i].rawResult.aWins,
          run2.events[i].rawResult.aWins,
          reason: 'Match $i: aWins must be identical for identical seeds+fake',
        );
      }
    });

    test('loading all prior events means no new matches need to run', () {
      final candidates = [_config('p'), _config('q')];
      final fake = _FakeExecutor(fixedAWins: 7, fixedBWins: 3);

      // First complete run.
      final run1 = _TestScheduler(candidates: candidates, fakeExecutor: fake);
      run1.runMatch(_config('p'), _config('q'));

      final jsonl = _toJsonl(run1.events);
      final finalHash = run1.ladder.hash;

      final manifest = AiArenaRunManifest(
        candidateIds: (['p', 'q']..sort()),
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 12345,
      );

      // Second invocation: load all events from run1.
      final resumeState = buildResumeState(
        currentManifest: manifest,
        savedManifest: manifest,
        savedJsonl: jsonl,
        initialLadderIds: (['p', 'q']..sort()),
      );

      // All matches already completed — offset equals total planned matches.
      expect(resumeState.matchCounterOffset, run1.events.length);
      expect(resumeState.reconstructedLadder.hash, finalHash,
          reason: 'Reconstructed ladder must match the end state of run1');

      // Nothing new to run — skipping produces the same final hash.
      expect(resumeState.reconstructedLadder.hash, finalHash);
    });

    test('manifest configHash is stable across two identical manifest builds',
        () {
      final ids = (['alpha', 'beta', 'gamma']..sort());
      final m1 = AiArenaRunManifest(
        candidateIds: ids,
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 20260430,
      );
      final m2 = AiArenaRunManifest(
        candidateIds: ids,
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 20260430,
      );
      expect(m1.configHash, m2.configHash);
      expect(m1.isCompatibleWith(m2), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Scenario 3: Configuration change detection
  // -------------------------------------------------------------------------
  group('Scenario 3 — Configuration change detection', () {
    final baseIds = (['alpha', 'beta']..sort());
    final baseManifest = AiArenaRunManifest(
      candidateIds: baseIds,
      boardSize: 9,
      captureTarget: 5,
      rounds: 10,
      promotionThreshold: 7,
      baseSeed: 20260430,
    );

    test('adding a candidate changes the configHash', () {
      final extended = AiArenaRunManifest(
        candidateIds: (['alpha', 'beta', 'gamma']..sort()),
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 20260430,
      );
      expect(baseManifest.configHash, isNot(extended.configHash));
      expect(baseManifest.isCompatibleWith(extended), isFalse);
    });

    test('changing boardSize changes the configHash', () {
      final other = AiArenaRunManifest(
        candidateIds: baseIds,
        boardSize: 13,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 20260430,
      );
      expect(baseManifest.configHash, isNot(other.configHash));
      expect(baseManifest.isCompatibleWith(other), isFalse);
    });

    test('changing promotionThreshold changes the configHash', () {
      final other = AiArenaRunManifest(
        candidateIds: baseIds,
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 6,
        baseSeed: 20260430,
      );
      expect(baseManifest.configHash, isNot(other.configHash));
      expect(baseManifest.isCompatibleWith(other), isFalse);
    });

    test('changing rounds changes the configHash', () {
      final other = AiArenaRunManifest(
        candidateIds: baseIds,
        boardSize: 9,
        captureTarget: 5,
        rounds: 20,
        promotionThreshold: 7,
        baseSeed: 20260430,
      );
      expect(baseManifest.configHash, isNot(other.configHash));
      expect(baseManifest.isCompatibleWith(other), isFalse);
    });

    test('changing baseSeed changes the configHash', () {
      final other = AiArenaRunManifest(
        candidateIds: baseIds,
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 99999,
      );
      expect(baseManifest.configHash, isNot(other.configHash));
      expect(baseManifest.isCompatibleWith(other), isFalse);
    });

    test('changing maxMoves changes the configHash', () {
      final other = AiArenaRunManifest(
        candidateIds: baseIds,
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 20260430,
        maxMoves: 128,
      );
      expect(baseManifest.configHash, isNot(other.configHash));
      expect(baseManifest.isCompatibleWith(other), isFalse);
    });

    test('changing openingPolicy changes the configHash', () {
      final other = AiArenaRunManifest(
        candidateIds: baseIds,
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 20260430,
        openingPolicy: 'empty_v1',
      );
      expect(baseManifest.configHash, isNot(other.configHash));
      expect(baseManifest.isCompatibleWith(other), isFalse);
    });

    test('buildResumeState throws AiArenaConfigMismatchException on mismatch',
        () {
      final differentManifest = AiArenaRunManifest(
        candidateIds: (['alpha', 'beta', 'gamma']..sort()),
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 20260430,
      );

      expect(
        () => buildResumeState(
          currentManifest: differentManifest,
          savedManifest: baseManifest,
          savedJsonl: '',
          initialLadderIds: baseIds,
        ),
        throwsA(isA<AiArenaConfigMismatchException>()),
        reason:
            'Should throw when current config does not match the saved manifest',
      );
    });

    test('AiArenaConfigMismatchException message includes both hashes', () {
      final differentManifest = AiArenaRunManifest(
        candidateIds: (['alpha', 'beta', 'gamma']..sort()),
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 20260430,
      );

      try {
        buildResumeState(
          currentManifest: differentManifest,
          savedManifest: baseManifest,
          savedJsonl: '',
          initialLadderIds: baseIds,
        );
        fail('Expected AiArenaConfigMismatchException');
      } on AiArenaConfigMismatchException catch (e) {
        expect(e.currentHash, differentManifest.configHash);
        expect(e.savedHash, baseManifest.configHash);
        expect(e.toString(), contains(differentManifest.configHash));
        expect(e.toString(), contains(baseManifest.configHash));
      }
    });

    test('manifest JSON round-trip preserves all fields and hash', () {
      final json = baseManifest.toJson();
      final restored = AiArenaRunManifest.fromJson(json);
      expect(restored.configHash, baseManifest.configHash);
      expect(restored.candidateIds, baseManifest.candidateIds);
      expect(restored.boardSize, baseManifest.boardSize);
      expect(restored.rounds, baseManifest.rounds);
      expect(restored.promotionThreshold, baseManifest.promotionThreshold);
      expect(restored.baseSeed, baseManifest.baseSeed);
      expect(restored.maxMoves, baseManifest.maxMoves);
      expect(restored.openingPolicy, baseManifest.openingPolicy);
    });
  });

  // -------------------------------------------------------------------------
  // Scenario 4: Consistency — live run vs reconstructed from persisted events
  // -------------------------------------------------------------------------
  group('Scenario 4 — Consistency between live run and replayed events', () {
    test(
        'final ladder from uninterrupted run equals ladder from replaying '
        'all persisted events', () {
      final candidates = [
        _config('alpha'),
        _config('beta'),
        _config('gamma'),
        _config('delta'),
      ];
      final fake = _FakeExecutor(fixedAWins: 7, fixedBWins: 3);

      // Initial (sorted): [alpha, beta, delta, gamma] — alpha=strongest.
      // Matches chosen so challengers (configA) win and cause promotions.
      final scheduler =
          _TestScheduler(candidates: candidates, fakeExecutor: fake);
      final initialLadder = scheduler.ladder.copy();

      // Match 1: delta (A) vs alpha (B) — delta is weaker, wins → promoted.
      scheduler.runMatch(_config('delta'), _config('alpha'));
      // Match 2: gamma (A) vs beta (B) — gamma is weaker, wins → promoted.
      scheduler.runMatch(_config('gamma'), _config('beta'));
      // Match 3: beta (A) vs delta (B) — verify another promotion.
      scheduler.runMatch(_config('beta'), _config('delta'));

      final liveFinalHash = scheduler.ladder.hash;
      final liveIds = scheduler.ladder.ids.toList();

      // Replay all persisted events from the initial ladder.
      final replayResult = AiArenaReplayer.replay(
        initialLadder: initialLadder,
        events: scheduler.events,
      );

      expect(replayResult.passed, isTrue,
          reason:
              'No hash mismatches expected: ${replayResult.hashMismatches}');
      expect(replayResult.finalLadder.hash, liveFinalHash,
          reason: 'Hash from replay must match live final hash');
      expect(replayResult.finalLadder.ids, liveIds,
          reason: 'Ladder order from replay must match live final order');
    });

    test(
        'final ladder from a run interrupted at each step and then resumed '
        'equals the uninterrupted final ladder', () {
      // Simulates the worst-case: interrupted after every single match,
      // then resumed from the accumulated log.
      //
      // Pair order chosen so both matches cause promotions, making the
      // ladder state after match 1 meaningfully different from the initial.
      final candidates = [_config('a'), _config('b'), _config('c')];
      final fake = _FakeExecutor(fixedAWins: 7, fixedBWins: 3);

      // Full run for ground truth.
      // Initial (sorted): [a, b, c] — a=strongest.
      // Match 1: c (A, weakest) beats a (B, strongest) → c promoted to top
      //          → ladder: [c, a, b]
      // Match 2: b (A, index 2) beats c (B, index 0) → b promoted to top
      //          → ladder: [b, c, a]
      final full = _TestScheduler(candidates: candidates, fakeExecutor: fake);
      final pairs = [
        (_config('c'), _config('a')), // match 1
        (_config('b'), _config('c')), // match 2
      ];
      for (final (ca, cb) in pairs) {
        full.runMatch(ca, cb);
      }
      final groundTruthHash = full.ladder.hash;
      final groundTruthIds = full.ladder.ids.toList();

      // Ground truth must reflect promotions.
      expect(groundTruthIds.first, 'b',
          reason: 'b should be at top after two promotions');

      // Simulate step-by-step resume: build up the event log match by match.
      final accumulated = <AiLadderEvent>[];
      final sortedIds = (['a', 'b', 'c']..sort());
      final manifest = AiArenaRunManifest(
        candidateIds: sortedIds,
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 12345,
      );

      for (var interrupt = 0; interrupt < pairs.length; interrupt++) {
        // Reconstruct state from events saved so far.
        final resumeState = buildResumeState(
          currentManifest: manifest,
          savedManifest: manifest,
          savedJsonl: _toJsonl(accumulated),
          initialLadderIds: sortedIds,
        );

        final scheduler = _TestScheduler(
          candidates: candidates,
          fakeExecutor: fake,
          matchCounterOffset: resumeState.matchCounterOffset,
        );
        scheduler.restoreLadder(resumeState.reconstructedLadder);

        // Run exactly one match (the next one not yet completed).
        final (ca, cb) = pairs[interrupt];
        final event = scheduler.runMatch(ca, cb);
        accumulated.add(event);
      }

      // After all pairs have been run (possibly resumed), replay all events.
      final replayResult = AiArenaReplayer.replay(
        initialLadder: AiLadderSnapshot(sortedIds),
        events: accumulated,
      );

      expect(replayResult.passed, isTrue);
      expect(replayResult.finalLadder.hash, groundTruthHash,
          reason: 'Step-by-step resumed run must produce same hash');
      expect(replayResult.finalLadder.ids, groundTruthIds,
          reason: 'Step-by-step resumed run must produce same ladder order');
    });
  });

  // -------------------------------------------------------------------------
  // AiArenaRunManifest — unit-level
  // -------------------------------------------------------------------------
  group('AiArenaRunManifest', () {
    test('configHash is prefixed with "djb2:"', () {
      const m = AiArenaRunManifest(
        candidateIds: ['x'],
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 1,
      );
      expect(m.configHash, startsWith('djb2:'));
    });

    test('toJson includes configHash field', () {
      const m = AiArenaRunManifest(
        candidateIds: ['x'],
        boardSize: 9,
        captureTarget: 5,
        rounds: 10,
        promotionThreshold: 7,
        baseSeed: 1,
      );
      expect(m.toJson()['configHash'], m.configHash);
      expect(m.toJson()['maxMoves'], 512);
      expect(m.toJson()['openingPolicy'], 'empty_twist_cross_random_v1');
    });

    test('empty JSONL produces empty event list', () {
      final events = parseJsonlEvents('');
      expect(events, isEmpty);
    });

    test('JSONL with blank lines is parsed without error', () {
      final candidates = [_config('a'), _config('b')];
      final fake = _FakeExecutor(fixedAWins: 7, fixedBWins: 3);
      final s = _TestScheduler(candidates: candidates, fakeExecutor: fake);
      s.runMatch(_config('a'), _config('b'));

      final jsonlWithBlanks = '\n${s.events.first.toJsonLine()}\n\n';
      final parsed = parseJsonlEvents(jsonlWithBlanks);
      expect(parsed.length, 1);
    });
  });
}
