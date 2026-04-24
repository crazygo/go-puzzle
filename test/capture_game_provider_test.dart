import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/go_engine.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:go_puzzle/models/game_state.dart';
import 'package:go_puzzle/providers/capture_game_provider.dart';
import 'package:go_puzzle/screens/capture_game_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('CaptureGameProvider', () {
    test('rejects unsupported board sizes', () {
      expect(
        () => CaptureGameProvider(
          boardSize: 10,
          captureTarget: 5,
          difficulty: DifficultyLevel.beginner,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects non-positive capture targets', () {
      expect(
        () => CaptureGameProvider(
          boardSize: 9,
          captureTarget: 0,
          difficulty: DifficultyLevel.beginner,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('returns no suggestions when count is non-positive', () async {
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
      );

      expect(provider.suggestMoves(count: 0), isEmpty);
      expect(await provider.suggestMovesAsync(count: -1), isEmpty);
    });

    test('updates ai style when switching style', () {
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
      );

      expect(provider.aiStyle, CaptureAiStyle.hunter);

      provider.setAiStyle(CaptureAiStyle.counter);
      expect(provider.aiStyle, CaptureAiStyle.counter);
    });
  });

  group('SimBoard', () {
    test('rejects moves outside the board', () {
      final board = SimBoard(9, captureTarget: 5);

      expect(board.applyMove(-1, 0), isFalse);
      expect(board.applyMove(0, -1), isFalse);
      expect(board.applyMove(9, 0), isFalse);
      expect(board.applyMove(0, 9), isFalse);
    });
  });

  group('GoEngine move validation', () {
    test('rejects out-of-bounds moves', () {
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      final state = GameState(
        boardSize: 9,
        board: board,
        currentPlayer: StoneColor.black,
      );

      expect(GoEngine.placeStone(state, -1, 0), isNull);
      expect(GoEngine.placeStone(state, 0, -1), isNull);
      expect(GoEngine.placeStone(state, 9, 0), isNull);
      expect(GoEngine.placeStone(state, 0, 9), isNull);
    });

    test('rejects moves after the game is no longer playing', () {
      final board = List.generate(9, (_) => List.filled(9, StoneColor.empty));
      final state = GameState(
        boardSize: 9,
        board: board,
        currentPlayer: StoneColor.black,
        status: GameStatus.solved,
      );

      expect(GoEngine.placeStone(state, 4, 4), isNull);
    });
  });

  group('CaptureGamePlayScreen', () {
    testWidgets('switches AI style from the navigation bar', (tester) async {
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: ChangeNotifierProvider.value(
            value: provider,
            child: const CaptureGamePlayScreen(
              difficulty: DifficultyLevel.beginner,
              captureTarget: 5,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('猎杀'), findsOneWidget);

      await tester.tap(find.text('猎杀'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('稳守 · 先补强自己，再等反击'));
      await tester.pumpAndSettle();

      expect(provider.aiStyle, CaptureAiStyle.counter);
      expect(find.text('稳守'), findsOneWidget);
    });
  });
}
