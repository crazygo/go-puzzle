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
      parameters:
          (json['parameters'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiBattleConfig && other.id == id;

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
    required this.black,
    required this.winner,
    required this.moves,
    required this.blackCaptures,
    required this.whiteCaptures,
    required this.endReason,
  });

  final int index;
  final int gameSeed;
  final int openingIndex;

  /// 'a' or 'b' — which config plays black.
  final String black;

  /// 'a', 'b', or 'draw'.
  final String winner;

  final int moves;
  final int blackCaptures;
  final int whiteCaptures;
  final String endReason;

  Map<String, dynamic> toJson() => {
        'index': index,
        'gameSeed': gameSeed,
        'openingIndex': openingIndex,
        'black': black,
        'winner': winner,
        'moves': moves,
        'blackCaptures': blackCaptures,
        'whiteCaptures': whiteCaptures,
        'endReason': endReason,
      };

  factory AiGameRecord.fromJson(Map<String, dynamic> json) {
    return AiGameRecord(
      index: json['index'] as int,
      gameSeed: json['gameSeed'] as int,
      openingIndex: json['openingIndex'] as int,
      black: json['black'] as String,
      winner: json['winner'] as String,
      moves: json['moves'] as int,
      blackCaptures: json['blackCaptures'] as int,
      whiteCaptures: json['whiteCaptures'] as int,
      endReason: json['endReason'] as String,
    );
  }
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
      configA: AiBattleConfig.fromJson(
          json['configA'] as Map<String, dynamic>),
      configB: AiBattleConfig.fromJson(
          json['configB'] as Map<String, dynamic>),
      aWins: json['aWins'] as int,
      bWins: json['bWins'] as int,
      draws: json['draws'] as int,
      games: (json['games'] as List<dynamic>)
          .map((g) => AiGameRecord.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }
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
      matchRules:
          Map<String, dynamic>.from(json['matchRules'] as Map),
      initialLadderHash: json['initialLadderHash'] as String,
      resultLadderHash: json['resultLadderHash'] as String,
      rawResult: AiMatchResult.fromJson(
          json['rawResult'] as Map<String, dynamic>),
      schedulerDecision: AiSchedulerDecision.fromJson(
          json['schedulerDecision'] as Map<String, dynamic>),
    );
  }

  String toJsonLine() => jsonEncode(toJson());

  static AiLadderEvent fromJsonLine(String line) =>
      AiLadderEvent.fromJson(
          jsonDecode(line) as Map<String, dynamic>);
}
