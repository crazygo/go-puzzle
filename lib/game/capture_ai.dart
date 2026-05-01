import 'dart:math' as math;

import '../models/board_position.dart';
import 'difficulty_level.dart';
import 'mcts_engine.dart';

enum CaptureAiStyle {
  /// Balanced, no tactical bias — maximises raw strength at equal playouts.
  adaptive,
  hunter,
  trapper,
  switcher,
  counter,
}

extension CaptureAiStyleExt on CaptureAiStyle {
  String get key => name;

  String get label {
    switch (this) {
      case CaptureAiStyle.adaptive:
        return '随机';
      case CaptureAiStyle.hunter:
        return '猎杀';
      case CaptureAiStyle.trapper:
        return '设陷';
      case CaptureAiStyle.switcher:
        return '转场';
      case CaptureAiStyle.counter:
        return '稳守';
    }
  }

  String get summary {
    switch (this) {
      case CaptureAiStyle.adaptive:
        return '均衡应变，不拘一格';
      case CaptureAiStyle.hunter:
        return '优先打吃和直接提子';
      case CaptureAiStyle.trapper:
        return '更重视制造连续威胁';
      case CaptureAiStyle.switcher:
        return '偏好多战场和中心机动';
      case CaptureAiStyle.counter:
        return '先补强自己，再等反击';
    }
  }
}

class CaptureAiMove {
  const CaptureAiMove({
    required this.position,
    required this.score,
  });

  final BoardPosition position;
  final double score;
}

abstract class CaptureAiAgent {
  CaptureAiStyle get style;

  CaptureAiMove? chooseMove(SimBoard board);
}

enum CaptureAiEngine {
  heuristic,
  hybridMcts,
  mcts,
}

class CaptureAiRobotConfig {
  const CaptureAiRobotConfig({
    required this.style,
    required this.difficulty,
    required this.engine,
    required this.heuristicPlayouts,
    required this.mctsPlayouts,
    required this.mctsRolloutDepth,
    required this.mctsCandidateLimit,
    required this.mctsExploration,
    required this.rolloutTemperature,
    required this.seed,
  });

  final CaptureAiStyle style;
  final DifficultyLevel difficulty;
  final CaptureAiEngine engine;
  final int heuristicPlayouts;
  final int mctsPlayouts;
  final int mctsRolloutDepth;
  final int mctsCandidateLimit;
  final double mctsExploration;
  final double rolloutTemperature;
  final int seed;

  String get id => '${style.name}_${difficulty.name}_v1';

  CaptureAiRobotConfig copyWith({
    CaptureAiEngine? engine,
    int? heuristicPlayouts,
    int? mctsPlayouts,
    int? mctsRolloutDepth,
    int? mctsCandidateLimit,
    double? mctsExploration,
    double? rolloutTemperature,
    int? seed,
  }) {
    return CaptureAiRobotConfig(
      style: style,
      difficulty: difficulty,
      engine: engine ?? this.engine,
      heuristicPlayouts: heuristicPlayouts ?? this.heuristicPlayouts,
      mctsPlayouts: mctsPlayouts ?? this.mctsPlayouts,
      mctsRolloutDepth: mctsRolloutDepth ?? this.mctsRolloutDepth,
      mctsCandidateLimit: mctsCandidateLimit ?? this.mctsCandidateLimit,
      mctsExploration: mctsExploration ?? this.mctsExploration,
      rolloutTemperature: rolloutTemperature ?? this.rolloutTemperature,
      seed: seed ?? this.seed,
    );
  }

  static CaptureAiRobotConfig forStyle(
    CaptureAiStyle style,
    DifficultyLevel difficulty, {
    int? seed,
  }) {
    final stableSeed = seed ?? _stableRobotSeed(style, difficulty);
    final engine = switch (difficulty) {
      DifficultyLevel.beginner => CaptureAiEngine.heuristic,
      DifficultyLevel.intermediate => CaptureAiEngine.hybridMcts,
      DifficultyLevel.advanced => CaptureAiEngine.hybridMcts,
    };

    return switch (difficulty) {
      DifficultyLevel.beginner => CaptureAiRobotConfig(
          style: style,
          difficulty: difficulty,
          engine: engine,
          heuristicPlayouts: 12,
          mctsPlayouts: 0,
          mctsRolloutDepth: 0,
          mctsCandidateLimit: 6,
          mctsExploration: 1.414,
          rolloutTemperature: 0,
          seed: stableSeed,
        ),
      DifficultyLevel.intermediate => CaptureAiRobotConfig(
          style: style,
          difficulty: difficulty,
          engine: engine,
          heuristicPlayouts: 12,
          mctsPlayouts: 24,
          mctsRolloutDepth: 14,
          mctsCandidateLimit: 11,
          mctsExploration: 1.25,
          rolloutTemperature: 8.0,
          seed: stableSeed,
        ),
      DifficultyLevel.advanced => CaptureAiRobotConfig(
          style: style,
          difficulty: difficulty,
          engine: engine,
          heuristicPlayouts: 40,
          mctsPlayouts: 72,
          mctsRolloutDepth: 20,
          mctsCandidateLimit: 14,
          mctsExploration: 1.05,
          rolloutTemperature: 6.0,
          seed: stableSeed,
        ),
    };
  }

  static int _stableRobotSeed(
    CaptureAiStyle style,
    DifficultyLevel difficulty,
  ) {
    return 1009 + style.index * 131 + difficulty.index * 1709;
  }
}

class CaptureAiRegistry {
  static CaptureAiAgent create({
    required CaptureAiStyle style,
    required DifficultyLevel difficulty,
    int? seed,
  }) {
    return createFromConfig(resolveConfig(
      style: style,
      difficulty: difficulty,
      seed: seed,
    ));
  }

  static CaptureAiRobotConfig resolveConfig({
    required CaptureAiStyle style,
    required DifficultyLevel difficulty,
    int? seed,
  }) {
    return CaptureAiRobotConfig.forStyle(style, difficulty, seed: seed);
  }

  static List<CaptureAiRobotConfig> get registeredConfigs {
    return [
      for (final style in CaptureAiStyle.values)
        for (final difficulty in DifficultyLevel.values)
          resolveConfig(style: style, difficulty: difficulty),
    ];
  }

  static CaptureAiAgent createFromConfig(CaptureAiRobotConfig config) {
    final profile = _CaptureAiProfile.forStyle(
      config.style,
      config.difficulty,
      playoutOverride: config.heuristicPlayouts,
    );
    final heuristic = _WeightedCaptureAiAgent(
      style: config.style,
      profile: profile,
    );
    if (config.engine == CaptureAiEngine.heuristic) return heuristic;

    final mcts = _MctsCaptureAiAgent(
      style: config.style,
      profile: profile,
      config: config,
    );
    if (config.engine == CaptureAiEngine.mcts) return mcts;

    return _HybridCaptureAiAgent(
      style: config.style,
      heuristicAgent: heuristic,
      mctsAgent: mcts,
    );
  }
}

class _HybridCaptureAiAgent implements CaptureAiAgent {
  const _HybridCaptureAiAgent({
    required this.style,
    required _WeightedCaptureAiAgent heuristicAgent,
    required _MctsCaptureAiAgent mctsAgent,
  })  : _heuristicAgent = heuristicAgent,
        _mctsAgent = mctsAgent;

  @override
  final CaptureAiStyle style;

  final _WeightedCaptureAiAgent _heuristicAgent;
  final _MctsCaptureAiAgent _mctsAgent;

  @override
  CaptureAiMove? chooseMove(SimBoard board) {
    final heuristicMove = _heuristicAgent.chooseMove(board);
    final mctsMove = _mctsAgent.chooseMove(board);
    if (mctsMove == null) return heuristicMove;
    if (heuristicMove == null) return mctsMove;
    if (!_isSaferThanHeuristic(board, mctsMove, heuristicMove)) {
      return heuristicMove;
    }
    return mctsMove.score >= heuristicMove.score + 30.0
        ? mctsMove
        : heuristicMove;
  }

  bool _isSaferThanHeuristic(
    SimBoard board,
    CaptureAiMove mctsMove,
    CaptureAiMove heuristicMove,
  ) {
    final currentPlayer = board.currentPlayer;
    final mctsBoard = SimBoard.copy(board);
    final heuristicBoard = SimBoard.copy(board);
    if (!mctsBoard.applyMove(mctsMove.position.row, mctsMove.position.col)) {
      return false;
    }
    if (!heuristicBoard.applyMove(
      heuristicMove.position.row,
      heuristicMove.position.col,
    )) {
      return true;
    }
    return _searchMargin(mctsBoard, currentPlayer, depth: 2) >=
        _searchMargin(heuristicBoard, currentPlayer, depth: 2);
  }

  double _searchMargin(SimBoard board, int player, {required int depth}) {
    if (board.winner == player) return 10000;
    if (board.winner != 0) return -10000;
    if (depth <= 0) return _captureMargin(board, player) * 100.0;

    final moves = _rankSafetyCandidates(board).take(8);
    if (board.currentPlayer == player) {
      var best = -double.infinity;
      for (final moveIndex in moves) {
        final next = SimBoard.copy(board);
        if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
          continue;
        }
        best = math.max(best, _searchMargin(next, player, depth: depth - 1));
      }
      return best.isFinite ? best : _captureMargin(board, player) * 100.0;
    }

    var worst = double.infinity;
    for (final moveIndex in moves) {
      final next = SimBoard.copy(board);
      if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
        continue;
      }
      worst = math.min(worst, _searchMargin(next, player, depth: depth - 1));
    }
    return worst.isFinite ? worst : _captureMargin(board, player) * 100.0;
  }

  int _captureMargin(SimBoard board, int player) {
    return player == SimBoard.black
        ? board.capturedByBlack - board.capturedByWhite
        : board.capturedByWhite - board.capturedByBlack;
  }

  List<int> _rankSafetyCandidates(SimBoard board) {
    final scored = <({int moveIndex, double score})>[];
    for (final moveIndex in board.getLegalMoves()) {
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      scored.add((
        moveIndex: moveIndex,
        score: _scoreWithProfile(board, analysis, _heuristicAgent._profile),
      ));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.moveIndex.compareTo(b.moveIndex);
    });
    return scored.map((entry) => entry.moveIndex).toList();
  }
}

class _MctsCaptureAiAgent implements CaptureAiAgent {
  const _MctsCaptureAiAgent({
    required this.style,
    required _CaptureAiProfile profile,
    required CaptureAiRobotConfig config,
  })  : _profile = profile,
        _config = config;

  @override
  final CaptureAiStyle style;

  final _CaptureAiProfile _profile;
  final CaptureAiRobotConfig _config;

  @override
  CaptureAiMove? chooseMove(SimBoard board) {
    final urgentMove = _chooseUrgentMove(board);
    if (urgentMove != null) return urgentMove;

    final lookaheadMove = _chooseLookaheadMove(board);
    final engine = MctsEngine(
      maxPlayouts: _config.mctsPlayouts,
      rolloutDepth: _config.mctsRolloutDepth,
      exploration: _config.mctsExploration,
      candidateLimit: _config.mctsCandidateLimit,
      moveScorer: _scoreMove,
      rolloutTemperature: _config.rolloutTemperature,
      seed: _config.seed + _boardFingerprint(board),
    );
    final position = engine.getBestMove(board);
    final mctsMove = position == null
        ? null
        : CaptureAiMove(
            position: position,
            score: _scoreMove(
              board,
              board.idx(position.row, position.col),
              board.analyzeMove(position.row, position.col),
            ),
          );

    final heuristicMove = _WeightedCaptureAiAgent(
      style: style,
      profile: _profile,
    ).chooseMove(board);
    final openingBaselineMove = _chooseAdvancedOpeningBaselineMove(board);
    if (openingBaselineMove != null) {
      return CaptureAiMove(
        position: openingBaselineMove.position,
        score: (heuristicMove?.score ?? openingBaselineMove.score) + 100.0,
      );
    }

    if (mctsMove == null) {
      final candidates = [
        if (lookaheadMove != null) lookaheadMove,
        if (heuristicMove != null) heuristicMove,
      ]..sort((a, b) => b.score.compareTo(a.score));
      return candidates.isEmpty ? null : candidates.first;
    }
    if (heuristicMove == null) {
      final candidates = [
        if (lookaheadMove != null) lookaheadMove,
        mctsMove,
      ]..sort((a, b) => b.score.compareTo(a.score));
      return candidates.first;
    }
    final candidates = [
      if (lookaheadMove != null) lookaheadMove,
      CaptureAiMove(
        position: mctsMove.position,
        score: mctsMove.score + _mctsDecisionBonus,
      ),
      heuristicMove,
    ]..sort((a, b) => b.score.compareTo(a.score));
    final heuristicSafety = _safetyScore(board, heuristicMove);
    final safeCandidates = candidates
        .where((move) => _safetyScore(board, move) >= heuristicSafety)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (safeCandidates.isEmpty) return heuristicMove;
    final best = safeCandidates.first;
    final sameAsHeuristic = best.position.row == heuristicMove.position.row &&
        best.position.col == heuristicMove.position.col;
    if (!sameAsHeuristic && best.score < heuristicMove.score + 30.0) {
      return heuristicMove;
    }
    return best;
  }

  double get _mctsDecisionBonus {
    return switch (_config.difficulty) {
      DifficultyLevel.beginner => 0,
      DifficultyLevel.intermediate => 0,
      DifficultyLevel.advanced => 12.0,
    };
  }

  CaptureAiMove? _chooseAdvancedOpeningBaselineMove(SimBoard board) {
    if (_config.difficulty != DifficultyLevel.advanced) return null;
    final stoneCount =
        board.cells.where((cell) => cell != SimBoard.empty).length;
    if (stoneCount > board.size * 2) return null;
    return CaptureAiRegistry.create(
      style: style,
      difficulty: DifficultyLevel.intermediate,
      seed: _config.seed,
    ).chooseMove(SimBoard.copy(board));
  }

  CaptureAiMove? _chooseUrgentMove(SimBoard board) {
    final legalMoves = board.getLegalMoves();
    CaptureAiMove? best;
    for (final moveIndex in legalMoves) {
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      final ownCaptureDelta = board.currentPlayer == SimBoard.black
          ? analysis.blackCaptureDelta
          : analysis.whiteCaptureDelta;
      final isUrgent = ownCaptureDelta > 0 || analysis.ownRescuedStones > 0;
      if (!isUrgent) continue;
      final move = CaptureAiMove(
        position: BoardPosition(row, col),
        score: _scoreMove(board, moveIndex, analysis) +
            ownCaptureDelta * 20 +
            analysis.ownRescuedStones * 10,
      );
      if (best == null || move.score > best.score) best = move;
    }
    return best;
  }

  double _safetyScore(SimBoard board, CaptureAiMove move) {
    final currentPlayer = board.currentPlayer;
    final next = SimBoard.copy(board);
    if (!next.applyMove(move.position.row, move.position.col)) {
      return -double.infinity;
    }
    return _minimaxScore(next, currentPlayer, 2);
  }

  CaptureAiMove? _chooseLookaheadMove(SimBoard board) {
    final legalMoves = board.getLegalMoves();
    final scored = <({int moveIndex, double score})>[];
    for (final moveIndex in legalMoves) {
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      scored.add((
        moveIndex: moveIndex,
        score: _scoreMove(board, moveIndex, analysis),
      ));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.moveIndex.compareTo(b.moveIndex);
    });

    CaptureAiMove? best;
    for (final entry in scored.take(_config.mctsCandidateLimit)) {
      final row = entry.moveIndex ~/ board.size;
      final col = entry.moveIndex % board.size;
      final afterMove = SimBoard.copy(board);
      if (!afterMove.applyMove(row, col)) continue;
      final terminalBonus =
          afterMove.winner == board.currentPlayer ? 1000.0 : 0.0;
      final depth = switch (_config.difficulty) {
        DifficultyLevel.beginner => 0,
        DifficultyLevel.intermediate => 2,
        DifficultyLevel.advanced => 2,
      };
      final lookaheadScore = entry.score +
          terminalBonus +
          _minimaxScore(afterMove, board.currentPlayer, depth);
      final move = CaptureAiMove(
        position: BoardPosition(row, col),
        score: lookaheadScore,
      );
      if (best == null || move.score > best.score) best = move;
    }
    return best;
  }

  double _minimaxScore(SimBoard board, int rootPlayer, int depth) {
    if (board.winner == rootPlayer) return 10000;
    if (board.winner != 0) return -10000;
    if (depth <= 0) return _positionScore(board, rootPlayer);

    final candidates = _rankSearchCandidates(board)
        .take(math.max(3, _config.mctsCandidateLimit ~/ 2));
    if (board.currentPlayer == rootPlayer) {
      var best = -double.infinity;
      for (final moveIndex in candidates) {
        final next = SimBoard.copy(board);
        if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
          continue;
        }
        best = math.max(best, _minimaxScore(next, rootPlayer, depth - 1));
      }
      return best.isFinite ? best : _positionScore(board, rootPlayer);
    }

    var worst = double.infinity;
    for (final moveIndex in candidates) {
      final next = SimBoard.copy(board);
      if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
        continue;
      }
      worst = math.min(worst, _minimaxScore(next, rootPlayer, depth - 1));
    }
    return worst.isFinite ? worst : _positionScore(board, rootPlayer);
  }

  List<int> _rankSearchCandidates(SimBoard board) {
    final scored = <({int moveIndex, double score})>[];
    for (final moveIndex in board.getLegalMoves()) {
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      scored.add((
        moveIndex: moveIndex,
        score: _scoreMove(board, moveIndex, analysis),
      ));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.moveIndex.compareTo(b.moveIndex);
    });
    return scored.map((entry) => entry.moveIndex).toList();
  }

  double _positionScore(SimBoard board, int player) {
    if (board.winner == player) return 1000;
    if (board.winner != 0) return -1000;
    final ownCaptures = player == SimBoard.black
        ? board.capturedByBlack
        : board.capturedByWhite;
    final opponentCaptures = player == SimBoard.black
        ? board.capturedByWhite
        : board.capturedByBlack;
    final captureScore = (ownCaptures - opponentCaptures) * 120.0;

    var opportunityScore = 0.0;
    for (final moveIndex in _rankSearchCandidates(board).take(16)) {
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      final moveScore = _scoreMove(board, moveIndex, analysis);
      if (board.currentPlayer == player) {
        opportunityScore = math.max(opportunityScore, moveScore);
      } else {
        opportunityScore = math.min(opportunityScore, -moveScore);
      }
    }

    return captureScore + opportunityScore;
  }

  double _scoreMove(
    SimBoard board,
    int moveIndex,
    SimMoveAnalysis analysis,
  ) {
    return _scoreWithProfile(board, analysis, _profile) +
        _sparseBoardInitiativeScore(board, analysis);
  }

  double _sparseBoardInitiativeScore(
    SimBoard board,
    SimMoveAnalysis analysis,
  ) {
    final stoneCount =
        board.cells.where((cell) => cell != SimBoard.empty).length;
    if (stoneCount > board.size) return 0;
    final scale = switch (_config.difficulty) {
      DifficultyLevel.beginner => 0.0,
      DifficultyLevel.intermediate => 32.0,
      DifficultyLevel.advanced => 64.0,
    };
    return analysis.adjacentOpponentStones * scale +
        analysis.centerProximityScore * scale * 0.12;
  }

  int _boardFingerprint(SimBoard board) {
    var hash = 17;
    for (var i = 0; i < board.cells.length; i++) {
      hash = 37 * hash + board.cells[i] * (i + 1);
    }
    hash = 37 * hash + board.currentPlayer;
    hash = 37 * hash + board.capturedByBlack * 11;
    hash = 37 * hash + board.capturedByWhite * 13;
    return hash & 0x7fffffff;
  }
}

class CaptureAiArenaResult {
  const CaptureAiArenaResult({
    required this.winner,
    required this.totalMoves,
    required this.blackCaptures,
    required this.whiteCaptures,
    required this.endReason,
  });

  final StoneColor winner;
  final int totalMoves;
  final int blackCaptures;
  final int whiteCaptures;
  final CaptureAiMatchEndReason endReason;

  bool get reachedCaptureTarget =>
      endReason == CaptureAiMatchEndReason.captureTargetReached;

  bool get completedWithoutFlowError =>
      endReason != CaptureAiMatchEndReason.invalidMove;
}

enum CaptureAiMatchEndReason {
  captureTargetReached,
  noLegalMove,
  invalidMove,
  maxMovesReached,
}

class CaptureAiSeriesEntry {
  const CaptureAiSeriesEntry({
    required this.blackStyle,
    required this.whiteStyle,
    required this.result,
  });

  final CaptureAiStyle blackStyle;
  final CaptureAiStyle whiteStyle;
  final CaptureAiArenaResult result;
}

class CaptureAiSeriesResult {
  const CaptureAiSeriesResult(this.entries);

  final List<CaptureAiSeriesEntry> entries;

  int winsFor(CaptureAiStyle style) {
    return entries.where((entry) {
      return (entry.result.winner == StoneColor.black &&
              entry.blackStyle == style) ||
          (entry.result.winner == StoneColor.white &&
              entry.whiteStyle == style);
    }).length;
  }
}

class CaptureAiBoardEvaluation {
  const CaptureAiBoardEvaluation({
    required this.boardSize,
    required this.captureTarget,
    required this.gamesPerPairing,
    required this.series,
  });

  final int boardSize;
  final int captureTarget;
  final int gamesPerPairing;
  final CaptureAiSeriesResult series;
}

class CaptureAiEvaluationConfig {
  const CaptureAiEvaluationConfig({
    required this.styles,
    required this.boardSizes,
    required this.captureTarget,
    required this.difficulty,
    this.gamesPerPairing = 1,
    this.maxMoves = 512,
  });

  final List<CaptureAiStyle> styles;
  final List<int> boardSizes;
  final int captureTarget;
  final DifficultyLevel difficulty;
  final int gamesPerPairing;
  final int maxMoves;
}

class CaptureAiStyleStanding {
  const CaptureAiStyleStanding({
    required this.style,
    required this.games,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.averageMoves,
    required this.averageCapturesFor,
    required this.averageCapturesAgainst,
    required this.elo,
    required this.invalidFinishes,
  });

  final CaptureAiStyle style;
  final int games;
  final int wins;
  final int losses;
  final int draws;
  final double averageMoves;
  final double averageCapturesFor;
  final double averageCapturesAgainst;
  final double elo;
  final int invalidFinishes;

  double get winRate => games == 0 ? 0 : wins / games;
}

class CaptureAiPairingStanding {
  const CaptureAiPairingStanding({
    required this.blackStyle,
    required this.whiteStyle,
    required this.games,
    required this.blackWins,
    required this.whiteWins,
    required this.draws,
  });

  final CaptureAiStyle blackStyle;
  final CaptureAiStyle whiteStyle;
  final int games;
  final int blackWins;
  final int whiteWins;
  final int draws;

  double get blackWinRate => games == 0 ? 0 : blackWins / games;
}

class CaptureAiEvaluationReport {
  const CaptureAiEvaluationReport({
    required this.boardEvaluations,
  });

  final List<CaptureAiBoardEvaluation> boardEvaluations;

  List<CaptureAiStyleStanding> standingsForBoard(int boardSize) {
    final evaluation = boardEvaluations.firstWhere(
      (entry) => entry.boardSize == boardSize,
    );
    return _buildStandings(evaluation.series);
  }

  List<CaptureAiPairingStanding> pairingsForBoard(int boardSize) {
    final evaluation = boardEvaluations.firstWhere(
      (entry) => entry.boardSize == boardSize,
    );
    return _buildPairings(evaluation.series);
  }

  String toPrettyString() {
    final buffer = StringBuffer();
    for (final evaluation in boardEvaluations) {
      buffer.writeln(
        'Board ${evaluation.boardSize}x${evaluation.boardSize} | '
        'CaptureTarget ${evaluation.captureTarget} | '
        'Games/Pairing ${evaluation.gamesPerPairing}',
      );
      buffer.writeln('Standings');
      buffer.writeln(
          'AI         W-L-D   WinRate  AvgMoves  AvgCap  AvgCapAgainst  Elo');
      for (final standing in _buildStandings(evaluation.series)) {
        buffer.writeln(
          '${standing.style.name.padRight(10)} '
          '${"${standing.wins}-${standing.losses}-${standing.draws}".padRight(7)} '
          '${(standing.winRate * 100).toStringAsFixed(1).padLeft(6)}% '
          '${standing.averageMoves.toStringAsFixed(1).padLeft(8)} '
          '${standing.averageCapturesFor.toStringAsFixed(2).padLeft(7)} '
          '${standing.averageCapturesAgainst.toStringAsFixed(2).padLeft(13)} '
          '${standing.elo.toStringAsFixed(0).padLeft(5)}',
        );
      }
      buffer.writeln('Pairings');
      for (final pairing in _buildPairings(evaluation.series)) {
        buffer.writeln(
          '${pairing.blackStyle.name} vs ${pairing.whiteStyle.name}: '
          '${pairing.blackWins}-${pairing.whiteWins}-${pairing.draws} '
          '(${(pairing.blackWinRate * 100).toStringAsFixed(1)}% black)',
        );
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  List<CaptureAiStyleStanding> _buildStandings(CaptureAiSeriesResult series) {
    final styles = <CaptureAiStyle>{};
    for (final entry in series.entries) {
      styles.add(entry.blackStyle);
      styles.add(entry.whiteStyle);
    }

    final standings = <CaptureAiStyleStanding>[];
    for (final style in styles) {
      var games = 0;
      var wins = 0;
      var losses = 0;
      var draws = 0;
      var totalMoves = 0;
      var capturesFor = 0;
      var capturesAgainst = 0;
      var invalidFinishes = 0;

      for (final entry in series.entries) {
        final isBlack = entry.blackStyle == style;
        final isWhite = entry.whiteStyle == style;
        if (!isBlack && !isWhite) continue;

        final result = entry.result;
        games++;
        totalMoves += result.totalMoves;
        if (!result.completedWithoutFlowError) {
          invalidFinishes++;
        }

        final ownCaptures =
            isBlack ? result.blackCaptures : result.whiteCaptures;
        final opponentCaptures =
            isBlack ? result.whiteCaptures : result.blackCaptures;
        capturesFor += ownCaptures;
        capturesAgainst += opponentCaptures;

        final winner = result.winner;
        if ((isBlack && winner == StoneColor.black) ||
            (isWhite && winner == StoneColor.white)) {
          wins++;
        } else if (winner == StoneColor.empty) {
          draws++;
        } else {
          losses++;
        }
      }

      standings.add(
        CaptureAiStyleStanding(
          style: style,
          games: games,
          wins: wins,
          losses: losses,
          draws: draws,
          averageMoves: games == 0 ? 0 : totalMoves / games,
          averageCapturesFor: games == 0 ? 0 : capturesFor / games,
          averageCapturesAgainst: games == 0 ? 0 : capturesAgainst / games,
          elo: _calculateElo(games: games, wins: wins, draws: draws),
          invalidFinishes: invalidFinishes,
        ),
      );
    }

    standings.sort((a, b) {
      final byWinRate = b.winRate.compareTo(a.winRate);
      if (byWinRate != 0) return byWinRate;
      return b.elo.compareTo(a.elo);
    });
    return standings;
  }

  List<CaptureAiPairingStanding> _buildPairings(CaptureAiSeriesResult series) {
    final pairings = <CaptureAiPairingStanding>[];
    final grouped = <String, List<CaptureAiSeriesEntry>>{};
    for (final entry in series.entries) {
      final key = '${entry.blackStyle.name}->${entry.whiteStyle.name}';
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    for (final entries in grouped.values) {
      final first = entries.first;
      var blackWins = 0;
      var whiteWins = 0;
      var draws = 0;
      for (final entry in entries) {
        final winner = entry.result.winner;
        if (winner == StoneColor.black) {
          blackWins++;
        } else if (winner == StoneColor.white) {
          whiteWins++;
        } else {
          draws++;
        }
      }
      pairings.add(
        CaptureAiPairingStanding(
          blackStyle: first.blackStyle,
          whiteStyle: first.whiteStyle,
          games: entries.length,
          blackWins: blackWins,
          whiteWins: whiteWins,
          draws: draws,
        ),
      );
    }

    pairings.sort((a, b) {
      final byBlack = a.blackStyle.name.compareTo(b.blackStyle.name);
      if (byBlack != 0) return byBlack;
      return a.whiteStyle.name.compareTo(b.whiteStyle.name);
    });
    return pairings;
  }

  double _calculateElo({
    required int games,
    required int wins,
    required int draws,
  }) {
    if (games == 0) return 1000;
    final score = (wins + draws * 0.5) / games;
    final clamped = score.clamp(0.01, 0.99);
    return 1000 + 400 * math.log(clamped / (1 - clamped)) / math.ln10;
  }
}

class CaptureAiArena {
  static CaptureAiArenaResult playMatch({
    required CaptureAiAgent blackAgent,
    required CaptureAiAgent whiteAgent,
    required int boardSize,
    required int captureTarget,
    int maxMoves = 512,
    SimBoard? initialBoard,
  }) {
    final board = initialBoard == null
        ? SimBoard(boardSize, captureTarget: captureTarget)
        : SimBoard.copy(initialBoard);
    var totalMoves = 0;
    var endReason = CaptureAiMatchEndReason.maxMovesReached;

    while (!board.isTerminal && totalMoves < maxMoves) {
      final agent =
          board.currentPlayer == SimBoard.black ? blackAgent : whiteAgent;
      final move = agent.chooseMove(board);
      if (move == null) {
        endReason = CaptureAiMatchEndReason.noLegalMove;
        break;
      }
      if (!board.applyMove(move.position.row, move.position.col)) {
        endReason = CaptureAiMatchEndReason.invalidMove;
        break;
      }
      totalMoves++;
    }

    if (board.isTerminal) {
      endReason = CaptureAiMatchEndReason.captureTargetReached;
    } else if (totalMoves >= maxMoves &&
        endReason == CaptureAiMatchEndReason.maxMovesReached) {
      endReason = CaptureAiMatchEndReason.maxMovesReached;
    }

    final winner = switch (board.winner) {
      SimBoard.black => StoneColor.black,
      SimBoard.white => StoneColor.white,
      _ => StoneColor.empty,
    };

    return CaptureAiArenaResult(
      winner: winner,
      totalMoves: totalMoves,
      blackCaptures: board.capturedByBlack,
      whiteCaptures: board.capturedByWhite,
      endReason: endReason,
    );
  }

  static CaptureAiSeriesResult runRoundRobin({
    required List<CaptureAiStyle> styles,
    required DifficultyLevel difficulty,
    required int boardSize,
    required int captureTarget,
    int gamesPerPairing = 1,
    int maxMoves = 512,
  }) {
    final entries = <CaptureAiSeriesEntry>[];

    for (final blackStyle in styles) {
      for (final whiteStyle in styles) {
        if (blackStyle == whiteStyle) continue;

        for (int gameIndex = 0; gameIndex < gamesPerPairing; gameIndex++) {
          final result = playMatch(
            blackAgent: CaptureAiRegistry.create(
                style: blackStyle, difficulty: difficulty),
            whiteAgent: CaptureAiRegistry.create(
                style: whiteStyle, difficulty: difficulty),
            boardSize: boardSize,
            captureTarget: captureTarget,
            maxMoves: maxMoves,
          );
          entries.add(
            CaptureAiSeriesEntry(
              blackStyle: blackStyle,
              whiteStyle: whiteStyle,
              result: result,
            ),
          );
        }
      }
    }

    return CaptureAiSeriesResult(entries);
  }

  static CaptureAiEvaluationReport evaluate(CaptureAiEvaluationConfig config) {
    final boardEvaluations = <CaptureAiBoardEvaluation>[];
    for (final boardSize in config.boardSizes) {
      final series = runRoundRobin(
        styles: config.styles,
        difficulty: config.difficulty,
        boardSize: boardSize,
        captureTarget: config.captureTarget,
        gamesPerPairing: config.gamesPerPairing,
        maxMoves: config.maxMoves,
      );
      boardEvaluations.add(
        CaptureAiBoardEvaluation(
          boardSize: boardSize,
          captureTarget: config.captureTarget,
          gamesPerPairing: config.gamesPerPairing,
          series: series,
        ),
      );
    }
    return CaptureAiEvaluationReport(boardEvaluations: boardEvaluations);
  }
}

class _CaptureAiProfile {
  const _CaptureAiProfile({
    required this.immediateCaptureWeight,
    required this.opponentAtariWeight,
    required this.ownRescueWeight,
    required this.selfAtariPenalty,
    required this.centerWeight,
    required this.contactWeight,
    required this.libertyWeight,
    required this.playouts,
  });

  final double immediateCaptureWeight;
  final double opponentAtariWeight;
  final double ownRescueWeight;
  final double selfAtariPenalty;
  final double centerWeight;
  final double contactWeight;
  final double libertyWeight;
  final int playouts;

  static _CaptureAiProfile forStyle(
    CaptureAiStyle style,
    DifficultyLevel difficulty, {
    int? playoutOverride,
  }) {
    final playouts = playoutOverride ??
        switch (difficulty) {
          DifficultyLevel.beginner => 12,
          DifficultyLevel.intermediate => 24,
          DifficultyLevel.advanced => 48,
        };

    final base = switch (style) {
      CaptureAiStyle.adaptive => _CaptureAiProfile(
          // Averaged weights across all four named styles, giving the
          // highest unconstrained strength at equal playouts.
          immediateCaptureWeight: 6.975,
          opponentAtariWeight: 3.8,
          ownRescueWeight: 2.025,
          selfAtariPenalty: 5.85,
          centerWeight: 0.625,
          contactWeight: 2.05,
          libertyWeight: 1.5,
          playouts: playouts,
        ),
      CaptureAiStyle.hunter => _CaptureAiProfile(
          immediateCaptureWeight: 9.0,
          opponentAtariWeight: 4.2,
          ownRescueWeight: 1.0,
          selfAtariPenalty: 6.0,
          centerWeight: 0.2,
          contactWeight: 2.8,
          libertyWeight: 0.8,
          playouts: playouts,
        ),
      CaptureAiStyle.trapper => _CaptureAiProfile(
          immediateCaptureWeight: 6.5,
          opponentAtariWeight: 5.5,
          ownRescueWeight: 1.5,
          selfAtariPenalty: 5.2,
          centerWeight: 0.4,
          contactWeight: 2.0,
          libertyWeight: 1.4,
          playouts: playouts,
        ),
      CaptureAiStyle.switcher => _CaptureAiProfile(
          immediateCaptureWeight: 5.6,
          opponentAtariWeight: 3.0,
          ownRescueWeight: 1.8,
          selfAtariPenalty: 4.8,
          centerWeight: 1.6,
          contactWeight: 2.2,
          libertyWeight: 1.2,
          playouts: playouts,
        ),
      CaptureAiStyle.counter => _CaptureAiProfile(
          immediateCaptureWeight: 5.8,
          opponentAtariWeight: 2.5,
          ownRescueWeight: 3.8,
          selfAtariPenalty: 7.4,
          centerWeight: 0.3,
          contactWeight: 1.2,
          libertyWeight: 2.6,
          playouts: playouts,
        ),
    };

    return base.tunedForDifficulty(difficulty);
  }

  _CaptureAiProfile tunedForDifficulty(DifficultyLevel difficulty) {
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

    return _CaptureAiProfile(
      immediateCaptureWeight: immediateCaptureWeight * tacticalScale,
      opponentAtariWeight: opponentAtariWeight * tacticalScale,
      ownRescueWeight: ownRescueWeight * safetyScale,
      selfAtariPenalty: selfAtariPenalty * safetyScale,
      centerWeight: centerWeight,
      contactWeight: contactWeight * contactScale,
      libertyWeight: libertyWeight * libertyScale,
      playouts: playouts,
    );
  }
}

class _WeightedCaptureAiAgent implements CaptureAiAgent {
  _WeightedCaptureAiAgent({
    required this.style,
    required _CaptureAiProfile profile,
  }) : _profile = profile;

  @override
  final CaptureAiStyle style;

  final _CaptureAiProfile _profile;

  @override
  CaptureAiMove? chooseMove(SimBoard board) {
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
        score: _score(board, analysis),
      ));
    }

    if (scoredMoves.isEmpty) return null;

    scoredMoves.sort((a, b) => b.score.compareTo(a.score));
    final bestMove = scoredMoves.first;

    if (_profile.playouts <= 0) {
      return bestMove;
    }

    final shortlisted = scoredMoves.take(6).toList();
    CaptureAiMove? refinedBest;
    for (final candidate in shortlisted) {
      final simulated = SimBoard.copy(board);
      if (!simulated.applyMove(
          candidate.position.row, candidate.position.col)) {
        continue;
      }
      final playoutBoard = SimBoard.copy(simulated);
      final winner = _rolloutWithStyle(playoutBoard, _profile.playouts);
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

  double _score(SimBoard board, SimMoveAnalysis analysis) {
    return _scoreWithProfile(board, analysis, _profile);
  }

  int _rolloutWithStyle(SimBoard board, int maxSteps) {
    var steps = 0;
    while (!board.isTerminal && steps < maxSteps) {
      final move = chooseMoveForRollout(board);
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

  BoardPosition? chooseMoveForRollout(SimBoard board) {
    final legalMoves = board.getLegalMoves();
    CaptureAiMove? bestMove;
    for (final moveIndex in legalMoves.take(12)) {
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      final score = _score(board, analysis);
      if (bestMove == null || score > bestMove.score) {
        bestMove = CaptureAiMove(
          position: BoardPosition(row, col),
          score: score,
        );
      }
    }
    return bestMove?.position;
  }
}

double _scoreWithProfile(
  SimBoard board,
  SimMoveAnalysis analysis,
  _CaptureAiProfile profile,
) {
  final currentPlayer = board.currentPlayer;
  final ownCaptured = currentPlayer == SimBoard.black
      ? analysis.blackCaptureDelta
      : analysis.whiteCaptureDelta;

  return ownCaptured * profile.immediateCaptureWeight +
      analysis.opponentAtariStones * profile.opponentAtariWeight +
      analysis.ownRescuedStones * profile.ownRescueWeight +
      analysis.adjacentOpponentStones * profile.contactWeight +
      analysis.libertiesAfterMove * profile.libertyWeight +
      analysis.centerProximityScore * profile.centerWeight -
      analysis.ownAtariStones * profile.selfAtariPenalty;
}
