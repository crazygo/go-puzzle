// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;

import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/difficulty_level.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/models/board_position.dart';

enum _ProbeOpening { empty, twistCross, random }

class _ProbeResult {
  _ProbeResult({
    required this.style,
    required this.boardSize,
    required this.opening,
    required this.stronger,
    required this.weaker,
  });

  final CaptureAiStyle style;
  final int boardSize;
  final _ProbeOpening opening;
  final DifficultyLevel stronger;
  final DifficultyLevel weaker;
  int strongerWins = 0;
  int weakerWins = 0;
  int draws = 0;
  int invalid = 0;
  int games = 0;

  double get strongerWinRate => games == 0 ? 0 : strongerWins / games;

  String get label => '${style.name.padRight(8)} ${boardSize}x$boardSize '
      '${opening.name.padRight(10)} ${stronger.name}>${weaker.name}';
}

class _ProbeGameOutcome {
  const _ProbeGameOutcome({
    required this.score,
    required this.strongerCaptures,
    required this.weakerCaptures,
    required this.invalid,
  });

  final int score;
  final int strongerCaptures;
  final int weakerCaptures;
  final bool invalid;
}

void main(List<String> args) {
  final opts = _parseArgs(args);
  final roundsPerOpening = int.tryParse(opts['rounds-per-opening'] ?? '1') ?? 1;
  final maxMoves = int.tryParse(opts['max-moves'] ?? '160') ?? 160;
  final captureTarget = int.tryParse(opts['capture-target'] ?? '5') ?? 5;
  final minWinRate = double.tryParse(opts['min-win-rate'] ?? '0.55') ?? 0.55;
  final styleFilter = opts['style'];
  final pairFilter = opts['pair'];
  final verbose = opts.containsKey('verbose');
  final boardSizes = (opts['board-sizes'] ?? '9,13,19')
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .toList();
  final openingFilter = opts['openings']
      ?.split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet();
  final openings = _ProbeOpening.values
      .where((opening) =>
          openingFilter == null || openingFilter.contains(opening.name))
      .toList();
  final styles = CaptureAiStyle.values
      .where((style) => styleFilter == null || style.name == styleFilter)
      .toList();

  if (styles.isEmpty) {
    stderr.writeln('ERROR: --style must be one of '
        '${CaptureAiStyle.values.map((s) => s.name).join(', ')}');
    exitCode = 2;
    return;
  }
  if (openings.isEmpty) {
    stderr.writeln('ERROR: --openings must include one of '
        '${_ProbeOpening.values.map((o) => o.name).join(', ')}');
    exitCode = 2;
    return;
  }

  print('=== Capture AI Strength Probe ===');
  print('Styles: ${styles.map((s) => s.name).join(', ')}');
  print('Board sizes: ${boardSizes.join(', ')}');
  print('Openings: ${openings.map((o) => o.name).join(', ')}');
  print('Rounds/opening/color: $roundsPerOpening');
  print('Max moves: $maxMoves, capture target: $captureTarget');
  print('Minimum adjacent-tier win rate: ${_pct(minWinRate)}');
  print('');

  var failed = false;
  for (final style in styles) {
    for (final boardSize in boardSizes) {
      for (final opening in openings) {
        if (_shouldRunPair(
          pairFilter,
          stronger: DifficultyLevel.intermediate,
          weaker: DifficultyLevel.beginner,
        )) {
          failed = _recordResult(
                _runComparison(
                  style: style,
                  boardSize: boardSize,
                  opening: opening,
                  stronger: DifficultyLevel.intermediate,
                  weaker: DifficultyLevel.beginner,
                  roundsPerOpening: roundsPerOpening,
                  maxMoves: maxMoves,
                  captureTarget: captureTarget,
                  verbose: verbose,
                ),
                minWinRate: minWinRate,
              ) ||
              failed;
        }
        if (_shouldRunPair(
          pairFilter,
          stronger: DifficultyLevel.advanced,
          weaker: DifficultyLevel.intermediate,
        )) {
          failed = _recordResult(
                _runComparison(
                  style: style,
                  boardSize: boardSize,
                  opening: opening,
                  stronger: DifficultyLevel.advanced,
                  weaker: DifficultyLevel.intermediate,
                  roundsPerOpening: roundsPerOpening,
                  maxMoves: maxMoves,
                  captureTarget: captureTarget,
                  verbose: verbose,
                ),
                minWinRate: minWinRate,
              ) ||
              failed;
        }
        if (_shouldRunPair(
          pairFilter,
          stronger: DifficultyLevel.advanced,
          weaker: DifficultyLevel.beginner,
        )) {
          failed = _recordResult(
                _runComparison(
                  style: style,
                  boardSize: boardSize,
                  opening: opening,
                  stronger: DifficultyLevel.advanced,
                  weaker: DifficultyLevel.beginner,
                  roundsPerOpening: roundsPerOpening,
                  maxMoves: maxMoves,
                  captureTarget: captureTarget,
                  verbose: verbose,
                ),
                minWinRate: minWinRate,
              ) ||
              failed;
        }
      }
    }
  }

  print('');
  if (failed) {
    print('Strength probe: FAILED');
    exitCode = 1;
  } else {
    print('Strength probe: PASSED');
  }
}

bool _shouldRunPair(
  String? pairFilter, {
  required DifficultyLevel stronger,
  required DifficultyLevel weaker,
}) {
  if (pairFilter == null) return true;
  return pairFilter == '${stronger.name}>${weaker.name}';
}

bool _recordResult(_ProbeResult result, {required double minWinRate}) {
  final adjacent = result.stronger == DifficultyLevel.intermediate ||
      result.weaker == DifficultyLevel.intermediate;
  final requiredRate = adjacent ? minWinRate : math.max(minWinRate, 0.65);
  final passed = result.strongerWinRate >= requiredRate &&
      result.invalid == 0 &&
      result.strongerWins > result.weakerWins;
  print(
    '${passed ? 'PASS' : 'FAIL'} ${result.label}: '
    '${result.strongerWins}-${result.weakerWins}-${result.draws} '
    'winRate=${_pct(result.strongerWinRate)} invalid=${result.invalid}',
  );
  stdout.flush();
  return !passed;
}

_ProbeResult _runComparison({
  required CaptureAiStyle style,
  required int boardSize,
  required _ProbeOpening opening,
  required DifficultyLevel stronger,
  required DifficultyLevel weaker,
  required int roundsPerOpening,
  required int maxMoves,
  required int captureTarget,
  required bool verbose,
}) {
  final result = _ProbeResult(
    style: style,
    boardSize: boardSize,
    opening: opening,
    stronger: stronger,
    weaker: weaker,
  );
  for (var round = 0; round < roundsPerOpening; round++) {
    final baseSeed =
        _seedFor(style, boardSize, opening, stronger, weaker, round);
    final blackOutcome = _playProbeGame(
      result: result,
      boardSize: boardSize,
      opening: opening,
      stronger: stronger,
      weaker: weaker,
      strongerIsBlack: true,
      seed: baseSeed,
      variant: round,
      maxMoves: maxMoves,
      captureTarget: captureTarget,
      verbose: verbose,
    );
    final whiteOutcome = _playProbeGame(
      result: result,
      boardSize: boardSize,
      opening: opening,
      stronger: stronger,
      weaker: weaker,
      strongerIsBlack: false,
      seed: baseSeed,
      variant: round,
      maxMoves: maxMoves,
      captureTarget: captureTarget,
      verbose: verbose,
    );
    result.games++;
    if (blackOutcome.invalid) result.invalid++;
    if (whiteOutcome.invalid) result.invalid++;

    final pairedScore = blackOutcome.score + whiteOutcome.score;
    if (pairedScore > 0) {
      result.strongerWins++;
    } else if (pairedScore < 0) {
      result.weakerWins++;
    } else {
      final strongerCaptures =
          blackOutcome.strongerCaptures + whiteOutcome.strongerCaptures;
      final weakerCaptures =
          blackOutcome.weakerCaptures + whiteOutcome.weakerCaptures;
      if (strongerCaptures > weakerCaptures) {
        result.strongerWins++;
      } else if (weakerCaptures > strongerCaptures) {
        result.weakerWins++;
      } else {
        result.draws++;
      }
    }
  }
  return result;
}

_ProbeGameOutcome _playProbeGame({
  required _ProbeResult result,
  required int boardSize,
  required _ProbeOpening opening,
  required DifficultyLevel stronger,
  required DifficultyLevel weaker,
  required bool strongerIsBlack,
  required int seed,
  required int variant,
  required int maxMoves,
  required int captureTarget,
  required bool verbose,
}) {
  final strongerAgent = CaptureAiRegistry.create(
    style: result.style,
    difficulty: stronger,
    seed: seed * 2,
  );
  final weakerAgent = CaptureAiRegistry.create(
    style: result.style,
    difficulty: weaker,
    seed: seed * 2 + 1,
  );
  final arenaResult = CaptureAiArena.playMatch(
    blackAgent: strongerIsBlack ? strongerAgent : weakerAgent,
    whiteAgent: strongerIsBlack ? weakerAgent : strongerAgent,
    boardSize: boardSize,
    captureTarget: captureTarget,
    maxMoves: maxMoves,
    initialBoard: _openingBoard(
      boardSize: boardSize,
      captureTarget: captureTarget,
      opening: opening,
      seed: seed,
      variant: variant,
    ),
  );

  final strongerWon =
      (strongerIsBlack && arenaResult.winner == StoneColor.black) ||
          (!strongerIsBlack && arenaResult.winner == StoneColor.white);
  final weakerWon =
      (strongerIsBlack && arenaResult.winner == StoneColor.white) ||
          (!strongerIsBlack && arenaResult.winner == StoneColor.black);
  final strongerCaptures =
      strongerIsBlack ? arenaResult.blackCaptures : arenaResult.whiteCaptures;
  final weakerCaptures =
      strongerIsBlack ? arenaResult.whiteCaptures : arenaResult.blackCaptures;
  final score = strongerWon
      ? 1
      : weakerWon
          ? -1
          : strongerCaptures > weakerCaptures
              ? 1
              : weakerCaptures > strongerCaptures
                  ? -1
                  : 0;
  if (verbose) {
    final side = strongerIsBlack ? 'black' : 'white';
    final winner = score > 0
        ? 'stronger'
        : score < 0
            ? 'weaker'
            : 'draw';
    print(
      '  game seed=$seed stronger=$side '
      'winner=$winner end=${arenaResult.endReason.name} '
      'captures=${arenaResult.blackCaptures}-${arenaResult.whiteCaptures} '
      'moves=${arenaResult.totalMoves}',
    );
    stdout.flush();
  }
  return _ProbeGameOutcome(
    score: score,
    strongerCaptures: strongerCaptures,
    weakerCaptures: weakerCaptures,
    invalid: !arenaResult.completedWithoutFlowError,
  );
}

SimBoard _openingBoard({
  required int boardSize,
  required int captureTarget,
  required _ProbeOpening opening,
  required int seed,
  required int variant,
}) {
  final board = SimBoard(boardSize, captureTarget: captureTarget);
  if (opening == _ProbeOpening.twistCross) {
    const arm = 3;
    if (boardSize < arm * 2 + 1) {
      throw ArgumentError(
        'Board size $boardSize is too small for the twistCross opening '
        '(minimum ${arm * 2 + 1}).',
      );
    }
    final center = boardSize ~/ 2;
    final points = switch (variant % 4) {
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
  } else if (opening == _ProbeOpening.random) {
    final rng = math.Random(seed ^ (0x5eed * boardSize));
    final center = boardSize ~/ 2;
    final radius = math.max(2, boardSize ~/ 3);
    final pairCount = boardSize <= 9 ? 2 : (boardSize <= 13 ? 3 : 4);
    var placedPairs = 0;
    var attempts = 0;
    while (placedPairs < pairCount && attempts < boardSize * boardSize * 4) {
      attempts++;
      final row = (center - radius) + rng.nextInt(radius * 2 + 1);
      final col = (center - radius) + rng.nextInt(radius * 2 + 1);
      if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) {
        continue;
      }
      final mirrorRow = boardSize - 1 - row;
      final mirrorCol = boardSize - 1 - col;
      if (row == mirrorRow && col == mirrorCol) continue;
      final blackIndex = board.idx(row, col);
      final whiteIndex = board.idx(mirrorRow, mirrorCol);
      if (board.cells[blackIndex] != SimBoard.empty ||
          board.cells[whiteIndex] != SimBoard.empty) {
        continue;
      }
      board.cells[blackIndex] = SimBoard.black;
      board.cells[whiteIndex] = SimBoard.white;
      placedPairs++;
    }
  }
  board.currentPlayer = SimBoard.black;
  return board;
}

int _seedFor(
  CaptureAiStyle style,
  int boardSize,
  _ProbeOpening opening,
  DifficultyLevel stronger,
  DifficultyLevel weaker,
  int round,
) {
  return 20260501 +
      style.index * 1000003 +
      boardSize * 10007 +
      opening.index * 1009 +
      stronger.index * 131 +
      weaker.index * 17 +
      round * 7919;
}

Map<String, String> _parseArgs(List<String> args) {
  final opts = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    // If the next token is a value (not another flag), consume it; otherwise
    // treat this as a boolean flag and record it with an empty string value.
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      opts[key] = args[i + 1];
      i++;
    } else {
      opts[key] = '';
    }
  }
  return opts;
}

String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
