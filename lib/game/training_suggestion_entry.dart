// Platform-agnostic AI training suggestion computation entry point.
//
// This file must only import pure Dart packages so it can run in both native
// isolates and browser DedicatedWorkers.

import 'ai_algorithm_framework.dart';
import 'capture_ai.dart';
import 'difficulty_level.dart';
import 'game_mode.dart';
import 'mcts_engine.dart';
import 'territory_ai.dart';
import '../models/board_position.dart';

/// Runs the AI training suggestion search from a serialised [params] map.
///
/// Returns up to `count` entries as `[row, col, winRateMillis]`, where
/// `winRateMillis` is the estimated win-rate multiplied by 1000.
List<List<num>> runTrainingSuggestions(Map<String, dynamic> params) {
  final boardSize = params['boardSize'] as int;
  final captureTarget = params['captureTarget'] as int;
  final cells = List<int>.from(params['cells'] as List);
  final capturedByBlack = params['capturedByBlack'] as int;
  final capturedByWhite = params['capturedByWhite'] as int;
  final currentPlayer = params['currentPlayer'] as int;
  final aiStyle = CaptureAiStyle.values.byName(params['aiStyle'] as String);
  final difficulty =
      DifficultyLevel.values.byName(params['difficulty'] as String);
  final algorithmConfigId = params['algorithmConfigId'] as String?;
  final gameMode = GameModeExt.fromStorageKey(params['gameMode'] as String?);
  final consecutivePasses = (params['consecutivePasses'] as int?) ?? 0;
  final count = (params['count'] as int?) ?? 3;

  final workBoard = SimBoard(
    boardSize,
    captureTarget: captureTarget,
    gameMode: gameMode,
  );
  for (int i = 0; i < cells.length; i++) {
    workBoard.cells[i] = cells[i];
  }
  workBoard.capturedByBlack = capturedByBlack;
  workBoard.capturedByWhite = capturedByWhite;
  workBoard.currentPlayer = currentPlayer;
  workBoard.consecutivePasses = consecutivePasses;

  final primaryAgent = gameMode == GameMode.capture
      ? _captureAgent(
          algorithmConfigId: algorithmConfigId,
          aiStyle: aiStyle,
          difficulty: difficulty,
        )
      : null;
  final territoryEngine = gameMode == GameMode.territory
      ? TerritoryAiEngine(difficulty: difficulty)
      : null;

  final origPlayer = currentPlayer;
  final results = <List<num>>[];

  for (int i = 0; i < count; i++) {
    if (workBoard.isTerminal) break;

    BoardPosition? move;
    if (gameMode == GameMode.capture) {
      move = primaryAgent?.chooseMove(workBoard)?.position;
    } else {
      final pos = territoryEngine?.chooseMove(workBoard);
      if (pos == null || pos == territoryPassMove) break;
      move = pos;
    }
    if (move == null) break;

    final afterBoard = SimBoard.copy(workBoard);
    if (!afterBoard.applyMove(move.row, move.col)) break;
    final winRate = _trainingWinRate(afterBoard, origPlayer, captureTarget);
    results.add([move.row, move.col, (winRate * 1000).round()]);

    workBoard.cells[workBoard.idx(move.row, move.col)] =
        origPlayer == SimBoard.black ? SimBoard.white : SimBoard.black;
  }
  return results;
}

CaptureAiAgent _captureAgent({
  required String? algorithmConfigId,
  required CaptureAiStyle aiStyle,
  required DifficultyLevel difficulty,
}) {
  if (algorithmConfigId != null) {
    return AiAlgorithmRegistry.createAgent(
      AiAlgorithmRegistry.configById(algorithmConfigId),
    );
  }
  return CaptureAiRegistry.create(style: aiStyle, difficulty: difficulty);
}

double _trainingWinRate(SimBoard board, int origPlayer, int captureTarget) {
  const floor = 0.05;
  const ceiling = 0.95;
  if (board.gameMode == GameMode.territory) {
    final myArea = board.areaScore(origPlayer);
    final oppArea = board.areaScore(
      origPlayer == SimBoard.black ? SimBoard.white : SimBoard.black,
    );
    final diff = myArea - oppArea;
    final normalized =
        (diff / (board.size * board.size)).clamp(-ceiling, ceiling);
    return (0.5 + normalized * 0.45).clamp(floor, ceiling);
  }
  final myCaps = origPlayer == SimBoard.black
      ? board.capturedByBlack
      : board.capturedByWhite;
  final oppCaps = origPlayer == SimBoard.black
      ? board.capturedByWhite
      : board.capturedByBlack;
  final progress = (myCaps - oppCaps) / captureTarget;
  return (0.5 + progress * 0.35).clamp(floor, ceiling);
}
