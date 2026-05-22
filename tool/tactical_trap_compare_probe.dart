// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final opts = _parseArgs(args);
  final beforePath = opts['before'] ??
      'docs/ai_eval/runs/2026-05-22-tactical-trap-expanded-baseline.json';
  final afterPath = opts['after'] ??
      'docs/ai_eval/runs/2026-05-22-tactical-trap-after-low-liberty-rescue-penalty.json';
  final outPath = opts['out'];

  final before =
      jsonDecode(File(beforePath).readAsStringSync()) as Map<String, dynamic>;
  final after =
      jsonDecode(File(afterPath).readAsStringSync()) as Map<String, dynamic>;

  final beforeSummaries =
      (before['summaries'] as List<dynamic>).cast<Map<String, dynamic>>();
  final afterSummaries =
      (after['summaries'] as List<dynamic>).cast<Map<String, dynamic>>();
  final afterByConfig = {
    for (final summary in afterSummaries)
      summary['configId'] as String: summary,
  };

  final comparisons = <Map<String, Object?>>[];
  for (final beforeSummary in beforeSummaries) {
    final configId = beforeSummary['configId'] as String;
    final afterSummary = afterByConfig[configId];
    if (afterSummary == null) continue;
    comparisons.add(_compareConfig(configId, beforeSummary, afterSummary));
  }

  final output = {
    'schemaVersion': 1,
    'probe': 'tactical_trap_compare_probe_v1',
    'beforePath': beforePath,
    'afterPath': afterPath,
    'beforeSampleCount': before['sampleCount'],
    'afterSampleCount': after['sampleCount'],
    'comparisonMode': 'sample_id_intersection',
    'comparisons': comparisons,
  };

  final encoded = const JsonEncoder.withIndent('  ').convert(output);
  if (outPath == null) {
    print(encoded);
  } else {
    File(outPath)
      ..createSync(recursive: true)
      ..writeAsStringSync('$encoded\n');
    print('WROTE $outPath');
  }
}

Map<String, Object?> _compareConfig(
  String configId,
  Map<String, dynamic> beforeSummary,
  Map<String, dynamic> afterSummary,
) {
  final beforeResults =
      _resultsBySampleId(beforeSummary['results'] as List<dynamic>);
  final afterResults =
      _resultsBySampleId(afterSummary['results'] as List<dynamic>);
  final sampleIds = beforeResults.keys
      .where(afterResults.containsKey)
      .toList(growable: false)
    ..sort();

  final beforeCounters = _count(sampleIds.map((id) => beforeResults[id]!));
  final afterCounters = _count(sampleIds.map((id) => afterResults[id]!));
  return {
    'configId': configId,
    'comparedSamples': sampleIds.length,
    'before': beforeCounters.toJson(),
    'after': afterCounters.toJson(),
    'delta': {
      'provenFailures':
          afterCounters.provenFailures - beforeCounters.provenFailures,
      'blunders': afterCounters.blunders - beforeCounters.blunders,
      'accepted': afterCounters.accepted - beforeCounters.accepted,
      'trapBlunderRate':
          afterCounters.trapBlunderRate - beforeCounters.trapBlunderRate,
      'acceptedMoveRate':
          afterCounters.acceptedMoveRate - beforeCounters.acceptedMoveRate,
      'provenFailureReductionRate': beforeCounters.provenFailures == 0
          ? null
          : (beforeCounters.provenFailures - afterCounters.provenFailures) /
              beforeCounters.provenFailures,
    },
  };
}

Map<String, Map<String, dynamic>> _resultsBySampleId(List<dynamic> results) => {
      for (final result in results.cast<Map<String, dynamic>>())
        result['sampleId'] as String: result,
    };

_Counters _count(Iterable<Map<String, dynamic>> results) {
  final counters = _Counters();
  for (final result in results) {
    counters.samples++;
    if (result['legal'] == true) counters.legalMoves++;
    if (result['blunder'] == true) counters.blunders++;
    if (result['provenFailure'] == true) counters.provenFailures++;
    if (result['accepted'] == true) counters.accepted++;
  }
  return counters;
}

Map<String, String> _parseArgs(List<String> args) {
  final parsed = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    final next = i + 1 < args.length ? args[i + 1] : null;
    if (next != null && !next.startsWith('--')) {
      parsed[key] = next;
      i++;
    } else {
      parsed[key] = 'true';
    }
  }
  return parsed;
}

class _Counters {
  int samples = 0;
  int legalMoves = 0;
  int blunders = 0;
  int provenFailures = 0;
  int accepted = 0;

  double get trapBlunderRate => samples == 0 ? 0 : blunders / samples;

  double get acceptedMoveRate => samples == 0 ? 0 : accepted / samples;

  Map<String, Object?> toJson() => {
        'samples': samples,
        'legalMoves': legalMoves,
        'illegalOrNoMove': samples - legalMoves,
        'blunders': blunders,
        'provenFailures': provenFailures,
        'accepted': accepted,
        'trapBlunderRate': trapBlunderRate,
        'acceptedMoveRate': acceptedMoveRate,
      };
}
