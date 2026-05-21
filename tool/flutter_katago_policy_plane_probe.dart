// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
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
    try {
      final katago = AiAlgorithmRegistry.configById('katago_onnx_standard_v1');
      final mctsWeak = AiAlgorithmRegistry.configById('mcts_counter_weak_v1');
      final planes = <Map<String, Object?>>[];
      for (var plane = 0; plane < 6; plane++) {
        final adapter = FlutterKatagoOnnxModelAdapter(policyPlane: plane);
        final matches = <Map<String, Object?>>[];
        try {
          var index = 0;
          for (final (openingName, openingPolicy) in _openings) {
            for (final first in [katago, mctsWeak]) {
              final second = identical(first, katago) ? mctsWeak : katago;
              final executor = AiArenaExecutor(
                boardSize: 9,
                captureTarget: 5,
                rounds: _repeatCount,
                maxMoves: 120,
                openingPolicy: openingPolicy,
              );
              final match = await executor.runFrameworkMatchAsync(
                configA: first,
                configB: second,
                matchSeed: _matchSeed + plane * 100000 + index * 7919,
                openingSeed: _openingSeed,
                alternateColors: false,
                asyncKatagoModelAdapter: adapter,
              );
              matches.add(_matchJson(
                opening: openingName,
                firstConfigId: first.id,
                secondConfigId: second.id,
                match: match,
              ));
              index++;
            }
          }
        } finally {
          await adapter.close();
        }
        planes.add(_planeJson(plane, matches));
      }

      final output = {
        'metadata': {
          'probe': 'flutter_katago_policy_plane_probe_v1',
          'katagoConfig': katago.id,
          'opponentConfig': mctsWeak.id,
          'planes': [0, 1, 2, 3, 4, 5],
          'openings': _openings.map((opening) => opening.$1).toList(),
          'repeatCount': _repeatCount,
          'captureTarget': 5,
          'maxMoves': 120,
        },
        'planes': planes,
      };
      final json = const JsonEncoder.withIndent('  ').convert(output);
      print('KATAGO_POLICY_PLANE_PROBE_JSON_BEGIN');
      print(json);
      print('KATAGO_POLICY_PLANE_PROBE_JSON_END');
      if (mounted) {
        setState(() {
          _status = 'complete';
          _summary = const JsonEncoder.withIndent('  ').convert({
            'status': 'complete',
            'planes': planes
                .map((plane) => {
                      'policyPlane': plane['policyPlane'],
                      'katagoWins': plane['katagoWins'],
                      'mctsWeakWins': plane['mctsWeakWins'],
                      'draws': plane['draws'],
                      'failures': plane['failureReasons'],
                    })
                .toList(),
          });
        });
      }
    } catch (error, stackTrace) {
      final failure = const JsonEncoder.withIndent('  ').convert({
        'status': 'failed',
        'failureReason': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
      print('KATAGO_POLICY_PLANE_PROBE_JSON_BEGIN');
      print(failure);
      print('KATAGO_POLICY_PLANE_PROBE_JSON_END');
      if (mounted) {
        setState(() {
          _status = 'failed';
          _summary = failure;
        });
      }
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
                Text('KataGo Policy Plane Probe: $_status'),
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

Map<String, Object?> _matchJson({
  required String opening,
  required String firstConfigId,
  required String secondConfigId,
  required dynamic match,
}) {
  final failures = match.games
      .map((dynamic game) => game.failureReason)
      .whereType<String>()
      .toSet()
      .toList()
    ..sort();
  return {
    'opening': opening,
    'firstConfigId': firstConfigId,
    'secondConfigId': secondConfigId,
    'firstWins': match.aWins,
    'secondWins': match.bWins,
    'draws': match.draws,
    'illegalMoves':
        match.games.where((dynamic game) => game.illegalMove).length,
    'timeouts': match.games.where((dynamic game) => game.timedOut).length,
    'fallbackGames':
        match.games.where((dynamic game) => game.fallbackUsed).length,
    'failureReasons': failures,
    'games': match.games.map((dynamic game) => game.toJson()).toList(),
  };
}

Map<String, Object?> _planeJson(
  int policyPlane,
  List<Map<String, Object?>> matches,
) {
  var katagoWins = 0;
  var mctsWeakWins = 0;
  var draws = 0;
  var illegalMoves = 0;
  var timeouts = 0;
  var fallbackGames = 0;
  final failures = <String>{};
  for (final match in matches) {
    final first = match['firstConfigId']! as String;
    final firstWins = match['firstWins']! as int;
    final secondWins = match['secondWins']! as int;
    if (first == 'katago_onnx_standard_v1') {
      katagoWins += firstWins;
      mctsWeakWins += secondWins;
    } else {
      mctsWeakWins += firstWins;
      katagoWins += secondWins;
    }
    draws += match['draws']! as int;
    illegalMoves += match['illegalMoves']! as int;
    timeouts += match['timeouts']! as int;
    fallbackGames += match['fallbackGames']! as int;
    final reasons = match['failureReasons'];
    if (reasons is List) failures.addAll(reasons.whereType<String>());
  }
  final games = katagoWins + mctsWeakWins + draws;
  return {
    'policyPlane': policyPlane,
    'katagoWins': katagoWins,
    'mctsWeakWins': mctsWeakWins,
    'draws': draws,
    'games': games,
    'katagoWinRate': games == 0 ? 0 : katagoWins / games,
    'illegalMoves': illegalMoves,
    'timeouts': timeouts,
    'fallbackGames': fallbackGames,
    'failureReasons': failures.toList()..sort(),
    'matches': matches,
  };
}
