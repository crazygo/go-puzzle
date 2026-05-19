import '../models/board_position.dart';
import 'mcts_engine.dart';

enum KatagoBackendStatus {
  ready,
  unavailable,
  failed,
}

class KatagoModelRequest {
  const KatagoModelRequest({
    required this.board,
    required this.modelAsset,
    required this.visits,
    required this.timeBudgetMillis,
    required this.policyTemperature,
    required this.candidateLimit,
  });

  final SimBoard board;
  final String modelAsset;
  final int visits;
  final int timeBudgetMillis;
  final double policyTemperature;
  final int candidateLimit;
}

class KatagoModelEvaluation {
  const KatagoModelEvaluation({
    required this.status,
    this.move,
    this.failureReason,
  });

  final KatagoBackendStatus status;
  final BoardPosition? move;
  final String? failureReason;

  bool get hasMove => move != null;
}

abstract class KatagoModelAdapter {
  KatagoModelEvaluation chooseMove(KatagoModelRequest request);
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
