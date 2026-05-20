import 'dart:convert';

/// A stable identifier for an AI configuration used in arena experiments.
class AiBattleConfig {
  const AiBattleConfig({
    required this.id,
    required this.style,
    required this.difficulty,
    this.rank,
    this.profileVersion = 'capture_ai_profile_v1',
    this.parameters = const {},
  });

  /// Stable unique identifier, e.g. `hunter_r03_v1`.
  final String id;

  /// CaptureAiStyle.name value.
  final String style;

  /// DifficultyLevel.name value.
  final String difficulty;

  /// Optional 1–28 rank when available.
  final int? rank;

  /// Version string for the parameter recipe.
  final String profileVersion;

  /// Future-compatible map for explicit weights, playouts, blunder rates, etc.
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'style': style,
      'difficulty': difficulty,
      'profileVersion': profileVersion,
    };
    if (rank != null) map['rank'] = rank;
    if (parameters.isNotEmpty) map['parameters'] = parameters;
    return map;
  }

  factory AiBattleConfig.fromJson(Map<String, dynamic> json) {
    return AiBattleConfig(
      id: json['id'] as String,
      style: json['style'] as String,
      difficulty: json['difficulty'] as String,
      rank: json['rank'] as int?,
      profileVersion:
          json['profileVersion'] as String? ?? 'capture_ai_profile_v1',
      parameters: (json['parameters'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  bool operator ==(Object other) => other is AiBattleConfig && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AiBattleConfig($id)';
}

/// Per-game record within a match.
class AiGameRecord {
  const AiGameRecord({
    required this.index,
    required this.gameSeed,
    required this.openingIndex,
    required this.opening,
    required this.black,
    required this.winner,
    required this.moves,
    required this.blackCaptures,
    required this.whiteCaptures,
    required this.endReason,
    this.illegalMove = false,
    this.timedOut = false,
    this.fallbackUsed = false,
    this.maxDecisionMillis = 0,
    this.failureReason,
  });

  final int index;
  final int gameSeed;
  final int openingIndex;

  /// Stable opening name used to initialize the board, e.g. 'empty'.
  final String opening;

  /// 'a' or 'b' — which config plays black.
  final String black;

  /// 'a', 'b', or 'draw'.
  final String winner;

  final int moves;
  final int blackCaptures;
  final int whiteCaptures;
  final String endReason;
  final bool illegalMove;
  final bool timedOut;
  final bool fallbackUsed;
  final int maxDecisionMillis;
  final String? failureReason;

  Map<String, dynamic> toJson() => {
        'index': index,
        'gameSeed': gameSeed,
        'openingIndex': openingIndex,
        'opening': opening,
        'black': black,
        'winner': winner,
        'moves': moves,
        'blackCaptures': blackCaptures,
        'whiteCaptures': whiteCaptures,
        'endReason': endReason,
        'illegalMove': illegalMove,
        'timedOut': timedOut,
        'fallbackUsed': fallbackUsed,
        'maxDecisionMillis': maxDecisionMillis,
        if (failureReason != null) 'failureReason': failureReason,
      };

  factory AiGameRecord.fromJson(Map<String, dynamic> json) {
    return AiGameRecord(
      index: json['index'] as int,
      gameSeed: json['gameSeed'] as int,
      openingIndex: json['openingIndex'] as int,
      opening: json['opening'] as String? ?? 'legacy',
      black: json['black'] as String,
      winner: json['winner'] as String,
      moves: json['moves'] as int,
      blackCaptures: json['blackCaptures'] as int,
      whiteCaptures: json['whiteCaptures'] as int,
      endReason: json['endReason'] as String,
      illegalMove: json['illegalMove'] as bool? ?? false,
      timedOut: json['timedOut'] as bool? ?? false,
      fallbackUsed: json['fallbackUsed'] as bool? ?? false,
      maxDecisionMillis: json['maxDecisionMillis'] as int? ?? 0,
      failureReason: json['failureReason'] as String?,
    );
  }
}

class AiOpeningPerformance {
  const AiOpeningPerformance({
    required this.opening,
    required this.games,
    required this.aWins,
    required this.bWins,
    required this.draws,
    required this.illegalMoves,
    required this.timeouts,
    required this.fallbackGames,
  });

  final String opening;
  final int games;
  final int aWins;
  final int bWins;
  final int draws;
  final int illegalMoves;
  final int timeouts;
  final int fallbackGames;

  double get aWinRate => games == 0 ? 0 : aWins / games;
  double get bWinRate => games == 0 ? 0 : bWins / games;

  Map<String, dynamic> toJson() => {
        'opening': opening,
        'games': games,
        'aWins': aWins,
        'bWins': bWins,
        'draws': draws,
        'aWinRate': aWinRate,
        'bWinRate': bWinRate,
        'illegalMoves': illegalMoves,
        'timeouts': timeouts,
        'fallbackGames': fallbackGames,
      };
}

class AiPairwiseSummary {
  const AiPairwiseSummary({
    required this.configAId,
    required this.configBId,
    required this.games,
    required this.aWins,
    required this.bWins,
    required this.draws,
    required this.illegalMoves,
    required this.timeouts,
    required this.fallbackGames,
    required this.failureReasons,
  });

  final String configAId;
  final String configBId;
  final int games;
  final int aWins;
  final int bWins;
  final int draws;
  final int illegalMoves;
  final int timeouts;
  final int fallbackGames;
  final List<String> failureReasons;

  double get aWinRate => games == 0 ? 0 : aWins / games;
  double get bWinRate => games == 0 ? 0 : bWins / games;

  Map<String, dynamic> toJson() => {
        'configAId': configAId,
        'configBId': configBId,
        'games': games,
        'aWins': aWins,
        'bWins': bWins,
        'draws': draws,
        'aWinRate': aWinRate,
        'bWinRate': bWinRate,
        'illegalMoves': illegalMoves,
        'timeouts': timeouts,
        'fallbackGames': fallbackGames,
        'failureReasons': failureReasons,
      };
}

class AiRankingEntry {
  const AiRankingEntry({
    required this.rank,
    required this.configId,
    required this.matchWins,
    required this.matchLosses,
    required this.matchDraws,
    required this.gameWins,
    required this.gameLosses,
    required this.draws,
    required this.games,
    required this.illegalMoves,
    required this.timeouts,
    required this.fallbackGames,
  });

  final int rank;
  final String configId;
  final int matchWins;
  final int matchLosses;
  final int matchDraws;
  final int gameWins;
  final int gameLosses;
  final int draws;
  final int games;
  final int illegalMoves;
  final int timeouts;
  final int fallbackGames;

  double get matchWinRate {
    final matches = matchWins + matchLosses + matchDraws;
    return matches == 0 ? 0 : matchWins / matches;
  }

  double get gameWinRate => games == 0 ? 0 : gameWins / games;

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'configId': configId,
        'matchWins': matchWins,
        'matchLosses': matchLosses,
        'matchDraws': matchDraws,
        'matchWinRate': matchWinRate,
        'gameWins': gameWins,
        'gameLosses': gameLosses,
        'draws': draws,
        'games': games,
        'gameWinRate': gameWinRate,
        'illegalMoves': illegalMoves,
        'timeouts': timeouts,
        'fallbackGames': fallbackGames,
      };
}

class AiArenaEvaluationSummary {
  const AiArenaEvaluationSummary({
    required this.matches,
    required this.pairwise,
    required this.rankings,
    required this.openingPerformance,
  });

  final List<AiMatchResult> matches;
  final List<AiPairwiseSummary> pairwise;
  final List<AiRankingEntry> rankings;
  final List<AiOpeningPerformance> openingPerformance;

  factory AiArenaEvaluationSummary.fromMatches(List<AiMatchResult> matches) {
    final pairwise = matches.map(_pairwiseSummaryFor).toList(growable: false);
    final stats = <String, _RankingStats>{};
    final openingGames = <String, List<AiGameRecord>>{};

    for (final match in matches) {
      final aId = match.configA.id;
      final bId = match.configB.id;
      final aStats = stats.putIfAbsent(aId, () => _RankingStats(aId));
      final bStats = stats.putIfAbsent(bId, () => _RankingStats(bId));

      if (match.aWins > match.bWins) {
        aStats.matchWins++;
        bStats.matchLosses++;
      } else if (match.bWins > match.aWins) {
        bStats.matchWins++;
        aStats.matchLosses++;
      } else {
        aStats.matchDraws++;
        bStats.matchDraws++;
      }

      aStats.gameWins += match.aWins;
      aStats.gameLosses += match.bWins;
      aStats.draws += match.draws;
      aStats.games += match.rounds;
      bStats.gameWins += match.bWins;
      bStats.gameLosses += match.aWins;
      bStats.draws += match.draws;
      bStats.games += match.rounds;

      for (final game in match.games) {
        openingGames.putIfAbsent(game.opening, () => []).add(game);
        if (game.illegalMove) {
          aStats.illegalMoves++;
          bStats.illegalMoves++;
        }
        if (game.timedOut) {
          aStats.timeouts++;
          bStats.timeouts++;
        }
        if (game.fallbackUsed) {
          aStats.fallbackGames++;
          bStats.fallbackGames++;
        }
      }
    }

    final sortedStats = stats.values.toList()
      ..sort((a, b) {
        final matchWins = b.matchWins.compareTo(a.matchWins);
        if (matchWins != 0) return matchWins;
        final gameRate = b.gameWinRate.compareTo(a.gameWinRate);
        if (gameRate != 0) return gameRate;
        final gameWins = b.gameWins.compareTo(a.gameWins);
        if (gameWins != 0) return gameWins;
        return a.configId.compareTo(b.configId);
      });

    final rankings = <AiRankingEntry>[];
    for (var i = 0; i < sortedStats.length; i++) {
      rankings.add(sortedStats[i].toEntry(rank: i + 1));
    }

    return AiArenaEvaluationSummary(
      matches: List.unmodifiable(matches),
      pairwise: pairwise,
      rankings: rankings,
      openingPerformance: _openingPerformanceFor(openingGames),
    );
  }

  Map<String, dynamic> toJson() => {
        'matches': matches.map((match) => match.toJson()).toList(),
        'pairwise': pairwise.map((entry) => entry.toJson()).toList(),
        'rankings': rankings.map((entry) => entry.toJson()).toList(),
        'openingPerformance':
            openingPerformance.map((entry) => entry.toJson()).toList(),
      };
}

/// Raw, reproducible executor output. Contains no promotion or ranking
/// interpretation — only match facts and deterministic replay fields.
class AiMatchResult {
  const AiMatchResult({
    required this.matchSeed,
    required this.openingSeed,
    required this.openingPolicy,
    required this.boardSize,
    required this.captureTarget,
    required this.rounds,
    required this.maxMoves,
    required this.configA,
    required this.configB,
    required this.aWins,
    required this.bWins,
    required this.draws,
    required this.games,
  });

  final int matchSeed;
  final int openingSeed;
  final String openingPolicy;
  final int boardSize;
  final int captureTarget;
  final int rounds;
  final int maxMoves;
  final AiBattleConfig configA;
  final AiBattleConfig configB;
  final int aWins;
  final int bWins;
  final int draws;
  final List<AiGameRecord> games;

  double get aWinRate => rounds == 0 ? 0 : aWins / rounds;
  double get bWinRate => rounds == 0 ? 0 : bWins / rounds;

  List<AiOpeningPerformance> get openingPerformance {
    final grouped = <String, List<AiGameRecord>>{};
    for (final game in games) {
      grouped.putIfAbsent(game.opening, () => []).add(game);
    }
    return _openingPerformanceFor(grouped);
  }

  Map<String, dynamic> toJson() => {
        'matchSeed': matchSeed,
        'openingSeed': openingSeed,
        'openingPolicy': openingPolicy,
        'boardSize': boardSize,
        'captureTarget': captureTarget,
        'rounds': rounds,
        'maxMoves': maxMoves,
        'configA': configA.toJson(),
        'configB': configB.toJson(),
        'aWins': aWins,
        'bWins': bWins,
        'draws': draws,
        'aWinRate': aWinRate,
        'bWinRate': bWinRate,
        'games': games.map((g) => g.toJson()).toList(),
        'openingPerformance':
            openingPerformance.map((entry) => entry.toJson()).toList(),
      };

  factory AiMatchResult.fromJson(Map<String, dynamic> json) {
    return AiMatchResult(
      matchSeed: json['matchSeed'] as int,
      openingSeed: json['openingSeed'] as int,
      openingPolicy: json['openingPolicy'] as String,
      boardSize: json['boardSize'] as int,
      captureTarget: json['captureTarget'] as int,
      rounds: json['rounds'] as int,
      maxMoves: json['maxMoves'] as int,
      configA: AiBattleConfig.fromJson(json['configA'] as Map<String, dynamic>),
      configB: AiBattleConfig.fromJson(json['configB'] as Map<String, dynamic>),
      aWins: json['aWins'] as int,
      bWins: json['bWins'] as int,
      draws: json['draws'] as int,
      games: (json['games'] as List<dynamic>)
          .map((g) => AiGameRecord.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }
}

AiPairwiseSummary _pairwiseSummaryFor(AiMatchResult match) {
  final failureReasons = <String>{};
  var illegalMoves = 0;
  var timeouts = 0;
  var fallbackGames = 0;
  for (final game in match.games) {
    if (game.illegalMove) illegalMoves++;
    if (game.timedOut) timeouts++;
    if (game.fallbackUsed) fallbackGames++;
    final failureReason = game.failureReason;
    if (failureReason != null) failureReasons.add(failureReason);
  }
  return AiPairwiseSummary(
    configAId: match.configA.id,
    configBId: match.configB.id,
    games: match.rounds,
    aWins: match.aWins,
    bWins: match.bWins,
    draws: match.draws,
    illegalMoves: illegalMoves,
    timeouts: timeouts,
    fallbackGames: fallbackGames,
    failureReasons: failureReasons.toList()..sort(),
  );
}

List<AiOpeningPerformance> _openingPerformanceFor(
  Map<String, List<AiGameRecord>> grouped,
) {
  final entries = <AiOpeningPerformance>[];
  for (final entry in grouped.entries) {
    var aWins = 0;
    var bWins = 0;
    var draws = 0;
    var illegalMoves = 0;
    var timeouts = 0;
    var fallbackGames = 0;
    for (final game in entry.value) {
      switch (game.winner) {
        case 'a':
          aWins++;
        case 'b':
          bWins++;
        default:
          draws++;
      }
      if (game.illegalMove) illegalMoves++;
      if (game.timedOut) timeouts++;
      if (game.fallbackUsed) fallbackGames++;
    }
    entries.add(AiOpeningPerformance(
      opening: entry.key,
      games: entry.value.length,
      aWins: aWins,
      bWins: bWins,
      draws: draws,
      illegalMoves: illegalMoves,
      timeouts: timeouts,
      fallbackGames: fallbackGames,
    ));
  }
  entries.sort((a, b) => a.opening.compareTo(b.opening));
  return entries;
}

class _RankingStats {
  _RankingStats(this.configId);

  final String configId;
  int matchWins = 0;
  int matchLosses = 0;
  int matchDraws = 0;
  int gameWins = 0;
  int gameLosses = 0;
  int draws = 0;
  int games = 0;
  int illegalMoves = 0;
  int timeouts = 0;
  int fallbackGames = 0;

  double get gameWinRate => games == 0 ? 0 : gameWins / games;

  AiRankingEntry toEntry({required int rank}) => AiRankingEntry(
        rank: rank,
        configId: configId,
        matchWins: matchWins,
        matchLosses: matchLosses,
        matchDraws: matchDraws,
        gameWins: gameWins,
        gameLosses: gameLosses,
        draws: draws,
        games: games,
        illegalMoves: illegalMoves,
        timeouts: timeouts,
        fallbackGames: fallbackGames,
      );
}

/// The scheduler's ranking decision after a match.
class AiSchedulerDecision {
  const AiSchedulerDecision({
    required this.winner,
    required this.loser,
    required this.decision,
    required this.reason,
    required this.before,
    required this.after,
  });

  /// Config id of the match winner, or null if inconclusive.
  final String? winner;

  /// Config id of the match loser, or null if inconclusive.
  final String? loser;

  /// One of: 'promote_winner', 'no_change_winner_already_higher',
  /// 'inconclusive', 'new_candidate_inserted'.
  final String decision;

  /// Human-readable rationale.
  final String reason;

  /// Ordered ladder (strongest → weakest) before this match.
  final List<String> before;

  /// Ordered ladder after this match.
  final List<String> after;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'decision': decision,
      'reason': reason,
      'before': before,
      'after': after,
    };
    if (winner != null) map['winner'] = winner;
    if (loser != null) map['loser'] = loser;
    return map;
  }

  factory AiSchedulerDecision.fromJson(Map<String, dynamic> json) {
    return AiSchedulerDecision(
      winner: json['winner'] as String?,
      loser: json['loser'] as String?,
      decision: json['decision'] as String,
      reason: json['reason'] as String,
      before: List<String>.from(json['before'] as List<dynamic>),
      after: List<String>.from(json['after'] as List<dynamic>),
    );
  }
}

/// Scheduler-owned append-only JSONL event. Wraps rawResult and adds
/// schedulerDecision, ladder hashes, and replay metadata.
class AiLadderEvent {
  const AiLadderEvent({
    required this.schemaVersion,
    required this.eventType,
    required this.matchId,
    required this.createdAt,
    this.previousMatchId,
    required this.schedulerVersion,
    required this.executorVersion,
    required this.configVersion,
    required this.matchRules,
    required this.initialLadderHash,
    required this.resultLadderHash,
    required this.rawResult,
    required this.schedulerDecision,
  });

  final int schemaVersion;
  final String eventType;
  final String matchId;
  final String createdAt;
  final String? previousMatchId;
  final String schedulerVersion;
  final String executorVersion;
  final String configVersion;
  final Map<String, dynamic> matchRules;
  final String initialLadderHash;
  final String resultLadderHash;
  final AiMatchResult rawResult;
  final AiSchedulerDecision schedulerDecision;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'eventType': eventType,
      'matchId': matchId,
      'createdAt': createdAt,
      'schedulerVersion': schedulerVersion,
      'executorVersion': executorVersion,
      'configVersion': configVersion,
      'matchRules': matchRules,
      'initialLadderHash': initialLadderHash,
      'resultLadderHash': resultLadderHash,
      'rawResult': rawResult.toJson(),
      'schedulerDecision': schedulerDecision.toJson(),
    };
    if (previousMatchId != null) map['previousMatchId'] = previousMatchId;
    return map;
  }

  factory AiLadderEvent.fromJson(Map<String, dynamic> json) {
    return AiLadderEvent(
      schemaVersion: json['schemaVersion'] as int,
      eventType: json['eventType'] as String,
      matchId: json['matchId'] as String,
      createdAt: json['createdAt'] as String,
      previousMatchId: json['previousMatchId'] as String?,
      schedulerVersion: json['schedulerVersion'] as String,
      executorVersion: json['executorVersion'] as String,
      configVersion: json['configVersion'] as String,
      matchRules: Map<String, dynamic>.from(json['matchRules'] as Map),
      initialLadderHash: json['initialLadderHash'] as String,
      resultLadderHash: json['resultLadderHash'] as String,
      rawResult:
          AiMatchResult.fromJson(json['rawResult'] as Map<String, dynamic>),
      schedulerDecision: AiSchedulerDecision.fromJson(
          json['schedulerDecision'] as Map<String, dynamic>),
    );
  }

  String toJsonLine() => jsonEncode(toJson());

  static AiLadderEvent fromJsonLine(String line) =>
      AiLadderEvent.fromJson(jsonDecode(line) as Map<String, dynamic>);
}
