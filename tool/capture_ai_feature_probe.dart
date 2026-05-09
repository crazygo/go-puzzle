// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/capture_ai_tactics.dart';
import 'package:go_puzzle/game/difficulty_level.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/models/board_position.dart';

const _defaultProblemsPath = 'docs/ai_eval/tactics/problems.json';

void main(List<String> args) {
  try {
    final opts = _parseArgs(args);
    if (opts.containsKey('help')) {
      _printUsage();
      return;
    }

    final outputPath = opts['output'];
    if (outputPath == null || outputPath.isEmpty) {
      stderr.writeln('ERROR: --output is required.');
      _printUsage();
      exitCode = 2;
      return;
    }

    final ids = _parseNames(opts['ids'] ?? '');
    final style = _parseStyle(opts['style'] ?? 'hunter');
    final difficulty = _parseDifficulty(opts['difficulty'] ?? 'advanced');
    final scoreProfile = _diagnosticProfileFor(style, difficulty);
    final top = _parsePositiveInt(opts['top'], fallback: 5);
    final problemsPath = opts['problems'] ?? _defaultProblemsPath;
    final oracleConfig = CaptureAiTacticalOracleConfig(
      depth: _parsePositiveInt(
        opts['oracle-depth'] ?? opts['depth'],
        fallback: 4,
      ),
      candidateHorizon: _parsePositiveInt(
        opts['oracle-horizon'] ?? opts['horizon'],
        fallback: 10,
      ),
      maxNodes: _parsePositiveInt(
        opts['oracle-max-nodes'] ?? opts['max-nodes'],
        fallback: 25000,
      ),
    );

    final problemsFile = File(problemsPath);
    if (!problemsFile.existsSync()) {
      stderr.writeln('ERROR: Problem file not found: $problemsPath');
      exitCode = 2;
      return;
    }

    final problemSet = CaptureAiTacticsProblemSet.fromJsonString(
      problemsFile.readAsStringSync(),
    );
    final problemById = {
      for (final problem in problemSet.problems) problem.id: problem,
    };
    final missingIds = [
      for (final id in ids)
        if (!problemById.containsKey(id)) id,
    ];
    if (missingIds.isNotEmpty) {
      throw FormatException('Unknown problem id(s): ${missingIds.join(', ')}');
    }

    final oracle = CaptureAiTacticalOracle(config: oracleConfig);
    final problemReports = <Map<String, Object?>>[];
    print('=== Capture AI Feature Probe ===');
    print(
      'Config: style=${style.name} difficulty=${difficulty.name} '
      'oracleDepth=${oracleConfig.depth} '
      'horizon=${oracleConfig.candidateHorizon} '
      'maxNodes=${oracleConfig.maxNodes} top=$top',
    );
    print('');

    for (final id in ids) {
      final problem = problemById[id]!;
      final report = _probeProblem(
        problem,
        oracle: oracle,
        style: style,
        difficulty: difficulty,
        scoreProfile: scoreProfile,
        top: top,
      );
      problemReports.add(report);
      _printProblem(report);
    }

    _writeReport(outputPath, {
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'problemPath': problemsPath,
      'ids': ids,
      'style': style.name,
      'difficulty': difficulty.name,
      'scoreProfile': scoreProfile.toJson(),
      'top': top,
      'oracleConfig': oracleConfig.toJson(),
      'problems': problemReports,
    });
    print('JSON report: $outputPath');
  } on CaptureAiTacticsFormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 2;
  } on FormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 2;
  } on FileSystemException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 1;
  }
}

Map<String, Object?> _probeProblem(
  CaptureAiTacticsProblem problem, {
  required CaptureAiTacticalOracle oracle,
  required CaptureAiStyle style,
  required DifficultyLevel difficulty,
  required _DiagnosticScoreProfile scoreProfile,
  required int top,
}) {
  final board = problem.toBoard();
  final oracleResult = oracle.rankMoves(problem);
  final aiMove = CaptureAiRegistry.create(
    style: style,
    difficulty: difficulty,
  ).chooseMove(SimBoard.copy(board));
  final aiPosition = aiMove?.position;
  final advancedCandidatePath = _advancedHunterCandidatePathReport(
    board,
    oracleResult: oracleResult,
    aiMove: aiMove,
    scoreProfile: scoreProfile,
    difficulty: difficulty,
  );
  final moves = <BoardPosition>[];
  for (final oracleMove in oracleResult.rankedMoves.take(top)) {
    moves.add(oracleMove.position);
  }
  if (aiPosition != null && !moves.contains(aiPosition)) {
    moves.add(aiPosition);
  }

  return {
    'id': problem.id,
    'boardSize': problem.boardSize,
    'captureTarget': problem.captureTarget,
    'currentPlayer': _playerName(problem.currentPlayer),
    'category': problem.category,
    'tactic': problem.metadata['tactic'],
    'oracle': {
      'authoritative': oracleResult.authoritative,
      'rankedMoveCount': oracleResult.rankedMoves.length,
      'acceptedMoveCount': oracleResult.acceptedMoveCount,
      'acceptedMoveRatio': _round(oracleResult.acceptedMoveRatio),
      'confidenceGap': _roundOrNull(oracleResult.confidenceGap),
      'acceptedBandGap': _roundOrNull(oracleResult.acceptedBandGap),
      'trace': oracleResult.trace.toJson(),
    },
    'aiMove': aiPosition == null
        ? null
        : {
            ..._positionJson(aiPosition),
            'score': _round(aiMove!.score),
            'oracleRank': oracleResult.rankOf(aiPosition),
            'oracleScore': _roundOrNull(oracleResult.moveAt(aiPosition)?.score),
          },
    'advancedHunterCandidatePath': advancedCandidatePath,
    'moves': [
      for (final position in moves)
        _moveReport(
          board,
          position,
          oracleResult: oracleResult,
          aiPosition: aiPosition,
          scoreProfile: scoreProfile,
          difficulty: difficulty,
        ),
    ],
  };
}

Map<String, Object?> _advancedHunterCandidatePathReport(
  SimBoard board, {
  required CaptureAiOracleResult oracleResult,
  required CaptureAiMove? aiMove,
  required _DiagnosticScoreProfile scoreProfile,
  required DifficultyLevel difficulty,
}) {
  final candidatesByPosition = <BoardPosition, _CandidateAccumulator>{};
  final targetWinCache = <int, bool>{};

  void addSource(
    String label,
    CaptureAiMove? move, {
    Map<String, Object?> details = const {},
  }) {
    if (move == null) return;
    final candidate = candidatesByPosition.putIfAbsent(
      move.position,
      () => _CandidateAccumulator(move.position),
    );
    candidate.addSource(label, move.score, details: details);
  }

  final urgentMove = _chooseDiagnosticUrgentMove(
    board,
    scoreProfile: scoreProfile,
    difficulty: difficulty,
  );
  addSource(
    'urgentMove',
    urgentMove,
    details: {
      'immediateTargetWin':
          urgentMove != null && _isImmediateTargetWin(board, urgentMove),
    },
  );

  final lookaheadMoves = _rankDiagnosticLookaheadMoves(
    board,
    scoreProfile: scoreProfile,
    difficulty: difficulty,
    limit: 4,
  );
  for (var i = 0; i < lookaheadMoves.length; i++) {
    addSource(
      'lookaheadTop${i + 1}',
      lookaheadMoves[i],
      details: {'lookaheadRank': i + 1},
    );
  }

  final heuristicMove = _chooseDiagnosticHeuristicMove(
    board,
    scoreProfile: scoreProfile,
  );
  addSource('heuristicMove', heuristicMove);

  final hasQuietTacticalContext = urgentMove != null ||
      board.capturedByBlack > 0 ||
      board.capturedByWhite > 0;
  final quietTacticalMoves =
      difficulty == DifficultyLevel.advanced && hasQuietTacticalContext
          ? _rankDiagnosticQuietTacticalMoves(
              board,
              scoreProfile: scoreProfile,
              limit: 4,
            )
          : const <CaptureAiMove>[];
  for (var i = 0; i < quietTacticalMoves.length; i++) {
    addSource(
      'quietTacticalTop${i + 1}',
      quietTacticalMoves[i],
      details: {'quietTacticalRank': i + 1},
    );
  }

  addSource('actualAiMove', aiMove);

  final urgentCandidateChoice = urgentMove == null
      ? null
      : _bestDiagnosticTargetSafeCandidate(
          board,
          [
            urgentMove,
            if (heuristicMove != null) heuristicMove,
            ...lookaheadMoves.take(4),
            ...quietTacticalMoves,
          ]..sort((a, b) => b.score.compareTo(a.score)),
          targetWinCache,
        );
  final quietCandidateChoice = urgentMove == null
      ? _bestDiagnosticAdvancedQuietTacticalMove(
          board,
          quietTacticalMoves,
          heuristicMove,
          targetWinCache,
        )
      : null;

  final candidates = candidatesByPosition.values.toList()
    ..sort((a, b) {
      final aRank = oracleResult.rankOf(a.position) ?? 1 << 20;
      final bRank = oracleResult.rankOf(b.position) ?? 1 << 20;
      final byRank = aRank.compareTo(bRank);
      if (byRank != 0) return byRank;
      return b.bestSourceScore.compareTo(a.bestSourceScore);
    });

  return {
    'note':
        'Diagnostic-only approximation of the private hunter advanced path in lib/game/capture_ai.dart.',
    'sourceSummary': {
      'urgentMove': _candidateSummary(urgentMove),
      'heuristicMove': _candidateSummary(heuristicMove),
      'lookaheadMoveCount': lookaheadMoves.length,
      'quietTacticalContext': hasQuietTacticalContext,
      'quietTacticalMoveCount': quietTacticalMoves.length,
      'urgentBranchChoice': _candidateSummary(urgentCandidateChoice),
      'quietBranchChoice': _candidateSummary(quietCandidateChoice),
      'actualAiMove': _candidateSummary(aiMove),
    },
    'candidates': [
      for (final candidate in candidates)
        _advancedCandidateJson(
          board,
          candidate,
          oracleResult: oracleResult,
          aiMove: aiMove,
          scoreProfile: scoreProfile,
          difficulty: difficulty,
        ),
    ],
  };
}

Map<String, Object?>? _candidateSummary(CaptureAiMove? move) {
  if (move == null) return null;
  return {
    ..._positionJson(move.position),
    'score': _round(move.score),
  };
}

Map<String, Object?> _advancedCandidateJson(
  SimBoard board,
  _CandidateAccumulator candidate, {
  required CaptureAiOracleResult oracleResult,
  required CaptureAiMove? aiMove,
  required _DiagnosticScoreProfile scoreProfile,
  required DifficultyLevel difficulty,
}) {
  final position = candidate.position;
  final analysis = board.analyzeMove(position.row, position.col);
  final scoreBreakdown = _scoreBreakdown(
    board,
    analysis,
    profile: scoreProfile,
    difficulty: difficulty,
  );
  final oracleMove = oracleResult.moveAt(position);
  return {
    ..._positionJson(position),
    'sourceLabels': candidate.sourceLabels,
    'sourceScores': candidate.sourceScores,
    'productionLikeScoreBreakdown': scoreBreakdown.toJson(),
    'oracleRank': oracleResult.rankOf(position),
    'oracleScore': _roundOrNull(oracleMove?.score),
    'oracleTacticalScore': _roundOrNull(oracleMove?.tacticalScore),
    'oracleAccepted': oracleResult.accepts(position, scoreDelta: 150),
    'sameAsAi': aiMove?.position == position,
    'allowsOpponentTargetWin': _allowsOpponentTargetWin(
      board,
      CaptureAiMove(position: position, score: candidate.bestSourceScore),
    ),
  };
}

class _CandidateAccumulator {
  _CandidateAccumulator(this.position);

  final BoardPosition position;
  final List<Map<String, Object?>> _sources = [];

  void addSource(
    String label,
    double score, {
    Map<String, Object?> details = const {},
  }) {
    _sources.add({
      'label': label,
      'score': _round(score),
      if (details.isNotEmpty) 'details': details,
    });
  }

  List<String> get sourceLabels => [
        for (final source in _sources) source['label']! as String,
      ];

  List<Map<String, Object?>> get sourceScores => _sources;

  double get bestSourceScore {
    var best = -double.infinity;
    for (final source in _sources) {
      final score = source['score'];
      if (score is num) best = math.max(best, score.toDouble());
    }
    return best;
  }
}

Map<String, Object?> _moveReport(
  SimBoard board,
  BoardPosition position, {
  required CaptureAiOracleResult oracleResult,
  required BoardPosition? aiPosition,
  required _DiagnosticScoreProfile scoreProfile,
  required DifficultyLevel difficulty,
}) {
  final analysis = board.analyzeMove(position.row, position.col);
  final oracleMove = oracleResult.moveAt(position);
  final oracleRank = oracleResult.rankOf(position);
  final captureDelta = _captureDeltaFor(analysis, board.currentPlayer);
  final targetAfter = _capturesFor(board, board.currentPlayer) + captureDelta;
  final move = CaptureAiMove(position: position, score: 0);
  final opponentTargetWinMove = _opponentTargetWinMoveAfter(board, move);
  final scoreBreakdown = _scoreBreakdown(
    board,
    analysis,
    profile: scoreProfile,
    difficulty: difficulty,
  );
  return {
    ..._positionJson(position),
    'oracleRank': oracleRank,
    'oracleScore': _roundOrNull(oracleMove?.score),
    'oracleTacticalScore': _roundOrNull(oracleMove?.tacticalScore),
    'oracleReason': oracleMove?.reason,
    'sameAsAi': aiPosition == position,
    'allowsOpponentTargetWin': opponentTargetWinMove != null,
    'opponentTargetWinMove': opponentTargetWinMove == null
        ? null
        : _positionJson(opponentTargetWinMove),
    'analysis': {
      'captureDelta': captureDelta,
      'opponentAtariStones': analysis.opponentAtariStones,
      'ownAtariStones': analysis.ownAtariStones,
      'ownRescuedStones': analysis.ownRescuedStones,
      'adjacentOpponentStones': analysis.adjacentOpponentStones,
      'libertiesAfterMove': analysis.libertiesAfterMove,
      'centerProximityScore': analysis.centerProximityScore,
      'targetAfter': targetAfter,
      'reachesTarget': targetAfter >= board.captureTarget,
    },
    'geometry': _geometryFeatures(board, position),
    'scoreBreakdown': scoreBreakdown.toJson(),
  };
}

_MoveScoreBreakdown _scoreBreakdown(
  SimBoard board,
  SimMoveAnalysis analysis, {
  required _DiagnosticScoreProfile profile,
  required DifficultyLevel difficulty,
}) {
  final player = board.currentPlayer;
  final ownCaptureDelta = _captureDeltaFor(analysis, player);
  final captureScore = ownCaptureDelta * profile.immediateCaptureWeight;
  final opponentAtariScore =
      analysis.opponentAtariStones * profile.opponentAtariWeight;
  final ownRescueScore = analysis.ownRescuedStones * profile.ownRescueWeight;
  final contactScore = analysis.adjacentOpponentStones * profile.contactWeight;
  final libertyScore = analysis.libertiesAfterMove * profile.libertyWeight;
  final centerScore = analysis.centerProximityScore * profile.centerWeight;
  final forcingSelfAtariRelief =
      analysis.ownAtariStones > 0 && analysis.opponentAtariStones > 0
          ? math.min(analysis.ownAtariStones, analysis.opponentAtariStones) *
              profile.selfAtariPenalty *
              0.85
          : 0.0;
  final selfAtariPenalty = -analysis.ownAtariStones * profile.selfAtariPenalty;
  final targetPlyScore = _targetPlyScore(board, analysis);
  final sparseBoardInitiativeScore = _sparseBoardInitiativeScore(
    board,
    analysis,
    difficulty,
  );
  return _MoveScoreBreakdown(
    captureScore: captureScore,
    opponentAtariScore: opponentAtariScore,
    ownRescueScore: ownRescueScore,
    contactScore: contactScore,
    libertyScore: libertyScore,
    centerScore: centerScore,
    selfAtariPenalty: selfAtariPenalty,
    forcingSelfAtariRelief: forcingSelfAtariRelief,
    targetPlyScore: targetPlyScore,
    sparseBoardInitiativeScore: sparseBoardInitiativeScore,
  );
}

CaptureAiMove? _chooseDiagnosticUrgentMove(
  SimBoard board, {
  required _DiagnosticScoreProfile scoreProfile,
  required DifficultyLevel difficulty,
}) {
  CaptureAiMove? best;
  for (final moveIndex in board.getLegalMoves()) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    final ownCaptureDelta = _captureDeltaFor(analysis, board.currentPlayer);
    final isUrgent = ownCaptureDelta > 0 || analysis.ownRescuedStones > 0;
    if (!isUrgent) continue;
    final score = _diagnosticScoreMove(
          board,
          analysis,
          scoreProfile: scoreProfile,
          difficulty: difficulty,
        ) +
        ownCaptureDelta * 14 +
        analysis.ownRescuedStones * 7;
    final move = CaptureAiMove(
      position: BoardPosition(row, col),
      score: score,
    );
    if (best == null || move.score > best.score) best = move;
  }
  return best;
}

CaptureAiMove? _chooseDiagnosticHeuristicMove(
  SimBoard board, {
  required _DiagnosticScoreProfile scoreProfile,
}) {
  if (board.isTerminal) return null;
  final legalMoves = board.getLegalMoves();
  if (legalMoves.isEmpty) return null;

  final scoredMoves = <CaptureAiMove>[];
  for (final moveIndex in legalMoves) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    scoredMoves.add(CaptureAiMove(
      position: BoardPosition(row, col),
      score: _diagnosticHeuristicScore(
        board,
        analysis,
        scoreProfile: scoreProfile,
      ),
    ));
  }
  if (scoredMoves.isEmpty) return null;

  scoredMoves.sort((a, b) => b.score.compareTo(a.score));
  final bestMove = scoredMoves.first;
  const heuristicPlayouts = 40;
  CaptureAiMove? refinedBest;
  for (final candidate in scoredMoves.take(6)) {
    final simulated = SimBoard.copy(board);
    if (!simulated.applyMove(candidate.position.row, candidate.position.col)) {
      continue;
    }
    final winner = _diagnosticRolloutWithStyle(
      SimBoard.copy(simulated),
      heuristicPlayouts,
      scoreProfile: scoreProfile,
    );
    final score =
        candidate.score + (winner == board.currentPlayer ? 3.5 : -1.5);
    final refined = CaptureAiMove(
      position: candidate.position,
      score: score,
    );
    if (refinedBest == null || refined.score > refinedBest.score) {
      refinedBest = refined;
    }
  }

  return refinedBest ?? bestMove;
}

List<CaptureAiMove> _rankDiagnosticLookaheadMoves(
  SimBoard board, {
  required _DiagnosticScoreProfile scoreProfile,
  required DifficultyLevel difficulty,
  required int limit,
}) {
  final scored = <({int moveIndex, double score})>[];
  for (final moveIndex in board.getLegalMoves()) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    scored.add((
      moveIndex: moveIndex,
      score: _diagnosticScoreMove(
        board,
        analysis,
        scoreProfile: scoreProfile,
        difficulty: difficulty,
      ),
    ));
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.moveIndex.compareTo(b.moveIndex);
  });

  const mctsCandidateLimit = 14;
  final moves = <CaptureAiMove>[];
  for (final entry in scored.take(mctsCandidateLimit)) {
    final row = entry.moveIndex ~/ board.size;
    final col = entry.moveIndex % board.size;
    final afterMove = SimBoard.copy(board);
    if (!afterMove.applyMove(row, col)) continue;
    final terminalBonus =
        afterMove.winner == board.currentPlayer ? 1000.0 : 0.0;
    final depth = switch (difficulty) {
      DifficultyLevel.beginner => 0,
      DifficultyLevel.intermediate => 2,
      DifficultyLevel.advanced => 2,
    };
    final lookaheadScore = entry.score +
        terminalBonus +
        _diagnosticMinimaxScore(
          afterMove,
          board.currentPlayer,
          depth,
          scoreProfile: scoreProfile,
          difficulty: difficulty,
        );
    moves.add(CaptureAiMove(
      position: BoardPosition(row, col),
      score: lookaheadScore,
    ));
  }
  moves.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final aIndex = board.idx(a.position.row, a.position.col);
    final bIndex = board.idx(b.position.row, b.position.col);
    return aIndex.compareTo(bIndex);
  });
  return moves.take(limit).toList();
}

List<CaptureAiMove> _rankDiagnosticQuietTacticalMoves(
  SimBoard board, {
  required _DiagnosticScoreProfile scoreProfile,
  int limit = 4,
}) {
  final scored = <({int moveIndex, double score})>[];
  final quietContextBonus =
      board.capturedByBlack > 0 || board.capturedByWhite > 0 ? 44.0 : 40.0;

  for (final moveIndex in board.getLegalMoves()) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    if (!_isQuietTacticalAnalysis(analysis, board.currentPlayer)) continue;

    final score = analysis.libertiesAfterMove * scoreProfile.libertyWeight +
        analysis.centerProximityScore * scoreProfile.centerWeight +
        _targetPlyScore(board, analysis) +
        quietContextBonus;
    scored.add((moveIndex: moveIndex, score: score));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.moveIndex.compareTo(b.moveIndex);
  });

  return [
    for (final entry in scored.take(limit))
      CaptureAiMove(
        position: BoardPosition(
          entry.moveIndex ~/ board.size,
          entry.moveIndex % board.size,
        ),
        score: entry.score,
      ),
  ];
}

double _diagnosticScoreMove(
  SimBoard board,
  SimMoveAnalysis analysis, {
  required _DiagnosticScoreProfile scoreProfile,
  required DifficultyLevel difficulty,
}) {
  return _scoreBreakdown(
    board,
    analysis,
    profile: scoreProfile,
    difficulty: difficulty,
  ).totalApproxScore;
}

double _diagnosticHeuristicScore(
  SimBoard board,
  SimMoveAnalysis analysis, {
  required _DiagnosticScoreProfile scoreProfile,
}) {
  final breakdown = _scoreBreakdown(
    board,
    analysis,
    profile: scoreProfile,
    difficulty: scoreProfile.difficulty,
  );
  return breakdown.totalApproxScore - breakdown.sparseBoardInitiativeScore;
}

double _diagnosticRolloutScore(
  SimBoard board,
  SimMoveAnalysis analysis, {
  required _DiagnosticScoreProfile scoreProfile,
}) {
  final breakdown = _scoreBreakdown(
    board,
    analysis,
    profile: scoreProfile,
    difficulty: scoreProfile.difficulty,
  );
  return breakdown.totalApproxScore -
      breakdown.targetPlyScore -
      breakdown.sparseBoardInitiativeScore;
}

int _diagnosticRolloutWithStyle(
  SimBoard board,
  int maxSteps, {
  required _DiagnosticScoreProfile scoreProfile,
}) {
  var steps = 0;
  while (!board.isTerminal && steps < maxSteps) {
    final move = _chooseDiagnosticRolloutMove(
      board,
      scoreProfile: scoreProfile,
    );
    if (move == null) break;
    if (!board.applyMove(move.row, move.col)) break;
    steps++;
  }

  if (board.isTerminal) return board.winner;
  if (board.capturedByBlack == board.capturedByWhite) {
    return board.currentPlayer;
  }
  return board.capturedByBlack > board.capturedByWhite
      ? SimBoard.black
      : SimBoard.white;
}

BoardPosition? _chooseDiagnosticRolloutMove(
  SimBoard board, {
  required _DiagnosticScoreProfile scoreProfile,
}) {
  CaptureAiMove? bestMove;
  for (final moveIndex in board.getLegalMoves().take(12)) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    final score = _diagnosticRolloutScore(
      board,
      analysis,
      scoreProfile: scoreProfile,
    );
    if (bestMove == null || score > bestMove.score) {
      bestMove = CaptureAiMove(
        position: BoardPosition(row, col),
        score: score,
      );
    }
  }
  return bestMove?.position;
}

double _diagnosticMinimaxScore(
  SimBoard board,
  int rootPlayer,
  int depth, {
  required _DiagnosticScoreProfile scoreProfile,
  required DifficultyLevel difficulty,
}) {
  if (board.winner == rootPlayer) return 10000;
  if (board.winner != 0) return -10000;
  if (depth <= 0) {
    return _diagnosticPositionScore(
      board,
      rootPlayer,
      scoreProfile: scoreProfile,
      difficulty: difficulty,
    );
  }

  const mctsCandidateLimit = 14;
  final candidates = _rankDiagnosticSearchCandidates(
    board,
    scoreProfile: scoreProfile,
    difficulty: difficulty,
  ).take(math.max(3, mctsCandidateLimit ~/ 2));
  if (board.currentPlayer == rootPlayer) {
    var best = -double.infinity;
    for (final moveIndex in candidates) {
      final next = SimBoard.copy(board);
      if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
        continue;
      }
      best = math.max(
        best,
        _diagnosticMinimaxScore(
          next,
          rootPlayer,
          depth - 1,
          scoreProfile: scoreProfile,
          difficulty: difficulty,
        ),
      );
    }
    return best.isFinite
        ? best
        : _diagnosticPositionScore(
            board,
            rootPlayer,
            scoreProfile: scoreProfile,
            difficulty: difficulty,
          );
  }

  var worst = double.infinity;
  for (final moveIndex in candidates) {
    final next = SimBoard.copy(board);
    if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
      continue;
    }
    worst = math.min(
      worst,
      _diagnosticMinimaxScore(
        next,
        rootPlayer,
        depth - 1,
        scoreProfile: scoreProfile,
        difficulty: difficulty,
      ),
    );
  }
  return worst.isFinite
      ? worst
      : _diagnosticPositionScore(
          board,
          rootPlayer,
          scoreProfile: scoreProfile,
          difficulty: difficulty,
        );
}

double _diagnosticPositionScore(
  SimBoard board,
  int player, {
  required _DiagnosticScoreProfile scoreProfile,
  required DifficultyLevel difficulty,
}) {
  if (board.winner == player) return 1000;
  if (board.winner != 0) return -1000;
  final ownCaptures = _capturesFor(board, player);
  final opponentCaptures = _capturesFor(board, _opponentOf(player));
  final captureScore = (ownCaptures - opponentCaptures) * 120.0;

  var opportunityScore = 0.0;
  for (final moveIndex in _rankDiagnosticSearchCandidates(
    board,
    scoreProfile: scoreProfile,
    difficulty: difficulty,
  ).take(16)) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    final moveScore = _diagnosticScoreMove(
      board,
      analysis,
      scoreProfile: scoreProfile,
      difficulty: difficulty,
    );
    if (board.currentPlayer == player) {
      opportunityScore = math.max(opportunityScore, moveScore);
    } else {
      opportunityScore = math.min(opportunityScore, -moveScore);
    }
  }

  return captureScore + opportunityScore;
}

List<int> _rankDiagnosticSearchCandidates(
  SimBoard board, {
  required _DiagnosticScoreProfile scoreProfile,
  required DifficultyLevel difficulty,
}) {
  final scored = <({int moveIndex, double score})>[];
  for (final moveIndex in board.getLegalMoves()) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    scored.add((
      moveIndex: moveIndex,
      score: _diagnosticScoreMove(
        board,
        analysis,
        scoreProfile: scoreProfile,
        difficulty: difficulty,
      ),
    ));
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.moveIndex.compareTo(b.moveIndex);
  });
  return scored.map((entry) => entry.moveIndex).toList();
}

CaptureAiMove? _bestDiagnosticAdvancedQuietTacticalMove(
  SimBoard board,
  List<CaptureAiMove> quietTacticalMoves,
  CaptureAiMove? heuristicMove,
  Map<int, bool> targetWinCache,
) {
  if (quietTacticalMoves.isEmpty) return null;
  final best = _bestDiagnosticTargetSafeCandidate(
    board,
    quietTacticalMoves,
    targetWinCache,
  );
  if (best == null || !_isQuietTacticalMove(board, best)) return null;
  if (heuristicMove != null && best.score < heuristicMove.score + 30.0) {
    return null;
  }
  return best;
}

CaptureAiMove? _bestDiagnosticTargetSafeCandidate(
  SimBoard board,
  List<CaptureAiMove> candidates,
  Map<int, bool> targetWinCache,
) {
  if (candidates.isEmpty) return null;
  final safeCandidates = candidates.where((move) {
    final moveIndex = board.idx(move.position.row, move.position.col);
    return !targetWinCache.putIfAbsent(
      moveIndex,
      () => _allowsOpponentTargetWin(board, move),
    );
  }).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  if (safeCandidates.isNotEmpty) return safeCandidates.first;
  return candidates.first;
}

bool _isImmediateTargetWin(SimBoard board, CaptureAiMove move) {
  final analysis = board.analyzeMove(move.position.row, move.position.col);
  if (!analysis.isLegal) return false;
  return _capturesFor(board, board.currentPlayer) +
          _captureDeltaFor(analysis, board.currentPlayer) >=
      board.captureTarget;
}

bool _allowsOpponentTargetWin(SimBoard board, CaptureAiMove move) {
  return _opponentTargetWinMoveAfter(board, move) != null;
}

BoardPosition? _opponentTargetWinMoveAfter(SimBoard board, CaptureAiMove move) {
  final currentPlayer = board.currentPlayer;
  final next = SimBoard.copy(board);
  if (!next.applyMove(move.position.row, move.position.col)) {
    return move.position;
  }
  if (_capturesFor(next, currentPlayer) >= next.captureTarget) return null;
  return _currentPlayerTargetWinMove(next);
}

BoardPosition? _currentPlayerTargetWinMove(SimBoard board) {
  return _playerTargetWinMove(board, board.currentPlayer);
}

BoardPosition? _playerTargetWinMove(SimBoard board, int player) {
  if (_capturesFor(board, player) >= board.captureTarget) return null;
  final target = board.captureTarget;
  final capturesBefore = _capturesFor(board, player);
  if (capturesBefore < target - 1) return null;

  final probe = SimBoard.copy(board)..currentPlayer = player;
  final localMoves = probe.getLegalMoves()..sort();
  for (final moveIndex in localMoves) {
    if (probe.cells[moveIndex] != SimBoard.empty) continue;
    final row = moveIndex ~/ probe.size;
    final col = moveIndex % probe.size;
    final analysis = probe.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    if (capturesBefore + _captureDeltaFor(analysis, player) >= target) {
      return BoardPosition(row, col);
    }
  }
  return null;
}

bool _isQuietTacticalMove(SimBoard board, CaptureAiMove move) {
  final analysis = board.analyzeMove(move.position.row, move.position.col);
  return analysis.isLegal &&
      _isQuietTacticalAnalysis(analysis, board.currentPlayer);
}

bool _isQuietTacticalAnalysis(SimMoveAnalysis analysis, int player) {
  return _captureDeltaFor(analysis, player) == 0 &&
      analysis.adjacentOpponentStones == 0 &&
      analysis.ownAtariStones == 0;
}

double _targetPlyScore(
  SimBoard board,
  SimMoveAnalysis analysis,
) {
  final player = board.currentPlayer;
  final opponent = _opponentOf(player);
  final target = board.captureTarget;
  final ownBefore = _capturesFor(board, player);
  final opponentBefore = _capturesFor(board, opponent);
  final ownCaptureDelta = _captureDeltaFor(analysis, player);
  final ownAfter = ownBefore + ownCaptureDelta;

  if (ownAfter >= target) {
    return 100000.0 + ownCaptureDelta * 1000.0;
  }

  final ownRemainingBefore = math.max(1, target - ownBefore);
  var score = ownCaptureDelta * (40.0 / ownRemainingBefore);

  if (opponentBefore < target - 2) return score;

  if (opponentBefore >= target - 1) {
    score += analysis.ownRescuedStones * 220.0;
    score += analysis.opponentAtariStones * 80.0;
    if (ownCaptureDelta == 0 && analysis.ownRescuedStones == 0) {
      score -= 180.0;
    }
  } else {
    score += analysis.ownRescuedStones * 60.0;
    score += analysis.opponentAtariStones * 20.0;
  }

  return score;
}

double _sparseBoardInitiativeScore(
  SimBoard board,
  SimMoveAnalysis analysis,
  DifficultyLevel difficulty,
) {
  if (board.capturedByBlack > 0 || board.capturedByWhite > 0) return 0;
  final ownCaptureDelta = _captureDeltaFor(analysis, board.currentPlayer);
  if (ownCaptureDelta > 0 ||
      analysis.opponentAtariStones > 0 ||
      analysis.ownAtariStones > 0 ||
      analysis.ownRescuedStones > 0 ||
      analysis.adjacentOpponentStones > 0) {
    return 0;
  }

  final stoneCount = board.cells.where((cell) => cell != SimBoard.empty).length;
  if (stoneCount > board.size) return 0;
  final scale = switch (difficulty) {
    DifficultyLevel.beginner => 0.0,
    DifficultyLevel.intermediate => 32.0,
    DifficultyLevel.advanced => 64.0,
  };
  return analysis.adjacentOpponentStones * scale +
      analysis.centerProximityScore * scale * 0.12;
}

Map<String, Object?> _geometryFeatures(
  SimBoard board,
  BoardPosition position,
) {
  final row = position.row;
  final col = position.col;
  final own = board.currentPlayer;
  final opponent = own == SimBoard.black ? SimBoard.white : SimBoard.black;
  var adjacentOwn = 0;
  var diagonalOwn = 0;
  var nearbyOwnRadius2 = 0;
  var nearbyOpponentRadius2 = 0;
  var knightOpponent = 0;

  for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
    if (_cellAt(board, row + dr, col + dc) == own) adjacentOwn++;
  }

  for (final (dr, dc) in const [(-1, -1), (-1, 1), (1, -1), (1, 1)]) {
    if (_cellAt(board, row + dr, col + dc) == own) diagonalOwn++;
  }

  for (var dr = -2; dr <= 2; dr++) {
    for (var dc = -2; dc <= 2; dc++) {
      if (dr == 0 && dc == 0) continue;
      final cell = _cellAt(board, row + dr, col + dc);
      if (cell == own) nearbyOwnRadius2++;
      if (cell == opponent) nearbyOpponentRadius2++;
    }
  }

  for (final (dr, dc) in const [
    (-2, -1),
    (-2, 1),
    (-1, -2),
    (-1, 2),
    (1, -2),
    (1, 2),
    (2, -1),
    (2, 1),
  ]) {
    if (_cellAt(board, row + dr, col + dc) == opponent) knightOpponent++;
  }

  final adjacentOpponent = board.analyzeMove(row, col).adjacentOpponentStones;
  return {
    'adjacentOwn': adjacentOwn,
    'diagonalOwn': diagonalOwn,
    'nearbyOwnRadius2': nearbyOwnRadius2,
    'nearbyOpponentRadius2': nearbyOpponentRadius2,
    'knightOpponent': knightOpponent,
    'isAdjacentContact': adjacentOpponent > 0,
  };
}

class _DiagnosticScoreProfile {
  const _DiagnosticScoreProfile({
    required this.style,
    required this.difficulty,
    required this.immediateCaptureWeight,
    required this.opponentAtariWeight,
    required this.ownRescueWeight,
    required this.selfAtariPenalty,
    required this.centerWeight,
    required this.contactWeight,
    required this.libertyWeight,
  });

  final CaptureAiStyle style;
  final DifficultyLevel difficulty;
  final double immediateCaptureWeight;
  final double opponentAtariWeight;
  final double ownRescueWeight;
  final double selfAtariPenalty;
  final double centerWeight;
  final double contactWeight;
  final double libertyWeight;

  Map<String, Object?> toJson() {
    return {
      'style': style.name,
      'difficulty': difficulty.name,
      'immediateCaptureWeight': _round(immediateCaptureWeight),
      'opponentAtariWeight': _round(opponentAtariWeight),
      'ownRescueWeight': _round(ownRescueWeight),
      'selfAtariPenalty': _round(selfAtariPenalty),
      'centerWeight': _round(centerWeight),
      'contactWeight': _round(contactWeight),
      'libertyWeight': _round(libertyWeight),
      'note':
          'Local diagnostic constants copied from public production scoring.',
    };
  }
}

class _MoveScoreBreakdown {
  const _MoveScoreBreakdown({
    required this.captureScore,
    required this.opponentAtariScore,
    required this.ownRescueScore,
    required this.contactScore,
    required this.libertyScore,
    required this.centerScore,
    required this.selfAtariPenalty,
    required this.forcingSelfAtariRelief,
    required this.targetPlyScore,
    required this.sparseBoardInitiativeScore,
  });

  final double captureScore;
  final double opponentAtariScore;
  final double ownRescueScore;
  final double contactScore;
  final double libertyScore;
  final double centerScore;
  final double selfAtariPenalty;
  final double forcingSelfAtariRelief;
  final double targetPlyScore;
  final double sparseBoardInitiativeScore;

  double get totalApproxScore =>
      captureScore +
      opponentAtariScore +
      ownRescueScore +
      contactScore +
      libertyScore +
      centerScore +
      selfAtariPenalty +
      forcingSelfAtariRelief +
      targetPlyScore +
      sparseBoardInitiativeScore;

  Map<String, Object?> toJson() {
    return {
      'captureScore': _round(captureScore),
      'opponentAtariScore': _round(opponentAtariScore),
      'ownRescueScore': _round(ownRescueScore),
      'contactScore': _round(contactScore),
      'libertyScore': _round(libertyScore),
      'centerScore': _round(centerScore),
      'selfAtariPenalty': _round(selfAtariPenalty),
      'forcingSelfAtariRelief': _round(forcingSelfAtariRelief),
      'targetPlyScore': _round(targetPlyScore),
      'sparseBoardInitiativeScore': _round(sparseBoardInitiativeScore),
      'totalApproxScore': _round(totalApproxScore),
    };
  }
}

_DiagnosticScoreProfile _diagnosticProfileFor(
  CaptureAiStyle style,
  DifficultyLevel difficulty,
) {
  if (style != CaptureAiStyle.hunter) {
    throw FormatException(
      'Score breakdown currently supports --style=hunter only; got '
      '"${style.name}".',
    );
  }

  const base = _DiagnosticScoreProfile(
    style: CaptureAiStyle.hunter,
    difficulty: DifficultyLevel.beginner,
    immediateCaptureWeight: 9.0,
    opponentAtariWeight: 4.2,
    ownRescueWeight: 1.0,
    selfAtariPenalty: 6.0,
    centerWeight: 0.2,
    contactWeight: 2.8,
    libertyWeight: 0.8,
  );

  final tacticalScale = switch (difficulty) {
    DifficultyLevel.beginner => 1.0,
    DifficultyLevel.intermediate => 1.35,
    DifficultyLevel.advanced => 1.45,
  };
  final safetyScale = switch (difficulty) {
    DifficultyLevel.beginner => 1.0,
    DifficultyLevel.intermediate => 1.18,
    DifficultyLevel.advanced => 1.22,
  };
  final libertyScale = switch (difficulty) {
    DifficultyLevel.beginner => 1.0,
    DifficultyLevel.intermediate => 1.1,
    DifficultyLevel.advanced => 1.12,
  };
  final contactScale = switch (difficulty) {
    DifficultyLevel.beginner => 1.0,
    DifficultyLevel.intermediate => 1.9,
    DifficultyLevel.advanced => 2.2,
  };

  return _DiagnosticScoreProfile(
    style: style,
    difficulty: difficulty,
    immediateCaptureWeight: base.immediateCaptureWeight * tacticalScale,
    opponentAtariWeight: base.opponentAtariWeight * tacticalScale,
    ownRescueWeight: base.ownRescueWeight * safetyScale,
    selfAtariPenalty: base.selfAtariPenalty * safetyScale,
    centerWeight: base.centerWeight,
    contactWeight: base.contactWeight * contactScale,
    libertyWeight: base.libertyWeight * libertyScale,
  );
}

void _printProblem(Map<String, Object?> report) {
  final aiMove = report['aiMove'] as Map<String, Object?>?;
  final oracle = report['oracle'] as Map<String, Object?>;
  print(
    '${report['id']} tactic=${report['tactic'] ?? '-'} '
    'toMove=${report['currentPlayer']} '
    'ai=${aiMove?['label'] ?? 'none'} '
    'aiRank=${aiMove?['oracleRank'] ?? '-'} '
    'authoritative=${oracle['authoritative']}',
  );
  print(
    'Move    Src Rank Oracle   Total    Cap  Atar Rescue Cont Lib Ctr Self Target Sparse Geo(own/diag/r2Own/r2Opp/kOpp/contact)',
  );
  for (final rawMove in report['moves']! as List<Object?>) {
    final move = rawMove! as Map<String, Object?>;
    final analysis = move['analysis']! as Map<String, Object?>;
    final geometry = move['geometry']! as Map<String, Object?>;
    final scoreBreakdown = move['scoreBreakdown']! as Map<String, Object?>;
    final rank = move['oracleRank']?.toString() ?? '-';
    final score = _formatDouble(move['oracleScore']);
    final source = move['sameAsAi'] == true ? 'AI' : 'O';
    final geo = '${geometry['adjacentOwn']}/${geometry['diagonalOwn']}/'
        '${geometry['nearbyOwnRadius2']}/${geometry['nearbyOpponentRadius2']}/'
        '${geometry['knightOpponent']}/'
        '${geometry['isAdjacentContact'] == true ? 'Y' : 'N'}';
    print(
      '${(move['label']! as String).padRight(7)} '
      '${source.padRight(3)} '
      '${rank.padLeft(4)} '
      '${score.padLeft(8)} '
      '${_formatDouble(scoreBreakdown['totalApproxScore']).padLeft(7)} '
      '${_formatDouble(scoreBreakdown['captureScore']).padLeft(6)} '
      '${_formatDouble(scoreBreakdown['opponentAtariScore']).padLeft(5)} '
      '${_formatDouble(scoreBreakdown['ownRescueScore']).padLeft(6)} '
      '${_formatDouble(scoreBreakdown['contactScore']).padLeft(5)} '
      '${_formatDouble(scoreBreakdown['libertyScore']).padLeft(4)} '
      '${_formatDouble(scoreBreakdown['centerScore']).padLeft(3)} '
      '${_formatDouble(scoreBreakdown['selfAtariPenalty']).padLeft(5)} '
      '${_formatDouble(scoreBreakdown['targetPlyScore']).padLeft(6)} '
      '${_formatDouble(scoreBreakdown['sparseBoardInitiativeScore']).padLeft(6)} '
      '${analysis['targetAfter'].toString().padLeft(2)}'
      '${analysis['reachesTarget'] == true ? '*' : ' '} '
      '$geo',
    );
  }
  _printAdvancedCandidatePath(report);
  print('');
}

void _printAdvancedCandidatePath(Map<String, Object?> report) {
  final path = report['advancedHunterCandidatePath']! as Map<String, Object?>;
  final sourceSummary = path['sourceSummary']! as Map<String, Object?>;
  print('Advanced hunter candidate path:');
  print(
    '  urgent=${_summaryLabel(sourceSummary['urgentMove'])} '
    'heuristic=${_summaryLabel(sourceSummary['heuristicMove'])} '
    'lookahead=${sourceSummary['lookaheadMoveCount']} '
    'quietContext=${sourceSummary['quietTacticalContext']} '
    'quiet=${sourceSummary['quietTacticalMoveCount']} '
    'urgentChoice=${_summaryLabel(sourceSummary['urgentBranchChoice'])} '
    'quietChoice=${_summaryLabel(sourceSummary['quietBranchChoice'])} '
    'actual=${_summaryLabel(sourceSummary['actualAiMove'])}',
  );
  print(
    '  Move    Sources                         Rank Oracle   Accept Total    BestSrc Unsafe',
  );
  for (final rawCandidate in path['candidates']! as List<Object?>) {
    final candidate = rawCandidate! as Map<String, Object?>;
    final breakdown =
        candidate['productionLikeScoreBreakdown']! as Map<String, Object?>;
    final labels =
        (candidate['sourceLabels']! as List<Object?>).cast<String>().join(',');
    final sourceScores = candidate['sourceScores']! as List<Object?>;
    var bestSourceScore = -double.infinity;
    for (final rawSource in sourceScores) {
      final source = rawSource! as Map<String, Object?>;
      final score = source['score'];
      if (score is num) {
        bestSourceScore = math.max(bestSourceScore, score.toDouble());
      }
    }
    print(
      '  ${(candidate['label']! as String).padRight(7)} '
      '${labels.padRight(31).substring(0, 31)} '
      '${(candidate['oracleRank']?.toString() ?? '-').padLeft(4)} '
      '${_formatDouble(candidate['oracleScore']).padLeft(8)} '
      '${(candidate['oracleAccepted'] == true ? 'Y' : 'N').padLeft(6)} '
      '${_formatDouble(breakdown['totalApproxScore']).padLeft(7)} '
      '${_formatDouble(bestSourceScore).padLeft(8)} '
      '${candidate['allowsOpponentTargetWin'] == true ? 'Y' : 'N'}',
    );
  }
}

String _summaryLabel(Object? rawSummary) {
  if (rawSummary is! Map<String, Object?>) return '-';
  return '${rawSummary['label']}@${_formatDouble(rawSummary['score'])}';
}

int? _cellAt(SimBoard board, int row, int col) {
  if (row < 0 || row >= board.size || col < 0 || col >= board.size) {
    return null;
  }
  return board.cells[board.idx(row, col)];
}

int _captureDeltaFor(SimMoveAnalysis analysis, int player) {
  return player == SimBoard.black
      ? analysis.blackCaptureDelta
      : analysis.whiteCaptureDelta;
}

int _capturesFor(SimBoard board, int player) {
  return player == SimBoard.black
      ? board.capturedByBlack
      : board.capturedByWhite;
}

int _opponentOf(int player) {
  return player == SimBoard.black ? SimBoard.white : SimBoard.black;
}

Map<String, Object?> _positionJson(BoardPosition position) {
  return {
    'row': position.row,
    'col': position.col,
    'label': _formatPosition(position),
  };
}

String _formatPosition(BoardPosition position) {
  return 'r${position.row + 1}c${position.col + 1}';
}

String _playerName(int player) {
  return switch (player) {
    SimBoard.black => 'black',
    SimBoard.white => 'white',
    _ => 'empty',
  };
}

void _writeReport(String outputPath, Map<String, Object?> report) {
  final file = File(outputPath);
  final parent = file.parent;
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(report)}\n');
}

Map<String, String> _parseArgs(List<String> args) {
  final opts = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) {
      throw FormatException('Unexpected argument "$arg".');
    }
    final raw = arg.substring(2);
    if (raw == 'help') {
      opts['help'] = 'true';
      continue;
    }
    final equals = raw.indexOf('=');
    if (equals >= 0) {
      opts[raw.substring(0, equals)] = raw.substring(equals + 1);
      continue;
    }
    if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
      throw FormatException('Missing value for --$raw.');
    }
    opts[raw] = args[++i];
  }
  return opts;
}

List<String> _parseNames(String value) {
  final names = value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (names.isEmpty) throw const FormatException('--ids is required.');
  return names;
}

CaptureAiStyle _parseStyle(String name) {
  for (final style in CaptureAiStyle.values) {
    if (style.name == name) return style;
  }
  throw FormatException(
    '--style must use one of: '
    '${CaptureAiStyle.values.map((style) => style.name).join(', ')}.',
  );
}

DifficultyLevel _parseDifficulty(String name) {
  for (final difficulty in DifficultyLevel.values) {
    if (difficulty.name == name) return difficulty;
  }
  throw FormatException(
    '--difficulty must use one of: '
    '${DifficultyLevel.values.map((level) => level.name).join(', ')}.',
  );
}

int _parsePositiveInt(String? value, {required int fallback}) {
  if (value == null) return fallback;
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 1) {
    throw FormatException('Expected a positive integer, got "$value".');
  }
  return parsed;
}

String _formatDouble(Object? value) {
  if (value is! num) return '-';
  return value.toStringAsFixed(1);
}

double? _roundOrNull(double? value) => value == null ? null : _round(value);

double _round(double value) {
  if (!value.isFinite) return value;
  return double.parse(value.toStringAsFixed(3));
}

void _printUsage() {
  print(
    'Usage: dart run tool/capture_ai_feature_probe.dart '
    '--ids=<id1,id2> --output=<path> [options]\n'
    '\n'
    'Options:\n'
    '  --style=<name>             AI style, default hunter.\n'
    '  --difficulty=<name>        Difficulty, default advanced.\n'
    '  --top=<n>                  Oracle moves to include, default 5.\n'
    '  --oracle-depth=<n>         Oracle minimax depth, default 4.\n'
    '  --oracle-horizon=<n>       Oracle candidate horizon, default 10.\n'
    '  --oracle-max-nodes=<n>     Oracle node cap, default 25000.\n'
    '  --problems=<path>          Problem JSON path.\n',
  );
}
