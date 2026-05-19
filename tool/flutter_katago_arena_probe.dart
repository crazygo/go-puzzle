// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/katago_flutter_onnx_model_adapter.dart';

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
  String _json = '';

  @override
  void initState() {
    super.initState();
    _runProbe();
  }

  Future<void> _runProbe() async {
    final adapter = FlutterKatagoOnnxModelAdapter();
    try {
      const executor = AiArenaExecutor(
        boardSize: 9,
        captureTarget: 1,
        rounds: 4,
        maxMoves: 120,
        openingPolicy: 'empty_cross_twist_cross_random_v1',
      );
      final summary = await executor.runFrameworkEvaluationAsync(
        configs: [
          AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1'),
          AiAlgorithmRegistry.configById('mcts_counter_standard_v1'),
          AiAlgorithmRegistry.configById(
            'hybrid_tactical_counter_standard_v1',
          ),
          AiAlgorithmRegistry.configById('katago_onnx_weak_v1'),
          AiAlgorithmRegistry.configById('katago_onnx_standard_v1'),
        ],
        matchSeed: 20260519,
        openingSeed: 0,
        asyncKatagoModelAdapter: adapter,
      );
      final json = const JsonEncoder.withIndent('  ').convert(
        summary.toJson(),
      );
      print('KATAGO_ARENA_PROBE_JSON_BEGIN');
      print(json);
      print('KATAGO_ARENA_PROBE_JSON_END');
      if (mounted) {
        setState(() {
          _status = 'complete';
          _json = json;
        });
      }
    } catch (error, stackTrace) {
      final failure = const JsonEncoder.withIndent('  ').convert({
        'status': 'failed',
        'failureReason': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
      print('KATAGO_ARENA_PROBE_JSON_BEGIN');
      print(failure);
      print('KATAGO_ARENA_PROBE_JSON_END');
      if (mounted) {
        setState(() {
          _status = 'failed';
          _json = failure;
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
                Text('KataGo Flutter ONNX Arena Probe: $_status'),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(_json),
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
