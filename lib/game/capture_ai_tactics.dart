import 'dart:convert';
import 'dart:math' as math;

import '../models/board_position.dart';
import 'capture_ai.dart';
import 'difficulty_level.dart';
import 'mcts_engine.dart';

class CaptureAiTacticsFormatException implements Exception {
  const CaptureAiTacticsFormatException(this.message);

  final String message;

  @override
  String toString() => 'CaptureAiTacticsFormatException: $message';
}

class CaptureAiTacticsProblemSet {
  const CaptureAiTacticsProblemSet({
    required this.problems,
  });

  final List<CaptureAiTacticsProblem> problems;

  factory CaptureAiTacticsProblemSet.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    Object? rawProblems = decoded;
    if (decoded is Map<String, dynamic>) {
      rawProblems = decoded['problems'] ?? decoded['items'] ?? decoded['cases'];
    }
    if (rawProblems is! List) {
      throw const CaptureAiTacticsFormatException(
        'Expected a JSON list or an object with a problems list.',
      );
    }

    return CaptureAiTacticsProblemSet(
      problems: [
        for (var i = 0; i < rawProblems.length; i++)
          CaptureAiTacticsProblem.fromJson(
            _asJsonObject(rawProblems[i], 'problems[$i]'),
            index: i,
          ),
      ],
    );
  }
}

class CaptureAiTacticsProblem {
  const CaptureAiTacticsProblem({
    required this.id,
    required this.boardSize,
    required this.captureTarget,
    required this.currentPlayer,
    required this.diagramRows,
    required this.cells,
    required this.category,
    required this.objective,
    required this.notes,
    required this.split,
    required this.capturedByBlack,
    required this.capturedByWhite,
    required this.metadata,
  });

  final String id;
  final int boardSize;
  final int captureTarget;
  final int currentPlayer;
  final List<String> diagramRows;
  final List<int> cells;
  final String category;
  final Object? objective;
  final String notes;
  final String split;
  final int capturedByBlack;
  final int capturedByWhite;
  final Map<String, Object?> metadata;

  factory CaptureAiTacticsProblem.fromJson(
    Map<String, dynamic> json, {
    required int index,
  }) {
    final boardSize = _readInt(json, ['boardSize', 'board_size', 'size']);
    if (boardSize != 9 && boardSize != 13) {
      throw CaptureAiTacticsFormatException(
        'Problem ${json['id'] ?? index} has board size $boardSize; only 9x9 '
        'and 13x13 are supported.',
      );
    }

    final diagramRows = _readDiagramRows(json['diagram'], boardSize, index);
    final cells = _parseDiagramCells(diagramRows, boardSize, index);

    final captureTarget = _readOptionalInt(
          json,
          ['captureTarget', 'capture_target'],
        ) ??
        5;
    if (captureTarget < 1) {
      throw CaptureAiTacticsFormatException(
        'Problem ${json['id'] ?? index} has captureTarget $captureTarget; '
        'it must be positive.',
      );
    }
    final capturedByBlack = _readOptionalInt(
          json,
          ['capturedByBlack', 'captured_by_black', 'blackCaptures'],
        ) ??
        0;
    final capturedByWhite = _readOptionalInt(
          json,
          ['capturedByWhite', 'captured_by_white', 'whiteCaptures'],
        ) ??
        0;
    if (capturedByBlack < 0 || capturedByWhite < 0) {
      throw CaptureAiTacticsFormatException(
        'Problem ${json['id'] ?? index} has negative captured counts.',
      );
    }
    if (capturedByBlack >= captureTarget || capturedByWhite >= captureTarget) {
      throw CaptureAiTacticsFormatException(
        'Problem ${json['id'] ?? index} starts after the capture target has '
        'already been reached.',
      );
    }

    return CaptureAiTacticsProblem(
      id: (json['id'] ?? 'problem_${index + 1}').toString(),
      boardSize: boardSize,
      captureTarget: captureTarget,
      currentPlayer: _parsePlayer(
        json['currentPlayer'] ?? json['current_player'] ?? json['toMove'],
        defaultPlayer: SimBoard.black,
      ),
      diagramRows: diagramRows,
      cells: cells,
      category: (json['category'] ?? 'uncategorized').toString(),
      objective: json['objective'],
      notes: (json['notes'] ?? '').toString(),
      split: (json['split'] ?? 'unspecified').toString(),
      capturedByBlack: capturedByBlack,
      capturedByWhite: capturedByWhite,
      metadata: Map<String, Object?>.from(
        _asJsonObject(
            json['metadata'] ?? const <String, Object?>{}, 'metadata'),
      ),
    );
  }

  SimBoard toBoard() {
    final board = SimBoard(boardSize, captureTarget: captureTarget);
    for (var i = 0; i < cells.length; i++) {
      board.cells[i] = cells[i];
    }
    board.currentPlayer = currentPlayer;
    board.capturedByBlack = capturedByBlack;
    board.capturedByWhite = capturedByWhite;
    return board;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'boardSize': boardSize,
      'captureTarget': captureTarget,
      'currentPlayer': _playerName(currentPlayer),
      'category': category,
      if (objective != null) 'objective': objective,
      if (notes.isNotEmpty) 'notes': notes,
      'split': split,
      'capturedByBlack': capturedByBlack,
      'capturedByWhite': capturedByWhite,
      'diagram': diagramRows,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class CaptureAiTacticalOracleConfig {
  const CaptureAiTacticalOracleConfig({
    this.depth = 4,
    this.candidateHorizon = 10,
    this.maxNodes = 25000,
    this.acceptScoreDelta = 150,
    this.topNAccepted,
    this.maxAcceptedMoveRatio = 0.25,
    this.minConfidenceGap = 300,
  });

  final int depth;
  final int candidateHorizon;
  final int maxNodes;
  final double acceptScoreDelta;
  final int? topNAccepted;
  final double maxAcceptedMoveRatio;
  final double minConfidenceGap;

  Map<String, Object?> toJson() {
    return {
      'depth': depth,
      'candidateHorizon': candidateHorizon,
      'maxNodes': maxNodes,
      'acceptScoreDelta': acceptScoreDelta,
      'topNAccepted': topNAccepted,
      'maxAcceptedMoveRatio': maxAcceptedMoveRatio,
      'minConfidenceGap': minConfidenceGap,
    };
  }
}

class CaptureAiTacticalOracle {
  const CaptureAiTacticalOracle({
    this.config = const CaptureAiTacticalOracleConfig(),
  });

  final CaptureAiTacticalOracleConfig config;

  CaptureAiOracleResult rankMoves(CaptureAiTacticsProblem problem) {
    final board = problem.toBoard();
    final stats = _OracleSearchStats();
    final legalMoves = _rankTacticalCandidates(
      board,
      rootPlayer: board.currentPlayer,
      limit: null,
    );
    final rankedMoves = <CaptureAiOracleMove>[];

    for (var i = 0; i < legalMoves.length; i++) {
      final moveIndex = legalMoves[i];
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;

      final next = SimBoard.copy(board);
      if (!next.applyMove(row, col)) continue;

      final tacticalScore = _scoreMoveForPlayer(board, moveIndex, analysis);
      final opponentCanReachTarget =
          next.winner == 0 && _currentPlayerCanReachCaptureTarget(next);
      final searchScore = opponentCanReachTarget
          ? -100000.0
          : _minimax(
              next,
              rootPlayer: board.currentPlayer,
              depth: math.max(0, config.depth - 1),
              alpha: -double.infinity,
              beta: double.infinity,
              stats: stats,
            );
      final score =
          searchScore + tacticalScore * 0.03 + _stableTieBreaker(moveIndex);
      rankedMoves.add(
        CaptureAiOracleMove(
          position: BoardPosition(row, col),
          score: score,
          tacticalScore: tacticalScore,
          reason: _explainMove(
            board,
            analysis,
            afterMove: next,
            rootPlayer: board.currentPlayer,
          ),
        ),
      );
    }

    rankedMoves.sort(_compareOracleMoves);
    final confidenceGap = _confidenceGap(rankedMoves);
    final acceptedBand = _acceptedBandMetrics(
      rankedMoves,
      acceptScoreDelta: config.acceptScoreDelta,
      topNAccepted: config.topNAccepted,
    );
    final authoritative = !stats.truncatedByNodeLimit &&
        acceptedBand.acceptedMoveRatio <= config.maxAcceptedMoveRatio &&
        acceptedBand.acceptedBandGap != null &&
        acceptedBand.acceptedBandGap! >= config.minConfidenceGap;
    return CaptureAiOracleResult(
      problemId: problem.id,
      depth: config.depth,
      candidateHorizon: config.candidateHorizon,
      minConfidenceGap: config.minConfidenceGap,
      confidenceGap: confidenceGap,
      acceptedBandGap: acceptedBand.acceptedBandGap,
      acceptedMoveCount: acceptedBand.acceptedMoveCount,
      acceptedMoveRatio: acceptedBand.acceptedMoveRatio,
      authoritative: authoritative,
      rankedMoves: rankedMoves,
      trace: CaptureAiOracleTrace(
        nodes: stats.nodes,
        cutoffs: stats.cutoffs,
        maxDepthReached: stats.maxDepthReached,
        truncatedByNodeLimit: stats.truncatedByNodeLimit,
        summary: _summarizeTrace(problem, rankedMoves, stats),
        topNAccepted: config.topNAccepted,
      ),
    );
  }

  double _minimax(
    SimBoard board, {
    required int rootPlayer,
    required int depth,
    required double alpha,
    required double beta,
    required _OracleSearchStats stats,
  }) {
    stats.nodes++;
    stats.maxDepthReached =
        math.max(stats.maxDepthReached, config.depth - depth);
    if (stats.nodes >= config.maxNodes) {
      stats.truncatedByNodeLimit = true;
      return _evaluatePosition(board, rootPlayer);
    }
    if (board.winner == rootPlayer) return 100000;
    if (board.winner != 0) return -100000;
    if (depth <= 0) return _evaluatePosition(board, rootPlayer);

    final candidates = _rankTacticalCandidates(
      board,
      rootPlayer: rootPlayer,
      limit: math.max(1, config.candidateHorizon),
    );
    if (candidates.isEmpty) return _evaluatePosition(board, rootPlayer);

    if (board.currentPlayer == rootPlayer) {
      var best = -double.infinity;
      var localAlpha = alpha;
      for (final moveIndex in candidates) {
        final next = SimBoard.copy(board);
        if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
          continue;
        }
        best = math.max(
          best,
          _minimax(
            next,
            rootPlayer: rootPlayer,
            depth: depth - 1,
            alpha: localAlpha,
            beta: beta,
            stats: stats,
          ),
        );
        localAlpha = math.max(localAlpha, best);
        if (localAlpha >= beta) {
          stats.cutoffs++;
          break;
        }
      }
      return best.isFinite ? best : _evaluatePosition(board, rootPlayer);
    }

    var worst = double.infinity;
    var localBeta = beta;
    for (final moveIndex in candidates) {
      final next = SimBoard.copy(board);
      if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
        continue;
      }
      worst = math.min(
        worst,
        _minimax(
          next,
          rootPlayer: rootPlayer,
          depth: depth - 1,
          alpha: alpha,
          beta: localBeta,
          stats: stats,
        ),
      );
      localBeta = math.min(localBeta, worst);
      if (alpha >= localBeta) {
        stats.cutoffs++;
        break;
      }
    }
    return worst.isFinite ? worst : _evaluatePosition(board, rootPlayer);
  }

  List<int> _rankTacticalCandidates(
    SimBoard board, {
    required int rootPlayer,
    required int? limit,
  }) {
    final scored = <({int moveIndex, double score})>[];
    for (final move in _generateOracleLegalMoves(board)) {
      scored.add((
        moveIndex: move.moveIndex,
        score: _scoreMoveForPlayer(board, move.moveIndex, move.analysis) +
            _rootUrgencyScore(board, rootPlayer, move.analysis),
      ));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.moveIndex.compareTo(b.moveIndex);
    });
    final selected = limit == null ? scored : scored.take(limit);
    return selected.map((entry) => entry.moveIndex).toList();
  }

  List<_OracleLegalMove> _generateOracleLegalMoves(SimBoard board) {
    final moves = <_OracleLegalMove>[];
    for (var moveIndex = 0; moveIndex < board.cells.length; moveIndex++) {
      if (board.cells[moveIndex] != SimBoard.empty) continue;
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final simulated = SimBoard.copy(board);
      if (!simulated.applyMove(row, col)) continue;

      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      moves.add(_OracleLegalMove(moveIndex, analysis));
    }
    return moves;
  }

  bool _currentPlayerCanReachCaptureTarget(SimBoard board) {
    final player = board.currentPlayer;
    final capturesBefore = player == SimBoard.black
        ? board.capturedByBlack
        : board.capturedByWhite;
    if (capturesBefore >= board.captureTarget) return true;
    if (capturesBefore < board.captureTarget - 1) return false;

    for (final move in _generateOracleLegalMoves(board)) {
      final captureDelta = player == SimBoard.black
          ? move.analysis.blackCaptureDelta
          : move.analysis.whiteCaptureDelta;
      if (capturesBefore + captureDelta >= board.captureTarget) {
        return true;
      }
    }
    return false;
  }

  double _scoreMoveForPlayer(
    SimBoard board,
    int moveIndex,
    SimMoveAnalysis analysis,
  ) {
    final mover = board.currentPlayer;
    final ownCaptures =
        mover == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
    final captureDelta = mover == SimBoard.black
        ? analysis.blackCaptureDelta
        : analysis.whiteCaptureDelta;
    final reachesTarget = ownCaptures + captureDelta >= board.captureTarget;
    final targetPressure =
        (board.captureTarget - ownCaptures).clamp(1, board.captureTarget);

    return (reachesTarget ? 60000.0 : 0.0) +
        captureDelta * (2400.0 + 400.0 / targetPressure) +
        analysis.opponentAtariStones * 150.0 +
        analysis.ownRescuedStones * 260.0 +
        analysis.adjacentOpponentStones * 35.0 +
        analysis.libertiesAfterMove * 12.0 +
        analysis.centerProximityScore * 3.0 -
        analysis.ownAtariStones * (captureDelta > 0 ? 35.0 : 170.0);
  }

  double _rootUrgencyScore(
    SimBoard board,
    int rootPlayer,
    SimMoveAnalysis analysis,
  ) {
    final rootToMove = board.currentPlayer == rootPlayer;
    final rootCaptures = rootPlayer == SimBoard.black
        ? board.capturedByBlack
        : board.capturedByWhite;
    final opponentCaptures = rootPlayer == SimBoard.black
        ? board.capturedByWhite
        : board.capturedByBlack;
    final rootDelta = rootPlayer == SimBoard.black
        ? analysis.blackCaptureDelta
        : analysis.whiteCaptureDelta;
    final opponentDelta = rootPlayer == SimBoard.black
        ? analysis.whiteCaptureDelta
        : analysis.blackCaptureDelta;

    if (rootToMove) {
      if (rootCaptures + rootDelta >= board.captureTarget) return 90000;
      if (opponentCaptures >= board.captureTarget - 1) {
        return analysis.ownRescuedStones * 400.0 + rootDelta * 300.0;
      }
    } else {
      if (opponentCaptures + opponentDelta >= board.captureTarget) {
        return 90000;
      }
    }
    return 0;
  }

  double _evaluatePosition(SimBoard board, int rootPlayer) {
    if (board.winner == rootPlayer) return 100000;
    if (board.winner != 0) return -100000;

    final rootCaptures = rootPlayer == SimBoard.black
        ? board.capturedByBlack
        : board.capturedByWhite;
    final opponentCaptures = rootPlayer == SimBoard.black
        ? board.capturedByWhite
        : board.capturedByBlack;
    final rootRemaining =
        math.max(0, board.captureTarget - rootCaptures).toDouble();
    final opponentRemaining =
        math.max(0, board.captureTarget - opponentCaptures).toDouble();
    final captureRaceScore = (opponentRemaining - rootRemaining) * 950.0 +
        (rootCaptures - opponentCaptures) * 260.0;

    final targetRisk = opponentRemaining <= 1 ? -700.0 : 0.0;
    final targetThreat = rootRemaining <= 1 ? 500.0 : 0.0;
    return captureRaceScore + targetThreat + targetRisk;
  }

  String _explainMove(
    SimBoard board,
    SimMoveAnalysis analysis, {
    required SimBoard afterMove,
    required int rootPlayer,
  }) {
    final parts = <String>[];
    final mover = board.currentPlayer;
    final captureDelta = mover == SimBoard.black
        ? analysis.blackCaptureDelta
        : analysis.whiteCaptureDelta;
    final capturesAfter = mover == SimBoard.black
        ? afterMove.capturedByBlack
        : afterMove.capturedByWhite;
    if (capturesAfter >= board.captureTarget) {
      parts.add('reaches capture target');
    } else if (captureDelta > 0) {
      parts.add('captures $captureDelta');
    }
    if (analysis.opponentAtariStones > 0) {
      parts.add('puts ${analysis.opponentAtariStones} stone(s) in atari');
    }
    if (analysis.ownRescuedStones > 0) {
      parts.add('rescues ${analysis.ownRescuedStones} stone(s)');
    }
    if (analysis.ownAtariStones > 0 && captureDelta == 0) {
      parts.add('leaves ${analysis.ownAtariStones} own stone(s) in atari');
    }
    if (board.currentPlayer != rootPlayer) {
      parts.add('opponent reply candidate');
    }
    if (parts.isEmpty) {
      parts.add('improves local liberties/contact');
    }
    return parts.join('; ');
  }

  String _summarizeTrace(
    CaptureAiTacticsProblem problem,
    List<CaptureAiOracleMove> moves,
    _OracleSearchStats stats,
  ) {
    if (moves.isEmpty) {
      return '${problem.id}: no legal tactical candidates.';
    }
    final best = moves.first;
    final band = _acceptedBandMetrics(
      moves,
      acceptScoreDelta: config.acceptScoreDelta,
      topNAccepted: config.topNAccepted,
    );
    final truncated = stats.truncatedByNodeLimit ? ', node limit reached' : '';
    return '${problem.id}: best ${_formatPosition(best.position)} '
        'score=${best.score.toStringAsFixed(1)}, '
        'accepted=${band.acceptedMoveCount} '
        '(${(band.acceptedMoveRatio * 100).toStringAsFixed(1)}%), '
        'bandGap=${band.acceptedBandGap?.toStringAsFixed(1) ?? '-'}, '
        'nodes=${stats.nodes}$truncated.';
  }

  double _stableTieBreaker(int moveIndex) => -moveIndex / 100000.0;
}

class CaptureAiOracleResult {
  const CaptureAiOracleResult({
    required this.problemId,
    required this.depth,
    required this.candidateHorizon,
    required this.minConfidenceGap,
    required this.confidenceGap,
    required this.acceptedBandGap,
    required this.acceptedMoveCount,
    required this.acceptedMoveRatio,
    required this.authoritative,
    required this.rankedMoves,
    required this.trace,
  });

  final String problemId;
  final int depth;
  final int candidateHorizon;
  final double minConfidenceGap;
  final double? confidenceGap;
  final double? acceptedBandGap;
  final int acceptedMoveCount;
  final double acceptedMoveRatio;
  final bool authoritative;
  final List<CaptureAiOracleMove> rankedMoves;
  final CaptureAiOracleTrace trace;

  CaptureAiOracleMove? get bestMove =>
      rankedMoves.isEmpty ? null : rankedMoves.first;

  int? rankOf(BoardPosition position) {
    for (var i = 0; i < rankedMoves.length; i++) {
      final move = rankedMoves[i];
      if (move.position == position) return i + 1;
    }
    return null;
  }

  CaptureAiOracleMove? moveAt(BoardPosition position) {
    for (final move in rankedMoves) {
      if (move.position == position) return move;
    }
    return null;
  }

  bool accepts(BoardPosition position, {required double scoreDelta}) {
    final best = bestMove;
    final move = moveAt(position);
    if (best == null || move == null) return false;
    final rank = rankOf(position);
    if (rank == null) return false;
    final topNAccepted = trace.topNAccepted;
    if (topNAccepted != null && rank > topNAccepted) return false;
    return best.score - move.score <= scoreDelta;
  }

  Map<String, Object?> toJson({int top = 8}) {
    return {
      'problemId': problemId,
      'depth': depth,
      'candidateHorizon': candidateHorizon,
      'minConfidenceGap': minConfidenceGap,
      'confidenceGap': confidenceGap == null ? null : _round(confidenceGap!),
      'acceptedBandGap':
          acceptedBandGap == null ? null : _round(acceptedBandGap!),
      'acceptedMoveCount': acceptedMoveCount,
      'acceptedMoveRatio': _round(acceptedMoveRatio),
      'authoritative': authoritative,
      'rankedMoveCount': rankedMoves.length,
      'bestMove': bestMove?.toJson(rank: 1),
      'rankedMoves': [
        for (var i = 0; i < math.min(top, rankedMoves.length); i++)
          rankedMoves[i].toJson(rank: i + 1),
      ],
      'trace': trace.toJson(),
    };
  }
}

class CaptureAiOracleMove {
  const CaptureAiOracleMove({
    required this.position,
    required this.score,
    required this.tacticalScore,
    required this.reason,
  });

  final BoardPosition position;
  final double score;
  final double tacticalScore;
  final String reason;

  Map<String, Object?> toJson({int? rank}) {
    return {
      if (rank != null) 'rank': rank,
      'move': _positionToJson(position),
      'score': _round(score),
      'tacticalScore': _round(tacticalScore),
      'reason': reason,
    };
  }
}

class CaptureAiOracleTrace {
  const CaptureAiOracleTrace({
    required this.nodes,
    required this.cutoffs,
    required this.maxDepthReached,
    required this.truncatedByNodeLimit,
    required this.summary,
    this.topNAccepted,
  });

  final int nodes;
  final int cutoffs;
  final int maxDepthReached;
  final bool truncatedByNodeLimit;
  final String summary;
  final int? topNAccepted;

  Map<String, Object?> toJson() {
    return {
      'nodes': nodes,
      'cutoffs': cutoffs,
      'maxDepthReached': maxDepthReached,
      'truncatedByNodeLimit': truncatedByNodeLimit,
      'topNAccepted': topNAccepted,
      'summary': summary,
    };
  }
}

class CaptureAiTacticsEvaluator {
  const CaptureAiTacticsEvaluator({
    this.oracle = const CaptureAiTacticalOracle(),
  });

  final CaptureAiTacticalOracle oracle;

  CaptureAiTacticsReport evaluate({
    required List<CaptureAiTacticsProblem> problems,
    required List<CaptureAiStyle> styles,
    required List<DifficultyLevel> difficulties,
    List<int>? boardSizes,
    int? limit,
  }) {
    final allowedBoardSizes = boardSizes?.toSet();
    final selectedProblems = <CaptureAiTacticsProblem>[];
    for (final problem in problems) {
      if (allowedBoardSizes != null &&
          !allowedBoardSizes.contains(problem.boardSize)) {
        continue;
      }
      selectedProblems.add(problem);
      if (limit != null && selectedProblems.length >= limit) break;
    }

    final configs = [
      for (final style in styles)
        for (final difficulty in difficulties)
          CaptureAiRobotConfig.forStyle(style, difficulty)
    ];

    final results = <CaptureAiTacticsProblemResult>[];
    for (final problem in selectedProblems) {
      final oracleResult = oracle.rankMoves(problem);
      final aiResults = <CaptureAiTacticsAiResult>[];
      for (final config in configs) {
        aiResults.add(_evaluateConfig(problem, oracleResult, config));
      }
      results.add(
        CaptureAiTacticsProblemResult(
          problem: problem,
          oracle: oracleResult,
          aiResults: aiResults,
        ),
      );
    }

    return CaptureAiTacticsReport(
      oracleConfig: oracle.config,
      styles: styles,
      difficulties: difficulties,
      boardSizes: boardSizes ?? const [9, 13],
      results: results,
    );
  }

  CaptureAiTacticsAiResult _evaluateConfig(
    CaptureAiTacticsProblem problem,
    CaptureAiOracleResult oracleResult,
    CaptureAiRobotConfig config,
  ) {
    final board = problem.toBoard();
    final move = CaptureAiRegistry.createFromConfig(config).chooseMove(board);
    if (move == null) {
      return CaptureAiTacticsAiResult(
        style: config.style,
        difficulty: config.difficulty,
        move: null,
        score: null,
        rank: null,
        accepted: false,
        acceptedAuthoritative: false,
        scoreGap: null,
        severeBlunder: true,
        oracleAuthoritative: oracleResult.authoritative,
        outsideOracleMoveSet: true,
      );
    }

    final selected = oracleResult.moveAt(move.position);
    final best = oracleResult.bestMove;
    final rank = oracleResult.rankOf(move.position);
    final accepted = oracleResult.accepts(
      move.position,
      scoreDelta: oracle.config.acceptScoreDelta,
    );
    final scoreGap = best == null || selected == null
        ? null
        : math.max(0.0, best.score - selected.score);
    return CaptureAiTacticsAiResult(
      style: config.style,
      difficulty: config.difficulty,
      move: move.position,
      score: selected?.score,
      rank: rank,
      accepted: accepted,
      acceptedAuthoritative: oracleResult.authoritative && accepted,
      scoreGap: scoreGap,
      severeBlunder: scoreGap == null || scoreGap > 1200,
      oracleAuthoritative: oracleResult.authoritative,
      outsideOracleMoveSet: selected == null,
    );
  }
}

class CaptureAiTacticsReport {
  const CaptureAiTacticsReport({
    required this.oracleConfig,
    required this.styles,
    required this.difficulties,
    required this.boardSizes,
    required this.results,
  });

  final CaptureAiTacticalOracleConfig oracleConfig;
  final List<CaptureAiStyle> styles;
  final List<DifficultyLevel> difficulties;
  final List<int> boardSizes;
  final List<CaptureAiTacticsProblemResult> results;

  CaptureAiTacticsSummary get summary {
    final configSummaries = <CaptureAiConfigSummary>[];
    for (final style in styles) {
      for (final difficulty in difficulties) {
        final aiResults = [
          for (final result in results)
            for (final ai in result.aiResults)
              if (ai.style == style && ai.difficulty == difficulty) ai
        ];
        configSummaries.add(
          CaptureAiConfigSummary(
            style: style,
            difficulty: difficulty,
            total: aiResults.length,
            accepted: aiResults.where((result) => result.accepted).length,
            authoritativeTotal:
                aiResults.where((result) => result.oracleAuthoritative).length,
            authoritativeAccepted: aiResults
                .where((result) => result.acceptedAuthoritative)
                .length,
            topOne: aiResults.where((result) => result.rank == 1).length,
            topThree: aiResults
                .where((result) => result.rank != null && result.rank! <= 3)
                .length,
            severeBlunders:
                aiResults.where((result) => result.severeBlunder).length,
            averageRank: _averageRank(aiResults),
            medianRank: _percentileRank(aiResults, 0.50),
            p75Rank: _percentileRank(aiResults, 0.75),
            p90Rank: _percentileRank(aiResults, 0.90),
            averageScoreGap: _averageScoreGap(aiResults),
            medianScoreGap: _percentileScoreGap(aiResults, 0.50),
            p75ScoreGap: _percentileScoreGap(aiResults, 0.75),
            p90ScoreGap: _percentileScoreGap(aiResults, 0.90),
            outsideOracleMoveSet:
                aiResults.where((result) => result.outsideOracleMoveSet).length,
          ),
        );
      }
    }
    return CaptureAiTacticsSummary(
      problems: results.length,
      authoritativeProblems:
          results.where((result) => result.oracle.authoritative).length,
      averageAcceptedMoveCount: _averageAcceptedMoveCount(results),
      averageAcceptedMoveRatio: _averageAcceptedMoveRatio(results),
      averageAcceptedBandGap: _averageAcceptedBandGap(results),
      configs: configSummaries,
      difficulties: _difficultySummaries(configSummaries),
      styles: _styleSummaries(configSummaries),
      difficultyDeltas: _difficultyDeltas(configSummaries),
      categories: _categorySummaries(results),
      tactics: _tacticSummaries(results),
    );
  }

  Map<String, Object?> toJson({
    DateTime? generatedAt,
    String? problemPath,
  }) {
    return {
      'schemaVersion': 2,
      if (generatedAt != null) 'generatedAt': generatedAt.toIso8601String(),
      if (problemPath != null) 'problemPath': problemPath,
      'config': {
        'styles': styles.map((style) => style.name).toList(),
        'difficulties':
            difficulties.map((difficulty) => difficulty.name).toList(),
        'boardSizes': boardSizes,
        'oracle': oracleConfig.toJson(),
      },
      'summary': summary.toJson(),
      'results': results.map((result) => result.toJson()).toList(),
    };
  }
}

class CaptureAiTacticsProblemResult {
  const CaptureAiTacticsProblemResult({
    required this.problem,
    required this.oracle,
    required this.aiResults,
  });

  final CaptureAiTacticsProblem problem;
  final CaptureAiOracleResult oracle;
  final List<CaptureAiTacticsAiResult> aiResults;

  Map<String, Object?> toJson() {
    return {
      'problem': problem.toJson(),
      'oracle': oracle.toJson(),
      'aiResults': aiResults.map((result) => result.toJson()).toList(),
    };
  }
}

class CaptureAiTacticsAiResult {
  const CaptureAiTacticsAiResult({
    required this.style,
    required this.difficulty,
    required this.move,
    required this.score,
    required this.rank,
    required this.accepted,
    required this.acceptedAuthoritative,
    required this.scoreGap,
    required this.severeBlunder,
    required this.oracleAuthoritative,
    required this.outsideOracleMoveSet,
  });

  final CaptureAiStyle style;
  final DifficultyLevel difficulty;
  final BoardPosition? move;
  final double? score;
  final int? rank;
  final bool accepted;
  final bool acceptedAuthoritative;
  final double? scoreGap;
  final bool severeBlunder;
  final bool oracleAuthoritative;
  final bool outsideOracleMoveSet;

  String get configId => '${style.name}_${difficulty.name}';

  Map<String, Object?> toJson() {
    return {
      'style': style.name,
      'difficulty': difficulty.name,
      'configId': configId,
      'move': move == null ? null : _positionToJson(move!),
      'oracleRank': rank,
      'oracleScore': score == null ? null : _round(score!),
      'accepted': accepted,
      'acceptedAuthoritative': acceptedAuthoritative,
      'scoreGap': scoreGap == null ? null : _round(scoreGap!),
      'severeBlunder': severeBlunder,
      'oracleAuthoritative': oracleAuthoritative,
      'outsideOracleMoveSet': outsideOracleMoveSet,
    };
  }
}

class CaptureAiTacticsSummary {
  const CaptureAiTacticsSummary({
    required this.problems,
    required this.authoritativeProblems,
    required this.averageAcceptedMoveCount,
    required this.averageAcceptedMoveRatio,
    required this.averageAcceptedBandGap,
    required this.configs,
    required this.difficulties,
    required this.styles,
    required this.difficultyDeltas,
    required this.categories,
    required this.tactics,
  });

  final int problems;
  final int authoritativeProblems;
  final double averageAcceptedMoveCount;
  final double averageAcceptedMoveRatio;
  final double averageAcceptedBandGap;
  final List<CaptureAiConfigSummary> configs;
  final List<CaptureAiGroupSummary> difficulties;
  final List<CaptureAiGroupSummary> styles;
  final List<CaptureAiDifficultyDeltaSummary> difficultyDeltas;
  final List<CaptureAiCategorySummary> categories;
  final List<CaptureAiTacticSummary> tactics;

  Map<String, Object?> toJson() {
    return {
      'problems': problems,
      'authoritativeProblems': authoritativeProblems,
      'averageAcceptedMoveCount': _round(averageAcceptedMoveCount),
      'averageAcceptedMoveRatio': _round(averageAcceptedMoveRatio),
      'averageAcceptedBandGap': _round(averageAcceptedBandGap),
      'configs': configs.map((summary) => summary.toJson()).toList(),
      'difficulties': difficulties.map((summary) => summary.toJson()).toList(),
      'styles': styles.map((summary) => summary.toJson()).toList(),
      'difficultyDeltas':
          difficultyDeltas.map((summary) => summary.toJson()).toList(),
      'categories': categories.map((summary) => summary.toJson()).toList(),
      'tactics': tactics.map((summary) => summary.toJson()).toList(),
    };
  }
}

class CaptureAiConfigSummary {
  const CaptureAiConfigSummary({
    required this.style,
    required this.difficulty,
    required this.total,
    required this.accepted,
    required this.authoritativeTotal,
    required this.authoritativeAccepted,
    required this.topOne,
    required this.topThree,
    required this.severeBlunders,
    required this.averageRank,
    required this.medianRank,
    required this.p75Rank,
    required this.p90Rank,
    required this.averageScoreGap,
    required this.medianScoreGap,
    required this.p75ScoreGap,
    required this.p90ScoreGap,
    required this.outsideOracleMoveSet,
  });

  final CaptureAiStyle style;
  final DifficultyLevel difficulty;
  final int total;
  final int accepted;
  final int authoritativeTotal;
  final int authoritativeAccepted;
  final int topOne;
  final int topThree;
  final int severeBlunders;
  final double averageRank;
  final double medianRank;
  final double p75Rank;
  final double p90Rank;
  final double averageScoreGap;
  final double medianScoreGap;
  final double p75ScoreGap;
  final double p90ScoreGap;
  final int outsideOracleMoveSet;

  double get acceptedRate => total == 0 ? 0 : accepted / total;
  double get authoritativeAcceptedRate =>
      authoritativeTotal == 0 ? 0 : authoritativeAccepted / authoritativeTotal;
  double get topOneRate => total == 0 ? 0 : topOne / total;
  double get topThreeRate => total == 0 ? 0 : topThree / total;
  double get severeBlunderRate => total == 0 ? 0 : severeBlunders / total;
  double get outsideOracleMoveSetRate =>
      total == 0 ? 0 : outsideOracleMoveSet / total;

  Map<String, Object?> toJson() {
    return {
      'style': style.name,
      'difficulty': difficulty.name,
      'configId': '${style.name}_${difficulty.name}',
      'total': total,
      'accepted': accepted,
      'acceptedRate': _round(acceptedRate),
      'authoritativeTotal': authoritativeTotal,
      'authoritativeAccepted': authoritativeAccepted,
      'authoritativeAcceptedRate': _round(authoritativeAcceptedRate),
      'topOne': topOne,
      'topOneRate': _round(topOneRate),
      'topThree': topThree,
      'topThreeRate': _round(topThreeRate),
      'severeBlunders': severeBlunders,
      'severeBlunderRate': _round(severeBlunderRate),
      'outsideOracleMoveSet': outsideOracleMoveSet,
      'outsideOracleMoveSetRate': _round(outsideOracleMoveSetRate),
      'averageRank': _round(averageRank),
      'medianRank': _round(medianRank),
      'p75Rank': _round(p75Rank),
      'p90Rank': _round(p90Rank),
      'averageScoreGap': _round(averageScoreGap),
      'medianScoreGap': _round(medianScoreGap),
      'p75ScoreGap': _round(p75ScoreGap),
      'p90ScoreGap': _round(p90ScoreGap),
    };
  }
}

class CaptureAiGroupSummary {
  const CaptureAiGroupSummary({
    required this.kind,
    required this.name,
    required this.total,
    required this.acceptedRate,
    required this.authoritativeAcceptedRate,
    required this.topOneRate,
    required this.topThreeRate,
    required this.averageRank,
    required this.medianRank,
    required this.averageScoreGap,
    required this.medianScoreGap,
    required this.severeBlunderRate,
  });

  final String kind;
  final String name;
  final int total;
  final double acceptedRate;
  final double authoritativeAcceptedRate;
  final double topOneRate;
  final double topThreeRate;
  final double averageRank;
  final double medianRank;
  final double averageScoreGap;
  final double medianScoreGap;
  final double severeBlunderRate;

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      'name': name,
      'total': total,
      'acceptedRate': _round(acceptedRate),
      'authoritativeAcceptedRate': _round(authoritativeAcceptedRate),
      'topOneRate': _round(topOneRate),
      'topThreeRate': _round(topThreeRate),
      'averageRank': _round(averageRank),
      'medianRank': _round(medianRank),
      'averageScoreGap': _round(averageScoreGap),
      'medianScoreGap': _round(medianScoreGap),
      'severeBlunderRate': _round(severeBlunderRate),
    };
  }
}

class CaptureAiDifficultyDeltaSummary {
  const CaptureAiDifficultyDeltaSummary({
    required this.style,
    required this.fromDifficulty,
    required this.toDifficulty,
    required this.acceptedRateDelta,
    required this.topOneRateDelta,
    required this.topThreeRateDelta,
    required this.averageRankDelta,
    required this.medianRankDelta,
    required this.averageScoreGapDelta,
    required this.medianScoreGapDelta,
    required this.severeBlunderRateDelta,
  });

  final CaptureAiStyle style;
  final DifficultyLevel fromDifficulty;
  final DifficultyLevel toDifficulty;
  final double acceptedRateDelta;
  final double topOneRateDelta;
  final double topThreeRateDelta;
  final double averageRankDelta;
  final double medianRankDelta;
  final double averageScoreGapDelta;
  final double medianScoreGapDelta;
  final double severeBlunderRateDelta;

  Map<String, Object?> toJson() {
    return {
      'style': style.name,
      'fromDifficulty': fromDifficulty.name,
      'toDifficulty': toDifficulty.name,
      'acceptedRateDelta': _round(acceptedRateDelta),
      'topOneRateDelta': _round(topOneRateDelta),
      'topThreeRateDelta': _round(topThreeRateDelta),
      'averageRankDelta': _round(averageRankDelta),
      'medianRankDelta': _round(medianRankDelta),
      'averageScoreGapDelta': _round(averageScoreGapDelta),
      'medianScoreGapDelta': _round(medianScoreGapDelta),
      'severeBlunderRateDelta': _round(severeBlunderRateDelta),
    };
  }
}

class CaptureAiCategorySummary {
  const CaptureAiCategorySummary({
    required this.category,
    required this.problems,
    required this.configId,
    required this.accepted,
    required this.authoritativeProblems,
    required this.authoritativeAccepted,
    required this.severeBlunders,
  });

  final String category;
  final int problems;
  final String configId;
  final int accepted;
  final int authoritativeProblems;
  final int authoritativeAccepted;
  final int severeBlunders;

  double get acceptedRate => problems == 0 ? 0 : accepted / problems;
  double get authoritativeAcceptedRate => authoritativeProblems == 0
      ? 0
      : authoritativeAccepted / authoritativeProblems;

  Map<String, Object?> toJson() {
    return {
      'category': category,
      'configId': configId,
      'problems': problems,
      'accepted': accepted,
      'acceptedRate': _round(acceptedRate),
      'authoritativeProblems': authoritativeProblems,
      'authoritativeAccepted': authoritativeAccepted,
      'authoritativeAcceptedRate': _round(authoritativeAcceptedRate),
      'severeBlunders': severeBlunders,
    };
  }
}

class CaptureAiTacticSummary {
  const CaptureAiTacticSummary({
    required this.tactic,
    required this.problems,
    required this.configId,
    required this.accepted,
    required this.authoritativeProblems,
    required this.authoritativeAccepted,
    required this.topOne,
    required this.topThree,
    required this.severeBlunders,
  });

  final String tactic;
  final int problems;
  final String configId;
  final int accepted;
  final int authoritativeProblems;
  final int authoritativeAccepted;
  final int topOne;
  final int topThree;
  final int severeBlunders;

  double get acceptedRate => problems == 0 ? 0 : accepted / problems;
  double get authoritativeAcceptedRate => authoritativeProblems == 0
      ? 0
      : authoritativeAccepted / authoritativeProblems;
  double get topOneRate => problems == 0 ? 0 : topOne / problems;
  double get topThreeRate => problems == 0 ? 0 : topThree / problems;

  Map<String, Object?> toJson() {
    return {
      'tactic': tactic,
      'configId': configId,
      'problems': problems,
      'accepted': accepted,
      'acceptedRate': _round(acceptedRate),
      'authoritativeProblems': authoritativeProblems,
      'authoritativeAccepted': authoritativeAccepted,
      'authoritativeAcceptedRate': _round(authoritativeAcceptedRate),
      'topOne': topOne,
      'topOneRate': _round(topOneRate),
      'topThree': topThree,
      'topThreeRate': _round(topThreeRate),
      'severeBlunders': severeBlunders,
    };
  }
}

class _OracleLegalMove {
  const _OracleLegalMove(this.moveIndex, this.analysis);

  final int moveIndex;
  final SimMoveAnalysis analysis;
}

class _OracleSearchStats {
  int nodes = 0;
  int cutoffs = 0;
  int maxDepthReached = 0;
  bool truncatedByNodeLimit = false;
}

int _compareOracleMoves(CaptureAiOracleMove a, CaptureAiOracleMove b) {
  final byScore = b.score.compareTo(a.score);
  if (byScore != 0) return byScore;
  final byTactical = b.tacticalScore.compareTo(a.tacticalScore);
  if (byTactical != 0) return byTactical;
  final byRow = a.position.row.compareTo(b.position.row);
  if (byRow != 0) return byRow;
  return a.position.col.compareTo(b.position.col);
}

double _averageRank(List<CaptureAiTacticsAiResult> results) {
  final ranks = results.map((result) => result.rank).whereType<int>().toList();
  if (ranks.isEmpty) return 0;
  return ranks.reduce((a, b) => a + b) / ranks.length;
}

double _percentileRank(List<CaptureAiTacticsAiResult> results, double p) {
  final ranks = results
      .map((result) => result.rank)
      .whereType<int>()
      .map((rank) => rank.toDouble())
      .toList();
  return _percentile(ranks, p);
}

double _averageScoreGap(List<CaptureAiTacticsAiResult> results) {
  final gaps =
      results.map((result) => result.scoreGap).whereType<double>().toList();
  if (gaps.isEmpty) return 0;
  return gaps.reduce((a, b) => a + b) / gaps.length;
}

double _percentileScoreGap(List<CaptureAiTacticsAiResult> results, double p) {
  return _percentile(
    results.map((result) => result.scoreGap).whereType<double>().toList(),
    p,
  );
}

double _percentile(List<double> values, double p) {
  if (values.isEmpty) return 0;
  values.sort();
  final clamped = p.clamp(0.0, 1.0);
  final index = (values.length - 1) * clamped;
  final lower = index.floor();
  final upper = index.ceil();
  if (lower == upper) return values[lower];
  final weight = index - lower;
  return values[lower] * (1 - weight) + values[upper] * weight;
}

double _averageAcceptedMoveCount(
  List<CaptureAiTacticsProblemResult> results,
) {
  if (results.isEmpty) return 0;
  final total = results.fold<int>(
    0,
    (sum, result) => sum + result.oracle.acceptedMoveCount,
  );
  return total / results.length;
}

double _averageAcceptedMoveRatio(
  List<CaptureAiTacticsProblemResult> results,
) {
  if (results.isEmpty) return 0;
  final total = results.fold<double>(
    0,
    (sum, result) => sum + result.oracle.acceptedMoveRatio,
  );
  return total / results.length;
}

double _averageAcceptedBandGap(
  List<CaptureAiTacticsProblemResult> results,
) {
  final gaps = results
      .map((result) => result.oracle.acceptedBandGap)
      .whereType<double>()
      .toList();
  if (gaps.isEmpty) return 0;
  return gaps.reduce((a, b) => a + b) / gaps.length;
}

List<CaptureAiGroupSummary> _difficultySummaries(
  List<CaptureAiConfigSummary> configs,
) {
  return [
    for (final difficulty in DifficultyLevel.values)
      _groupSummary(
        kind: 'difficulty',
        name: difficulty.name,
        configs: [
          for (final config in configs)
            if (config.difficulty == difficulty) config,
        ],
      ),
  ].where((summary) => summary.total > 0).toList();
}

List<CaptureAiGroupSummary> _styleSummaries(
  List<CaptureAiConfigSummary> configs,
) {
  return [
    for (final style in CaptureAiStyle.values)
      _groupSummary(
        kind: 'style',
        name: style.name,
        configs: [
          for (final config in configs)
            if (config.style == style) config,
        ],
      ),
  ].where((summary) => summary.total > 0).toList();
}

CaptureAiGroupSummary _groupSummary({
  required String kind,
  required String name,
  required List<CaptureAiConfigSummary> configs,
}) {
  final total = configs.fold<int>(0, (sum, config) => sum + config.total);
  if (total == 0) {
    return CaptureAiGroupSummary(
      kind: kind,
      name: name,
      total: 0,
      acceptedRate: 0,
      authoritativeAcceptedRate: 0,
      topOneRate: 0,
      topThreeRate: 0,
      averageRank: 0,
      medianRank: 0,
      averageScoreGap: 0,
      medianScoreGap: 0,
      severeBlunderRate: 0,
    );
  }

  final authoritativeTotal = configs.fold<int>(
    0,
    (sum, config) => sum + config.authoritativeTotal,
  );
  return CaptureAiGroupSummary(
    kind: kind,
    name: name,
    total: total,
    acceptedRate:
        configs.fold<int>(0, (sum, config) => sum + config.accepted) / total,
    authoritativeAcceptedRate: authoritativeTotal == 0
        ? 0
        : configs.fold<int>(
              0,
              (sum, config) => sum + config.authoritativeAccepted,
            ) /
            authoritativeTotal,
    topOneRate:
        configs.fold<int>(0, (sum, config) => sum + config.topOne) / total,
    topThreeRate:
        configs.fold<int>(0, (sum, config) => sum + config.topThree) / total,
    averageRank: _weightedAverage(
      configs,
      (config) => config.averageRank,
    ),
    medianRank: _weightedAverage(
      configs,
      (config) => config.medianRank,
    ),
    averageScoreGap: _weightedAverage(
      configs,
      (config) => config.averageScoreGap,
    ),
    medianScoreGap: _weightedAverage(
      configs,
      (config) => config.medianScoreGap,
    ),
    severeBlunderRate:
        configs.fold<int>(0, (sum, config) => sum + config.severeBlunders) /
            total,
  );
}

double _weightedAverage(
  List<CaptureAiConfigSummary> configs,
  double Function(CaptureAiConfigSummary config) read,
) {
  final total = configs.fold<int>(0, (sum, config) => sum + config.total);
  if (total == 0) return 0;
  final weighted = configs.fold<double>(
    0,
    (sum, config) => sum + read(config) * config.total,
  );
  return weighted / total;
}

List<CaptureAiDifficultyDeltaSummary> _difficultyDeltas(
  List<CaptureAiConfigSummary> configs,
) {
  final summaries = <CaptureAiDifficultyDeltaSummary>[];
  for (final style in CaptureAiStyle.values) {
    final byDifficulty = {
      for (final config in configs)
        if (config.style == style) config.difficulty: config,
    };
    void addDelta(DifficultyLevel from, DifficultyLevel to) {
      final fromConfig = byDifficulty[from];
      final toConfig = byDifficulty[to];
      if (fromConfig == null || toConfig == null) return;
      summaries.add(
        CaptureAiDifficultyDeltaSummary(
          style: style,
          fromDifficulty: from,
          toDifficulty: to,
          acceptedRateDelta: toConfig.acceptedRate - fromConfig.acceptedRate,
          topOneRateDelta: toConfig.topOneRate - fromConfig.topOneRate,
          topThreeRateDelta: toConfig.topThreeRate - fromConfig.topThreeRate,
          averageRankDelta: toConfig.averageRank - fromConfig.averageRank,
          medianRankDelta: toConfig.medianRank - fromConfig.medianRank,
          averageScoreGapDelta:
              toConfig.averageScoreGap - fromConfig.averageScoreGap,
          medianScoreGapDelta:
              toConfig.medianScoreGap - fromConfig.medianScoreGap,
          severeBlunderRateDelta:
              toConfig.severeBlunderRate - fromConfig.severeBlunderRate,
        ),
      );
    }

    addDelta(DifficultyLevel.beginner, DifficultyLevel.intermediate);
    addDelta(DifficultyLevel.intermediate, DifficultyLevel.advanced);
    addDelta(DifficultyLevel.beginner, DifficultyLevel.advanced);
  }
  return summaries;
}

List<CaptureAiCategorySummary> _categorySummaries(
  List<CaptureAiTacticsProblemResult> results,
) {
  final grouped = <String, List<CaptureAiTacticsProblemResult>>{};
  for (final result in results) {
    grouped.putIfAbsent(result.problem.category, () => []).add(result);
  }

  final summaries = <CaptureAiCategorySummary>[];
  for (final entry in grouped.entries) {
    final configIds = <String>{};
    for (final result in entry.value) {
      for (final ai in result.aiResults) {
        configIds.add(ai.configId);
      }
    }
    for (final configId in configIds) {
      final aiResults = [
        for (final result in entry.value)
          for (final ai in result.aiResults)
            if (ai.configId == configId) ai
      ];
      summaries.add(
        CaptureAiCategorySummary(
          category: entry.key,
          problems: aiResults.length,
          configId: configId,
          accepted: aiResults.where((result) => result.accepted).length,
          authoritativeProblems:
              aiResults.where((result) => result.oracleAuthoritative).length,
          authoritativeAccepted:
              aiResults.where((result) => result.acceptedAuthoritative).length,
          severeBlunders:
              aiResults.where((result) => result.severeBlunder).length,
        ),
      );
    }
  }
  summaries.sort((a, b) {
    final byCategory = a.category.compareTo(b.category);
    if (byCategory != 0) return byCategory;
    return a.configId.compareTo(b.configId);
  });
  return summaries;
}

List<CaptureAiTacticSummary> _tacticSummaries(
  List<CaptureAiTacticsProblemResult> results,
) {
  final grouped = <String, List<CaptureAiTacticsProblemResult>>{};
  for (final result in results) {
    final tactic = result.problem.metadata['tactic']?.toString();
    if (tactic == null || tactic.isEmpty) continue;
    grouped.putIfAbsent(tactic, () => []).add(result);
  }

  final summaries = <CaptureAiTacticSummary>[];
  for (final entry in grouped.entries) {
    final configIds = <String>{};
    for (final result in entry.value) {
      for (final ai in result.aiResults) {
        configIds.add(ai.configId);
      }
    }
    for (final configId in configIds) {
      final aiResults = [
        for (final result in entry.value)
          for (final ai in result.aiResults)
            if (ai.configId == configId) ai
      ];
      summaries.add(
        CaptureAiTacticSummary(
          tactic: entry.key,
          problems: aiResults.length,
          configId: configId,
          accepted: aiResults.where((result) => result.accepted).length,
          authoritativeProblems:
              aiResults.where((result) => result.oracleAuthoritative).length,
          authoritativeAccepted:
              aiResults.where((result) => result.acceptedAuthoritative).length,
          topOne: aiResults.where((result) => result.rank == 1).length,
          topThree: aiResults
              .where((result) => result.rank != null && result.rank! <= 3)
              .length,
          severeBlunders:
              aiResults.where((result) => result.severeBlunder).length,
        ),
      );
    }
  }
  summaries.sort((a, b) {
    final byTactic = a.tactic.compareTo(b.tactic);
    if (byTactic != 0) return byTactic;
    return a.configId.compareTo(b.configId);
  });
  return summaries;
}

double? _confidenceGap(List<CaptureAiOracleMove> rankedMoves) {
  if (rankedMoves.length <= 1) return null;
  return math.max(0.0, rankedMoves[0].score - rankedMoves[1].score);
}

_AcceptedBandMetrics _acceptedBandMetrics(
  List<CaptureAiOracleMove> rankedMoves, {
  required double acceptScoreDelta,
  required int? topNAccepted,
}) {
  final best = rankedMoves.isEmpty ? null : rankedMoves.first;
  if (best == null) return const _AcceptedBandMetrics.empty();

  var acceptedMoveCount = 0;
  for (final move in rankedMoves) {
    if (best.score - move.score > acceptScoreDelta) break;
    if (topNAccepted != null && acceptedMoveCount >= topNAccepted) break;
    acceptedMoveCount++;
  }

  final firstRejected = acceptedMoveCount < rankedMoves.length
      ? rankedMoves[acceptedMoveCount]
      : null;
  final worstAccepted = rankedMoves[acceptedMoveCount - 1];
  final acceptedBandGap = firstRejected == null
      ? null
      : math.max(0.0, worstAccepted.score - firstRejected.score);
  return _AcceptedBandMetrics(
    acceptedMoveCount: acceptedMoveCount,
    acceptedMoveRatio: acceptedMoveCount / rankedMoves.length,
    acceptedBandGap: acceptedBandGap,
  );
}

class _AcceptedBandMetrics {
  const _AcceptedBandMetrics({
    required this.acceptedMoveCount,
    required this.acceptedMoveRatio,
    required this.acceptedBandGap,
  });

  const _AcceptedBandMetrics.empty()
      : acceptedMoveCount = 0,
        acceptedMoveRatio = 0,
        acceptedBandGap = null;

  final int acceptedMoveCount;
  final double acceptedMoveRatio;
  final double? acceptedBandGap;
}

List<String> _readDiagramRows(Object? rawDiagram, int boardSize, int index) {
  if (rawDiagram is String) {
    return rawDiagram
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
  if (rawDiagram is List) {
    return rawDiagram.map((row) => row.toString().trim()).toList();
  }
  throw CaptureAiTacticsFormatException(
    'Problem ${index + 1} is missing a diagram.',
  );
}

List<int> _parseDiagramCells(
  List<String> rows,
  int boardSize,
  int problemIndex,
) {
  if (rows.length != boardSize) {
    throw CaptureAiTacticsFormatException(
      'Problem ${problemIndex + 1} diagram has ${rows.length} rows; '
      'expected $boardSize.',
    );
  }

  final cells = <int>[];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    final tokens = row.contains(RegExp(r'\s'))
        ? row.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList()
        : row.split('');
    if (tokens.length != boardSize) {
      throw CaptureAiTacticsFormatException(
        'Problem ${problemIndex + 1} diagram row ${rowIndex + 1} has '
        '${tokens.length} cells; expected $boardSize.',
      );
    }
    for (final token in tokens) {
      cells.add(_parseCell(token, problemIndex, rowIndex));
    }
  }
  return cells;
}

int _parseCell(String token, int problemIndex, int rowIndex) {
  switch (token) {
    case '.':
      return SimBoard.empty;
    case 'B':
    case 'b':
      return SimBoard.black;
    case 'W':
    case 'w':
      return SimBoard.white;
  }
  throw CaptureAiTacticsFormatException(
    'Problem ${problemIndex + 1} diagram row ${rowIndex + 1} contains '
    'unsupported cell "$token"; use only ".", "B", or "W".',
  );
}

int _parsePlayer(Object? raw, {required int defaultPlayer}) {
  if (raw == null) return defaultPlayer;
  final value = raw.toString().trim().toLowerCase();
  switch (value) {
    case 'b':
    case 'black':
      return SimBoard.black;
    case 'w':
    case 'white':
      return SimBoard.white;
  }
  throw CaptureAiTacticsFormatException(
    'Unsupported current player "$raw"; use B/black or W/white.',
  );
}

Map<String, dynamic> _asJsonObject(Object? value, String path) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw CaptureAiTacticsFormatException('Expected object at $path.');
}

int _readInt(Map<String, dynamic> json, List<String> keys) {
  final value = _readOptionalInt(json, keys);
  if (value == null) {
    throw CaptureAiTacticsFormatException(
      'Missing required integer field ${keys.join('/')}',
    );
  }
  return value;
}

int? _readOptionalInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) continue;
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    throw CaptureAiTacticsFormatException('Field $key must be an integer.');
  }
  return null;
}

String _playerName(int player) {
  return switch (player) {
    SimBoard.black => 'black',
    SimBoard.white => 'white',
    _ => 'empty',
  };
}

Map<String, Object?> _positionToJson(BoardPosition position) {
  return {
    'row': position.row,
    'col': position.col,
    'label': _formatPosition(position),
  };
}

String _formatPosition(BoardPosition position) {
  return 'r${position.row + 1}c${position.col + 1}';
}

double _round(double value) => double.parse(value.toStringAsFixed(3));
