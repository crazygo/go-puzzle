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
        return '戰力優先';
      case CaptureAiStyle.hunter:
        return '獵殺';
      case CaptureAiStyle.trapper:
        return '設陷';
      case CaptureAiStyle.switcher:
        return '轉場';
      case CaptureAiStyle.counter:
        return '穩守';
    }
  }

  String get summary {
    switch (this) {
      case CaptureAiStyle.adaptive:
        return '均衡應變，不拘一格';
      case CaptureAiStyle.hunter:
        return '優先打吃和直接提子';
      case CaptureAiStyle.trapper:
        return '更重視製造連續威脅';
      case CaptureAiStyle.switcher:
        return '偏好多戰場和中心機動';
      case CaptureAiStyle.counter:
        return '先補強自己，再等反擊';
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
    final largeBoardFallback =
        _mctsAgent._chooseAdvancedLargeBoardHeuristicFallback(board);
    if (largeBoardFallback != null) return largeBoardFallback;
    final twistWhiteFallback =
        _mctsAgent._chooseAdvancedTwistWhiteFallback(board);
    if (twistWhiteFallback != null) return twistWhiteFallback;
    final whiteSpacingFallback =
        _mctsAgent._chooseAdvancedWhiteSpacingFallback(board);
    if (whiteSpacingFallback != null) return whiteSpacingFallback;
    final twistBlackFallback =
        _mctsAgent._chooseAdvancedTwistBlackFallback(board);
    if (twistBlackFallback != null) return twistBlackFallback;

    final heuristicMove = _heuristicAgent.chooseMove(board);
    final mctsMove = _mctsAgent.chooseMove(board);
    if (mctsMove == null) return heuristicMove;
    if (heuristicMove == null) return mctsMove;
    final isAdvancedQuietTactical =
        _mctsAgent._isAdvancedQuietTacticalMove(board, mctsMove);
    final isAdvancedTacticalSearch =
        _mctsAgent._isAdvancedTacticalSearchMove(board, mctsMove);
    if (isAdvancedTacticalSearch &&
        _mctsAgent._shouldPreferSafeMoveOverTacticalSearch(
          board,
          safeMove: heuristicMove,
          tacticalSearchMove: mctsMove,
        )) {
      return heuristicMove;
    }
    if (!isAdvancedQuietTactical &&
        !isAdvancedTacticalSearch &&
        !_isSaferThanHeuristic(board, mctsMove, heuristicMove)) {
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

  static const int _advancedTacticalDepth = 2;
  static const int _advancedTacticalHorizon = 10;
  static const int _advancedTacticalMaxNodes = 1000;
  static const double _advancedTacticalDecisionBonus = 750.0;
  static const double _advancedTacticalDecisionScore = 650.0;

  @override
  CaptureAiMove? chooseMove(SimBoard board) {
    final targetWinCache = <int, bool>{};
    final largeBoardFallback =
        _chooseAdvancedLargeBoardHeuristicFallback(board);
    if (largeBoardFallback != null) return largeBoardFallback;
    final twistWhiteFallback = _chooseAdvancedTwistWhiteFallback(board);
    if (twistWhiteFallback != null) return twistWhiteFallback;
    final whiteSpacingFallback = _chooseAdvancedWhiteSpacingFallback(board);
    if (whiteSpacingFallback != null) return whiteSpacingFallback;
    final twistBlackFallback = _chooseAdvancedTwistBlackFallback(board);
    if (twistBlackFallback != null) return twistBlackFallback;

    final urgentMove = _chooseUrgentMove(board);
    if (urgentMove != null && _isImmediateTargetWin(board, urgentMove)) {
      return urgentMove;
    }
    if (urgentMove != null &&
        _capturesFor(board, _opponentOf(board.currentPlayer)) >=
            board.captureTarget - 2 &&
        !_allowsOpponentTargetWinCached(
          board,
          urgentMove,
          targetWinCache,
        )) {
      return urgentMove;
    }

    final lookaheadMoves = _rankLookaheadMoves(board, limit: 4);
    final lookaheadMove = lookaheadMoves.isEmpty ? null : lookaheadMoves.first;
    final heuristicMove = _WeightedCaptureAiAgent(
      style: style,
      profile: _profile,
    ).chooseMove(board);
    final tacticalSearchMove = _chooseAdvancedTargetSearchMove(
      board,
      heuristicMove: heuristicMove,
    );
    final hasQuietTacticalContext = urgentMove != null ||
        board.capturedByBlack > 0 ||
        board.capturedByWhite > 0;
    final quietTacticalMoves = _config.difficulty == DifficultyLevel.advanced &&
            hasQuietTacticalContext
        ? _rankQuietTacticalMoves(board, limit: 4)
        : const <CaptureAiMove>[];
    final forcingCounterAtariMoves =
        _config.difficulty == DifficultyLevel.advanced
            ? _rankForcingCounterAtariMoves(board, limit: 3)
            : const <CaptureAiMove>[];

    if (urgentMove != null) {
      if (_shouldPreferSafeMoveOverTacticalSearch(
        board,
        safeMove: urgentMove,
        tacticalSearchMove: tacticalSearchMove,
        targetWinCache: targetWinCache,
      )) {
        return urgentMove;
      }
      final candidates = [
        urgentMove,
        if (tacticalSearchMove != null) tacticalSearchMove,
        if (heuristicMove != null) heuristicMove,
        ...lookaheadMoves.take(4),
        ...forcingCounterAtariMoves,
        ...quietTacticalMoves,
      ]..sort((a, b) => b.score.compareTo(a.score));
      return _bestTargetSafeCandidate(board, candidates, targetWinCache);
    }

    if (tacticalSearchMove != null) return tacticalSearchMove;

    final quietTacticalMove = _bestAdvancedQuietTacticalMove(
      board,
      quietTacticalMoves,
      heuristicMove,
      targetWinCache,
    );
    if (quietTacticalMove != null) return quietTacticalMove;

    final openingBaselineMove = _chooseAdvancedOpeningBaselineMove(board);
    if (openingBaselineMove != null) {
      return CaptureAiMove(
        position: openingBaselineMove.position,
        score: (heuristicMove?.score ?? openingBaselineMove.score) + 100.0,
      );
    }

    final engine = MctsEngine(
      maxPlayouts: _config.mctsPlayouts,
      rolloutDepth: _config.mctsRolloutDepth,
      exploration: _config.mctsExploration,
      candidateLimit: _config.mctsCandidateLimit,
      moveScorer: _scoreRolloutMove,
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

    if (mctsMove == null) {
      final candidates = [
        if (tacticalSearchMove != null) tacticalSearchMove,
        if (lookaheadMove != null) lookaheadMove,
        if (heuristicMove != null) heuristicMove,
        ...forcingCounterAtariMoves,
        ...quietTacticalMoves,
      ]..sort((a, b) => b.score.compareTo(a.score));
      return _bestTargetSafeCandidate(board, candidates, targetWinCache);
    }
    if (heuristicMove == null) {
      final candidates = [
        if (tacticalSearchMove != null) tacticalSearchMove,
        if (lookaheadMove != null) lookaheadMove,
        mctsMove,
        ...forcingCounterAtariMoves,
        ...quietTacticalMoves,
      ]..sort((a, b) => b.score.compareTo(a.score));
      return _bestTargetSafeCandidate(board, candidates, targetWinCache);
    }
    final candidates = [
      if (tacticalSearchMove != null) tacticalSearchMove,
      if (lookaheadMove != null) lookaheadMove,
      CaptureAiMove(
        position: mctsMove.position,
        score: mctsMove.score + _mctsDecisionBonus,
      ),
      heuristicMove,
      ...forcingCounterAtariMoves,
      ...quietTacticalMoves,
    ]..sort((a, b) => b.score.compareTo(a.score));
    final heuristicSafety = _safetyScore(board, heuristicMove);
    final safeCandidates = candidates
        .where((move) {
          return !_allowsOpponentTargetWinCached(
            board,
            move,
            targetWinCache,
          );
        })
        .where((move) =>
            _isAdvancedQuietTacticalMove(board, move) ||
            _safetyScore(board, move) >= heuristicSafety)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (safeCandidates.isEmpty) {
      return _allowsOpponentTargetWinCached(
        board,
        heuristicMove,
        targetWinCache,
      )
          ? _bestTargetSafeCandidate(board, candidates, targetWinCache)
          : heuristicMove;
    }
    final best = safeCandidates.first;
    final sameAsHeuristic = best.position.row == heuristicMove.position.row &&
        best.position.col == heuristicMove.position.col;
    if (!sameAsHeuristic && best.score < heuristicMove.score + 30.0) {
      return heuristicMove;
    }
    return best;
  }

  CaptureAiMove? _chooseAdvancedLargeBoardHeuristicFallback(SimBoard board) {
    if (_config.difficulty != DifficultyLevel.advanced) return null;
    if (board.size <= 9 || board.isTerminal) return null;
    return _WeightedCaptureAiAgent(
      style: style,
      profile: _CaptureAiProfile.forStyle(
        style,
        DifficultyLevel.beginner,
      ),
    ).chooseMove(board);
  }

  CaptureAiMove? _chooseAdvancedTwistBlackFallback(SimBoard board) {
    if (_config.difficulty != DifficultyLevel.advanced) return null;
    if (board.size != 9 || board.isTerminal) return null;
    if (board.currentPlayer != SimBoard.black) return null;
    if (board.capturedByBlack > 0) return null;
    if (!_hasTwistOpeningAnchors(board)) return null;
    return CaptureAiRegistry.create(
      style: style,
      difficulty: DifficultyLevel.intermediate,
      seed: _config.seed,
    ).chooseMove(SimBoard.copy(board));
  }

  CaptureAiMove? _chooseAdvancedTwistWhiteFallback(SimBoard board) {
    if (_config.difficulty != DifficultyLevel.advanced) return null;
    if (board.size != 9 || board.isTerminal) return null;
    if (board.currentPlayer != SimBoard.white) return null;
    if (!_hasTwistOpeningAnchors(board)) return null;
    if (board.capturedByWhite >= board.captureTarget - 1) return null;
    if (_isFirstTwistWhiteReplyToEdgeProbe(board)) return null;

    for (final moveIndex in board.getLegalMoves()) {
      final analysis =
          board.analyzeMove(moveIndex ~/ board.size, moveIndex % board.size);
      if (!analysis.isLegal) continue;
      if (_captureDeltaFor(analysis, SimBoard.white) > 0 ||
          analysis.ownRescuedStones > 0) {
        return null;
      }
    }

    _SpacingCandidate? best;
    for (var moveIndex = 0; moveIndex < board.cells.length; moveIndex++) {
      if (board.cells[moveIndex] != SimBoard.empty) continue;
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final edgeDistance = math.min(
        math.min(row, col),
        math.min(board.size - 1 - row, board.size - 1 - col),
      );
      if (edgeDistance == 0) continue;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      final next = SimBoard.copy(board);
      if (!next.applyMove(row, col)) continue;
      if (_playerCanReachCaptureTarget(next, SimBoard.black)) continue;
      final blackBestCapture = _bestImmediateCaptureDeltaForPlayer(
        next,
        SimBoard.black,
      );
      final center = board.size ~/ 2;
      final centerDistance = (row - center).abs() + (col - center).abs();
      final centerScore = math.max(0, board.size - centerDistance);
      final score = centerScore * 85.0 +
          analysis.adjacentOpponentStones * 180.0 +
          analysis.opponentAtariStones * 260.0 +
          analysis.libertiesAfterMove * 22.0 -
          analysis.ownAtariStones * 2400.0 -
          blackBestCapture * 2800.0 +
          _stableMoveTieBreaker(moveIndex);
      final candidate = _SpacingCandidate(moveIndex, score);
      if (best == null || candidate.score > best.score) best = candidate;
    }
    if (best == null) return null;
    return CaptureAiMove(
      position: BoardPosition(
          best.moveIndex ~/ board.size, best.moveIndex % board.size),
      score: best.score + 260.0,
    );
  }

  bool _isFirstTwistWhiteReplyToEdgeProbe(SimBoard board) {
    var occupied = 0;
    var blackEdgeStones = 0;
    for (var moveIndex = 0; moveIndex < board.cells.length; moveIndex++) {
      final cell = board.cells[moveIndex];
      if (cell == SimBoard.empty) continue;
      occupied++;
      if (cell != SimBoard.black) continue;
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      if (row == 0 ||
          col == 0 ||
          row == board.size - 1 ||
          col == board.size - 1) {
        blackEdgeStones++;
      }
    }
    return occupied <= 5 && blackEdgeStones > 0;
  }

  CaptureAiMove? _chooseAdvancedWhiteSpacingFallback(SimBoard board) {
    if (_config.difficulty != DifficultyLevel.advanced) return null;
    if (board.size != 9 || board.isTerminal) return null;
    if (board.currentPlayer != SimBoard.white) return null;
    if (board.capturedByWhite >= board.captureTarget - 1) return null;

    for (final moveIndex in board.getLegalMoves()) {
      final analysis =
          board.analyzeMove(moveIndex ~/ board.size, moveIndex % board.size);
      if (!analysis.isLegal) continue;
      if (_captureDeltaFor(analysis, SimBoard.white) > 0 ||
          analysis.ownRescuedStones > 0) {
        return null;
      }
    }

    _SpacingCandidate? best;
    for (var moveIndex = 0; moveIndex < board.cells.length; moveIndex++) {
      if (board.cells[moveIndex] != SimBoard.empty) continue;
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      final next = SimBoard.copy(board);
      if (!next.applyMove(row, col)) continue;
      if (_playerCanReachCaptureTarget(next, SimBoard.black)) continue;
      final blackBestCapture = _bestImmediateCaptureDeltaForPlayer(
        next,
        SimBoard.black,
      );
      final score = _spacingScore(board, moveIndex) +
          analysis.libertiesAfterMove * 18.0 -
          analysis.adjacentOpponentStones * 950.0 -
          analysis.ownAtariStones * 2200.0 -
          blackBestCapture * 2600.0 +
          _stableMoveTieBreaker(moveIndex);
      final candidate = _SpacingCandidate(moveIndex, score);
      if (best == null || candidate.score > best.score) best = candidate;
    }
    if (best == null) return null;
    return CaptureAiMove(
      position: BoardPosition(
          best.moveIndex ~/ board.size, best.moveIndex % board.size),
      score: best.score + 220.0,
    );
  }

  double _spacingScore(SimBoard board, int moveIndex) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    var nearestOpponent = board.size * 2;
    var nearestOwn = board.size * 2;
    var opponentEdgeStones = 0;
    for (var other = 0; other < board.cells.length; other++) {
      final color = board.cells[other];
      if (color == SimBoard.empty) continue;
      final otherRow = other ~/ board.size;
      final otherCol = other % board.size;
      final distance = (row - otherRow).abs() + (col - otherCol).abs();
      if (color == board.currentPlayer) {
        nearestOwn = math.min(nearestOwn, distance);
      } else {
        nearestOpponent = math.min(nearestOpponent, distance);
        if (otherRow == 0 ||
            otherCol == 0 ||
            otherRow == board.size - 1 ||
            otherCol == board.size - 1) {
          opponentEdgeStones++;
        }
      }
    }
    final edgeDistance = math.min(
      math.min(row, col),
      math.min(board.size - 1 - row, board.size - 1 - col),
    );
    final edgePenalty =
        opponentEdgeStones >= 2 ? math.max(0, 2 - edgeDistance) * 220.0 : 0.0;
    return math.min(nearestOpponent, 6) * 80.0 +
        math.min(nearestOwn, 4) * 25.0 -
        edgePenalty;
  }

  CaptureAiMove? _bestAdvancedQuietTacticalMove(
    SimBoard board,
    List<CaptureAiMove> quietTacticalMoves,
    CaptureAiMove? heuristicMove,
    Map<int, bool> targetWinCache,
  ) {
    if (quietTacticalMoves.isEmpty) return null;
    final best = _bestTargetSafeCandidate(
      board,
      quietTacticalMoves,
      targetWinCache,
    );
    if (best == null || !_isAdvancedQuietTacticalMove(board, best)) {
      return null;
    }
    if (heuristicMove != null && best.score < heuristicMove.score + 30.0) {
      return null;
    }
    return best;
  }

  CaptureAiMove? _bestTargetSafeCandidate(
    SimBoard board,
    List<CaptureAiMove> candidates,
    Map<int, bool> targetWinCache,
  ) {
    if (candidates.isEmpty) return null;
    final safeCandidates = candidates.where((move) {
      return !_allowsOpponentTargetWinCached(
        board,
        move,
        targetWinCache,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (safeCandidates.isNotEmpty) return safeCandidates.first;
    return candidates.first;
  }

  bool _allowsOpponentTargetWinCached(
    SimBoard board,
    CaptureAiMove move,
    Map<int, bool> targetWinCache,
  ) {
    final moveIndex = board.idx(move.position.row, move.position.col);
    return targetWinCache.putIfAbsent(
      moveIndex,
      () => _allowsOpponentTargetWin(board, move),
    );
  }

  bool _isImmediateTargetWin(SimBoard board, CaptureAiMove move) {
    final row = move.position.row;
    final col = move.position.col;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) return false;
    final player = board.currentPlayer;
    return _capturesFor(board, player) + _captureDeltaFor(analysis, player) >=
        board.captureTarget;
  }

  bool _isAdvancedQuietTacticalMove(SimBoard board, CaptureAiMove move) {
    return _config.difficulty == DifficultyLevel.advanced &&
        _isQuietTacticalMove(board, move);
  }

  bool _isAdvancedTacticalSearchMove(SimBoard board, CaptureAiMove move) {
    if (_config.difficulty != DifficultyLevel.advanced) return false;
    if (move.score < _advancedTacticalDecisionScore) return false;
    return board.analyzeMove(move.position.row, move.position.col).isLegal;
  }

  bool _shouldPreferSafeMoveOverTacticalSearch(
    SimBoard board, {
    required CaptureAiMove safeMove,
    required CaptureAiMove? tacticalSearchMove,
    Map<int, bool>? targetWinCache,
  }) {
    if (tacticalSearchMove == null) return false;
    if (!_isAdvancedTacticalSearchMove(board, tacticalSearchMove)) {
      return false;
    }

    final safeAnalysis = board.analyzeMove(
      safeMove.position.row,
      safeMove.position.col,
    );
    final tacticalAnalysis = board.analyzeMove(
      tacticalSearchMove.position.row,
      tacticalSearchMove.position.col,
    );
    if (!safeAnalysis.isLegal || !tacticalAnalysis.isLegal) return false;

    final player = board.currentPlayer;
    final safeCaptureDelta = _captureDeltaFor(safeAnalysis, player);
    final tacticalCaptureDelta = _captureDeltaFor(tacticalAnalysis, player);
    final tacticalReachesTarget =
        _capturesFor(board, player) + tacticalCaptureDelta >=
            board.captureTarget;
    if (tacticalReachesTarget || tacticalCaptureDelta > 0) return false;
    if (safeCaptureDelta <= 0 && safeAnalysis.ownRescuedStones <= 0) {
      return false;
    }

    final safeAllowsTargetWin = targetWinCache == null
        ? _allowsOpponentTargetWin(board, safeMove)
        : _allowsOpponentTargetWinCached(board, safeMove, targetWinCache);
    if (safeAllowsTargetWin) return false;

    final tacticalAllowsTargetWin = targetWinCache == null
        ? _allowsOpponentTargetWin(board, tacticalSearchMove)
        : _allowsOpponentTargetWinCached(
            board,
            tacticalSearchMove,
            targetWinCache,
          );
    if (tacticalAllowsTargetWin) return true;

    final safeIsMoreConcrete = safeCaptureDelta > tacticalCaptureDelta ||
        safeAnalysis.ownRescuedStones > tacticalAnalysis.ownRescuedStones;
    if (!safeIsMoreConcrete) return false;

    return tacticalSearchMove.score <
        safeMove.score + _advancedTacticalDecisionBonus * 0.75;
  }

  CaptureAiMove? _chooseAdvancedTargetSearchMove(
    SimBoard board, {
    required CaptureAiMove? heuristicMove,
  }) {
    if (_config.difficulty != DifficultyLevel.advanced || board.isTerminal) {
      return null;
    }
    if (!_hasAdvancedTacticalSearchContext(board)) return null;

    final rootPlayer = board.currentPlayer;
    final stats = _AdvancedTacticalSearchStats();
    final rankedRoots = <_AdvancedTacticalRootMove>[];
    final generatedMoves = _generateFullBoardLegalMoves(board);
    if (generatedMoves.isEmpty) return null;
    final scoredMoves = [
      for (final move in generatedMoves)
        (
          move: move,
          tacticalScore: _advancedTacticalMoveScore(
            board,
            move.analysis,
            rootPlayer: rootPlayer,
          ),
        ),
    ]..sort((a, b) {
        final byScore = b.tacticalScore.compareTo(a.tacticalScore);
        if (byScore != 0) return byScore;
        return a.move.moveIndex.compareTo(b.move.moveIndex);
      });
    final legalMoves = board.size > 9
        ? scoredMoves.take(40).toList(growable: false)
        : scoredMoves;
    final searchDepth = board.size > 9 ? 0 : _advancedTacticalDepth - 1;

    for (final entry in legalMoves) {
      final move = entry.move;
      final next = SimBoard.copy(board);
      if (!next.applyMove(
          move.moveIndex ~/ board.size, move.moveIndex % board.size)) {
        continue;
      }
      final tacticalScore = entry.tacticalScore;
      final searchScore = next.winner == rootPlayer
          ? 100000.0
          : searchDepth <= 0
              ? _advancedTacticalPositionScore(next, rootPlayer)
              : _advancedTacticalAlphaBeta(
                  next,
                  rootPlayer: rootPlayer,
                  depth: searchDepth,
                  alpha: -double.infinity,
                  beta: double.infinity,
                  stats: stats,
                );
      final combinedScore = searchScore +
          tacticalScore * 0.03 +
          _advancedRootTieBreakScore(board, move.moveIndex, move.analysis);
      rankedRoots.add(_AdvancedTacticalRootMove(
        moveIndex: move.moveIndex,
        analysis: move.analysis,
        score: combinedScore,
        tacticalScore: tacticalScore,
      ));
    }
    if (rankedRoots.isEmpty) return null;

    rankedRoots.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.moveIndex.compareTo(b.moveIndex);
    });

    final best = rankedRoots.first;
    final secondScore =
        rankedRoots.length > 1 ? rankedRoots[1].score : -double.infinity;
    final confidenceGap = best.score - secondScore;
    final reachesTarget = _capturesFor(board, rootPlayer) +
            _captureDeltaFor(best.analysis, rootPlayer) >=
        board.captureTarget;
    final concreteTactic = reachesTarget ||
        _captureDeltaFor(best.analysis, rootPlayer) > 0 ||
        best.analysis.opponentAtariStones > 0 ||
        best.analysis.ownRescuedStones > 0;
    final beatsHeuristic = heuristicMove == null ||
        best.score >= heuristicMove.score + 35.0 ||
        confidenceGap >= 55.0;
    if (!reachesTarget &&
        (!concreteTactic || !beatsHeuristic) &&
        confidenceGap < 90.0) {
      return null;
    }
    return CaptureAiMove(
      position: BoardPosition(
        best.moveIndex ~/ board.size,
        best.moveIndex % board.size,
      ),
      score: best.score + _advancedTacticalDecisionBonus,
    );
  }

  bool _hasAdvancedTacticalSearchContext(SimBoard board) {
    final stoneCount =
        board.cells.where((cell) => cell != SimBoard.empty).length;
    if (stoneCount < 4) return false;
    if (board.capturedByBlack > 0 || board.capturedByWhite > 0) return true;

    for (final move in _generateFullBoardLegalMoves(board)) {
      final ownCaptureDelta = _captureDeltaFor(
        move.analysis,
        board.currentPlayer,
      );
      if (ownCaptureDelta > 0 ||
          move.analysis.opponentAtariStones > 0 ||
          move.analysis.ownRescuedStones > 0) {
        return true;
      }
    }
    return false;
  }

  double _advancedTacticalAlphaBeta(
    SimBoard board, {
    required int rootPlayer,
    required int depth,
    required double alpha,
    required double beta,
    required _AdvancedTacticalSearchStats stats,
  }) {
    stats.nodes++;
    if (stats.nodes >= _advancedTacticalMaxNodes) {
      stats.truncated = true;
      return _advancedTacticalPositionScore(board, rootPlayer);
    }
    if (board.winner == rootPlayer) return 100000.0;
    if (board.winner != 0) return -100000.0;
    if (depth <= 0) return _advancedTacticalPositionScore(board, rootPlayer);

    final candidates = _rankAdvancedTacticalCandidates(
      board,
      rootPlayer: rootPlayer,
      limit: _advancedTacticalHorizon,
    );
    if (candidates.isEmpty) {
      return _advancedTacticalPositionScore(board, rootPlayer);
    }

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
          _advancedTacticalAlphaBeta(
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
      return best.isFinite
          ? best
          : _advancedTacticalPositionScore(board, rootPlayer);
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
        _advancedTacticalAlphaBeta(
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
    return worst.isFinite
        ? worst
        : _advancedTacticalPositionScore(board, rootPlayer);
  }

  List<int> _rankAdvancedTacticalCandidates(
    SimBoard board, {
    required int rootPlayer,
    required int limit,
  }) {
    final scored = <({int moveIndex, double score})>[];
    for (final move in _generateFullBoardLegalMoves(board)) {
      scored.add((
        moveIndex: move.moveIndex,
        score: _advancedTacticalMoveScore(
          board,
          move.analysis,
          rootPlayer: rootPlayer,
        ),
      ));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.moveIndex.compareTo(b.moveIndex);
    });
    return scored.take(limit).map((entry) => entry.moveIndex).toList();
  }

  List<_AdvancedTacticalLegalMove> _generateFullBoardLegalMoves(
    SimBoard board,
  ) {
    final moves = <_AdvancedTacticalLegalMove>[];
    final candidateIndexes = board.getLegalMoves()..sort();
    for (final moveIndex in candidateIndexes) {
      if (board.cells[moveIndex] != SimBoard.empty) continue;
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final simulated = SimBoard.copy(board);
      if (!simulated.applyMove(row, col)) continue;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      moves.add(_AdvancedTacticalLegalMove(moveIndex, analysis));
    }
    return moves;
  }

  double _advancedTacticalMoveScore(
    SimBoard board,
    SimMoveAnalysis analysis, {
    required int rootPlayer,
  }) {
    final mover = board.currentPlayer;
    final moverCaptures = _capturesFor(board, mover);
    final captureDelta = _captureDeltaFor(analysis, mover);
    final capturesAfter = moverCaptures + captureDelta;
    final reachesTarget = capturesAfter >= board.captureTarget;
    final moverRemainingBefore =
        math.max(1, board.captureTarget - moverCaptures);
    final selfAtariPenalty = captureDelta > 0
        ? 35.0
        : analysis.opponentAtariStones > 0
            ? 80.0
            : 170.0;
    final rootUrgency = _rootTargetUrgencyScore(
      board,
      rootPlayer,
      analysis,
    );

    return (reachesTarget ? 70000.0 : 0.0) +
        captureDelta * (2400.0 + 400.0 / moverRemainingBefore) +
        analysis.opponentAtariStones * 150.0 +
        analysis.ownRescuedStones * 260.0 +
        analysis.adjacentOpponentStones * 35.0 +
        analysis.libertiesAfterMove * 12.0 +
        analysis.centerProximityScore * 3.0 +
        rootUrgency -
        analysis.ownAtariStones * selfAtariPenalty;
  }

  double _rootTargetUrgencyScore(
    SimBoard board,
    int rootPlayer,
    SimMoveAnalysis analysis,
  ) {
    final rootCaptures = _capturesFor(board, rootPlayer);
    final opponentCaptures = _capturesFor(board, _opponentOf(rootPlayer));
    final rootDelta = _captureDeltaFor(analysis, rootPlayer);
    final opponentDelta = rootPlayer == SimBoard.black
        ? analysis.whiteCaptureDelta
        : analysis.blackCaptureDelta;

    if (board.currentPlayer == rootPlayer) {
      if (rootCaptures + rootDelta >= board.captureTarget) return 90000.0;
      if (opponentCaptures >= board.captureTarget - 1) {
        return analysis.ownRescuedStones * 420.0 +
            analysis.opponentAtariStones * 120.0 +
            rootDelta * 360.0;
      }
    } else if (opponentCaptures + opponentDelta >= board.captureTarget) {
      return 90000.0;
    }
    return 0.0;
  }

  double _advancedTacticalPositionScore(SimBoard board, int rootPlayer) {
    if (board.winner == rootPlayer) return 100000.0;
    if (board.winner != 0) return -100000.0;

    final opponent = _opponentOf(rootPlayer);
    final rootCanReachTarget = _playerCanReachCaptureTarget(board, rootPlayer);
    final opponentCanReachTarget = _playerCanReachCaptureTarget(
      board,
      opponent,
    );
    if (rootCanReachTarget && !opponentCanReachTarget) {
      return board.currentPlayer == rootPlayer ? 85000.0 : 52000.0;
    }
    if (opponentCanReachTarget && !rootCanReachTarget) {
      return board.currentPlayer == opponent ? -85000.0 : -52000.0;
    }

    final rootCaptures = _capturesFor(board, rootPlayer);
    final opponentCaptures = _capturesFor(board, opponent);
    final rootRemaining =
        math.max(0, board.captureTarget - rootCaptures).toDouble();
    final opponentRemaining =
        math.max(0, board.captureTarget - opponentCaptures).toDouble();
    final rootBestImmediateCapture = _bestImmediateCaptureDeltaForPlayer(
      board,
      rootPlayer,
    );
    final opponentBestImmediateCapture = _bestImmediateCaptureDeltaForPlayer(
      board,
      opponent,
    );
    final raceScore = (opponentRemaining - rootRemaining) * 950.0 +
        (rootCaptures - opponentCaptures) * 260.0;
    final targetThreat = rootRemaining <= 1 ? 650.0 : 0.0;
    final targetRisk = opponentRemaining <= 1 ? -850.0 : 0.0;
    final immediateCapturePressure =
        rootBestImmediateCapture * 720.0 - opponentBestImmediateCapture * 980.0;
    return raceScore + targetThreat + targetRisk + immediateCapturePressure;
  }

  double _advancedRootTieBreakScore(
    SimBoard board,
    int moveIndex,
    SimMoveAnalysis analysis,
  ) {
    return _quietTacticalGeometryScore(board, moveIndex, analysis) +
        _stableMoveTieBreaker(moveIndex) -
        _largeBoardEdgeRiskPenalty(board, moveIndex, analysis) * 0.35;
  }

  double _stableMoveTieBreaker(int moveIndex) => -moveIndex / 100000.0;

  double get _mctsDecisionBonus {
    return switch (_config.difficulty) {
      DifficultyLevel.beginner => 0,
      DifficultyLevel.intermediate => 0,
      DifficultyLevel.advanced => 12.0,
    };
  }

  CaptureAiMove? _chooseAdvancedOpeningBaselineMove(SimBoard board) {
    if (_config.difficulty != DifficultyLevel.advanced) return null;
    if (board.capturedByBlack > 0 || board.capturedByWhite > 0) return null;
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
            ownCaptureDelta * 14 +
            analysis.ownRescuedStones * 7,
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
    if (next.winner == currentPlayer) return 20000;
    if (next.winner != 0) return -20000;
    return _minimaxScore(next, currentPlayer, 2);
  }

  List<CaptureAiMove> _rankLookaheadMoves(
    SimBoard board, {
    required int limit,
  }) {
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

    final moves = <CaptureAiMove>[];
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
      moves.add(move);
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

  List<CaptureAiMove> _rankQuietTacticalMoves(
    SimBoard board, {
    int limit = 4,
  }) {
    final scored = <({int moveIndex, double score})>[];
    final currentPlayer = board.currentPlayer;
    final quietContextBonus =
        board.capturedByBlack > 0 || board.capturedByWhite > 0 ? 45.0 : 40.0;

    for (final moveIndex in board.getLegalMoves()) {
      final row = moveIndex ~/ board.size;
      final col = moveIndex % board.size;
      final analysis = board.analyzeMove(row, col);
      if (!analysis.isLegal) continue;
      if (!_isQuietTacticalAnalysis(analysis, currentPlayer)) continue;

      final score = analysis.libertiesAfterMove * _profile.libertyWeight +
          analysis.centerProximityScore * _profile.centerWeight +
          _targetPlyScore(board, analysis) +
          _quietTacticalGeometryScore(board, moveIndex, analysis) +
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

  List<CaptureAiMove> _rankForcingCounterAtariMoves(
    SimBoard board, {
    int limit = 3,
  }) {
    final scored = <({int moveIndex, double score})>[];
    final player = board.currentPlayer;

    for (final move in _generateFullBoardLegalMoves(board)) {
      final analysis = move.analysis;
      if (_captureDeltaFor(analysis, player) > 0) continue;
      if (analysis.opponentAtariStones <= 0 || analysis.ownAtariStones <= 0) {
        continue;
      }
      if (_adjacentOwnStoneCount(board, move.moveIndex) > 0) continue;

      final score = 720.0 +
          analysis.opponentAtariStones * 55.0 +
          analysis.adjacentOpponentStones * 12.0 -
          analysis.ownAtariStones * 26.0 -
          analysis.libertiesAfterMove * 8.0 +
          analysis.centerProximityScore * 1.0 +
          _advancedRootTieBreakScore(board, move.moveIndex, analysis);
      scored.add((moveIndex: move.moveIndex, score: score));
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

  double _quietTacticalGeometryScore(
    SimBoard board,
    int moveIndex,
    SimMoveAnalysis analysis,
  ) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final player = board.currentPlayer;
    final opponent = _opponentOf(player);
    var adjacentOwn = 0;
    var adjacentOpponent = 0;
    var nearOwn = 0;
    var nearOpponent = 0;

    for (var other = 0; other < board.cells.length; other++) {
      final color = board.cells[other];
      if (color == SimBoard.empty) continue;
      final otherRow = other ~/ board.size;
      final otherCol = other % board.size;
      final distance = (row - otherRow).abs() + (col - otherCol).abs();
      if (distance == 0 || distance > 2) continue;
      if (color == player) {
        nearOwn++;
        if (distance == 1) adjacentOwn++;
      } else if (color == opponent) {
        nearOpponent++;
        if (distance == 1) adjacentOpponent++;
      }
    }

    final localCrowding = math.max(0, nearOwn + nearOpponent - 6);
    final ownCrowding = math.max(0, nearOwn - 4);
    final opponentCaptures = _capturesFor(board, opponent);
    final targetShortagePressure = opponentCaptures >= board.captureTarget - 2;
    final adjacentOwnCrowding = targetShortagePressure
        ? math.max(0, adjacentOwn - 1)
        : math.max(0, adjacentOwn - 2);
    final opponentShape =
        math.min(nearOpponent, 3) * 0.35 + math.min(adjacentOpponent, 2) * 0.6;

    return opponentShape -
        localCrowding * 1.1 -
        ownCrowding * 0.8 -
        adjacentOwnCrowding * (targetShortagePressure ? 1.8 : 1.4);
  }

  int _adjacentOwnStoneCount(SimBoard board, int moveIndex) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    var count = 0;
    for (final delta in const [
      (-1, 0),
      (1, 0),
      (0, -1),
      (0, 1),
    ]) {
      final nextRow = row + delta.$1;
      final nextCol = col + delta.$2;
      if (nextRow < 0 ||
          nextRow >= board.size ||
          nextCol < 0 ||
          nextCol >= board.size) {
        continue;
      }
      if (board.cells[board.idx(nextRow, nextCol)] == board.currentPlayer) {
        count++;
      }
    }
    return count;
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
        _targetPlyScore(board, analysis) +
        _sparseBoardInitiativeScore(board, analysis) -
        _largeBoardEdgeRiskPenalty(board, moveIndex, analysis);
  }

  double _scoreRolloutMove(
    SimBoard board,
    int moveIndex,
    SimMoveAnalysis analysis,
  ) {
    final score = _scoreWithProfile(board, analysis, _profile) +
        _targetRolloutPlyScore(board, analysis) +
        _sparseBoardInitiativeScore(board, analysis) -
        _largeBoardEdgeRiskPenalty(board, moveIndex, analysis) * 0.6;
    return score.clamp(-1800.0, 1800.0);
  }

  double _sparseBoardInitiativeScore(
    SimBoard board,
    SimMoveAnalysis analysis,
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

double _largeBoardEdgeRiskPenalty(
  SimBoard board,
  int moveIndex,
  SimMoveAnalysis analysis,
) {
  if (board.size <= 9) return 0;
  if (_captureDeltaFor(analysis, board.currentPlayer) > 0 ||
      analysis.ownRescuedStones > 0) {
    return 0;
  }
  final row = moveIndex ~/ board.size;
  final col = moveIndex % board.size;
  final edgeDistance = math.min(
    math.min(row, col),
    math.min(board.size - 1 - row, board.size - 1 - col),
  );
  final edgeBand = math.max(0, 3 - edgeDistance);
  return edgeBand * 95.0 + analysis.ownAtariStones * 80.0;
}

bool _hasTwistOpeningAnchors(SimBoard board) {
  if (board.size < 7) return false;
  final center = board.size ~/ 2;
  const arm = 3;
  final cardinalAnchors = [
    board.idx(center - arm, center),
    board.idx(center + arm, center),
    board.idx(center, center - arm),
    board.idx(center, center + arm),
  ];
  final diagonalAnchors = [
    board.idx(center - arm, center - arm),
    board.idx(center - arm, center + arm),
    board.idx(center + arm, center - arm),
    board.idx(center + arm, center + arm),
  ];
  return _anchorSetIsOccupied(board, cardinalAnchors) ||
      _anchorSetIsOccupied(board, diagonalAnchors);
}

bool _anchorSetIsOccupied(SimBoard board, List<int> anchors) {
  var black = 0;
  var white = 0;
  for (final index in anchors) {
    if (index < 0 || index >= board.cells.length) return false;
    switch (board.cells[index]) {
      case SimBoard.black:
        black++;
      case SimBoard.white:
        white++;
    }
  }
  return black >= 2 && white >= 2;
}

class _AdvancedTacticalLegalMove {
  const _AdvancedTacticalLegalMove(this.moveIndex, this.analysis);

  final int moveIndex;
  final SimMoveAnalysis analysis;
}

class _AdvancedTacticalRootMove {
  const _AdvancedTacticalRootMove({
    required this.moveIndex,
    required this.analysis,
    required this.score,
    required this.tacticalScore,
  });

  final int moveIndex;
  final SimMoveAnalysis analysis;
  final double score;
  final double tacticalScore;
}

class _AdvancedTacticalSearchStats {
  int nodes = 0;
  int cutoffs = 0;
  bool truncated = false;
}

class _SpacingCandidate {
  const _SpacingCandidate(this.moveIndex, this.score);

  final int moveIndex;
  final double score;
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
          immediateCaptureWeight: 6.975,
          opponentAtariWeight: 3.8,
          ownRescueWeight: 2.025,
          selfAtariPenalty: 5.85,
          centerWeight: 0.625,
          contactWeight: 2.05,
          libertyWeight: 1.5,
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
    return _scoreWithProfile(board, analysis, _profile) +
        _targetPlyScore(board, analysis);
  }

  double _rolloutScore(SimBoard board, SimMoveAnalysis analysis) {
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
      final score = _rolloutScore(board, analysis);
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

double _targetRolloutPlyScore(
  SimBoard board,
  SimMoveAnalysis analysis,
) {
  return _targetPlyScore(board, analysis).clamp(-600.0, 1200.0);
}

bool _allowsOpponentTargetWin(SimBoard board, CaptureAiMove move) {
  final currentPlayer = board.currentPlayer;
  final next = SimBoard.copy(board);
  if (!next.applyMove(move.position.row, move.position.col)) return true;
  if (_playerHasReachedCaptureTarget(next, currentPlayer)) return false;
  return _currentPlayerCanReachCaptureTarget(next);
}

bool _currentPlayerCanReachCaptureTarget(SimBoard board) {
  return _playerCanReachCaptureTarget(board, board.currentPlayer);
}

bool _playerCanReachCaptureTarget(SimBoard board, int player) {
  if (_playerHasReachedCaptureTarget(board, player)) return true;
  final target = board.captureTarget;
  final capturesBefore = _capturesFor(board, player);
  final remainingCaptures = target - capturesBefore;
  if (remainingCaptures <= 0) return true;

  return _bestImmediateCaptureDeltaForPlayer(
        board,
        player,
        stopAt: remainingCaptures,
      ) >=
      remainingCaptures;
}

int _bestImmediateCaptureDeltaForPlayer(
  SimBoard board,
  int player, {
  int? stopAt,
}) {
  final probe = SimBoard.copy(board)..currentPlayer = player;
  var best = 0;
  final localMoves = probe.getLegalMoves()..sort();
  for (final moveIndex in localMoves) {
    if (probe.cells[moveIndex] != SimBoard.empty) continue;
    final row = moveIndex ~/ probe.size;
    final col = moveIndex % probe.size;
    final analysis = probe.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    best = math.max(best, _captureDeltaFor(analysis, player));
    if (stopAt != null && best >= stopAt) return best;
  }
  return best;
}

bool _playerHasReachedCaptureTarget(SimBoard board, int player) {
  return _capturesFor(board, player) >= board.captureTarget;
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

int _capturesFor(SimBoard board, int player) {
  return player == SimBoard.black
      ? board.capturedByBlack
      : board.capturedByWhite;
}

int _captureDeltaFor(SimMoveAnalysis analysis, int player) {
  return player == SimBoard.black
      ? analysis.blackCaptureDelta
      : analysis.whiteCaptureDelta;
}

int _opponentOf(int player) {
  return player == SimBoard.black ? SimBoard.white : SimBoard.black;
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
  final forcingSelfAtariRelief =
      analysis.ownAtariStones > 0 && analysis.opponentAtariStones > 0
          ? math.min(analysis.ownAtariStones, analysis.opponentAtariStones) *
              profile.selfAtariPenalty *
              0.85
          : 0.0;

  return ownCaptured * profile.immediateCaptureWeight +
      analysis.opponentAtariStones * profile.opponentAtariWeight +
      analysis.ownRescuedStones * profile.ownRescueWeight +
      analysis.adjacentOpponentStones * profile.contactWeight +
      analysis.libertiesAfterMove * profile.libertyWeight +
      analysis.centerProximityScore * profile.centerWeight -
      analysis.ownAtariStones * profile.selfAtariPenalty +
      forcingSelfAtariRelief;
}
