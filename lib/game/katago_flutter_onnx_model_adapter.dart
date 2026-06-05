import 'dart:math' as math;

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
        _defaultPolicyPlane = policyPlane;

  final OnnxRuntime _runtime;
  final KatagoOnnxFeatureEncoder _encoder;
  final Duration _sessionLoadTimeout;
  final int _defaultPolicyPlane;
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
      final effectivePolicyPlane =
          request.policyPlane == 0 ? _defaultPolicyPlane : request.policyPlane;
      final policyOutput = await _policyOutputFor(
        outputs,
        minPolicyLength: (effectivePolicyPlane + 1) *
            (request.board.size * request.board.size + 1),
      );
      if (policyOutput == null) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'katago_onnx_missing_policy_output',
        );
      }
      final policy = await policyOutput.asFlattenedList();
      final candidates = _rankPolicyCandidates(
        policy: policy,
        legalMoves: legalMoves,
        boardPointCount: request.board.size * request.board.size,
        candidateLimit: request.candidateLimit,
        policyPlane: effectivePolicyPlane,
        boardSize: request.board.size,
      );
      final move = _selectMove(
        candidates: candidates,
        temperature: request.policyTemperature,
      );
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.ready,
        move: move,
        policyCandidates: candidates,
        value: await _valueEstimateFor(outputs['value']),
        miscValue: await _vectorOutputFor(outputs['miscvalue']),
        moreMiscValue: await _vectorOutputFor(outputs['moremiscvalue']),
        scoreBelief: await _scoreBeliefFor(outputs['scorebelief']),
        ownership: await _spatialOutputFor(
          outputs['ownership'],
          width: request.board.size,
          height: request.board.size,
          channels: 1,
        ),
        scoring: await _spatialOutputFor(
          outputs['scoring'],
          width: request.board.size,
          height: request.board.size,
          channels: 1,
        ),
        futurePosition: await _spatialOutputFor(
          outputs['futurepos'],
          width: request.board.size,
          height: request.board.size,
          channels: 2,
        ),
        seki: await _spatialOutputFor(
          outputs['seki'],
          width: request.board.size,
          height: request.board.size,
          channels: 4,
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

  List<KatagoPolicyCandidate> _rankPolicyCandidates({
    required List<dynamic> policy,
    required List<int> legalMoves,
    required int boardPointCount,
    required int candidateLimit,
    required int policyPlane,
    required int boardSize,
  }) {
    final scored = <({double score, int move})>[];
    final policyPlaneStride = boardPointCount + 1;
    final policyPlaneOffset = policyPlane * policyPlaneStride;
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
    final shortlisted = scored.take(limit).toList(growable: false);
    final probabilities = _softmax(
      shortlisted.map((entry) => entry.score).toList(growable: false),
    );
    return [
      for (var i = 0; i < shortlisted.length; i++)
        KatagoPolicyCandidate(
          position: BoardPosition(
            shortlisted[i].move ~/ boardSize,
            shortlisted[i].move % boardSize,
          ),
          score: shortlisted[i].score,
          probability: probabilities[i],
          rank: i + 1,
          policyPlane: policyPlane,
        ),
    ];
  }

  BoardPosition _selectMove({
    required List<KatagoPolicyCandidate> candidates,
    required double temperature,
  }) {
    if (candidates.isEmpty) {
      throw StateError('policy_has_no_finite_legal_scores');
    }
    if (temperature <= 0) return candidates.first.position;
    // Softmax sampling: convert policy scores to probabilities scaled by
    // temperature, then sample proportionally so higher-scored moves are more
    // likely without always being deterministic.
    final maxScore = candidates.fold(
      candidates.first.score,
      (m, e) => e.score > m ? e.score : m,
    );
    final weights = candidates
        .map((e) => math.exp((e.score - maxScore) / temperature))
        .toList();
    final totalWeight = weights.reduce((a, b) => a + b);
    final threshold = math.Random().nextDouble() * totalWeight;
    double cumulative = 0;
    for (var i = 0; i < candidates.length; i++) {
      cumulative += weights[i];
      if (cumulative >= threshold) return candidates[i].position;
    }
    return candidates.last.position;
  }

  Future<KatagoValueEstimate?> _valueEstimateFor(OrtValue? output) async {
    if (output == null) return null;
    final raw = (await output.asFlattenedList())
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList(growable: false);
    if (raw.length < 3) return null;
    final probs = _softmax(raw.take(3).toList(growable: false));
    return KatagoValueEstimate(
      win: probs[0],
      loss: probs[1],
      noResult: probs[2],
    );
  }

  Future<KatagoScoreBeliefSummary?> _scoreBeliefFor(OrtValue? output) async {
    if (output == null) return null;
    final raw = (await output.asFlattenedList())
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList(growable: false);
    if (raw.isEmpty) return null;
    final probs = _softmax(raw);
    final mid = raw.length / 2;
    double mean = 0;
    for (var i = 0; i < probs.length; i++) {
      mean += probs[i] * (i - mid + 0.5);
    }
    double variance = 0;
    for (var i = 0; i < probs.length; i++) {
      final score = i - mid + 0.5;
      final delta = score - mean;
      variance += probs[i] * delta * delta;
    }
    return KatagoScoreBeliefSummary(
      mean: mean,
      stdev: math.sqrt(math.max(0, variance)),
      distribution: probs,
    );
  }

  Future<KatagoVectorOutput?> _vectorOutputFor(OrtValue? output) async {
    if (output == null) return null;
    final raw = (await output.asFlattenedList())
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList(growable: false);
    if (raw.isEmpty) return null;
    return KatagoVectorOutput(values: raw);
  }

  Future<KatagoSpatialOutput?> _spatialOutputFor(
    OrtValue? output, {
    required int width,
    required int height,
    required int channels,
  }) async {
    if (output == null) return null;
    final raw = (await output.asFlattenedList())
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList(growable: false);
    final count = width * height * channels;
    if (raw.length < count) return null;
    return KatagoSpatialOutput(
      width: width,
      height: height,
      channels: channels,
      values: raw.take(count).toList(growable: false),
    );
  }

  List<double> _softmax(List<double> values) {
    if (values.isEmpty) return const [];
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final weights = values
        .map((value) => math.exp(value - maxValue))
        .toList(growable: false);
    final totalWeight = weights.reduce((a, b) => a + b);
    if (totalWeight <= 0) return List<double>.filled(values.length, 0);
    return weights.map((value) => value / totalWeight).toList(growable: false);
  }
}
