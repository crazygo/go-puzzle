import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/providers/capture_game_provider.dart';

void main() {
  final report = CaptureAiArena.evaluate(
    const CaptureAiEvaluationConfig(
      styles: CaptureAiStyle.values,
      boardSizes: [9, 13, 19],
      captureTarget: 1,
      difficulty: DifficultyLevel.beginner,
      gamesPerPairing: 1,
      maxMoves: 220,
    ),
  );

  print(report.toPrettyString());
}
