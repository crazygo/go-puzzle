// Platform-agnostic AI search computation entry point.
//
// This file must only import pure Dart packages — no Flutter framework
// dependencies — so it can be used both in:
//   • The main Flutter app via compute() on native platforms.
//   • A compiled Dart Web Worker on Flutter Web.

import 'capture_ai.dart';
import 'difficulty_level.dart';
import 'mcts_engine.dart';

/// Runs the AI move search from a serialised [params] map.
///
/// Input keys (all required):
/// - `boardSize`      : int
/// - `captureTarget`  : int
/// - `cells`          : List<int>  (flattened board, row-major)
/// - `capturedByBlack`: int
/// - `capturedByWhite`: int
/// - `currentPlayer`  : int  (StoneColor.index)
/// - `aiStyle`        : String  (CaptureAiStyle.name)
/// - `difficulty`     : String  (DifficultyLevel.name)
///
/// Returns `[row, col]` of the chosen move, or `null` if no move was found.
List<int>? runChooseAiMove(Map<String, dynamic> params) {
  final boardSize = params['boardSize'] as int;
  final captureTarget = params['captureTarget'] as int;
  final cells = List<int>.from(params['cells'] as List);
  final capturedByBlack = params['capturedByBlack'] as int;
  final capturedByWhite = params['capturedByWhite'] as int;
  final currentPlayer = params['currentPlayer'] as int;
  final aiStyle = CaptureAiStyle.values.byName(params['aiStyle'] as String);
  final difficulty =
      DifficultyLevel.values.byName(params['difficulty'] as String);

  final sim = SimBoard(boardSize, captureTarget: captureTarget);
  for (int i = 0; i < cells.length; i++) {
    sim.cells[i] = cells[i];
  }
  sim.capturedByBlack = capturedByBlack;
  sim.capturedByWhite = capturedByWhite;
  sim.currentPlayer = currentPlayer;

  final move = CaptureAiRegistry.create(style: aiStyle, difficulty: difficulty)
      .chooseMove(sim)
      ?.position;
  if (move == null) return null;
  return [move.row, move.col];
}
