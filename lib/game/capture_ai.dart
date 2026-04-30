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

class CaptureAiRegistry {
  static CaptureAiAgent create({
    required CaptureAiStyle style,
    required DifficultyLevel difficulty,
  }) {
    return _WeightedCaptureAiAgent(
      style: style,
      profile: _CaptureAiProfile.forStyle(style, difficulty),
    );
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
  }) {
    final board = SimBoard(boardSize, captureTarget: captureTarget);
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
    DifficultyLevel difficulty,
  ) {
    final playouts = switch (difficulty) {
      DifficultyLevel.beginner => 12,
      DifficultyLevel.intermediate => 24,
      DifficultyLevel.advanced => 48,
    };

    return switch (style) {
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
    final currentPlayer = board.currentPlayer;
    final ownCaptured = currentPlayer == SimBoard.black
        ? analysis.blackCaptureDelta
        : analysis.whiteCaptureDelta;

    return ownCaptured * _profile.immediateCaptureWeight +
        analysis.opponentAtariStones * _profile.opponentAtariWeight +
        analysis.ownRescuedStones * _profile.ownRescueWeight +
        analysis.adjacentOpponentStones * _profile.contactWeight +
        analysis.libertiesAfterMove * _profile.libertyWeight +
        analysis.centerProximityScore * _profile.centerWeight -
        analysis.ownAtariStones * _profile.selfAtariPenalty;
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
