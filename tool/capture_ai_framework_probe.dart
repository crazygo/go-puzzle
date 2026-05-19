// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';
import 'package:go_puzzle/game/katago_process_model_adapter.dart';

void main(List<String> args) {
  final opts = _parseArgs(args);
  final configIds = (opts['configs'] ?? '')
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (configIds.length < 2) {
    stderr.writeln('ERROR: --configs must contain at least two config ids.');
    stderr.writeln('Known configs:');
    for (final config in AiAlgorithmRegistry.configs) {
      stderr.writeln('  ${config.id}');
    }
    exitCode = 2;
    return;
  }

  final configs = <AiAlgorithmConfig>[];
  for (final id in configIds) {
    try {
      configs.add(AiAlgorithmRegistry.configById(id));
    } on StateError {
      stderr.writeln('ERROR: unknown config id "$id".');
      exitCode = 2;
      return;
    }
  }

  final rounds = int.tryParse(opts['rounds'] ?? '12') ?? 12;
  final maxMoves = int.tryParse(opts['max-moves'] ?? '160') ?? 160;
  final boardSize = int.tryParse(opts['board-size'] ?? '9') ?? 9;
  final captureTarget = int.tryParse(opts['capture-target'] ?? '5') ?? 5;
  final matchSeed = int.tryParse(opts['match-seed'] ?? '20260519') ?? 20260519;
  final openingSeed = int.tryParse(opts['opening-seed'] ?? '0') ?? 0;
  final openingPolicy =
      opts['opening-policy'] ?? 'empty_cross_twist_cross_random_v1';
  final expectedWinner = opts['expected-winner'];
  final minWinRate = double.tryParse(opts['min-win-rate'] ?? '0.55') ?? 0.55;
  final jsonOutput = opts.containsKey('json');
  final matrixOutput = opts.containsKey('matrix');
  final realKatagoOnnx = opts.containsKey('real-katago-onnx');

  if (matrixOutput && configs.length != 2) {
    stderr.writeln('ERROR: --matrix requires exactly two config ids.');
    exitCode = 2;
    return;
  }

  final summary = matrixOutput
      ? _runOpeningFirstMatrix(
          configs[0],
          configs[1],
          boardSize: boardSize,
          captureTarget: captureTarget,
          rounds: rounds,
          maxMoves: maxMoves,
          matchSeed: matchSeed,
          openingSeed: openingSeed,
          realKatagoOnnx: realKatagoOnnx,
        )
      : AiArenaExecutor(
          boardSize: boardSize,
          captureTarget: captureTarget,
          rounds: rounds,
          maxMoves: maxMoves,
          openingPolicy: openingPolicy,
          katagoModelAdapter:
              realKatagoOnnx ? const ProcessKatagoOnnxModelAdapter() : null,
        ).runFrameworkEvaluation(
          configs: configs,
          matchSeed: matchSeed,
          openingSeed: openingSeed,
        );

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(summary.toJson()));
  } else if (matrixOutput) {
    _printMatrixSummary(summary);
  } else {
    _printHumanSummary(summary);
  }

  var failed = false;
  for (final pair in summary.pairwise) {
    if (pair.illegalMoves > 0 || pair.timeouts > 0) {
      stderr.writeln(
        'FAIL ${pair.configAId} vs ${pair.configBId}: '
        'illegal=${pair.illegalMoves} timeout=${pair.timeouts}',
      );
      failed = true;
    }
  }

  if (expectedWinner != null && matrixOutput) {
    final expected = _scoreFor(summary, expectedWinner);
    final opponentGames = summary.matches.fold<int>(
      0,
      (sum, match) => sum + match.rounds,
    );
    final expectedRate =
        opponentGames == 0 ? 0.0 : expected.wins / opponentGames;
    if (expectedRate < minWinRate || expected.wins <= expected.losses) {
      stderr.writeln(
        'FAIL $expectedWinner: wins=${expected.wins} '
        'losses=${expected.losses} draws=${expected.draws} '
        'winRate=${_pct(expectedRate)} min=${_pct(minWinRate)}',
      );
      failed = true;
    }
  } else if (expectedWinner != null) {
    final pair = summary.pairwise.singleWhere(
      (entry) =>
          entry.configAId == expectedWinner ||
          entry.configBId == expectedWinner,
      orElse: () {
        stderr.writeln('ERROR: --expected-winner "$expectedWinner" was not in '
            'a unique pairwise result.');
        exitCode = 2;
        return summary.pairwise.first;
      },
    );
    if (exitCode == 2) return;

    final expectedWins =
        pair.configAId == expectedWinner ? pair.aWins : pair.bWins;
    final expectedRate = expectedWins / pair.games;
    final opponentWins =
        pair.configAId == expectedWinner ? pair.bWins : pair.aWins;
    if (expectedRate < minWinRate || expectedWins <= opponentWins) {
      stderr.writeln(
        'FAIL $expectedWinner: wins=$expectedWins opponentWins=$opponentWins '
        'winRate=${_pct(expectedRate)} min=${_pct(minWinRate)}',
      );
      failed = true;
    }
  }

  if (failed) {
    exitCode = 1;
  }
}

AiArenaEvaluationSummary _runOpeningFirstMatrix(
  AiAlgorithmConfig configA,
  AiAlgorithmConfig configB, {
  required int boardSize,
  required int captureTarget,
  required int rounds,
  required int maxMoves,
  required int matchSeed,
  required int openingSeed,
  required bool realKatagoOnnx,
}) {
  const openings = [
    ('empty', 'empty_v1'),
    ('cross', 'cross_v1'),
    ('twistCross', 'twist_cross_v1'),
  ];
  final matches = <AiMatchResult>[];
  var index = 0;
  for (final (_, openingPolicy) in openings) {
    final executor = AiArenaExecutor(
      boardSize: boardSize,
      captureTarget: captureTarget,
      rounds: rounds,
      maxMoves: maxMoves,
      openingPolicy: openingPolicy,
      katagoModelAdapter:
          realKatagoOnnx ? const ProcessKatagoOnnxModelAdapter() : null,
    );
    matches.add(executor.runFrameworkMatch(
      configA: configA,
      configB: configB,
      matchSeed: matchSeed + index * 7919,
      openingSeed: openingSeed,
      alternateColors: false,
    ));
    index++;
    matches.add(executor.runFrameworkMatch(
      configA: configB,
      configB: configA,
      matchSeed: matchSeed + index * 7919,
      openingSeed: openingSeed,
      alternateColors: false,
    ));
    index++;
  }
  return AiArenaEvaluationSummary.fromMatches(matches);
}

void _printMatrixSummary(AiArenaEvaluationSummary summary) {
  print('=== Capture AI Framework Matrix Probe ===');
  print('Matrix: opening x first algorithm x repeated games');
  for (final match in summary.matches) {
    final first = match.configA.id;
    final second = match.configB.id;
    final opening = _openingFamily(match.games.first.opening);
    print(
      '  opening=$opening first=$first second=$second: '
      '${match.aWins}-${match.bWins}-${match.draws} '
      'firstWinRate=${_pct(match.aWinRate)} '
      'illegal=${match.games.where((g) => g.illegalMove).length} '
      'timeout=${match.games.where((g) => g.timedOut).length}',
    );
  }
  print('Aggregate ranking:');
  for (final entry in summary.rankings) {
    print(
      '  #${entry.rank} ${entry.configId}: '
      'games=${entry.gameWins}-${entry.gameLosses}-${entry.draws} '
      'winRate=${_pct(entry.gameWinRate)}',
    );
  }
  print('Opening aggregate:');
  final openingScores = <String, _OpeningScore>{};
  for (final match in summary.matches) {
    for (final game in match.games) {
      final opening = _openingFamily(game.opening);
      openingScores
          .putIfAbsent(opening, () => _OpeningScore(opening))
          .add(game);
    }
  }
  for (final score in openingScores.values) {
    print(
      '  ${score.opening}: games=${score.games} a=${score.aWins} '
      'b=${score.bWins} draws=${score.draws} illegal=${score.illegalMoves} '
      'timeout=${score.timeouts}',
    );
  }
}

void _printHumanSummary(AiArenaEvaluationSummary summary) {
  print('=== Capture AI Framework Probe ===');
  print('Pairwise:');
  for (final pair in summary.pairwise) {
    print(
      '  ${pair.configAId} vs ${pair.configBId}: '
      '${pair.aWins}-${pair.bWins}-${pair.draws} '
      'aWinRate=${_pct(pair.aWinRate)} bWinRate=${_pct(pair.bWinRate)} '
      'illegal=${pair.illegalMoves} timeout=${pair.timeouts} '
      'fallback=${pair.fallbackGames}',
    );
    if (pair.failureReasons.isNotEmpty) {
      print('    failures: ${pair.failureReasons.join('; ')}');
    }
  }
  print('Ranking:');
  for (final entry in summary.rankings) {
    print(
      '  #${entry.rank} ${entry.configId}: '
      'matches=${entry.matchWins}-${entry.matchLosses}-${entry.matchDraws} '
      'games=${entry.gameWins}-${entry.gameLosses}-${entry.draws} '
      'gameWinRate=${_pct(entry.gameWinRate)}',
    );
  }
  print('Opening performance:');
  for (final entry in summary.openingPerformance) {
    print(
      '  ${entry.opening}: games=${entry.games} '
      'a=${entry.aWins} b=${entry.bWins} draws=${entry.draws} '
      'illegal=${entry.illegalMoves} timeout=${entry.timeouts} '
      'fallback=${entry.fallbackGames}',
    );
  }
}

_ConfigScore _scoreFor(AiArenaEvaluationSummary summary, String configId) {
  final score = _ConfigScore(configId);
  for (final match in summary.matches) {
    if (match.configA.id == configId) {
      score.wins += match.aWins;
      score.losses += match.bWins;
      score.draws += match.draws;
    } else if (match.configB.id == configId) {
      score.wins += match.bWins;
      score.losses += match.aWins;
      score.draws += match.draws;
    }
  }
  return score;
}

String _openingFamily(String opening) {
  if (opening.startsWith('twistCross')) return 'twistCross';
  return opening;
}

class _ConfigScore {
  _ConfigScore(this.configId);

  final String configId;
  int wins = 0;
  int losses = 0;
  int draws = 0;
}

class _OpeningScore {
  _OpeningScore(this.opening);

  final String opening;
  int games = 0;
  int aWins = 0;
  int bWins = 0;
  int draws = 0;
  int illegalMoves = 0;
  int timeouts = 0;

  void add(AiGameRecord game) {
    games++;
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
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final opts = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--json' || arg == '--matrix' || arg == '--real-katago-onnx') {
      opts[arg.substring(2)] = 'true';
    } else if (arg.startsWith('--') && i + 1 < args.length) {
      opts[arg.substring(2)] = args[i + 1];
      i++;
    }
  }
  return opts;
}

String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
