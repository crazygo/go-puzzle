// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';

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

  final executor = AiArenaExecutor(
    boardSize: boardSize,
    captureTarget: captureTarget,
    rounds: rounds,
    maxMoves: maxMoves,
    openingPolicy: openingPolicy,
  );
  final summary = executor.runFrameworkEvaluation(
    configs: configs,
    matchSeed: matchSeed,
    openingSeed: openingSeed,
  );

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(summary.toJson()));
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

  if (expectedWinner != null) {
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

Map<String, String> _parseArgs(List<String> args) {
  final opts = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--json') {
      opts['json'] = 'true';
    } else if (arg.startsWith('--') && i + 1 < args.length) {
      opts[arg.substring(2)] = args[i + 1];
      i++;
    }
  }
  return opts;
}

String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
