import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/providers/capture_game_provider.dart';

void main() {
  group('Capture AI rating report', () {
    test('builds standings and pairings for all requested board sizes', () {
      final report = CaptureAiArena.evaluate(
        const CaptureAiEvaluationConfig(
          styles: [CaptureAiStyle.hunter, CaptureAiStyle.counter],
          boardSizes: [9, 13, 19],
          captureTarget: 1,
          difficulty: DifficultyLevel.beginner,
          gamesPerPairing: 1,
          maxMoves: 120,
        ),
      );

      expect(report.boardEvaluations, hasLength(3));

      for (final boardSize in const [9, 13, 19]) {
        final standings = report.standingsForBoard(boardSize);
        final pairings = report.pairingsForBoard(boardSize);

        expect(standings, hasLength(2));
        expect(
          pairings,
          hasLength(2),
        );

        for (final standing in standings) {
          expect(standing.games, greaterThan(0));
          expect(standing.elo.isFinite, isTrue);
          expect(standing.invalidFinishes, 0);
        }
      }
    });

    test('pretty report includes summary sections and board headers', () {
      final report = CaptureAiArena.evaluate(
        const CaptureAiEvaluationConfig(
          styles: [CaptureAiStyle.hunter, CaptureAiStyle.counter],
          boardSizes: [9],
          captureTarget: 1,
          difficulty: DifficultyLevel.beginner,
          gamesPerPairing: 1,
          maxMoves: 120,
        ),
      );

      final text = report.toPrettyString();

      expect(text, contains('Board 9x9'));
      expect(text, contains('Standings'));
      expect(text, contains('Pairings'));
      expect(text, contains('hunter'));
      expect(text, contains('counter'));
    });
  });
}
