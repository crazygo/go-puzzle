// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/capture_ai_scripted_trials.dart';
import 'package:go_puzzle/game/difficulty_level.dart';

void main(List<String> args) {
  final opts = _parseArgs(args);
  if (opts.containsKey('help')) {
    _printUsage();
    return;
  }

  final style = _parseStyle(opts['style'] ?? 'hunter');
  final difficulty = _parseDifficulty(opts['difficulty'] ?? 'advanced');
  final boardSizes = _parseIntList(
    opts['board-sizes'] ?? opts['board-size'] ?? '9',
    fallback: const [9],
  );
  final captureTarget = _parseInt(opts['capture-target'] ?? '5', fallback: 5);
  final maxMoves = _parseInt(opts['max-moves'] ?? '180', fallback: 180);
  final maxAiMoveMs = opts.containsKey('max-ai-move-ms')
      ? _parseInt(opts['max-ai-move-ms'] ?? '5000', fallback: 5000)
      : null;
  final aiSides = _parseAiSides(opts['ai-side'] ?? 'white');
  final openingFilter = _parseNameSet(opts['openings']);
  final tacticFilter = _parseNameSet(opts['tactics']);
  final includeMoves = opts.containsKey('include-moves');
  final verbose = opts.containsKey('verbose');

  final config = CaptureAiRobotConfig.forStyle(style, difficulty);
  final runner = CaptureAiScriptedTrialRunner(aiConfig: config);
  final results = <CaptureAiScriptedTrialResult>[];

  for (final boardSize in boardSizes) {
    for (final aiSide in aiSides) {
      final trials = CaptureAiScriptedTrialCatalog.defaults(
        boardSize: boardSize,
        captureTarget: captureTarget,
        aiSide: aiSide,
        maxMoves: maxMoves,
      ).where((trial) {
        final openingAllowed =
            openingFilter == null || openingFilter.contains(trial.opening.name);
        final tacticAllowed =
            tacticFilter == null || tacticFilter.contains(trial.tactic.name);
        return openingAllowed && tacticAllowed;
      }).toList();

      for (final trial in trials) {
        final result = runner.run(
          trial,
          maxAiMoveDuration:
              maxAiMoveMs == null ? null : Duration(milliseconds: maxAiMoveMs),
        );
        results.add(result);
        if (verbose || !result.aiDidNotLose) {
          print(_formatResult(result));
        }
      }
    }
  }

  final passed = results.where((result) => result.aiDidNotLose).length;
  final failed = results.length - passed;
  final timing = _timingSummary(results);
  print('=== Capture AI Scripted Trials Probe ===');
  print('AI: ${style.name}/${difficulty.name}');
  print('Boards: ${boardSizes.join(',')} captureTarget=$captureTarget');
  print('Trials: ${results.length}, passed=$passed, failed=$failed');
  print('AI timing: max=${timing['maxMoveMs']}ms '
      'p95=${timing['p95MoveMs']}ms p99=${timing['p99MoveMs']}ms '
      'slow=${timing['slowMovesOverLimit']}');

  final outputPath = opts['output'];
  if (outputPath != null && outputPath.isNotEmpty) {
    final output = {
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'ai': {
        'id': config.id,
        'style': config.style.name,
        'difficulty': config.difficulty.name,
        'engine': config.engine.name,
        'mctsPlayouts': config.mctsPlayouts,
        'mctsRolloutDepth': config.mctsRolloutDepth,
        'mctsCandidateLimit': config.mctsCandidateLimit,
      },
      'summary': {
        'trials': results.length,
        'passed': passed,
        'failed': failed,
        'scoreRate': _roundRate(passed, results.length),
        ...timing,
      },
      'byBoard': _groupSummary(
        results,
        (result) => result.trial.boardSize.toString(),
      ),
      'byPolicy': _groupSummary(
        results,
        (result) => result.trial.tactic.name,
      ),
      'bySide': _groupSummary(
        results,
        (result) => result.trial.aiSide.name,
      ),
      'failures': [
        for (final result in results.where((result) => !result.aiDidNotLose))
          {
            'id': result.trial.id,
            'boardSize': result.trial.boardSize,
            'policy': result.trial.tactic.name,
            'opening': result.trial.opening.name,
            'aiSide': result.trial.aiSide.name,
            'winner': result.winner.name,
            'endReason': result.endReason.name,
            'blackCaptures': result.blackCaptures,
            'whiteCaptures': result.whiteCaptures,
            'totalMoves': result.totalMoves,
            'maxAiMoveMs': result.maxAiMoveMs,
            'slowAiMovesOverLimit': result.slowAiMovesOverLimit,
          },
      ],
      'results': [
        for (final result in results) result.toJson(includeMoves: includeMoves),
      ],
    };
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
    print('JSON report: $outputPath');
  }

  if (failed > 0) {
    exitCode = 1;
  }
}

String _formatResult(CaptureAiScriptedTrialResult result) {
  final trial = result.trial;
  return '${result.aiDidNotLose ? 'PASS' : 'FAIL'} ${trial.id}: '
      'winner=${result.winner.name} end=${result.endReason.name} '
      'captures=${result.blackCaptures}-${result.whiteCaptures} '
      'moves=${result.totalMoves} aiSide=${trial.aiSide.name} '
      'maxAi=${result.maxAiMoveMs}ms slow=${result.slowAiMovesOverLimit}';
}

CaptureAiStyle _parseStyle(String value) {
  return CaptureAiStyle.values.firstWhere(
    (style) => style.name == value,
    orElse: () {
      stderr.writeln('ERROR: --style must be one of '
          '${CaptureAiStyle.values.map((style) => style.name).join(', ')}');
      exit(2);
    },
  );
}

DifficultyLevel _parseDifficulty(String value) {
  return DifficultyLevel.values.firstWhere(
    (difficulty) => difficulty.name == value,
    orElse: () {
      stderr.writeln('ERROR: --difficulty must be one of '
          '${DifficultyLevel.values.map((level) => level.name).join(', ')}');
      exit(2);
    },
  );
}

List<CaptureAiTrialSide> _parseAiSides(String value) {
  if (value == 'both') return CaptureAiTrialSide.values;
  return [
    CaptureAiTrialSide.values.firstWhere(
      (side) => side.name == value,
      orElse: () {
        stderr.writeln('ERROR: --ai-side must be black, white, or both.');
        exit(2);
      },
    ),
  ];
}

Set<String>? _parseNameSet(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet();
}

int _parseInt(String value, {required int fallback}) {
  return int.tryParse(value) ?? fallback;
}

List<int> _parseIntList(String value, {required List<int> fallback}) {
  final parsed = value
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .toList();
  return parsed.isEmpty ? fallback : parsed;
}

Map<String, Object?> _timingSummary(
    List<CaptureAiScriptedTrialResult> results) {
  final durations = [
    for (final result in results) ...result.aiMoveDurationsMs,
  ]..sort();
  final slowMoves = results.fold<int>(
    0,
    (sum, result) => sum + result.slowAiMovesOverLimit,
  );
  return {
    'aiMoveSamples': durations.length,
    'maxMoveMs': durations.isEmpty ? 0 : durations.last,
    'p95MoveMs': _percentile(durations, 0.95),
    'p99MoveMs': _percentile(durations, 0.99),
    'slowMovesOverLimit': slowMoves,
  };
}

int _percentile(List<int> sorted, double percentile) {
  if (sorted.isEmpty) return 0;
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index.clamp(0, sorted.length - 1)];
}

Map<String, Object?> _groupSummary(
  List<CaptureAiScriptedTrialResult> results,
  String Function(CaptureAiScriptedTrialResult result) keyFor,
) {
  final groups = <String, List<CaptureAiScriptedTrialResult>>{};
  for (final result in results) {
    groups.putIfAbsent(keyFor(result), () => []).add(result);
  }
  final entries = groups.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return {
    for (final entry in entries)
      entry.key: {
        'trials': entry.value.length,
        'passed': entry.value.where((result) => result.aiDidNotLose).length,
        'failed': entry.value.where((result) => !result.aiDidNotLose).length,
        'scoreRate': _roundRate(
          entry.value.where((result) => result.aiDidNotLose).length,
          entry.value.length,
        ),
        ..._timingSummary(entry.value),
      },
  };
}

double _roundRate(int numerator, int denominator) {
  if (denominator == 0) return 0;
  return ((numerator / denominator) * 10000).round() / 10000;
}

Map<String, String> _parseArgs(List<String> args) {
  final opts = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      opts[key] = args[i + 1];
      i++;
    } else {
      opts[key] = '';
    }
  }
  return opts;
}

void _printUsage() {
  print('Usage: dart run tool/capture_ai_scripted_trials_probe.dart [options]');
  print('');
  print('Options:');
  print('  --style <name>          AI style, default hunter');
  print(
      '  --difficulty <name>     beginner/intermediate/advanced, default advanced');
  print('  --board-size <n>        Board size, default 9');
  print('  --board-sizes <csv>     Board sizes, overrides --board-size');
  print('  --capture-target <n>    Capture target, default 5');
  print('  --max-moves <n>         Max moves per trial, default 180');
  print('  --max-ai-move-ms <n>    Fail trial when an AI move exceeds this');
  print('  --ai-side <side>        black, white, or both; default white');
  print('  --openings <csv>        Filter openings by enum name');
  print('  --tactics <csv>         Filter tactics by enum name');
  print('  --output <path>         Write JSON report');
  print('  --include-moves         Include move trace in JSON output');
  print('  --verbose               Print every trial, not only failures');
}
