import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../models/board_position.dart';
import 'katago_model_adapter.dart';
import 'katago_onnx_features.dart';

class FlutterKatagoOnnxModelAdapter implements AsyncKatagoModelAdapter {
  FlutterKatagoOnnxModelAdapter({
    OnnxRuntime? runtime,
    KatagoOnnxFeatureEncoder encoder = const KatagoOnnxFeatureEncoder(),
  })  : _runtime = runtime ?? OnnxRuntime(),
        _encoder = encoder;

  final OnnxRuntime _runtime;
  final KatagoOnnxFeatureEncoder _encoder;
  final Map<String, OrtSession> _sessions = {};

  @override
  Future<void> preload(Iterable<KatagoModelRequest> requests) async {
    final assets = requests.map((request) => request.modelAsset).toSet();
    for (final asset in assets) {
      await _sessionFor(asset);
    }
  }

  @override
  Future<KatagoModelEvaluation> chooseMove(KatagoModelRequest request) async {
    OrtValue? binInput;
    OrtValue? globalInput;
    Map<String, OrtValue> outputs = const {};
    try {
      final legalMoves = request.board.getLegalMoves().where((moveIndex) {
        return request.board
            .analyzeMove(
              moveIndex ~/ request.board.size,
              moveIndex % request.board.size,
            )
            .isLegal;
      }).toList(growable: false);
      if (legalMoves.isEmpty) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'katago_onnx_no_legal_moves',
        );
      }

      final session = await _sessionFor(request.modelAsset);
      final features = _encoder.encode(request.board);
      binInput = await OrtValue.fromList(features.binInput, features.binShape);
      globalInput = await OrtValue.fromList(
        features.globalInput,
        features.globalShape,
      );
      outputs = await session.run({
        'bin_input': binInput,
        'global_input': globalInput,
      });
      final policyOutput =
          outputs['policy'] ?? outputs[outputs.keys.firstOrNull ?? ''];
      if (policyOutput == null) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'katago_onnx_missing_policy_output',
        );
      }
      final policy = await policyOutput.asFlattenedList();
      final moveIndex = _selectMove(
        policy: policy,
        legalMoves: legalMoves,
        temperature: request.policyTemperature,
        candidateLimit: request.candidateLimit,
      );
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.ready,
        move: BoardPosition(
          moveIndex ~/ request.board.size,
          moveIndex % request.board.size,
        ),
      );
    } catch (error) {
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.failed,
        failureReason: 'katago_flutter_onnx_error:$error',
      );
    } finally {
      await binInput?.dispose();
      await globalInput?.dispose();
      for (final output in outputs.values) {
        await output.dispose();
      }
    }
  }

  Future<void> close() async {
    for (final session in _sessions.values) {
      await session.close();
    }
    _sessions.clear();
  }

  Future<OrtSession> _sessionFor(String modelAsset) async {
    final existing = _sessions[modelAsset];
    if (existing != null) return existing;
    final session = await _runtime.createSessionFromAsset(modelAsset);
    _sessions[modelAsset] = session;
    return session;
  }

  int _selectMove({
    required List<dynamic> policy,
    required List<int> legalMoves,
    required double temperature,
    required int candidateLimit,
  }) {
    final scored = <({double score, int move})>[];
    const policyPlaneOffset = 0;
    for (final move in legalMoves) {
      final scoreValue = policy[policyPlaneOffset + move];
      if (scoreValue is! num) continue;
      final score = scoreValue.toDouble();
      if (score.isNaN || score.isInfinite) continue;
      scored.add((score: score, move: move));
    }
    if (scored.isEmpty) {
      throw StateError('policy_has_no_finite_legal_scores');
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final limit = candidateLimit.clamp(1, scored.length).toInt();
    final shortlisted = scored.take(limit);
    if (temperature <= 0) return shortlisted.first.move;
    return shortlisted
        .map((entry) => (score: entry.score / temperature, move: entry.move))
        .reduce((best, entry) => entry.score > best.score ? entry : best)
        .move;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
