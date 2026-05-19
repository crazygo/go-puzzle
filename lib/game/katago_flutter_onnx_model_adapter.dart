import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter/foundation.dart';

import '../models/board_position.dart';
import 'katago_model_adapter.dart';
import 'katago_onnx_features.dart';

class FlutterKatagoOnnxModelAdapter implements AsyncKatagoModelAdapter {
  FlutterKatagoOnnxModelAdapter({
    OnnxRuntime? runtime,
    KatagoOnnxFeatureEncoder encoder = const KatagoOnnxFeatureEncoder(),
    Duration sessionLoadTimeout = const Duration(seconds: 60),
    int policyPlane = 0,
  })  : _runtime = runtime ?? OnnxRuntime(),
        _encoder = encoder,
        _sessionLoadTimeout = sessionLoadTimeout,
        _policyPlane = policyPlane;

  final OnnxRuntime _runtime;
  final KatagoOnnxFeatureEncoder _encoder;
  final Duration _sessionLoadTimeout;
  final int _policyPlane;
  final Map<String, OrtSession> _sessions = {};
  final Map<String, String> _loadFailures = {};

  @override
  Future<void> preload(Iterable<KatagoModelRequest> requests) async {
    final assets = requests.map((request) => request.modelAsset).toSet();
    for (final asset in assets) {
      try {
        await _sessionFor(asset);
      } catch (_) {
        // Store the failure in _sessionFor and let chooseMove surface it as a
        // structured failed evaluation for each affected game.
      }
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
      final decisionTimeout = Duration(
        milliseconds: request.timeBudgetMillis,
      );
      binInput = await OrtValue.fromList(features.binInput, features.binShape)
          .timeout(decisionTimeout);
      globalInput = await OrtValue.fromList(
        features.globalInput,
        features.globalShape,
      ).timeout(decisionTimeout);
      outputs = await session.run({
        'bin_input': binInput,
        'global_input': globalInput,
      }).timeout(decisionTimeout);
      final policyOutput = await _policyOutputFor(
        outputs,
        minPolicyLength:
            (_policyPlane + 1) * (request.board.size * request.board.size + 1),
      );
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
        boardPointCount: request.board.size * request.board.size,
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
    _loadFailures.clear();
  }

  Future<OrtSession> _sessionFor(String modelAsset) async {
    final existing = _sessions[modelAsset];
    if (existing != null) return existing;
    final previousFailure = _loadFailures[modelAsset];
    if (previousFailure != null) {
      throw StateError(previousFailure);
    }
    try {
      final session = await _runtime
          .createSessionFromAsset(_runtimeAssetPath(modelAsset))
          .timeout(_sessionLoadTimeout);
      _sessions[modelAsset] = session;
      return session;
    } catch (error) {
      final reason = 'katago_flutter_onnx_load_failed:$modelAsset:$error';
      _loadFailures[modelAsset] = reason;
      throw StateError(reason);
    }
  }

  Future<OrtValue?> _policyOutputFor(
    Map<String, OrtValue> outputs, {
    required int minPolicyLength,
  }) async {
    final named = outputs['policy'];
    if (named != null) {
      final data = await named.asFlattenedList();
      if (data.length >= minPolicyLength) return named;
    }
    for (final output in outputs.values) {
      if (identical(output, named)) continue;
      final data = await output.asFlattenedList();
      if (data.length >= minPolicyLength) return output;
    }
    return null;
  }

  String _runtimeAssetPath(String modelAsset) {
    if (!kIsWeb) return modelAsset;
    return modelAsset.startsWith('assets/') ? 'assets/$modelAsset' : modelAsset;
  }

  int _selectMove({
    required List<dynamic> policy,
    required List<int> legalMoves,
    required int boardPointCount,
    required double temperature,
    required int candidateLimit,
  }) {
    final scored = <({double score, int move})>[];
    final policyPlaneStride = boardPointCount + 1;
    final policyPlaneOffset = _policyPlane * policyPlaneStride;
    if (policyPlaneOffset + boardPointCount >= policy.length) {
      throw RangeError.index(
        policyPlaneOffset + boardPointCount,
        policy,
        'policyPlaneOffset + boardPointCount',
      );
    }
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
