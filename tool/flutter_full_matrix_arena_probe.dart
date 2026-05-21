// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';
import 'package:go_puzzle/game/katago_flutter_onnx_model_adapter.dart';

const _repeatCount = 2;
const _matchSeed = 20260519;
const _openingSeed = 0;

const _openings = [
  ('empty', 'empty_v1'),
  ('cross', 'cross_v1'),
  ('twistCross', 'twist_cross_v1'),
];

void main() {
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  String _status = 'running';
  String _summary = '';

  @override
  void initState() {
    super.initState();
    _runProbe();
  }

  Future<void> _runProbe() async {
    final adapter = FlutterKatagoOnnxModelAdapter();
    try {
      final query = Uri.base.queryParameters;
      final startCell = int.tryParse(query['startCell'] ?? '') ?? 0;
      final endCell = int.tryParse(query['endCell'] ?? '') ?? 1 << 30;
      final configs = AiAlgorithmRegistry.configs;
      final matches = <AiMatchResult>[];
      final cells = <Map<String, Object?>>[];
      var cellIndex = 0;

      for (var i = 0; i < configs.length - 1; i++) {
        for (var j = i + 1; j < configs.length; j++) {
          final left = configs[i];
          final right = configs[j];
          for (final (openingName, openingPolicy) in _openings) {
            for (final firstConfig in [left, right]) {
              final secondConfig = identical(firstConfig, left) ? right : left;
              if (cellIndex < startCell || cellIndex >= endCell) {
                cellIndex++;
                continue;
              }
              final executor = AiArenaExecutor(
                boardSize: 9,
                captureTarget: 5,
                rounds: _repeatCount,
                maxMoves: 120,
                openingPolicy: openingPolicy,
              );
              final match = await executor.runFrameworkMatchAsync(
                configA: firstConfig,
                configB: secondConfig,
                matchSeed: _matchSeed + cellIndex * 7919,
                openingSeed: _openingSeed,
                alternateColors: false,
                asyncKatagoModelAdapter: adapter,
              );
              matches.add(match);
              cells.add(_cellJson(
                index: cellIndex,
                opening: openingName,
                firstConfigId: firstConfig.id,
                secondConfigId: secondConfig.id,
                match: match,
              ));
              cellIndex++;
            }
          }
        }
      }

      final summary = AiArenaEvaluationSummary.fromMatches(matches);
      final output = {
        'metadata': {
          'probe': 'flutter_full_matrix_arena_probe_v1',
          'configs': configs.map((config) => config.id).toList(),
          'openings': _openings.map((opening) => opening.$1).toList(),
          'repeatCount': _repeatCount,
          'totalCells': _expectedCells(configs.length),
          'startCell': startCell,
          'endCell': endCell,
          'selectedCells': cells.length,
          'expectedGames': cells.length * _repeatCount,
          'totalExpectedGames': _expectedGames(configs.length),
          'actualGames': _actualGames(matches),
          'matchSeed': _matchSeed,
          'openingSeed': _openingSeed,
          'boardSize': 9,
          'captureTarget': 5,
          'maxMoves': 120,
        },
        'matrixCells': cells,
        'pairwiseOverall': _pairwiseOverall(cells),
        'perOpeningPerformance': _perOpeningPerformance(cells),
        'perFirstPlayerPerformance': _perFirstPlayerPerformance(cells),
        'summary': summary.toJson(),
      };
      final json = const JsonEncoder.withIndent('  ').convert(output);
      print('FULL_MATRIX_ARENA_PROBE_JSON_BEGIN');
      print(json);
      print('FULL_MATRIX_ARENA_PROBE_JSON_END');
      if (mounted) {
        setState(() {
          _status = 'complete';
          _summary = _shortSummary(output);
        });
      }
    } catch (error, stackTrace) {
      final failure = const JsonEncoder.withIndent('  ').convert({
        'status': 'failed',
        'failureReason': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
      print('FULL_MATRIX_ARENA_PROBE_JSON_BEGIN');
      print(failure);
      print('FULL_MATRIX_ARENA_PROBE_JSON_END');
      if (mounted) {
        setState(() {
          _status = 'failed';
          _summary = failure;
        });
      }
    } finally {
      await adapter.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Full AI Config Matrix Probe: $_status'),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(_summary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Map<String, Object?> _cellJson({
  required int index,
  required String opening,
  required String firstConfigId,
  required String secondConfigId,
  required AiMatchResult match,
}) {
  final illegalMoves = match.games.where((game) => game.illegalMove).length;
  final timeouts = match.games.where((game) => game.timedOut).length;
  final fallbackGames = match.games.where((game) => game.fallbackUsed).length;
  final failureReasons = match.games
      .map((game) => game.failureReason)
      .whereType<String>()
      .toSet()
      .toList()
    ..sort();
  return {
    'index': index,
    'pairId': _pairId(firstConfigId, secondConfigId),
    'opening': opening,
    'firstConfigId': firstConfigId,
    'secondConfigId': secondConfigId,
    'repeats': match.rounds,
    'firstWins': match.aWins,
    'secondWins': match.bWins,
    'draws': match.draws,
    'firstWinRate': match.aWinRate,
    'secondWinRate': match.bWinRate,
    'illegalMoves': illegalMoves,
    'timeouts': timeouts,
    'fallbackGames': fallbackGames,
    'failureReasons': failureReasons,
    'games': match.games.map((game) => game.toJson()).toList(),
  };
}

List<Map<String, Object?>> _pairwiseOverall(List<Map<String, Object?>> cells) {
  final scores = <String, _Score>{};
  for (final cell in cells) {
    final first = cell['firstConfigId']! as String;
    final second = cell['secondConfigId']! as String;
    final pairId = cell['pairId']! as String;
    final score = scores.putIfAbsent(pairId, () => _Score(pairId: pairId));
    score.add(
      firstConfigId: first,
      secondConfigId: second,
      firstWins: cell['firstWins']! as int,
      secondWins: cell['secondWins']! as int,
      draws: cell['draws']! as int,
      illegalMoves: cell['illegalMoves']! as int,
      timeouts: cell['timeouts']! as int,
      fallbackGames: cell['fallbackGames']! as int,
      failureReasons: _failureReasonsFor(cell),
    );
  }
  return scores.values.map((score) => score.toJson()).toList()
    ..sort(
        (a, b) => (a['pairId']! as String).compareTo(b['pairId']! as String));
}

List<Map<String, Object?>> _perOpeningPerformance(
  List<Map<String, Object?>> cells,
) {
  final scores = <String, _Score>{};
  for (final cell in cells) {
    final opening = cell['opening']! as String;
    final first = cell['firstConfigId']! as String;
    final second = cell['secondConfigId']! as String;
    for (final configId in [first, second]) {
      final key = '$opening::$configId';
      final score = scores.putIfAbsent(
        key,
        () => _Score(opening: opening, configId: configId),
      );
      score.addConfigPerspective(
        configId: configId,
        firstConfigId: first,
        secondConfigId: second,
        firstWins: cell['firstWins']! as int,
        secondWins: cell['secondWins']! as int,
        draws: cell['draws']! as int,
        illegalMoves: cell['illegalMoves']! as int,
        timeouts: cell['timeouts']! as int,
        fallbackGames: cell['fallbackGames']! as int,
        failureReasons: _failureReasonsFor(cell),
      );
    }
  }
  return scores.values.map((score) => score.toJson()).toList()
    ..sort((a, b) {
      final opening = (a['opening']! as String).compareTo(
        b['opening']! as String,
      );
      if (opening != 0) return opening;
      return (a['configId']! as String).compareTo(b['configId']! as String);
    });
}

List<Map<String, Object?>> _perFirstPlayerPerformance(
  List<Map<String, Object?>> cells,
) {
  final scores = <String, _Score>{};
  for (final cell in cells) {
    final first = cell['firstConfigId']! as String;
    final score = scores.putIfAbsent(
      first,
      () => _Score(firstConfigId: first),
    );
    score.addFirstPlayer(
      wins: cell['firstWins']! as int,
      losses: cell['secondWins']! as int,
      draws: cell['draws']! as int,
      illegalMoves: cell['illegalMoves']! as int,
      timeouts: cell['timeouts']! as int,
      fallbackGames: cell['fallbackGames']! as int,
      failureReasons: _failureReasonsFor(cell),
    );
  }
  return scores.values.map((score) => score.toJson()).toList()
    ..sort(
      (a, b) => (a['firstConfigId']! as String).compareTo(
        b['firstConfigId']! as String,
      ),
    );
}

String _shortSummary(Map<String, Object?> output) {
  final metadata = output['metadata']! as Map<String, Object?>;
  final pairwise = output['pairwiseOverall']! as List<Map<String, Object?>>;
  final illegal = pairwise.fold<int>(
    0,
    (sum, entry) => sum + (entry['illegalMoves']! as int),
  );
  final timeouts = pairwise.fold<int>(
    0,
    (sum, entry) => sum + (entry['timeouts']! as int),
  );
  final fallback = pairwise.fold<int>(
    0,
    (sum, entry) => sum + (entry['fallbackGames']! as int),
  );
  return const JsonEncoder.withIndent('  ').convert({
    'status': 'complete',
    'actualGames': metadata['actualGames'],
    'expectedGames': metadata['expectedGames'],
    'pairwiseCount': pairwise.length,
    'illegalMoves': illegal,
    'timeouts': timeouts,
    'fallbackGames': fallback,
  });
}

int _expectedGames(int configCount) {
  return _expectedCells(configCount) * _repeatCount;
}

int _expectedCells(int configCount) {
  return (configCount * (configCount - 1) ~/ 2) * _openings.length * 2;
}

int _actualGames(List<AiMatchResult> matches) {
  return matches.fold(0, (sum, match) => sum + match.games.length);
}

String _pairId(String a, String b) {
  return (a.compareTo(b) <= 0) ? '$a::$b' : '$b::$a';
}

List<String> _failureReasonsFor(Map<String, Object?> cell) {
  final reasons = cell['failureReasons'];
  if (reasons is List<String>) return reasons;
  if (reasons is List) return reasons.whereType<String>().toList();
  return const [];
}

double _rate(int wins, int losses, int draws) {
  final games = wins + losses + draws;
  return games == 0 ? 0 : wins / games;
}

class _Score {
  _Score({
    this.pairId,
    this.configId,
    this.opening,
    this.firstConfigId,
  });

  final String? pairId;
  final String? configId;
  final String? opening;
  final String? firstConfigId;
  final configWins = <String, int>{};
  final configLosses = <String, int>{};
  int wins = 0;
  int losses = 0;
  int draws = 0;
  int illegalMoves = 0;
  int timeouts = 0;
  int fallbackGames = 0;
  final failureReasons = <String>{};

  int get games => wins + losses + draws;
  double get winRate => games == 0 ? 0 : wins / games;

  void add({
    required String firstConfigId,
    required String secondConfigId,
    required int firstWins,
    required int secondWins,
    required int draws,
    required int illegalMoves,
    required int timeouts,
    required int fallbackGames,
    required List<String> failureReasons,
  }) {
    configWins[firstConfigId] = (configWins[firstConfigId] ?? 0) + firstWins;
    configLosses[firstConfigId] =
        (configLosses[firstConfigId] ?? 0) + secondWins;
    configWins[secondConfigId] = (configWins[secondConfigId] ?? 0) + secondWins;
    configLosses[secondConfigId] =
        (configLosses[secondConfigId] ?? 0) + firstWins;
    this.draws += draws;
    this.illegalMoves += illegalMoves;
    this.timeouts += timeouts;
    this.fallbackGames += fallbackGames;
    this.failureReasons.addAll(failureReasons);
  }

  void addConfigPerspective({
    required String configId,
    required String firstConfigId,
    required String secondConfigId,
    required int firstWins,
    required int secondWins,
    required int draws,
    required int illegalMoves,
    required int timeouts,
    required int fallbackGames,
    required List<String> failureReasons,
  }) {
    final isFirst = configId == firstConfigId;
    wins += isFirst ? firstWins : secondWins;
    losses += isFirst ? secondWins : firstWins;
    this.draws += draws;
    this.illegalMoves += illegalMoves;
    this.timeouts += timeouts;
    this.fallbackGames += fallbackGames;
    this.failureReasons.addAll(failureReasons);
  }

  void addFirstPlayer({
    required int wins,
    required int losses,
    required int draws,
    required int illegalMoves,
    required int timeouts,
    required int fallbackGames,
    required List<String> failureReasons,
  }) {
    this.wins += wins;
    this.losses += losses;
    this.draws += draws;
    this.illegalMoves += illegalMoves;
    this.timeouts += timeouts;
    this.fallbackGames += fallbackGames;
    this.failureReasons.addAll(failureReasons);
  }

  Map<String, Object?> toJson() {
    if (pairId != null) {
      final ids = pairId!.split('::');
      final configAWins = configWins[ids[0]] ?? 0;
      final configALosses = configLosses[ids[0]] ?? 0;
      final configBWins = configWins[ids[1]] ?? 0;
      final configBLosses = configLosses[ids[1]] ?? 0;
      return {
        'pairId': pairId,
        'configAId': ids[0],
        'configBId': ids[1],
        'configAWins': configAWins,
        'configALosses': configALosses,
        'configAWinRate': _rate(configAWins, configALosses, draws),
        'configBWins': configBWins,
        'configBLosses': configBLosses,
        'configBWinRate': _rate(configBWins, configBLosses, draws),
        'draws': draws,
        'games': configAWins + configALosses + draws,
        'illegalMoves': illegalMoves,
        'timeouts': timeouts,
        'fallbackGames': fallbackGames,
        'failureReasons': failureReasons.toList()..sort(),
      };
    }
    final json = <String, Object?>{
      if (configId != null) 'configId': configId,
      if (opening != null) 'opening': opening,
      if (firstConfigId != null) 'firstConfigId': firstConfigId,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'games': games,
      'winRate': winRate,
      'illegalMoves': illegalMoves,
      'timeouts': timeouts,
      'fallbackGames': fallbackGames,
      'failureReasons': failureReasons.toList()..sort(),
    };
    return json;
  }
}
