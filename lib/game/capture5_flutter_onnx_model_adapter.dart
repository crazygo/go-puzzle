import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../models/board_position.dart';
import 'capture5_onnx_features.dart';
import 'katago_model_adapter.dart';

class FlutterCapture5OnnxModelAdapter implements AsyncKatagoModelAdapter {
  FlutterCapture5OnnxModelAdapter({
    OnnxRuntime? runtime,
    Capture5FeatureEncoder encoder = const Capture5FeatureEncoder(),
    Duration sessionLoadTimeout = const Duration(seconds: 30),
  })  : _runtime = runtime ?? OnnxRuntime(),
        _encoder = encoder,
        _sessionLoadTimeout = sessionLoadTimeout;

  final OnnxRuntime _runtime;
  final Capture5FeatureEncoder _encoder;
  final Duration _sessionLoadTimeout;
  final Map<String, OrtSession> _sessions = {};
  final Map<String, String> _loadFailures = {};

  @override
  Future<void> preload(Iterable<KatagoModelRequest> requests) async {
    final assets = requests.map((request) => request.modelAsset).toSet();
    for (final asset in assets) {
      try {
        await _sessionFor(asset);
      } catch (_) {
        // chooseMove reports the structured load failure for the active game.
      }
    }
  }

  @override
  Future<KatagoModelEvaluation> chooseMove(KatagoModelRequest request) async {
    // Spec: docs/specs_map/main_game_flow.yaml#capture5_ai_player
    OrtValue? featuresInput;
    OrtValue? globalsInput;
    Map<String, OrtValue> outputs = const {};
    try {
      if (request.board.size != Capture5FeatureEncoder.boardSize ||
          request.board.captureTarget != Capture5FeatureEncoder.captureTarget) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'capture5_requires_13x13_capture5',
        );
      }

      final legalMoves =
          Capture5FeatureEncoder.legalBoardMoveIndices(request.board);
      if (legalMoves.isEmpty) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'capture5_no_legal_board_moves',
        );
      }

      final session = await _sessionFor(request.modelAsset);
      final encoded = _encoder.encode(request.board);
      final timeout = Duration(milliseconds: request.timeBudgetMillis);
      featuresInput = await OrtValue.fromList(
        encoded.features,
        encoded.featuresShape,
      ).timeout(timeout);
      globalsInput = await OrtValue.fromList(
        encoded.globals,
        encoded.globalsShape,
      ).timeout(timeout);
      outputs = await session.run({
        'features': featuresInput,
        'globals': globalsInput,
      }).timeout(timeout);

      final policyOutput = outputs['policy'];
      if (policyOutput == null) {
        return const KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'capture5_missing_policy_output',
        );
      }
      final policy = await policyOutput.asFlattenedList();
      if (policy.length < Capture5FeatureEncoder.policySize) {
        return KatagoModelEvaluation(
          status: KatagoBackendStatus.failed,
          failureReason: 'capture5_policy_output_too_short:${policy.length}',
        );
      }

      final candidates = _rankPolicyCandidates(
        policy: policy,
        legalMoves: legalMoves,
        candidateLimit: request.candidateLimit,
      );
      final move = _selectMove(
        candidates: candidates,
        temperature: request.policyTemperature,
      );
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.ready,
        move: move,
        policyCandidates: candidates,
        miscValue: await _scalarVectorFor(outputs['capture_delta']),
        moreMiscValue: await _scalarVectorFor(outputs['group_risk']),
      );
    } catch (error) {
      return KatagoModelEvaluation(
        status: KatagoBackendStatus.failed,
        failureReason: 'capture5_flutter_onnx_error:$error',
      );
    } finally {
      await featuresInput?.dispose();
      await globalsInput?.dispose();
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
      final reason = 'capture5_flutter_onnx_load_failed:$modelAsset:$error';
      _loadFailures[modelAsset] = reason;
      throw StateError(reason);
    }
  }

  String _runtimeAssetPath(String modelAsset) {
    if (!kIsWeb) return modelAsset;
    return modelAsset.startsWith('assets/') ? 'assets/$modelAsset' : modelAsset;
  }

  List<KatagoPolicyCandidate> _rankPolicyCandidates({
    required List<dynamic> policy,
    required List<int> legalMoves,
    required int candidateLimit,
  }) {
    final scored = <({double score, int move})>[];
    for (final move in legalMoves) {
      if (move >= Capture5FeatureEncoder.passMoveIndex) continue;
      final scoreValue = policy[move];
      if (scoreValue is! num) continue;
      final score = scoreValue.toDouble();
      if (score.isNaN || score.isInfinite) continue;
      scored.add((score: score, move: move));
    }
    if (scored.isEmpty) {
      throw StateError('capture5_policy_has_no_finite_legal_scores');
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
            shortlisted[i].move ~/ Capture5FeatureEncoder.boardSize,
            shortlisted[i].move % Capture5FeatureEncoder.boardSize,
          ),
          score: shortlisted[i].score,
          probability: probabilities[i],
          rank: i + 1,
          policyPlane: 0,
        ),
    ];
  }

  BoardPosition _selectMove({
    required List<KatagoPolicyCandidate> candidates,
    required double temperature,
  }) {
    if (candidates.isEmpty) {
      throw StateError('capture5_policy_has_no_finite_legal_scores');
    }
    if (temperature <= 0) return candidates.first.position;
    final maxScore = candidates.fold(
      candidates.first.score,
      (maxValue, candidate) =>
          candidate.score > maxValue ? candidate.score : maxValue,
    );
    final weights = candidates
        .map(
            (candidate) => math.exp((candidate.score - maxScore) / temperature))
        .toList(growable: false);
    final totalWeight = weights.reduce((a, b) => a + b);
    final threshold = math.Random().nextDouble() * totalWeight;
    double cumulative = 0;
    for (var i = 0; i < candidates.length; i++) {
      cumulative += weights[i];
      if (cumulative >= threshold) return candidates[i].position;
    }
    return candidates.last.position;
  }

  Future<KatagoVectorOutput?> _scalarVectorFor(OrtValue? output) async {
    if (output == null) return null;
    final raw = (await output.asFlattenedList())
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList(growable: false);
    if (raw.isEmpty) return null;
    return KatagoVectorOutput(values: raw);
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
