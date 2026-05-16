import 'dart:math' as math;

import '../models/board_position.dart';
import 'difficulty_level.dart';
import 'game_mode.dart';
import 'mcts_engine.dart';

const BoardPosition territoryPassMove = BoardPosition(-1, -1);

/// Territory-mode move picker.
///
/// The engine uses a lightweight weighted heuristic first (area edge, local
/// influence, rescue pressure, own-atari penalty), then adds a few shallow
/// stochastic rollouts to separate moves with similar surface scores. The
/// constants are intentionally tuned to prefer stable area growth over
/// capture-race greed so the territory player punishes the existing capture AI
/// families under territory rules without needing a full neural network path.
///
/// In practice the weights are ordered by importance as:
/// 1) area delta, 2) influence, 3) rescue / self-danger, 4) local tactical
/// pressure, 5) soft shape bias. They were tuned together so a move that gains
/// secure area still beats a flashy capture-go-style move unless the tactical
/// swing is large enough to matter for the final score.
class TerritoryAiEngine {
  static const int _baseSeed = 0x71A0;
  static const int _difficultySeedStride = 977;
  static const double _bestMoveGapThreshold = 0.35;
  static const double _secondaryPickChance = 0.08;
  static const double _areaWeight = 12.0;
  static const double _influenceWeight = 4.6;
  static const double _rescueWeight = 5.0;
  static const double _opponentAtariWeight = 2.4;
  static const double _libertyWeight = 0.8;
  static const double _ownAtariPenalty = 5.2;

  TerritoryAiEngine({
    required this.difficulty,
    int? seed,
  }) : _rng = math.Random(
            seed ?? _baseSeed + difficulty.index * _difficultySeedStride);

  final DifficultyLevel difficulty;
  final math.Random _rng;

  static const _passIndex = -1;

  BoardPosition chooseMove(
    SimBoard board, {
    List<double>? policyPrior,
  }) {
    if (board.gameMode != GameMode.territory) {
      throw ArgumentError('TerritoryAiEngine requires territory mode.');
    }

    final config = _TerritoryAiConfig.forDifficulty(difficulty);
    final rootPlayer = board.currentPlayer;
    final legalMoves = board.getLegalMoves();
    final candidates = <_TerritoryCandidate>[
      for (final moveIndex in legalMoves)
        _scoreCandidate(
          board,
          moveIndex: moveIndex,
          rootPlayer: rootPlayer,
          config: config,
          policyPrior: policyPrior,
        ),
    ]..removeWhere((candidate) => candidate.score.isNaN);

    if (_shouldConsiderPass(board, config: config)) {
      candidates.add(
        _TerritoryCandidate(
          moveIndex: _passIndex,
          score: _scorePass(board, rootPlayer),
        ),
      );
    }

    if (candidates.isEmpty) return territoryPassMove;

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.moveIndex.compareTo(b.moveIndex);
    });

    final shortlisted = candidates.take(config.candidateLimit).toList();
    var best = shortlisted.first;
    for (final candidate in shortlisted.skip(1)) {
      final gap = best.score - candidate.score;
      if (gap <= _bestMoveGapThreshold &&
          _rng.nextDouble() < _secondaryPickChance) {
        best = candidate;
      }
    }

    if (best.moveIndex == _passIndex) return territoryPassMove;
    return BoardPosition(
        best.moveIndex ~/ board.size, best.moveIndex % board.size);
  }

  _TerritoryCandidate _scoreCandidate(
    SimBoard board, {
    required int moveIndex,
    required int rootPlayer,
    required _TerritoryAiConfig config,
    List<double>? policyPrior,
  }) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) {
      return const _TerritoryCandidate(
          moveIndex: _passIndex, score: double.nan);
    }

    final next = SimBoard.copy(board);
    if (!next.applyMove(row, col)) {
      return const _TerritoryCandidate(
          moveIndex: _passIndex, score: double.nan);
    }

    var score = 0.0;
    score += next.estimateAreaDifference(forPlayer: rootPlayer) * _areaWeight;
    score += next.estimateTerritoryInfluence(forPlayer: rootPlayer) *
        _influenceWeight;
    score += analysis.ownRescuedStones * _rescueWeight;
    score += analysis.opponentAtariStones * _opponentAtariWeight;
    score += analysis.libertiesAfterMove * _libertyWeight;
    score -= analysis.ownAtariStones * _ownAtariPenalty;
    score += _shapeBonus(next, moveIndex);
    score += _policyBonus(moveIndex, policyPrior);

    if (next.isTerminal) {
      final winner = next.winner;
      if (winner == rootPlayer) {
        score += 10000;
      } else if (winner != 0) {
        score -= 10000;
      }
    }

    for (var i = 0; i < config.playouts; i++) {
      final rollout = SimBoard.copy(next);
      score += _rolloutScore(
        rollout,
        rootPlayer: rootPlayer,
        depthLimit: config.rolloutDepth,
      );
    }

    return _TerritoryCandidate(moveIndex: moveIndex, score: score);
  }

  double _scorePass(SimBoard board, int rootPlayer) {
    final diff = board.estimateAreaDifference(forPlayer: rootPlayer).toDouble();
    final influence = board.estimateTerritoryInfluence(forPlayer: rootPlayer);
    final unresolved = board.getLegalMoves().length.toDouble();
    var score = diff * 15.0 + influence * 3.5 - unresolved * 0.15;
    if (board.consecutivePasses == 1) {
      final done = SimBoard.copy(board)..applyPass();
      final winner = done.winner;
      if (winner == rootPlayer) {
        score += 5000;
      } else if (winner != 0) {
        score -= 5000;
      }
    }
    return score;
  }

  bool _shouldConsiderPass(
    SimBoard board, {
    required _TerritoryAiConfig config,
  }) {
    if (board.consecutivePasses > 0) return true;
    final legalCount = board.getLegalMoves().length;
    return legalCount <= config.passCandidateThreshold ||
        board.estimateTerritoryInfluence(forPlayer: board.currentPlayer).abs() >
            board.size * 2.8;
  }

  double _rolloutScore(
    SimBoard board, {
    required int rootPlayer,
    required int depthLimit,
  }) {
    var depth = 0;
    while (!board.isTerminal && depth < depthLimit) {
      final moveIndex = _chooseRolloutMove(board);
      if (moveIndex == _passIndex) {
        board.applyPass();
      } else {
        board.applyMove(moveIndex ~/ board.size, moveIndex % board.size);
      }
      depth++;
    }

    final diff = board.estimateAreaDifference(forPlayer: rootPlayer).toDouble();
    final influence = board.estimateTerritoryInfluence(forPlayer: rootPlayer);
    if (board.isTerminal) {
      final winner = board.winner;
      if (winner == rootPlayer) return 1800 + diff * 8.0;
      if (winner != 0) return -1800 + diff * 8.0;
      return diff * 8.0;
    }
    return diff * 6.0 + influence * 2.0;
  }

  int _chooseRolloutMove(SimBoard board) {
    final legalMoves = board.getLegalMoves();
    if (legalMoves.isEmpty) return _passIndex;
    final rootPlayer = board.currentPlayer;
    if (_shouldPassRollout(board, rootPlayer)) return _passIndex;

    final scored = <_TerritoryCandidate>[
      for (final moveIndex in legalMoves)
        _TerritoryCandidate(
          moveIndex: moveIndex,
          score: _fastRolloutMoveScore(board, moveIndex, rootPlayer),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final top = scored.take(5).toList();
    if (top.isEmpty) return legalMoves[_rng.nextInt(legalMoves.length)];
    final totalWeight = top.fold<double>(
      0,
      (sum, entry) => sum + math.max(0.01, entry.score + 20.0),
    );
    var ticket = _rng.nextDouble() * totalWeight;
    for (final entry in top) {
      ticket -= math.max(0.01, entry.score + 20.0);
      if (ticket <= 0) return entry.moveIndex;
    }
    return top.first.moveIndex;
  }

  bool _shouldPassRollout(SimBoard board, int rootPlayer) {
    if (board.consecutivePasses > 0) return true;
    if (board.getLegalMoves().length > math.max(6, board.size ~/ 2)) {
      return false;
    }
    return board.estimateAreaDifference(forPlayer: rootPlayer) >= 0;
  }

  double _fastRolloutMoveScore(SimBoard board, int moveIndex, int rootPlayer) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) return -9999;
    final next = SimBoard.copy(board);
    if (!next.applyMove(row, col)) return -9999;
    return next.estimateAreaDifference(forPlayer: rootPlayer) * 3.4 +
        next.estimateTerritoryInfluence(forPlayer: rootPlayer) * 1.8 +
        analysis.ownRescuedStones * 2.4 -
        analysis.ownAtariStones * 2.8 +
        _shapeBonus(next, moveIndex);
  }

  double _shapeBonus(SimBoard board, int moveIndex) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final center = board.size ~/ 2;
    final distance = (row - center).abs() + (col - center).abs();
    final centerBias = math.max(0, board.size - distance) * 0.12;
    final edgePenalty =
        (row == 0 || col == 0 || row == board.size - 1 || col == board.size - 1)
            ? -0.4
            : 0.0;
    return centerBias + edgePenalty;
  }

  double _policyBonus(int moveIndex, List<double>? policyPrior) {
    if (policyPrior == null ||
        moveIndex < 0 ||
        moveIndex >= policyPrior.length) {
      return 0;
    }
    return policyPrior[moveIndex] * 9.0;
  }
}

class _TerritoryAiConfig {
  const _TerritoryAiConfig({
    required this.candidateLimit,
    required this.playouts,
    required this.rolloutDepth,
    required this.passCandidateThreshold,
  });

  final int candidateLimit;
  final int playouts;
  final int rolloutDepth;
  final int passCandidateThreshold;

  factory _TerritoryAiConfig.forDifficulty(DifficultyLevel difficulty) {
    return switch (difficulty) {
      DifficultyLevel.beginner => const _TerritoryAiConfig(
          candidateLimit: 6,
          playouts: 2,
          rolloutDepth: 10,
          passCandidateThreshold: 6,
        ),
      DifficultyLevel.intermediate => const _TerritoryAiConfig(
          candidateLimit: 8,
          playouts: 5,
          rolloutDepth: 14,
          passCandidateThreshold: 10,
        ),
      DifficultyLevel.advanced => const _TerritoryAiConfig(
          candidateLimit: 10,
          playouts: 9,
          rolloutDepth: 18,
          passCandidateThreshold: 14,
        ),
    };
  }
}

class _TerritoryCandidate {
  const _TerritoryCandidate({
    required this.moveIndex,
    required this.score,
  });

  final int moveIndex;
  final double score;
}
