import 'mcts_engine.dart';

const String kCapture5V8ModelAsset =
    'assets/models/capture5_13x13_policy_only_v8.onnx';

const String kCapture5V8ModelSha256 =
    '98441223424eef68eaeab35c715f56add24ff0207c0d59ab66a85fdaed4f48c6';

class Capture5EncodedFeatures {
  const Capture5EncodedFeatures({
    required this.features,
    required this.featuresShape,
    required this.globals,
    required this.globalsShape,
  });

  final List<double> features;
  final List<int> featuresShape;
  final List<double> globals;
  final List<int> globalsShape;
}

class Capture5FeatureEncoder {
  const Capture5FeatureEncoder();

  static const int boardSize = 13;
  static const int captureTarget = 5;
  static const int policyPointCount = boardSize * boardSize;
  static const int passMoveIndex = policyPointCount;
  static const int policySize = policyPointCount + 1;
  static const int _featurePlanes = 9;
  static const int _globalCount = 6;

  Capture5EncodedFeatures encode(SimBoard board) {
    // Spec: docs/specs_map/main_game_flow.yaml#capture5_v8_ai_player
    if (board.size != boardSize || board.captureTarget != captureTarget) {
      throw ArgumentError(
        'Capture5 v8 supports only 13x13 capture-five boards.',
      );
    }

    // Spec: docs/specs_map/technical_contracts.yaml#model_input_contract
    final total = board.size * board.size;
    final planes = List<double>.filled(_featurePlanes * total, 0);
    final currentPlayer = board.currentPlayer;
    final playerValue = currentPlayer == SimBoard.black ? 1.0 : -1.0;

    for (var index = 0; index < total; index++) {
      final color = board.cells[index];
      if (color == SimBoard.black) {
        planes[index] = 1;
      } else if (color == SimBoard.white) {
        planes[total + index] = 1;
      }
      planes[2 * total + index] = playerValue;
    }

    for (final moveIndex in legalBoardMoveIndices(board)) {
      planes[4 * total + moveIndex] = 1;
    }
    final koIndex = board.koIndex;
    if (koIndex >= 0 && koIndex < total) {
      planes[4 * total + koIndex] = -1;
    }

    _encodeLibertyPlanes(board, planes, total);

    final stonesOnBoard =
        board.cells.where((cell) => cell != SimBoard.empty).length;
    final estimatedMoveNumber = stonesOnBoard +
        board.capturedByBlack +
        board.capturedByWhite +
        board.consecutivePasses;

    return Capture5EncodedFeatures(
      features: planes,
      featuresShape: const [1, _featurePlanes, boardSize, boardSize],
      globals: [
        board.size / 19.0,
        board.captureTarget / 10.0,
        board.capturedByBlack / board.captureTarget,
        board.capturedByWhite / board.captureTarget,
        playerValue,
        estimatedMoveNumber / (total * 2.0),
      ],
      globalsShape: const [1, _globalCount],
    );
  }

  static List<int> legalBoardMoveIndices(SimBoard board) {
    final moves = <int>[];
    for (var index = 0; index < board.size * board.size; index++) {
      final analysis =
          board.analyzeMove(index ~/ board.size, index % board.size);
      if (analysis.isLegal) moves.add(index);
    }
    return moves;
  }

  void _encodeLibertyPlanes(
    SimBoard board,
    List<double> planes,
    int total,
  ) {
    final visited = <int>{};
    for (var index = 0; index < total; index++) {
      final color = board.cells[index];
      if (color == SimBoard.empty || visited.contains(index)) continue;
      final group = board.groupAtIndex(index);
      visited.addAll(group);
      final libertyCount = board.libertiesForGroup(group).length;
      if (libertyCount != 1 && libertyCount != 2) continue;

      final own = color == board.currentPlayer;
      final planeIndex =
          own ? (libertyCount == 1 ? 5 : 6) : (libertyCount == 1 ? 7 : 8);
      for (final point in group) {
        planes[planeIndex * total + point] = 1;
      }
    }
  }
}
