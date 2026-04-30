import 'dart:convert';

import 'ai_arena_ladder.dart';
import 'ai_arena_executor.dart';

const String _schedulerVersion = 'ai_arena_scheduler_v1';

/// Computes a canonical ladder hash from an ordered list of config IDs.
///
/// Canonicalization: UTF-8 JSON with sorted object keys, stable array order,
/// no insignificant whitespace.
String computeLadderHash(List<String> ladderIds) {
  // Build canonical JSON representation.
  final canonical = _canonicalJson({'ladder': ladderIds});
  // Use a simple deterministic digest (djb2-style) encoded as hex,
  // prefixed with 'djb2:'. The value is stable and deterministic.
  final bytes = utf8.encode(canonical);
  final hash = _stableDjb2Hex(bytes);
  return 'djb2:$hash';
}

/// Produces a canonical JSON string with sorted object keys.
String _canonicalJson(Object? value) {
  if (value is Map) {
    final sorted = Map.fromEntries(
      (value.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
          .map((e) => MapEntry(e.key, e.value)),
    );
    final inner = sorted.entries
        .map((e) => '${jsonEncode(e.key)}:${_canonicalJson(e.value)}')
        .join(',');
    return '{$inner}';
  } else if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  } else {
    return jsonEncode(value);
  }
}

/// DJB2 hash over bytes, returned as a 16-character hex string.
String _stableDjb2Hex(List<int> bytes) {
  var h = 5381;
  for (final b in bytes) {
    h = ((h << 5) + h + b) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// Ladder snapshot — the current ordered list (strongest → weakest).
class AiLadderSnapshot {
  AiLadderSnapshot(List<String> ids) : _ids = List<String>.from(ids);

  final List<String> _ids;

  /// Ordered list of config IDs (strongest → weakest).
  List<String> get ids => List<String>.unmodifiable(_ids);

  String get hash => computeLadderHash(_ids);

  Map<String, dynamic> toJson() => {
        'ladder': _ids,
        'hash': hash,
      };

  factory AiLadderSnapshot.fromJson(Map<String, dynamic> json) {
    return AiLadderSnapshot(
      List<String>.from(json['ladder'] as List<dynamic>),
    );
  }

  /// Returns the 0-based rank index of [id], or -1 if not present.
  int indexOf(String id) => _ids.indexOf(id);

  /// Ensures [id] exists in the ladder (appended at weakest end if absent).
  void ensurePresent(String id) {
    if (!_ids.contains(id)) _ids.add(id);
  }

  /// Inserts all IDs that are not yet present, in the given order,
  /// at the weakest end (appended).
  void insertNewCandidates(List<String> candidates) {
    for (final id in candidates) {
      if (!_ids.contains(id)) _ids.add(id);
    }
  }

  /// Moves [winnerId] immediately before [loserId] in the list.
  /// No-op if [winnerId] is already ranked above [loserId].
  ///
  /// Returns true if the ladder changed.
  bool promoteWinner(String winnerId, String loserId) {
    final winnerIdx = _ids.indexOf(winnerId);
    final loserIdx = _ids.indexOf(loserId);

    if (winnerIdx == -1 || loserIdx == -1) return false;
    if (winnerIdx < loserIdx) return false; // already above, no change
    // Remove winner and insert immediately before loser's current position.
    _ids.removeAt(winnerIdx);
    final newLoserIdx = _ids.indexOf(loserId);
    _ids.insert(newLoserIdx, winnerId);
    return true;
  }

  AiLadderSnapshot copy() => AiLadderSnapshot(List<String>.from(_ids));
}

/// The scheduler owns the ranking list and drives match selection.
///
/// Ladder rules (Phase C):
/// - Promotion threshold: 7 wins out of [promotionThreshold] games.
/// - If A wins >= threshold, A is the match winner.
/// - If B wins >= threshold, B is the match winner.
/// - Otherwise the match is inconclusive.
/// - Draws do NOT count toward either side's threshold.
/// - If the winner is already ranked above the loser → no change.
/// - If the winner is ranked below the loser → winner moves immediately
///   before the loser.
/// - New configs are appended at the weakest end first.
class AiArenaScheduler {
  AiArenaScheduler({
    required List<AiBattleConfig> candidates,
    AiArenaExecutor? executor,
    this.promotionThreshold = 7,
    int? baseSeed,
  })  : _executor = executor ?? const AiArenaExecutor(),
        _baseSeed = baseSeed ?? 123456 {
    // Register candidates in registration order, falling back to id lexical.
    final sorted = List<AiBattleConfig>.from(candidates)
      ..sort((a, b) => a.id.compareTo(b.id));
    _candidateMap = {for (final c in sorted) c.id: c};
    _ladder = AiLadderSnapshot([]);
    // Insert candidates at the weakest end in lexical order.
    _ladder.insertNewCandidates(sorted.map((c) => c.id).toList());
  }

  final AiArenaExecutor _executor;
  final int _baseSeed;
  late final Map<String, AiBattleConfig> _candidateMap;
  late AiLadderSnapshot _ladder;

  final int promotionThreshold;

  String? _lastMatchId;
  int _matchCounter = 0;

  final List<AiLadderEvent> _events = [];

  String get schedulerVersion => _schedulerVersion;

  /// Current ladder snapshot (strongest → weakest).
  AiLadderSnapshot get ladder => _ladder;

  /// All events logged so far.
  List<AiLadderEvent> get events => List.unmodifiable(_events);

  /// Runs a single head-to-head match between [configA] and [configB],
  /// applies the ladder rules, and appends an [AiLadderEvent].
  AiLadderEvent runMatch(AiBattleConfig configA, AiBattleConfig configB) {
    // Ensure both are registered.
    _candidateMap.putIfAbsent(configA.id, () => configA);
    _candidateMap.putIfAbsent(configB.id, () => configB);
    _ladder.insertNewCandidates([configA.id, configB.id]);

    final initialSnapshot = _ladder.copy();
    final initialHash = initialSnapshot.hash;

    final matchSeed = _baseSeed + _matchCounter * 7919;
    final openingSeed = _baseSeed + _matchCounter * 1337;
    _matchCounter++;

    final rawResult = _executor.runMatch(
      configA: configA,
      configB: configB,
      matchSeed: matchSeed,
      openingSeed: openingSeed,
    );

    final decision = _applyLadderRules(rawResult, initialSnapshot);

    final resultHash = _ladder.hash;

    final now = DateTime.now().toUtc();
    final matchId = _buildMatchId(now, configA.id, configB.id);

    final event = AiLadderEvent(
      schemaVersion: 1,
      eventType: 'ladder_match',
      matchId: matchId,
      createdAt: now.toIso8601String(),
      previousMatchId: _lastMatchId,
      schedulerVersion: _schedulerVersion,
      executorVersion: _executor.executorVersion,
      configVersion: configA.profileVersion,
      matchRules: {'promotionThreshold': promotionThreshold},
      initialLadderHash: initialHash,
      resultLadderHash: resultHash,
      rawResult: rawResult,
      schedulerDecision: decision,
    );

    _events.add(event);
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
      decision = 'inconclusive';
      reason =
          'aWins(${result.aWins}) and bWins(${result.bWins}) both < $promotionThreshold';
      return AiSchedulerDecision(
        winner: null,
        loser: null,
        decision: decision,
        reason: reason,
        before: before,
        after: _ladder.ids.toList(),
      );
    }

    final winnerIdx = _ladder.indexOf(winnerId);
    final loserIdx = _ladder.indexOf(loserId);

    if (winnerIdx <= loserIdx) {
      // Winner is already ranked at or above loser (lower index = stronger,
      // equal indices means same config or already at same level).
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

    // Move winner immediately before loser.
    _ladder.promoteWinner(winnerId, loserId);
    decision = 'promote_winner';

    return AiSchedulerDecision(
      winner: winnerId,
      loser: loserId,
      decision: decision,
      reason: reason,
      before: before,
      after: _ladder.ids.toList(),
    );
  }

  /// Builds a match ID from the timestamp and config IDs.
  String _buildMatchId(
      DateTime ts, String configAId, String configBId) {
    final stamp = ts
        .toIso8601String()
        .replaceAll(RegExp(r'[:\-]'), '')
        .substring(0, 15);
    final a = configAId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final b = configBId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '${stamp}Z_${a}_vs_$b';
  }
}

/// Decision-replay: replays a list of [AiLadderEvent] objects against an
/// initial ladder state and returns the final [AiLadderSnapshot].
///
/// This does NOT rerun actual games — it only re-applies scheduler decisions
/// from the event log and verifies hashes.
class AiArenaReplayer {
  /// Replays [events] starting from [initialLadder].
  ///
  /// Returns the final snapshot and a list of any hash mismatches found.
  static AiReplayResult replay({
    required AiLadderSnapshot initialLadder,
    required List<AiLadderEvent> events,
    int promotionThreshold = 7,
  }) {
    final ladder = initialLadder.copy();
    final mismatches = <String>[];

    for (final event in events) {
      final initialHash = ladder.hash;
      if (initialHash != event.initialLadderHash) {
        mismatches.add(
          'match=${event.matchId}: '
          'expected initialLadderHash=${event.initialLadderHash}, '
          'got=$initialHash',
        );
      }

      // Re-apply the scheduler decision.
      final decision = event.schedulerDecision;
      if (decision.decision == 'promote_winner' &&
          decision.winner != null &&
          decision.loser != null) {
        // Ensure both are present.
        ladder.ensurePresent(decision.winner!);
        ladder.ensurePresent(decision.loser!);
        ladder.promoteWinner(decision.winner!, decision.loser!);
      }

      final resultHash = ladder.hash;
      if (resultHash != event.resultLadderHash) {
        mismatches.add(
          'match=${event.matchId}: '
          'expected resultLadderHash=${event.resultLadderHash}, '
          'got=$resultHash',
        );
      }
    }

    return AiReplayResult(
      finalLadder: ladder,
      hashMismatches: mismatches,
    );
  }
}

/// Result of replaying a match log.
class AiReplayResult {
  const AiReplayResult({
    required this.finalLadder,
    required this.hashMismatches,
  });

  final AiLadderSnapshot finalLadder;
  final List<String> hashMismatches;

  bool get passed => hashMismatches.isEmpty;
}

/// Runs a per-style adjacent-pair ladder sweep until stable.
///
/// For each adjacent pair (i, i+1), runs a match. If the lower-ranked config
/// wins, it is promoted and the sweep restarts from the top. Stops when one
/// full pass produces no changes.
class AiArenaAdjacentPairScheduler {
  AiArenaAdjacentPairScheduler({
    required List<AiBattleConfig> candidates,
    AiArenaExecutor? executor,
    int promotionThreshold = 7,
    int? baseSeed,
  }) : _scheduler = AiArenaScheduler(
          candidates: candidates,
          executor: executor,
          promotionThreshold: promotionThreshold,
          baseSeed: baseSeed,
        );

  final AiArenaScheduler _scheduler;

  AiArenaScheduler get scheduler => _scheduler;

  /// Runs adjacent-pair sweeps until stable.
  /// Returns all events produced.
  List<AiLadderEvent> runUntilStable({int maxPasses = 20}) {
    final allEvents = <AiLadderEvent>[];

    for (var pass = 0; pass < maxPasses; pass++) {
      var changed = false;

      final ids = _scheduler.ladder.ids;
      for (var i = 0; i < ids.length - 1; i++) {
        final higherIdx = i;
        final lowerIdx = i + 1;
        final higherId = ids[higherIdx];
        final lowerId = ids[lowerIdx];

        final configA = _scheduler._candidateMap[lowerId]!;
        final configB = _scheduler._candidateMap[higherId]!;

        final event = _scheduler.runMatch(configA, configB);
        allEvents.add(event);

        if (event.schedulerDecision.decision == 'promote_winner') {
          changed = true;
          break; // restart pass
        }
      }

      if (!changed) break;
    }

    return allEvents;
  }

  // Expose candidate map for convenience.
}
