import '../models/board_position.dart';
import 'mcts_engine.dart';

const String kKatagoDefaultModelAsset =
    'assets/models/katago-kata1-b18c384nbt-batched-fp16.onnx';

enum KatagoBackendStatus {
  ready,
  unavailable,
  failed,
}

class KatagoModelRequest {
  const KatagoModelRequest({
    required this.board,
    required this.modelAsset,
    required this.timeBudgetMillis,
    required this.policyTemperature,
    required this.candidateLimit,
    this.policyPlane = 0,
  });

  final SimBoard board;
  final String modelAsset;
  final int timeBudgetMillis;
  final double policyTemperature;
  final int candidateLimit;
  final int policyPlane;
}

enum KatagoPolicyPlane {
  // Spec: docs/specs_map/main_game_flow.yaml#training_coach_katago
  normal,
  opponentReply,
  soft,
  softOpponentReply,
  longTermOptimistic,
  shortTermOptimistic,
}

extension KatagoPolicyPlaneLabel on KatagoPolicyPlane {
  String get shortLabel {
    return switch (this) {
      KatagoPolicyPlane.normal => '穩定',
      KatagoPolicyPlane.opponentReply => '應手',
      KatagoPolicyPlane.soft => '柔和',
      KatagoPolicyPlane.softOpponentReply => '柔和應手',
      KatagoPolicyPlane.longTermOptimistic => '長期',
      KatagoPolicyPlane.shortTermOptimistic => '短期',
    };
  }

  String get explanationLabel {
    return switch (this) {
      KatagoPolicyPlane.normal => '穩定推薦',
      KatagoPolicyPlane.opponentReply => '對手應手視角',
      KatagoPolicyPlane.soft => '柔和推薦',
      KatagoPolicyPlane.softOpponentReply => '柔和對手應手',
      KatagoPolicyPlane.longTermOptimistic => '長期樂觀',
      KatagoPolicyPlane.shortTermOptimistic => '短期樂觀',
    };
  }
}

class KatagoPolicyCandidate {
  const KatagoPolicyCandidate({
    required this.position,
    required this.score,
    required this.probability,
    required this.rank,
    required this.policyPlane,
  });

  final BoardPosition position;
  final double score;
  final double probability;
  final int rank;
  final int policyPlane;
}

class KatagoValueEstimate {
  const KatagoValueEstimate({
    required this.win,
    required this.loss,
    required this.noResult,
  });

  final double win;
  final double loss;
  final double noResult;
}

class KatagoScoreBeliefSummary {
  const KatagoScoreBeliefSummary({
    required this.mean,
    required this.stdev,
    this.distribution = const [],
  });

  final double mean;
  final double stdev;
  final List<double> distribution;
}

class KatagoVectorOutput {
  const KatagoVectorOutput({
    required this.values,
  });

  final List<double> values;
}

class KatagoSpatialOutput {
  const KatagoSpatialOutput({
    required this.width,
    required this.height,
    required this.channels,
    required this.values,
  });

  final int width;
  final int height;
  final int channels;
  final List<double> values;
}

class KatagoModelEvaluation {
  const KatagoModelEvaluation({
    required this.status,
    this.move,
    this.policyCandidates = const [],
    this.value,
    this.miscValue,
    this.moreMiscValue,
    this.scoreBelief,
    this.ownership,
    this.scoring,
    this.futurePosition,
    this.seki,
    this.failureReason,
  });

  final KatagoBackendStatus status;
  final BoardPosition? move;
  final List<KatagoPolicyCandidate> policyCandidates;
  final KatagoValueEstimate? value;
  final KatagoVectorOutput? miscValue;
  final KatagoVectorOutput? moreMiscValue;
  final KatagoScoreBeliefSummary? scoreBelief;
  final KatagoSpatialOutput? ownership;
  final KatagoSpatialOutput? scoring;
  final KatagoSpatialOutput? futurePosition;
  final KatagoSpatialOutput? seki;
  final String? failureReason;

  bool get hasMove => move != null;
}

abstract class KatagoModelAdapter {
  KatagoModelEvaluation chooseMove(KatagoModelRequest request);
}

abstract class AsyncKatagoModelAdapter {
  Future<void> preload(Iterable<KatagoModelRequest> requests);

  Future<KatagoModelEvaluation> chooseMove(KatagoModelRequest request);
}

class KatagoModelException implements Exception {
  const KatagoModelException(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

class UnavailableKatagoOnnxModelAdapter implements KatagoModelAdapter {
  const UnavailableKatagoOnnxModelAdapter();

  @override
  KatagoModelEvaluation chooseMove(KatagoModelRequest request) {
    return KatagoModelEvaluation(
      status: KatagoBackendStatus.unavailable,
      failureReason: 'katago_onnx_model_unavailable:${request.modelAsset}',
    );
  }
}

class UnavailableAsyncKatagoOnnxModelAdapter
    implements AsyncKatagoModelAdapter {
  const UnavailableAsyncKatagoOnnxModelAdapter();

  @override
  Future<void> preload(Iterable<KatagoModelRequest> requests) async {}

  @override
  Future<KatagoModelEvaluation> chooseMove(KatagoModelRequest request) async {
    return KatagoModelEvaluation(
      status: KatagoBackendStatus.unavailable,
      failureReason: 'katago_onnx_model_unavailable:${request.modelAsset}',
    );
  }
}
