// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/capture_ai_tactics.dart';
import 'package:go_puzzle/game/difficulty_level.dart';

const _defaultProblemsPath = 'docs/ai_eval/tactics/problems.json';

void main(List<String> args) {
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

  final problemsPath = opts['problems'] ?? _defaultProblemsPath;
  final problemsFile = File(problemsPath);
  if (!problemsFile.existsSync()) {
    stderr.writeln('ERROR: Problem file not found: $problemsPath');
    exitCode = 2;
    return;
  }

  final problemSet = CaptureAiTacticsProblemSet.fromJsonString(
    problemsFile.readAsStringSync(),
  );
  final limit = opts['limit'] == null
      ? null
      : _parsePositiveInt(opts['limit'], fallback: 0);
  final boardSizes = _parseIntSet(opts['board-sizes'] ?? '9,13');
  final problems = problemSet.problems
      .where((problem) => boardSizes.contains(problem.boardSize))
      .take(limit == null || limit == 0 ? problemSet.problems.length : limit)
      .toList();
  final oracleConfig = CaptureAiTacticalOracleConfig(
    depth: _parsePositiveInt(opts['oracle-depth'], fallback: 2),
    candidateHorizon: _parsePositiveInt(opts['oracle-horizon'], fallback: 6),
    maxNodes: _parsePositiveInt(opts['oracle-max-nodes'], fallback: 3000),
    acceptScoreDelta: _parseDouble(opts['top-score-delta'], fallback: 80),
    topNAccepted: _parsePositiveInt(opts['top-n-accepted'], fallback: 3),
    maxAcceptedMoveRatio: _parseDouble(
      opts['max-accepted-move-ratio'],
      fallback: 0.25,
    ),
    minConfidenceGap: _parseDouble(opts['min-confidence-gap'], fallback: 80),
  );
  final repeats = _parsePositiveInt(opts['repeats'], fallback: 3);
  final playouts = _parseIntList(opts['playouts'] ?? '0,24,72,144,288');

  final oracle = CaptureAiTacticalOracle(config: oracleConfig);
  final oracleResults = <CaptureAiOracleResult>[];
  final oracleTimes = <int>[];
  print('=== Capture AI Performance Probe ===');
  print('Problems: ${problems.length}');
  print('Oracle: depth=${oracleConfig.depth} '
      'horizon=${oracleConfig.candidateHorizon} '
      'maxNodes=${oracleConfig.maxNodes}');
  for (final problem in problems) {
    final watch = Stopwatch()..start();
    oracleResults.add(oracle.rankMoves(problem));
    watch.stop();
    oracleTimes.add(watch.elapsedMicroseconds);
  }

  final configs = <_MeasuredConfig>[
    _MeasuredConfig(
      id: 'hunter_beginner',
      config: CaptureAiRobotConfig.forStyle(
        CaptureAiStyle.hunter,
        DifficultyLevel.beginner,
      ),
    ),
    _MeasuredConfig(
      id: 'hunter_intermediate',
      config: CaptureAiRobotConfig.forStyle(
        CaptureAiStyle.hunter,
        DifficultyLevel.intermediate,
      ),
    ),
    _MeasuredConfig(
      id: 'hunter_advanced_default',
      config: CaptureAiRobotConfig.forStyle(
        CaptureAiStyle.hunter,
        DifficultyLevel.advanced,
      ),
    ),
    for (final playout in playouts)
      _MeasuredConfig(
        id: 'hunter_advanced_mcts_$playout',
        config: CaptureAiRobotConfig.forStyle(
          CaptureAiStyle.hunter,
          DifficultyLevel.advanced,
        ).copyWith(mctsPlayouts: playout),
      ),
  ];

  final summaries = <Map<String, Object?>>[];
  for (final measured in configs) {
    final times = <int>[];
    var accepted = 0;
    var authoritativeAccepted = 0;
    var topOne = 0;
    var topThree = 0;
    var severe = 0;
    final totalWatch = Stopwatch()..start();

    for (var i = 0; i < problems.length; i++) {
      final problem = problems[i];
      final oracleResult = oracleResults[i];
      CaptureAiMove? selected;
      for (var repeat = 0; repeat < repeats; repeat++) {
        final board = problem.toBoard();
        final agent = CaptureAiRegistry.createFromConfig(measured.config);
        final watch = Stopwatch()..start();
        final move = agent.chooseMove(board);
        watch.stop();
        times.add(watch.elapsedMicroseconds);
        selected = move;
      }

      final position = selected?.position;
      final oracleMove =
          position == null ? null : oracleResult.moveAt(position);
      final rank = position == null ? null : oracleResult.rankOf(position);
      final best = oracleResult.bestMove;
      final scoreGap = best == null || oracleMove == null
          ? null
          : math.max(0.0, best.score - oracleMove.score);
      final isAccepted = position != null &&
          oracleResult.accepts(
            position,
            scoreDelta: oracleConfig.acceptScoreDelta,
          );
      if (isAccepted) accepted++;
      if (oracleResult.authoritative && isAccepted) authoritativeAccepted++;
      if (rank == 1) topOne++;
      if (rank != null && rank <= 3) topThree++;
      if (scoreGap == null || scoreGap > 1200) severe++;
    }
    totalWatch.stop();

    final authoritativeTotal =
        oracleResults.where((result) => result.authoritative).length;
    final summary = {
      'id': measured.id,
      'engine': measured.config.engine.name,
      'difficulty': measured.config.difficulty.name,
      'mctsPlayouts': measured.config.mctsPlayouts,
      'mctsRolloutDepth': measured.config.mctsRolloutDepth,
      'mctsCandidateLimit': measured.config.mctsCandidateLimit,
      'repeats': repeats,
      'problems': problems.length,
      'accepted': accepted,
      'acceptedRate': _round(accepted / problems.length),
      'authoritativeAccepted': authoritativeAccepted,
      'authoritativeTotal': authoritativeTotal,
      'authoritativeAcceptedRate': authoritativeTotal == 0
          ? null
          : _round(authoritativeAccepted / authoritativeTotal),
      'topOneRate': _round(topOne / problems.length),
      'topThreeRate': _round(topThree / problems.length),
      'severeBlunders': severe,
      'severeBlunderRate': _round(severe / problems.length),
      'timing': _timingSummary(times),
      'wallSeconds': _round(totalWatch.elapsedMicroseconds / 1000000),
    };
    summaries.add(summary);
    print(_formatSummary(summary));
  }

  final output = {
    'schemaVersion': 1,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'problemPath': problemsPath,
    'oracleConfig': oracleConfig.toJson(),
    'problems': problems.length,
    'repeats': repeats,
    'oracleTiming': _timingSummary(oracleTimes),
    'configs': summaries,
  };
  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(output),
  );
  print('Oracle timing: ${jsonEncode(output['oracleTiming'])}');
  print('JSON report: $outputPath');
}

String _formatSummary(Map<String, Object?> summary) {
  final timing = summary['timing']! as Map<String, Object?>;
  return '${summary['id']}: accepted=${_pct(summary['acceptedRate'])} '
      'auth=${_pct(summary['authoritativeAcceptedRate'])} '
      'severe=${summary['severeBlunders']} '
      'median=${timing['medianMs']}ms p90=${timing['p90Ms']}ms '
      'p99=${timing['p99Ms']}ms max=${timing['maxMs']}ms';
}

Map<String, Object?> _timingSummary(List<int> micros) {
  final sorted = [...micros]..sort();
  return {
    'samples': sorted.length,
    'totalSeconds': _round(sorted.fold<int>(0, (sum, v) => sum + v) / 1000000),
    'meanMs':
        _round(sorted.fold<int>(0, (sum, v) => sum + v) / sorted.length / 1000),
    'medianMs': _round(_percentile(sorted, 0.50) / 1000),
    'p90Ms': _round(_percentile(sorted, 0.90) / 1000),
    'p95Ms': _round(_percentile(sorted, 0.95) / 1000),
    'p99Ms': _round(_percentile(sorted, 0.99) / 1000),
    'maxMs': _round(sorted.last / 1000),
  };
}

double _percentile(List<int> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final index = ((sorted.length - 1) * p).round();
  return sorted[index].toDouble();
}

String _pct(Object? value) {
  final number = value is num ? value.toDouble() : 0.0;
  return '${(number * 100).toStringAsFixed(1)}%';
}

double _round(double value) => double.parse(value.toStringAsFixed(3));

Map<String, String> _parseArgs(List<String> args) {
  final opts = <String, String>{};
  for (final arg in args) {
    if (arg == '--help' || arg == '-h') {
      opts['help'] = 'true';
      continue;
    }
    if (!arg.startsWith('--')) continue;
    final eq = arg.indexOf('=');
    if (eq == -1) {
      opts[arg.substring(2)] = 'true';
    } else {
      opts[arg.substring(2, eq)] = arg.substring(eq + 1);
    }
  }
  return opts;
}

Set<int> _parseIntSet(String value) => _parseIntList(value).toSet();

List<int> _parseIntList(String value) {
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList();
}

int _parsePositiveInt(String? value, {required int fallback}) {
  if (value == null || value.isEmpty) return fallback;
  final parsed = int.parse(value);
  if (parsed < 1) throw FormatException('Expected positive int: $value');
  return parsed;
}

double _parseDouble(String? value, {required double fallback}) {
  if (value == null || value.isEmpty) return fallback;
  return double.parse(value);
}

void _printUsage() {
  print('Usage: dart run tool/capture_ai_performance_probe.dart '
      '--output=<path> [--repeats=3] [--playouts=0,24,72,144,288]');
}

class _MeasuredConfig {
  const _MeasuredConfig({
    required this.id,
    required this.config,
  });

  final String id;
  final CaptureAiRobotConfig config;
}
