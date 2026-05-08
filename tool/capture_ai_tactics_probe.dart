// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

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

  try {
    final boardSizes = _parseBoardSizes(opts['board-sizes'] ?? '9,13');
    final styles = _parseStyles(opts['style'] ?? opts['styles'] ?? 'all');
    final difficulties = _parseDifficulties(
      opts['difficulty'] ?? opts['difficulties'] ?? 'advanced',
    );
    final oracleConfig = CaptureAiTacticalOracleConfig(
      depth: _parsePositiveInt(opts['oracle-depth'], fallback: 4),
      candidateHorizon: _parsePositiveInt(opts['oracle-horizon'], fallback: 10),
      maxNodes: _parsePositiveInt(opts['oracle-max-nodes'], fallback: 25000),
      acceptScoreDelta: _parseNonNegativeDouble(
        opts['top-score-delta'],
        fallback: 150,
      ),
      topNAccepted: opts['top-n-accepted'] == null
          ? null
          : _parsePositiveInt(opts['top-n-accepted'], fallback: 0),
      maxAcceptedMoveRatio: _parseRatio(
        opts['max-accepted-move-ratio'],
        fallback: 0.25,
      ),
      minConfidenceGap: _parseNonNegativeDouble(
        opts['min-confidence-gap'],
        fallback: 300,
      ),
    );
    final limit = opts['limit'] == null
        ? null
        : _parsePositiveInt(opts['limit'], fallback: 0);
    final splitFilter = _parseSet(opts['splits']);
    final problemFilter = _parseSet(opts['problems-filter'] ?? opts['ids']);
    final expectedCaptureTarget = _parsePositiveInt(
      opts['capture-target'],
      fallback: 5,
    );

    final problemSet = CaptureAiTacticsProblemSet.fromJsonString(
      problemsFile.readAsStringSync(),
    );
    _validateCaptureTarget(problemSet.problems, expectedCaptureTarget);
    final filteredProblems = problemSet.problems.where((problem) {
      if (splitFilter != null && !splitFilter.contains(problem.split)) {
        return false;
      }
      if (problemFilter != null && !problemFilter.contains(problem.id)) {
        return false;
      }
      return true;
    }).toList();

    final evaluator = CaptureAiTacticsEvaluator(
      oracle: CaptureAiTacticalOracle(config: oracleConfig),
    );
    final report = evaluator.evaluate(
      problems: filteredProblems,
      styles: styles,
      difficulties: difficulties,
      boardSizes: boardSizes,
      limit: limit == 0 ? null : limit,
    );

    _writeReport(
      outputPath,
      report.toJson(
        generatedAt: DateTime.now().toUtc(),
        problemPath: problemsPath,
      ),
    );
    _printSummary(
      report,
      problemsPath: problemsPath,
      outputPath: outputPath,
    );
  } on CaptureAiTacticsFormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 2;
  } on FormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 2;
  } on FileSystemException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 1;
  }
}

void _printSummary(
  CaptureAiTacticsReport report, {
  required String problemsPath,
  required String outputPath,
}) {
  final summary = report.summary;
  print('=== Capture AI Tactics Probe ===');
  print('Problems: $problemsPath');
  print('Evaluated problems: ${summary.problems}');
  print('Authoritative problems: ${summary.authoritativeProblems}');
  print('Board sizes: ${report.boardSizes.join(', ')}');
  print(
    'Oracle: depth=${report.oracleConfig.depth}, '
    'horizon=${report.oracleConfig.candidateHorizon}, '
    'maxNodes=${report.oracleConfig.maxNodes}, '
    'acceptedDelta=${report.oracleConfig.acceptScoreDelta}, '
    'topNAccepted=${report.oracleConfig.topNAccepted ?? 'none'}, '
    'maxAcceptedRatio=${report.oracleConfig.maxAcceptedMoveRatio}, '
    'minConfidenceGap=${report.oracleConfig.minConfidenceGap}',
  );
  print(
    'Oracle confidence: avgAcceptedMoves='
    '${summary.averageAcceptedMoveCount.toStringAsFixed(2)}, '
    'avgAcceptedRatio=${_pct(summary.averageAcceptedMoveRatio)}, '
    'avgAcceptedBandGap=${summary.averageAcceptedBandGap.toStringAsFixed(1)}',
  );
  print('');

  print('Config summary');
  print(
      'Config                    Top1    Top3    AcceptedAll  AcceptedAuth  MedRank  P90Rank  MedGap   P90Gap   Blunders');
  for (final config in summary.configs) {
    final id = '${config.style.name}_${config.difficulty.name}'.padRight(25);
    print(
      '$id '
      '${_pct(config.topOneRate).padLeft(7)} '
      '${_pct(config.topThreeRate).padLeft(7)} '
      '${_pct(config.acceptedRate).padLeft(13)} '
      '${_pct(config.authoritativeAcceptedRate).padLeft(13)} '
      '${config.medianRank.toStringAsFixed(1).padLeft(8)} '
      '${config.p90Rank.toStringAsFixed(1).padLeft(8)} '
      '${config.medianScoreGap.toStringAsFixed(1).padLeft(7)} '
      '${config.p90ScoreGap.toStringAsFixed(1).padLeft(8)} '
      '${config.severeBlunders.toString().padLeft(9)}',
    );
  }

  if (summary.difficulties.isNotEmpty) {
    print('');
    print('Difficulty summary');
    print(
        'Difficulty                Top1    Top3    AcceptedAll  MedRank  MedGap   BlunderRate');
    for (final difficulty in summary.difficulties) {
      print(
        '${difficulty.name.padRight(25)} '
        '${_pct(difficulty.topOneRate).padLeft(7)} '
        '${_pct(difficulty.topThreeRate).padLeft(7)} '
        '${_pct(difficulty.acceptedRate).padLeft(13)} '
        '${difficulty.medianRank.toStringAsFixed(1).padLeft(8)} '
        '${difficulty.medianScoreGap.toStringAsFixed(1).padLeft(7)} '
        '${_pct(difficulty.severeBlunderRate).padLeft(11)}',
      );
    }
  }

  if (summary.difficultyDeltas.isNotEmpty) {
    print('');
    print('Per-difficulty deltas');
    print(
        'Style      From->To                 Top1    Top3    Accepted  MedRank  MedGap   Blunders');
    for (final delta in summary.difficultyDeltas) {
      final transition =
          '${delta.fromDifficulty.name}->${delta.toDifficulty.name}';
      print(
        '${delta.style.name.padRight(10)} '
        '${transition.padRight(24)} '
        '${_signedPct(delta.topOneRateDelta).padLeft(7)} '
        '${_signedPct(delta.topThreeRateDelta).padLeft(7)} '
        '${_signedPct(delta.acceptedRateDelta).padLeft(9)} '
        '${_signed(delta.medianRankDelta).padLeft(8)} '
        '${_signed(delta.medianScoreGapDelta).padLeft(7)} '
        '${_signedPct(delta.severeBlunderRateDelta).padLeft(9)}',
      );
    }
  }

  if (summary.categories.isNotEmpty) {
    print('');
    print('Category summary');
    print(
        'Category                  Config                    AcceptedAll  AcceptedAuth  Blunders');
    for (final category in summary.categories) {
      print(
        '${category.category.padRight(25)} '
        '${category.configId.padRight(25)} '
        '${_pct(category.acceptedRate).padLeft(13)} '
        '${_pct(category.authoritativeAcceptedRate).padLeft(13)} '
        '${category.severeBlunders.toString().padLeft(9)}',
      );
    }
  }

  if (summary.tactics.isNotEmpty) {
    print('');
    print('Named tactic summary');
    print(
        'Tactic                    Config                    Top1    Top3    AcceptedAll  AcceptedAuth  Blunders');
    for (final tactic in summary.tactics) {
      print(
        '${tactic.tactic.padRight(25)} '
        '${tactic.configId.padRight(25)} '
        '${_pct(tactic.topOneRate).padLeft(7)} '
        '${_pct(tactic.topThreeRate).padLeft(7)} '
        '${_pct(tactic.acceptedRate).padLeft(13)} '
        '${_pct(tactic.authoritativeAcceptedRate).padLeft(13)} '
        '${tactic.severeBlunders.toString().padLeft(9)}',
      );
    }
  }

  final blunders = [
    for (final result in report.results)
      for (final ai in result.aiResults)
        if (ai.severeBlunder) (problem: result.problem, ai: ai)
  ];
  if (blunders.isNotEmpty) {
    print('');
    print('Severe blunders');
    for (final entry in blunders.take(12)) {
      final move = entry.ai.move == null
          ? 'none'
          : 'r${entry.ai.move!.row + 1}c${entry.ai.move!.col + 1}';
      print(
        '${entry.problem.id}: ${entry.ai.configId} chose $move '
        'rank=${entry.ai.rank ?? '-'} gap=${entry.ai.scoreGap?.toStringAsFixed(1) ?? '-'}',
      );
    }
    if (blunders.length > 12) {
      print('... ${blunders.length - 12} more in JSON report');
    }
  }

  print('');
  print('JSON report: $outputPath');
}

void _writeReport(String outputPath, Map<String, Object?> report) {
  final file = File(outputPath);
  final parent = file.parent;
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(report)}\n');
}

List<int> _parseBoardSizes(String value) {
  final sizes = value
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .toList();
  if (sizes.isEmpty) {
    throw const FormatException('--board-sizes must include 9 and/or 13.');
  }
  for (final size in sizes) {
    if (size != 9 && size != 13) {
      throw FormatException(
        '--board-sizes supports only 9 and 13; got $size.',
      );
    }
  }
  return sizes.toSet().toList()..sort();
}

List<CaptureAiStyle> _parseStyles(String value) {
  final names = _parseNames(value);
  if (names.contains('all')) return CaptureAiStyle.values;
  return [
    for (final name in names) _parseStyle(name),
  ];
}

CaptureAiStyle _parseStyle(String name) {
  for (final style in CaptureAiStyle.values) {
    if (style.name == name) return style;
  }
  throw FormatException(
    '--styles must use: all, '
    '${CaptureAiStyle.values.map((style) => style.name).join(', ')}.',
  );
}

List<DifficultyLevel> _parseDifficulties(String value) {
  final names = _parseNames(value);
  if (names.contains('all')) return DifficultyLevel.values;
  return [
    for (final name in names) _parseDifficulty(name),
  ];
}

DifficultyLevel _parseDifficulty(String name) {
  for (final difficulty in DifficultyLevel.values) {
    if (difficulty.name == name) return difficulty;
  }
  throw FormatException(
    '--difficulty must use: all, '
    '${DifficultyLevel.values.map((level) => level.name).join(', ')}.',
  );
}

List<String> _parseNames(String value) {
  final names = value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (names.isEmpty) throw const FormatException('Empty filter value.');
  return names;
}

Set<String>? _parseSet(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return _parseNames(value).toSet();
}

int _parsePositiveInt(String? value, {required int fallback}) {
  if (value == null) return fallback;
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 1) {
    throw FormatException('Expected a positive integer, got "$value".');
  }
  return parsed;
}

double _parseNonNegativeDouble(String? value, {required double fallback}) {
  if (value == null) return fallback;
  final parsed = double.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw FormatException('Expected a non-negative number, got "$value".');
  }
  return parsed;
}

double _parseRatio(String? value, {required double fallback}) {
  if (value == null) return fallback;
  final parsed = double.tryParse(value);
  if (parsed == null || parsed < 0 || parsed > 1) {
    throw FormatException('Expected a ratio from 0 to 1, got "$value".');
  }
  return parsed;
}

void _validateCaptureTarget(
  List<CaptureAiTacticsProblem> problems,
  int expectedCaptureTarget,
) {
  final mismatches = problems
      .where((problem) => problem.captureTarget != expectedCaptureTarget)
      .take(5)
      .toList();
  if (mismatches.isNotEmpty) {
    final examples = mismatches
        .map((problem) => '${problem.id}:${problem.captureTarget}')
        .join(', ');
    throw FormatException(
      'This probe is configured for captureTarget=$expectedCaptureTarget, '
      'but the problem set contains other targets: $examples.',
    );
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final opts = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) {
      throw FormatException('Unexpected argument "$arg".');
    }
    final raw = arg.substring(2);
    if (raw == 'help') {
      opts['help'] = 'true';
      continue;
    }
    final equals = raw.indexOf('=');
    if (equals >= 0) {
      opts[raw.substring(0, equals)] = raw.substring(equals + 1);
      continue;
    }
    if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
      throw FormatException('Missing value for --$raw.');
    }
    opts[raw] = args[++i];
  }
  return opts;
}

String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _signedPct(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${_pct(value)}';
}

String _signed(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}';
}

void _printUsage() {
  print('Usage: dart run tool/capture_ai_tactics_probe.dart --output=<path> '
      '[options]');
  print('');
  print('Options:');
  print('  --problems=<path>          Default: $_defaultProblemsPath');
  print('  --output=<path>            Required JSON report path');
  print('  --board-sizes=9,13         Only 9 and 13 are accepted');
  print('  --capture-target=5         Required target for all loaded problems');
  print('  --styles=all|hunter,...    Default: all');
  print(
      '  --difficulty=advanced      One of beginner, intermediate, advanced, all');
  print('  --oracle-depth=4           Minimax depth in plies');
  print('  --oracle-horizon=10        Tactical candidates considered per node');
  print('  --oracle-max-nodes=25000   Node cap per problem');
  print('  --top-score-delta=150      Accepted score gap from oracle best');
  print('  --top-n-accepted=<n>       Also require accepted moves to be top N');
  print('  --max-accepted-move-ratio=0.25');
  print('                              Max accepted-band share for authority');
  print('  --min-confidence-gap=300   Required accepted-band oracle gap');
  print('  --splits=train,holdout     Optional split filter');
  print('  --ids=problem_id,...       Optional problem id filter');
  print('  --limit=<n>                Optional problem limit');
}
