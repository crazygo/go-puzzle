import 'mcts_engine.dart';

const String kCapture5ModelId =
    'capture5_13x13_11p_resnet_phase_h_hard010';

const String kCapture5FeatureSchemaId = 'capture5_features_11p_ladder_v1';

const String kCapture5ModelAsset =
    'assets/models/capture5_13x13_11p_resnet_phase_h_hard010.onnx';

const String kCapture5ModelMetadataAsset =
    'assets/models/capture5_13x13_11p_resnet_phase_h_hard010.metadata.json';

const String kCapture5ModelSha256 =
    '204f39d27b719a307be09bef96adfe61415e53bf26be4d2c87e4560bd0e629de';

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
  static const int featurePlanes = 11;
  static const int _globalCount = 6;

  Capture5EncodedFeatures encode(SimBoard board) {
    // Spec: docs/specs_map/main_game_flow.yaml#capture5_ai_player
    if (board.size != boardSize || board.captureTarget != captureTarget) {
      throw ArgumentError(
        'Capture5 supports only 13x13 capture-five boards.',
      );
    }

    // Spec: docs/specs_map/technical_contracts.yaml#model_input_contract
    final total = board.size * board.size;
    final planes = List<double>.filled(featurePlanes * total, 0);
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
    _encodeLadderPlanes(board, planes, total);

    final stonesOnBoard =
        board.cells.where((cell) => cell != SimBoard.empty).length;
    final estimatedMoveNumber = stonesOnBoard +
        board.capturedByBlack +
        board.capturedByWhite +
        board.consecutivePasses;

    return Capture5EncodedFeatures(
      features: planes,
      featuresShape: const [1, featurePlanes, boardSize, boardSize],
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

  void _encodeLadderPlanes(
    SimBoard board,
    List<double> planes,
    int total,
  ) {
    // Spec: docs/specs_map/technical_contracts.yaml#capture5_features_11p_ladder_v1
    final currentPlayer = board.currentPlayer;
    final visited = <int>{};
    for (var index = 0; index < total; index++) {
      final color = board.cells[index];
      if (color == SimBoard.empty || visited.contains(index)) continue;
      final group = board.groupAtIndex(index);
      visited.addAll(group);
      final liberties = board.libertiesForGroup(group);
      if (!_isLadderCapture(board, group, liberties)) continue;

      final planeIndex = color == currentPlayer ? 9 : 10;
      for (final point in group) {
        planes[planeIndex * total + point] = 1;
      }
    }
  }

  bool _isLadderCapture(
    SimBoard board,
    Set<int> group,
    Set<int> liberties,
  ) {
    if (group.isEmpty || liberties.length != 1) return false;

    final start = group.first;
    final color = board.cells[start];
    if (color == SimBoard.empty) return false;

    final currentGroup = board.groupAtIndex(start);
    final currentLiberties = board.libertiesForGroup(currentGroup);
    if (!_sameSet(currentGroup, group) ||
        !_sameSet(currentLiberties, liberties)) {
      return false;
    }

    return _defenderToMove(
      board: SimBoard.copy(board),
      color: color,
      group: currentGroup,
      liberties: currentLiberties,
      depthRemaining: board.size * 4,
      visited: <String>{},
    );
  }

  bool _defenderToMove({
    required SimBoard board,
    required int color,
    required Set<int> group,
    required Set<int> liberties,
    required int depthRemaining,
    required Set<String> visited,
  }) {
    if (group.isEmpty) return true;
    if (liberties.length != 1) return false;
    if (depthRemaining <= 0) return false;

    final stateKey = board.cells.join(',');
    if (visited.contains(stateKey)) return false;
    visited.add(stateKey);

    final escape = liberties.first;
    final escapedBoard = _simulateColorPlacement(board, color, escape);
    if (escapedBoard == null) return true;

    final escapedGroup = escapedBoard.groupAtIndex(escape);
    final escapedLiberties = escapedBoard.libertiesForGroup(escapedGroup);
    if (escapedLiberties.isEmpty) return true;
    if (escapedLiberties.length >= 3) return false;
    if (escapedLiberties.length == 1) {
      return _opponentCanCaptureGroup(
        escapedBoard,
        color,
        escapedGroup,
        escapedLiberties.first,
      );
    }

    for (final chase in escapedLiberties.toList()..sort()) {
      final chasedBoard = _simulateColorPlacement(
        escapedBoard,
        _opponentOf(color),
        chase,
      );
      if (chasedBoard == null) continue;

      final remainingGroup = <int>{};
      for (final point in escapedGroup) {
        if (chasedBoard.cells[point] == color) remainingGroup.add(point);
      }
      if (remainingGroup.length != escapedGroup.length) return true;

      final probe = remainingGroup.first;
      final chasedGroup = chasedBoard.groupAtIndex(probe);
      if (!_sameSet(chasedGroup, escapedGroup)) continue;
      final chasedLiberties = chasedBoard.libertiesForGroup(chasedGroup);
      if (chasedLiberties.length != 1) continue;
      if (_defenderToMove(
        board: chasedBoard,
        color: color,
        group: chasedGroup,
        liberties: chasedLiberties,
        depthRemaining: depthRemaining - 1,
        visited: Set<String>.from(visited),
      )) {
        return true;
      }
    }
    return false;
  }

  SimBoard? _simulateColorPlacement(SimBoard board, int color, int point) {
    if (point < 0 || point >= board.size * board.size) return null;
    if (board.cells[point] != SimBoard.empty) return null;

    final next = SimBoard.copy(board);
    next.cells[point] = color;
    final opponent = _opponentOf(color);
    final captured = <int>{};
    final checked = <int>{};
    for (final adjacent in next.adjacentIndices(point)) {
      if (next.cells[adjacent] != opponent || checked.contains(adjacent)) {
        continue;
      }
      final opponentGroup = next.groupAtIndex(adjacent);
      checked.addAll(opponentGroup);
      if (next.libertiesForGroup(opponentGroup).isEmpty) {
        captured.addAll(opponentGroup);
      }
    }
    for (final capturedPoint in captured) {
      next.cells[capturedPoint] = SimBoard.empty;
    }
    if (captured.isEmpty &&
        next.libertiesForGroup(next.groupAtIndex(point)).isEmpty) {
      return null;
    }
    return next;
  }

  bool _opponentCanCaptureGroup(
    SimBoard board,
    int color,
    Set<int> group,
    int liberty,
  ) {
    final next = _simulateColorPlacement(board, _opponentOf(color), liberty);
    if (next == null) return false;
    for (final point in group) {
      if (next.cells[point] == SimBoard.empty) return true;
    }
    return false;
  }

  int _opponentOf(int color) =>
      color == SimBoard.black ? SimBoard.white : SimBoard.black;

  bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}
