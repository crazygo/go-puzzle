import 'dart:math' as math;

import '../models/board_position.dart';
import 'capture_ai.dart';
import 'mcts_engine.dart';

enum CaptureAiTrialOpening {
  empty,
  twistCrossA,
  twistCrossB,
  twistCrossC,
  twistCrossD,
}

enum CaptureAiScriptedTactic {
  captureFirst,
  atariFirst,
  rescueFirst,
  counterAtari,
  selfAtariBait,
  edgeClamp,
  ladderChase,
  netContain,
  snapback,
  libertyShortage,
  connectAndDie,
  sacrificeRace,
  koFight,
  throwIn,
}

enum CaptureAiTrialSide {
  black,
  white,
}

enum CaptureAiTrialWinner {
  ai,
  scripted,
  draw,
}

class CaptureAiScriptedTrial {
  const CaptureAiScriptedTrial({
    required this.id,
    required this.opening,
    required this.tactic,
    this.boardSize = 9,
    this.captureTarget = 5,
    this.aiSide = CaptureAiTrialSide.white,
    this.maxMoves = 180,
  });

  final String id;
  final CaptureAiTrialOpening opening;
  final CaptureAiScriptedTactic tactic;
  final int boardSize;
  final int captureTarget;
  final CaptureAiTrialSide aiSide;
  final int maxMoves;

  SimBoard buildInitialBoard() {
    final board = SimBoard(boardSize, captureTarget: captureTarget);
    if (opening == CaptureAiTrialOpening.empty) {
      board.currentPlayer = SimBoard.black;
      return board;
    }

    const arm = 3;
    if (boardSize < arm * 2 + 1) {
      throw ArgumentError(
        'Board size $boardSize is too small for $opening.',
      );
    }
    final center = boardSize ~/ 2;
    final variant = opening.index - CaptureAiTrialOpening.twistCrossA.index;
    final points = switch (variant) {
      0 => (
          black: [(center - arm, center), (center + arm, center)],
          white: [(center, center - arm), (center, center + arm)],
        ),
      1 => (
          black: [(center, center - arm), (center, center + arm)],
          white: [(center - arm, center), (center + arm, center)],
        ),
      2 => (
          black: [(center - arm, center - arm), (center + arm, center + arm)],
          white: [(center - arm, center + arm), (center + arm, center - arm)],
        ),
      _ => (
          black: [(center - arm, center + arm), (center + arm, center - arm)],
          white: [(center - arm, center - arm), (center + arm, center + arm)],
        ),
    };

    for (final (row, col) in points.black) {
      board.cells[board.idx(row, col)] = SimBoard.black;
    }
    for (final (row, col) in points.white) {
      board.cells[board.idx(row, col)] = SimBoard.white;
    }
    board.currentPlayer = SimBoard.black;
    return board;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'opening': opening.name,
      'tactic': tactic.name,
      'boardSize': boardSize,
      'captureTarget': captureTarget,
      'aiSide': aiSide.name,
      'maxMoves': maxMoves,
    };
  }
}

class CaptureAiScriptedTrialCatalog {
  const CaptureAiScriptedTrialCatalog._();

  static List<CaptureAiScriptedTrial> defaults({
    int boardSize = 9,
    int captureTarget = 5,
    CaptureAiTrialSide aiSide = CaptureAiTrialSide.white,
    int maxMoves = 180,
  }) {
    return [
      for (final opening in CaptureAiTrialOpening.values)
        for (final tactic in CaptureAiScriptedTactic.values)
          CaptureAiScriptedTrial(
            id: '${opening.name}_${tactic.name}_b$boardSize',
            opening: opening,
            tactic: tactic,
            boardSize: boardSize,
            captureTarget: captureTarget,
            aiSide: aiSide,
            maxMoves: maxMoves,
          ),
    ];
  }
}

class CaptureAiScriptedTrialRunner {
  const CaptureAiScriptedTrialRunner({
    required this.aiConfig,
  });

  final CaptureAiRobotConfig aiConfig;

  CaptureAiScriptedTrialResult run(
    CaptureAiScriptedTrial trial, {
    Duration? maxAiMoveDuration,
  }) {
    final board = trial.buildInitialBoard();
    final aiAgent = CaptureAiRegistry.createFromConfig(aiConfig);
    final scriptedAgent = _ScriptedTacticAgent(trial.tactic);
    final aiPlayer = trial.aiSide == CaptureAiTrialSide.black
        ? SimBoard.black
        : SimBoard.white;
    final moves = <CaptureAiTrialMoveRecord>[];
    var slowAiMovesOverLimit = 0;
    var endReason = CaptureAiMatchEndReason.maxMovesReached;

    while (!board.isTerminal && moves.length < trial.maxMoves) {
      final aiToMove = board.currentPlayer == aiPlayer;
      final agent = aiToMove ? aiAgent : scriptedAgent;
      final watch = aiToMove ? (Stopwatch()..start()) : null;
      final move = agent.chooseMove(board);
      watch?.stop();
      final aiMoveMs = watch?.elapsedMilliseconds;
      if (aiMoveMs != null &&
          maxAiMoveDuration != null &&
          aiMoveMs > maxAiMoveDuration.inMilliseconds) {
        slowAiMovesOverLimit++;
      }
      if (move == null) {
        endReason = CaptureAiMatchEndReason.noLegalMove;
        break;
      }
      final mover = board.currentPlayer;
      final applied = board.applyMove(move.position.row, move.position.col);
      if (!applied) {
        endReason = CaptureAiMatchEndReason.invalidMove;
        break;
      }
      moves.add(
        CaptureAiTrialMoveRecord(
          side: mover == aiPlayer ? 'ai' : 'scripted',
          row: move.position.row,
          col: move.position.col,
          score: move.score,
          blackCaptures: board.capturedByBlack,
          whiteCaptures: board.capturedByWhite,
          aiMoveMs: aiMoveMs,
        ),
      );
    }

    if (board.isTerminal) {
      endReason = CaptureAiMatchEndReason.captureTargetReached;
    }

    final winner = switch (board.winner) {
      final winner when winner == aiPlayer => CaptureAiTrialWinner.ai,
      SimBoard.black || SimBoard.white => CaptureAiTrialWinner.scripted,
      _ => CaptureAiTrialWinner.draw,
    };
    return CaptureAiScriptedTrialResult(
      trial: trial,
      aiConfig: aiConfig,
      winner: winner,
      endReason: endReason,
      totalMoves: moves.length,
      blackCaptures: board.capturedByBlack,
      whiteCaptures: board.capturedByWhite,
      moves: moves,
      maxAiMoveMsLimit: maxAiMoveDuration?.inMilliseconds,
      slowAiMovesOverLimit: slowAiMovesOverLimit,
    );
  }
}

class CaptureAiScriptedTrialResult {
  const CaptureAiScriptedTrialResult({
    required this.trial,
    required this.aiConfig,
    required this.winner,
    required this.endReason,
    required this.totalMoves,
    required this.blackCaptures,
    required this.whiteCaptures,
    required this.moves,
    required this.maxAiMoveMsLimit,
    required this.slowAiMovesOverLimit,
  });

  final CaptureAiScriptedTrial trial;
  final CaptureAiRobotConfig aiConfig;
  final CaptureAiTrialWinner winner;
  final CaptureAiMatchEndReason endReason;
  final int totalMoves;
  final int blackCaptures;
  final int whiteCaptures;
  final List<CaptureAiTrialMoveRecord> moves;
  final int? maxAiMoveMsLimit;
  final int slowAiMovesOverLimit;

  bool get aiDidNotLose =>
      winner != CaptureAiTrialWinner.scripted &&
      endReason != CaptureAiMatchEndReason.invalidMove &&
      slowAiMovesOverLimit == 0;

  List<int> get aiMoveDurationsMs {
    return [
      for (final move in moves)
        if (move.aiMoveMs != null) move.aiMoveMs!,
    ];
  }

  int get maxAiMoveMs =>
      aiMoveDurationsMs.isEmpty ? 0 : aiMoveDurationsMs.reduce(math.max);

  int get p95AiMoveMs => _durationPercentile(aiMoveDurationsMs, 0.95);

  int get p99AiMoveMs => _durationPercentile(aiMoveDurationsMs, 0.99);

  Map<String, Object?> toJson({bool includeMoves = false}) {
    return {
      'trial': trial.toJson(),
      'ai': {
        'id': aiConfig.id,
        'style': aiConfig.style.name,
        'difficulty': aiConfig.difficulty.name,
        'engine': aiConfig.engine.name,
      },
      'winner': winner.name,
      'passed': aiDidNotLose,
      'endReason': endReason.name,
      'totalMoves': totalMoves,
      'blackCaptures': blackCaptures,
      'whiteCaptures': whiteCaptures,
      'aiTiming': {
        'maxMoveMsLimit': maxAiMoveMsLimit,
        'maxMoveMs': maxAiMoveMs,
        'p95MoveMs': p95AiMoveMs,
        'p99MoveMs': p99AiMoveMs,
        'slowMovesOverLimit': slowAiMovesOverLimit,
      },
      if (includeMoves) 'moves': moves.map((move) => move.toJson()).toList(),
    };
  }
}

class CaptureAiTrialMoveRecord {
  const CaptureAiTrialMoveRecord({
    required this.side,
    required this.row,
    required this.col,
    required this.score,
    required this.blackCaptures,
    required this.whiteCaptures,
    this.aiMoveMs,
  });

  final String side;
  final int row;
  final int col;
  final double score;
  final int blackCaptures;
  final int whiteCaptures;
  final int? aiMoveMs;

  Map<String, Object?> toJson() {
    return {
      'side': side,
      'row': row,
      'col': col,
      'score': _round(score),
      'blackCaptures': blackCaptures,
      'whiteCaptures': whiteCaptures,
      if (aiMoveMs != null) 'aiMoveMs': aiMoveMs,
    };
  }
}

abstract class CaptureAiTrialPolicy {
  String get id;

  CaptureAiMove? chooseTacticalMove(SimBoard board);

  CaptureAiMove? chooseMove(SimBoard board);
}

CaptureAiTrialPolicy policyForTactic(CaptureAiScriptedTactic tactic) {
  return switch (tactic) {
    CaptureAiScriptedTactic.captureFirst => const _CaptureFirstPolicy(),
    CaptureAiScriptedTactic.atariFirst => const _AtariFirstPolicy(),
    CaptureAiScriptedTactic.rescueFirst => const _RescueFirstPolicy(),
    CaptureAiScriptedTactic.counterAtari => const _CounterAtariPolicy(),
    CaptureAiScriptedTactic.selfAtariBait => const _SelfAtariBaitPolicy(),
    CaptureAiScriptedTactic.edgeClamp => const _EdgeClampPolicy(),
    CaptureAiScriptedTactic.ladderChase => const _LadderChasePolicy(),
    CaptureAiScriptedTactic.netContain => const _NetContainPolicy(),
    CaptureAiScriptedTactic.snapback => const _SnapbackPolicy(),
    CaptureAiScriptedTactic.libertyShortage => const _LibertyShortagePolicy(),
    CaptureAiScriptedTactic.connectAndDie => const _ConnectAndDiePolicy(),
    CaptureAiScriptedTactic.sacrificeRace => const _SacrificeRacePolicy(),
    CaptureAiScriptedTactic.koFight => const _KoFightPolicy(),
    CaptureAiScriptedTactic.throwIn => const _ThrowInPolicy(),
  };
}

class _ScriptedTacticAgent implements CaptureAiAgent {
  _ScriptedTacticAgent(CaptureAiScriptedTactic tactic)
      : policy = policyForTactic(tactic);

  final CaptureAiTrialPolicy policy;

  @override
  CaptureAiStyle get style => CaptureAiStyle.adaptive;

  @override
  CaptureAiMove? chooseMove(SimBoard board) => policy.chooseMove(board);
}

abstract class _BasePolicy implements CaptureAiTrialPolicy {
  const _BasePolicy();

  @override
  CaptureAiMove? chooseMove(SimBoard board) {
    final tactical = chooseTacticalMove(board);
    if (tactical != null) return tactical;
    return _fallbackMove(board);
  }

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board);

  CaptureAiMove? _bestByScore(
    SimBoard board,
    double Function(_PolicyCandidate candidate) score, {
    bool Function(_PolicyCandidate candidate)? where,
  }) {
    _ScoredCandidate? best;
    for (final candidate in _legalCandidates(board)) {
      if (where != null && !where(candidate)) continue;
      final value = score(candidate);
      if (!value.isFinite) continue;
      final scored = _ScoredCandidate(candidate, value);
      if (best == null || _compareScored(scored, best) < 0) {
        best = scored;
      }
    }
    if (best == null) return null;
    return _moveFor(board, best.candidate.moveIndex, best.score);
  }

  CaptureAiMove? _fallbackMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) {
        final analysis = candidate.analysis;
        return _captureDeltaFor(analysis, board.currentPlayer) * 1000.0 +
            analysis.opponentAtariStones * 150.0 +
            analysis.ownRescuedStones * 180.0 +
            analysis.adjacentOpponentStones * 35.0 +
            analysis.libertiesAfterMove * 12.0 +
            _centerScore(board, candidate.moveIndex) +
            _tieBreak(candidate.moveIndex);
      },
    );
  }
}

class _CaptureFirstPolicy extends _BasePolicy {
  const _CaptureFirstPolicy();

  @override
  String get id => 'captureFirst';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) {
        final captureDelta =
            _captureDeltaFor(candidate.analysis, board.currentPlayer);
        return captureDelta * 10000.0 +
            candidate.analysis.opponentAtariStones * 100.0 +
            _tieBreak(candidate.moveIndex);
      },
      where: (candidate) =>
          _captureDeltaFor(candidate.analysis, board.currentPlayer) > 0,
    );
  }
}

class _AtariFirstPolicy extends _BasePolicy {
  const _AtariFirstPolicy();

  @override
  String get id => 'atariFirst';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          candidate.analysis.opponentAtariStones * 2200.0 +
          _captureDeltaFor(candidate.analysis, board.currentPlayer) * 450.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) => candidate.analysis.opponentAtariStones > 0,
    );
  }
}

class _RescueFirstPolicy extends _BasePolicy {
  const _RescueFirstPolicy();

  @override
  String get id => 'rescueFirst';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          candidate.analysis.ownRescuedStones * 2600.0 +
          candidate.analysis.libertiesAfterMove * 80.0 +
          _captureDeltaFor(candidate.analysis, board.currentPlayer) * 500.0 -
          candidate.analysis.ownAtariStones * 180.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) => candidate.analysis.ownRescuedStones > 0,
    );
  }
}

class _CounterAtariPolicy extends _BasePolicy {
  const _CounterAtariPolicy();

  @override
  String get id => 'counterAtari';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    final ownAtariBefore = _atariStoneCount(board, board.currentPlayer);
    return _bestByScore(
      board,
      (candidate) =>
          candidate.analysis.opponentAtariStones * 1700.0 +
          candidate.analysis.ownRescuedStones * 900.0 +
          _captureDeltaFor(candidate.analysis, board.currentPlayer) * 700.0 -
          candidate.analysis.ownAtariStones * 80.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) =>
          candidate.analysis.opponentAtariStones > 0 &&
          (ownAtariBefore > 0 || candidate.analysis.ownAtariStones > 0),
    );
  }
}

class _SelfAtariBaitPolicy extends _BasePolicy {
  const _SelfAtariBaitPolicy();

  @override
  String get id => 'selfAtariBait';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          _selfAtariFollowUpCapture(board, candidate.moveIndex) * 3200.0 +
          candidate.analysis.opponentAtariStones * 700.0 +
          _opponentLibertyReduction(board, candidate.moveIndex) * 400.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) =>
          _isSelfAtariMove(board, candidate.moveIndex) &&
          (_selfAtariFollowUpCapture(board, candidate.moveIndex) > 0 ||
              candidate.analysis.opponentAtariStones > 0 ||
              _opponentLibertyReduction(board, candidate.moveIndex) > 0),
    );
  }
}

class _EdgeClampPolicy extends _BasePolicy {
  const _EdgeClampPolicy();

  @override
  String get id => 'edgeClamp';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          _edgeScore(board, candidate.moveIndex) * 700.0 +
          candidate.analysis.adjacentOpponentStones * 800.0 +
          _opponentLibertyReduction(board, candidate.moveIndex) * 220.0 -
          _centerScore(board, candidate.moveIndex) * 20.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) =>
          _edgeScore(board, candidate.moveIndex) > 0 &&
          candidate.analysis.adjacentOpponentStones > 0,
    );
  }
}

class _LadderChasePolicy extends _BasePolicy {
  const _LadderChasePolicy();

  @override
  String get id => 'ladderChase';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    final candidates = board.size > 9
        ? _rankForcingMoves(board).take(16)
        : _legalCandidates(board);
    _ScoredCandidate? best;
    for (final candidate in candidates) {
      if (candidate.analysis.opponentAtariStones <= 0) continue;
      final canForceCapture = _canForceCaptureAfter(
        board,
        candidate.moveIndex,
        depth: board.size > 9 ? 4 : 6,
      );
      final linePressure = _linePressure(board, candidate.moveIndex);
      if (!canForceCapture && linePressure < 3) continue;
      final value = candidate.analysis.opponentAtariStones * 2500.0 +
          (canForceCapture ? 8000.0 : 0.0) +
          linePressure * 180.0 +
          _tieBreak(candidate.moveIndex);
      final scored = _ScoredCandidate(candidate, value);
      if (best == null || _compareScored(scored, best) < 0) {
        best = scored;
      }
    }
    if (best == null) return null;
    return _moveFor(board, best.candidate.moveIndex, best.score);
  }
}

class _NetContainPolicy extends _BasePolicy {
  const _NetContainPolicy();

  @override
  String get id => 'netContain';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          _opponentLibertyReduction(board, candidate.moveIndex) * 1100.0 +
          _nearOpponentCount(board, candidate.moveIndex) * 260.0 +
          candidate.analysis.libertiesAfterMove * 80.0 -
          candidate.analysis.opponentAtariStones * 350.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) {
        final captureDelta =
            _captureDeltaFor(candidate.analysis, board.currentPlayer);
        return captureDelta == 0 &&
            candidate.analysis.opponentAtariStones == 0 &&
            _opponentLibertyReduction(board, candidate.moveIndex) > 0 &&
            _nearOpponentCount(board, candidate.moveIndex) >= 1;
      },
    );
  }
}

class _SnapbackPolicy extends _BasePolicy {
  const _SnapbackPolicy();

  @override
  String get id => 'snapback';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          _selfAtariFollowUpCapture(board, candidate.moveIndex) * 4500.0 +
          _opponentLibertyReduction(board, candidate.moveIndex) * 900.0 +
          candidate.analysis.opponentAtariStones * 900.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) =>
          _isSelfAtariMove(board, candidate.moveIndex) &&
          (_selfAtariFollowUpCapture(board, candidate.moveIndex) >= 1 ||
              _opponentLibertyReduction(board, candidate.moveIndex) > 0),
    );
  }
}

class _LibertyShortagePolicy extends _BasePolicy {
  const _LibertyShortagePolicy();

  @override
  String get id => 'libertyShortage';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          _opponentLibertyReduction(board, candidate.moveIndex) * 1400.0 +
          candidate.analysis.opponentAtariStones * 1800.0 +
          _adjacentOwnCount(board, candidate.moveIndex) * 220.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) =>
          _opponentLibertyReduction(board, candidate.moveIndex) > 0,
    );
  }
}

class _ConnectAndDiePolicy extends _BasePolicy {
  const _ConnectAndDiePolicy();

  @override
  String get id => 'connectAndDie';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          _adjacentOpponentGroupCount(board, candidate.moveIndex) * 1800.0 +
          _opponentLibertyReduction(board, candidate.moveIndex) * 900.0 +
          candidate.analysis.opponentAtariStones * 800.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) =>
          _adjacentOpponentGroupCount(board, candidate.moveIndex) >= 2 &&
          _opponentLibertyReduction(board, candidate.moveIndex) > 0,
    );
  }
}

class _SacrificeRacePolicy extends _BasePolicy {
  const _SacrificeRacePolicy();

  @override
  String get id => 'sacrificeRace';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    final candidates = board.size > 9
        ? _rankForcingMoves(board).take(16)
        : _legalCandidates(board);
    final depth = board.size > 9 ? 3 : 4;
    _ScoredCandidate? best;
    for (final candidate in candidates) {
      final value = _captureRaceScoreAfter(
            board,
            candidate.moveIndex,
            depth: depth,
          ) +
          (_isSelfAtariMove(board, candidate.moveIndex) ? 600.0 : 0.0) +
          _tieBreak(candidate.moveIndex);
      if (!value.isFinite) continue;
      final scored = _ScoredCandidate(candidate, value);
      if (best == null || _compareScored(scored, best) < 0) {
        best = scored;
      }
    }
    if (best == null) return null;
    return _moveFor(board, best.candidate.moveIndex, best.score);
  }
}

class _KoFightPolicy extends _BasePolicy {
  const _KoFightPolicy();

  @override
  String get id => 'koFight';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          (_isKoLikeCapture(board, candidate.moveIndex) ? 7000.0 : 0.0) +
          _captureDeltaFor(candidate.analysis, board.currentPlayer) * 1200.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) =>
          _captureDeltaFor(candidate.analysis, board.currentPlayer) == 1,
    );
  }
}

class _ThrowInPolicy extends _BasePolicy {
  const _ThrowInPolicy();

  @override
  String get id => 'throwIn';

  @override
  CaptureAiMove? chooseTacticalMove(SimBoard board) {
    return _bestByScore(
      board,
      (candidate) =>
          _selfAtariFollowUpCapture(board, candidate.moveIndex) * 3200.0 +
          _adjacentOpponentCount(board, candidate.moveIndex) * 850.0 +
          _opponentLibertyReduction(board, candidate.moveIndex) * 700.0 +
          _tieBreak(candidate.moveIndex),
      where: (candidate) =>
          _isSelfAtariMove(board, candidate.moveIndex) &&
          _adjacentOpponentCount(board, candidate.moveIndex) > 0,
    );
  }
}

class _PolicyCandidate {
  const _PolicyCandidate(this.moveIndex, this.analysis);

  final int moveIndex;
  final SimMoveAnalysis analysis;
}

class _ScoredCandidate {
  const _ScoredCandidate(this.candidate, this.score);

  final _PolicyCandidate candidate;
  final double score;
}

List<_PolicyCandidate> _legalCandidates(SimBoard board) {
  final candidates = <_PolicyCandidate>[];
  for (final moveIndex in board.getLegalMoves()) {
    final row = moveIndex ~/ board.size;
    final col = moveIndex % board.size;
    final analysis = board.analyzeMove(row, col);
    if (!analysis.isLegal) continue;
    candidates.add(_PolicyCandidate(moveIndex, analysis));
  }
  return candidates;
}

CaptureAiMove _moveFor(SimBoard board, int moveIndex, double score) {
  return CaptureAiMove(
    position: BoardPosition(moveIndex ~/ board.size, moveIndex % board.size),
    score: score,
  );
}

int _compareScored(_ScoredCandidate a, _ScoredCandidate b) {
  final byScore = b.score.compareTo(a.score);
  if (byScore != 0) return byScore;
  return a.candidate.moveIndex.compareTo(b.candidate.moveIndex);
}

int _captureDeltaFor(SimMoveAnalysis analysis, int player) {
  return player == SimBoard.black
      ? analysis.blackCaptureDelta
      : analysis.whiteCaptureDelta;
}

int _opponentOf(int player) {
  return player == SimBoard.black ? SimBoard.white : SimBoard.black;
}

double _tieBreak(int moveIndex) => -moveIndex / 100000.0;

double _centerScore(SimBoard board, int moveIndex) {
  final center = board.size ~/ 2;
  final row = moveIndex ~/ board.size;
  final col = moveIndex % board.size;
  return math
      .max(0, board.size - (row - center).abs() - (col - center).abs())
      .toDouble();
}

double _edgeScore(SimBoard board, int moveIndex) {
  final row = moveIndex ~/ board.size;
  final col = moveIndex % board.size;
  final edgeDistance = [
    row,
    col,
    board.size - 1 - row,
    board.size - 1 - col,
  ].reduce(math.min);
  if (edgeDistance > 2) return 0;
  return (3 - edgeDistance).toDouble();
}

List<int> _adjacentIndices(SimBoard board, int moveIndex) {
  final row = moveIndex ~/ board.size;
  final col = moveIndex % board.size;
  return [
    if (row > 0) moveIndex - board.size,
    if (row < board.size - 1) moveIndex + board.size,
    if (col > 0) moveIndex - 1,
    if (col < board.size - 1) moveIndex + 1,
  ];
}

Set<int> _groupAt(SimBoard board, int start) {
  final color = board.cells[start];
  if (color == SimBoard.empty) return {};
  final group = <int>{start};
  final stack = [start];
  while (stack.isNotEmpty) {
    final current = stack.removeLast();
    for (final adjacent in _adjacentIndices(board, current)) {
      if (board.cells[adjacent] == color && group.add(adjacent)) {
        stack.add(adjacent);
      }
    }
  }
  return group;
}

Set<int> _libertiesOf(SimBoard board, Set<int> group) {
  final liberties = <int>{};
  for (final point in group) {
    for (final adjacent in _adjacentIndices(board, point)) {
      if (board.cells[adjacent] == SimBoard.empty) liberties.add(adjacent);
    }
  }
  return liberties;
}

List<Set<int>> _groupsFor(SimBoard board, int color) {
  final groups = <Set<int>>[];
  final visited = <int>{};
  for (var i = 0; i < board.cells.length; i++) {
    if (board.cells[i] != color || visited.contains(i)) continue;
    final group = _groupAt(board, i);
    visited.addAll(group);
    groups.add(group);
  }
  return groups;
}

int _atariStoneCount(SimBoard board, int color) {
  var stones = 0;
  for (final group in _groupsFor(board, color)) {
    if (_libertiesOf(board, group).length == 1) stones += group.length;
  }
  return stones;
}

double _opponentLibertyReduction(SimBoard board, int moveIndex) {
  final opponent = _opponentOf(board.currentPlayer);
  final before = _libertyPressure(board, opponent);
  final after = SimBoard.copy(board);
  if (!after.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return 0;
  }
  final afterPressure = _libertyPressure(after, opponent);
  return math.max(0.0, before - afterPressure);
}

double _libertyPressure(SimBoard board, int color) {
  var pressure = 0.0;
  for (final group in _groupsFor(board, color)) {
    final liberties = _libertiesOf(board, group).length;
    pressure += math.min(4, liberties) * group.length;
  }
  return pressure;
}

double _adjacentOwnCount(SimBoard board, int moveIndex) {
  return _adjacentIndices(board, moveIndex)
      .where((point) => board.cells[point] == board.currentPlayer)
      .length
      .toDouble();
}

double _adjacentOpponentCount(SimBoard board, int moveIndex) {
  final opponent = _opponentOf(board.currentPlayer);
  return _adjacentIndices(board, moveIndex)
      .where((point) => board.cells[point] == opponent)
      .length
      .toDouble();
}

double _nearOpponentCount(SimBoard board, int moveIndex) {
  final opponent = _opponentOf(board.currentPlayer);
  final row = moveIndex ~/ board.size;
  final col = moveIndex % board.size;
  var count = 0;
  for (var i = 0; i < board.cells.length; i++) {
    if (board.cells[i] != opponent) continue;
    final otherRow = i ~/ board.size;
    final otherCol = i % board.size;
    final distance = (row - otherRow).abs() + (col - otherCol).abs();
    if (distance > 0 && distance <= 3) count++;
  }
  return count.toDouble();
}

double _adjacentOpponentGroupCount(SimBoard board, int moveIndex) {
  final opponent = _opponentOf(board.currentPlayer);
  final representatives = <int>{};
  for (final adjacent in _adjacentIndices(board, moveIndex)) {
    if (board.cells[adjacent] != opponent) continue;
    final group = _groupAt(board, adjacent);
    if (group.isNotEmpty) representatives.add(group.reduce(math.min));
  }
  return representatives.length.toDouble();
}

double _linePressure(SimBoard board, int moveIndex) {
  final opponent = _opponentOf(board.currentPlayer);
  final row = moveIndex ~/ board.size;
  final col = moveIndex % board.size;
  var pressure = 0.0;
  for (var i = 0; i < board.cells.length; i++) {
    if (board.cells[i] != opponent) continue;
    final otherRow = i ~/ board.size;
    final otherCol = i % board.size;
    final distance = (row - otherRow).abs() + (col - otherCol).abs();
    if (distance == 0 || distance > 4) continue;
    if (row == otherRow ||
        col == otherCol ||
        (row - otherRow).abs() == (col - otherCol).abs()) {
      pressure += 5 - distance;
    }
  }
  return pressure;
}

bool _isSelfAtariMove(SimBoard board, int moveIndex) {
  final next = SimBoard.copy(board);
  if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return false;
  }
  if (next.cells[moveIndex] == SimBoard.empty) return false;
  return _libertiesOf(next, _groupAt(next, moveIndex)).length == 1;
}

double _selfAtariFollowUpCapture(SimBoard board, int moveIndex) {
  final player = board.currentPlayer;
  final afterMove = SimBoard.copy(board);
  if (!afterMove.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return 0;
  }
  if (afterMove.cells[moveIndex] == SimBoard.empty) return 0;
  if (_libertiesOf(afterMove, _groupAt(afterMove, moveIndex)).length != 1) {
    return 0;
  }

  var bestFollowUp = 0;
  for (final opponentMove in _legalCandidates(afterMove).take(12)) {
    final opponentCapture =
        _captureDeltaFor(opponentMove.analysis, afterMove.currentPlayer);
    if (opponentCapture <= 0) continue;
    final afterOpponent = SimBoard.copy(afterMove);
    if (!afterOpponent.applyMove(
      opponentMove.moveIndex ~/ afterOpponent.size,
      opponentMove.moveIndex % afterOpponent.size,
    )) {
      continue;
    }
    if (afterOpponent.currentPlayer != player) continue;
    for (final followUp in _legalCandidates(afterOpponent)) {
      bestFollowUp = math.max(
        bestFollowUp,
        _captureDeltaFor(followUp.analysis, player),
      );
    }
  }
  return bestFollowUp.toDouble();
}

bool _canForceCaptureAfter(
  SimBoard board,
  int moveIndex, {
  required int depth,
}) {
  final chaser = board.currentPlayer;
  final capturesBefore = _capturesFor(board, chaser);
  final next = SimBoard.copy(board);
  if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return false;
  }
  if (_capturesFor(next, chaser) > capturesBefore) return true;
  return _canForceCapture(next, chaser, depth, capturesBefore);
}

bool _canForceCapture(
  SimBoard board,
  int chaser,
  int depth,
  int capturesBefore,
) {
  if (_capturesFor(board, chaser) > capturesBefore) return true;
  if (board.winner == chaser) return true;
  if (board.winner != 0) return false;
  if (depth <= 0) return false;

  final moves = _rankForcingMoves(board).take(10).toList();
  if (moves.isEmpty) return false;
  if (board.currentPlayer == chaser) {
    for (final move in moves) {
      final next = SimBoard.copy(board);
      if (!next.applyMove(
          move.moveIndex ~/ board.size, move.moveIndex % board.size)) {
        continue;
      }
      if (_canForceCapture(next, chaser, depth - 1, capturesBefore)) {
        return true;
      }
    }
    return false;
  }

  for (final move in moves) {
    final next = SimBoard.copy(board);
    if (!next.applyMove(
        move.moveIndex ~/ board.size, move.moveIndex % board.size)) {
      continue;
    }
    if (!_canForceCapture(next, chaser, depth - 1, capturesBefore)) {
      return false;
    }
  }
  return true;
}

int _capturesFor(SimBoard board, int player) {
  return player == SimBoard.black
      ? board.capturedByBlack
      : board.capturedByWhite;
}

List<_PolicyCandidate> _rankForcingMoves(SimBoard board) {
  final moves = _legalCandidates(board);
  moves.sort((a, b) {
    final aScore = _captureDeltaFor(a.analysis, board.currentPlayer) * 1000 +
        a.analysis.opponentAtariStones * 100 +
        a.analysis.ownRescuedStones * 80;
    final bScore = _captureDeltaFor(b.analysis, board.currentPlayer) * 1000 +
        b.analysis.opponentAtariStones * 100 +
        b.analysis.ownRescuedStones * 80;
    final byScore = bScore.compareTo(aScore);
    if (byScore != 0) return byScore;
    return a.moveIndex.compareTo(b.moveIndex);
  });
  return moves;
}

double _captureRaceScoreAfter(
  SimBoard board,
  int moveIndex, {
  required int depth,
}) {
  final root = board.currentPlayer;
  final next = SimBoard.copy(board);
  if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return -double.infinity;
  }
  return _captureRaceScore(next, root, depth - 1);
}

double _captureRaceScore(SimBoard board, int root, int depth) {
  if (board.winner == root) return 100000.0;
  if (board.winner != 0) return -100000.0;
  final rootCaptures =
      root == SimBoard.black ? board.capturedByBlack : board.capturedByWhite;
  final opponentCaptures =
      root == SimBoard.black ? board.capturedByWhite : board.capturedByBlack;
  final staticScore = (rootCaptures - opponentCaptures) * 1600.0 +
      (board.captureTarget - opponentCaptures) * 120.0 -
      (board.captureTarget - rootCaptures) * 120.0;
  if (depth <= 0) return staticScore;

  final candidates = _rankForcingMoves(board).take(8);
  if (board.currentPlayer == root) {
    var best = -double.infinity;
    for (final candidate in candidates) {
      final next = SimBoard.copy(board);
      if (!next.applyMove(
        candidate.moveIndex ~/ board.size,
        candidate.moveIndex % board.size,
      )) {
        continue;
      }
      best = math.max(best, _captureRaceScore(next, root, depth - 1));
    }
    return best.isFinite ? best : staticScore;
  }

  var worst = double.infinity;
  for (final candidate in candidates) {
    final next = SimBoard.copy(board);
    if (!next.applyMove(
      candidate.moveIndex ~/ board.size,
      candidate.moveIndex % board.size,
    )) {
      continue;
    }
    worst = math.min(worst, _captureRaceScore(next, root, depth - 1));
  }
  return worst.isFinite ? worst : staticScore;
}

bool _isKoLikeCapture(SimBoard board, int moveIndex) {
  final analysis =
      board.analyzeMove(moveIndex ~/ board.size, moveIndex % board.size);
  if (!analysis.isLegal ||
      _captureDeltaFor(analysis, board.currentPlayer) != 1) {
    return false;
  }
  final next = SimBoard.copy(board);
  if (!next.applyMove(moveIndex ~/ board.size, moveIndex % board.size)) {
    return false;
  }
  if (next.cells[moveIndex] == SimBoard.empty) return false;
  return _libertiesOf(next, _groupAt(next, moveIndex)).length == 1;
}

int _durationPercentile(List<int> values, double percentile) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index.clamp(0, sorted.length - 1)];
}

double _round(double value) => (value * 1000).round() / 1000;
