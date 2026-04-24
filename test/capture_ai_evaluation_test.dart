import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/providers/capture_game_provider.dart';

import 'support/capture_ai_test_harness.dart';

void main() {
  const boardSizes = [9, 13, 19];

  group('Capture AI evaluation harness', () {
    test('every AI style can choose a legal opening move on all board sizes',
        () {
      for (final boardSize in boardSizes) {
        for (final style in CaptureAiStyle.values) {
          CaptureAiTestHarness.expectAgentCanChooseLegalMove(
            style: style,
            boardBuilder: () => SimBoard(boardSize, captureTarget: 5),
          );
        }
      }
    });

    test(
        'every AI style can finish a playable duel against hunter on all board sizes',
        () {
      for (final boardSize in boardSizes) {
        for (final style in CaptureAiStyle.values) {
          CaptureAiTestHarness.expectPlayableMatch(
            blackStyle: style,
            whiteStyle: CaptureAiStyle.hunter,
            difficulty: DifficultyLevel.beginner,
            boardSize: boardSize,
            captureTarget: 1,
            maxMoves: boardSize == 19 ? 220 : 120,
          );
        }
      }
    });

    test(
        'round robin evaluation is reusable for all registered styles on all board sizes',
        () {
      final report = CaptureAiArena.evaluate(
        const CaptureAiEvaluationConfig(
          styles: [CaptureAiStyle.hunter, CaptureAiStyle.counter],
          boardSizes: boardSizes,
          captureTarget: 1,
          difficulty: DifficultyLevel.beginner,
          gamesPerPairing: 1,
          maxMoves: 120,
        ),
      );

      for (final boardSize in boardSizes) {
        final result = CaptureAiTestHarness.expectRoundRobin(
          styles: [CaptureAiStyle.hunter, CaptureAiStyle.counter],
          difficulty: DifficultyLevel.beginner,
          boardSize: boardSize,
          captureTarget: 1,
          maxMoves: 120,
        );
        expect(result.entries, isNotEmpty);
        expect(report.standingsForBoard(boardSize), isNotEmpty);
        expect(report.pairingsForBoard(boardSize), isNotEmpty);

        for (final style in const [
          CaptureAiStyle.hunter,
          CaptureAiStyle.counter,
        ]) {
          expect(
            result.winsFor(style),
            greaterThanOrEqualTo(0),
          );
        }
      }
    });
  });
}
