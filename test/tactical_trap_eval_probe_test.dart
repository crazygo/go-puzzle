import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tactical trap eval probe records holdout metrics', () {
    final file =
        File('docs/ai_eval/runs/2026-05-22-tactical-trap-all-native-full.json');
    expect(file.existsSync(), isTrue);

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['probe'], 'tactical_trap_eval_probe_v1');
    expect(json['sampleCount'], greaterThanOrEqualTo(520));
    final summaries =
        (json['summaries'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(summaries, isNotEmpty);
    for (final summary in summaries) {
      expect(summary['provenFailures'], isA<int>());
      expect(summary['acceptedMoveRate'], isA<num>());
      expect(summary['evalProvenFailures'], isA<int>());
      expect(summary['evalAcceptedMoveRate'], isA<num>());
      final byFamily =
          (summary['byFamily'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(byFamily, isNotEmpty);
      expect(
        byFamily.map((family) => family['family']),
        containsAll([
          'doomed_rescue_twist_ladder',
          'edge_escape_dead_chain',
          'connect_and_die',
          'net_containment',
          'throw_in_snapback',
        ]),
      );
      for (final family in byFamily) {
        expect(family['provenFailures'], isA<int>());
      }
      final bySplit =
          (summary['bySplit'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(bySplit.map((split) => split['split']),
          containsAll(['train', 'eval']));
      for (final split in bySplit) {
        expect(split['acceptedMoveRate'], isA<num>());
        expect(split['provenFailures'], isA<int>());
      }
      final byFamilyAndSplit = (summary['byFamilyAndSplit'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(byFamilyAndSplit, isNotEmpty);
      expect(
        byFamilyAndSplit.where((entry) => entry['split'] == 'eval'),
        isNotEmpty,
      );
    }
  });

  test('tactical trap before-after comparison records improvement', () {
    final file = File(
        'docs/ai_eval/runs/2026-05-22-tactical-trap-520-before-after-comparison.json');
    expect(file.existsSync(), isTrue);

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['probe'], 'tactical_trap_compare_probe_v1');
    expect(json['comparisonMode'], 'sample_id_intersection');
    final comparisons =
        (json['comparisons'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(comparisons, isNotEmpty);

    final mcts = comparisons.singleWhere(
      (comparison) => comparison['configId'] == 'mcts_counter_standard_v1',
    );
    expect(mcts['comparedSamples'], greaterThanOrEqualTo(520));
    final before = mcts['before'] as Map<String, dynamic>;
    final after = mcts['after'] as Map<String, dynamic>;
    final delta = mcts['delta'] as Map<String, dynamic>;
    expect(before['provenFailures'], greaterThan(0));
    expect(after['provenFailures'], 0);
    expect(delta['provenFailureReductionRate'], greaterThanOrEqualTo(0.5));
  });

  test('tactical trap ONNX full corpus records real node adapter results', () {
    final file =
        File('docs/ai_eval/runs/2026-05-22-tactical-trap-all-onnx-full.json');
    expect(file.existsSync(), isTrue);

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['probe'], 'tactical_trap_eval_probe_v1');
    expect(json['katagoAdapter'], 'node');
    expect(json['sampleCount'], greaterThanOrEqualTo(520));

    final summaries =
        (json['summaries'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(
      summaries.map((summary) => summary['configId']),
      containsAll(['katago_onnx_weak_v1', 'katago_onnx_standard_v1']),
    );
    for (final summary in summaries) {
      expect(summary['illegalOrNoMove'], 0, reason: summary['configId']);
      expect(summary['evalAcceptedMoveRate'], greaterThanOrEqualTo(0.70),
          reason: summary['configId']);
    }
    final standard = summaries.singleWhere(
      (summary) => summary['configId'] == 'katago_onnx_standard_v1',
    );
    expect(standard['illegalOrNoMove'], 0);
    expect(standard['provenFailures'], 0);
    expect(standard['acceptedMoveRate'], greaterThanOrEqualTo(0.85));
  });
}
