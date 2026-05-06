import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_rank_level.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/go_engine.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:go_puzzle/models/game_state.dart';
import 'package:go_puzzle/providers/capture_game_provider.dart';
import 'package:go_puzzle/providers/settings_provider.dart';
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
        minMoveDelay: Duration.zero,
      );

      expect(provider.suggestMoves(count: 0), isEmpty);
      expect(await provider.suggestMovesAsync(count: -1), isEmpty);
    });

    test('updates ai style when switching style', () {
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        minMoveDelay: Duration.zero,
      );

      expect(provider.aiStyle, CaptureAiStyle.adaptive);

      provider.setAiStyle(CaptureAiStyle.counter);
      expect(provider.aiStyle, CaptureAiStyle.counter);
    });

    test('isAiThinking is true during delay and false after move completes',
        () async {
      final thinkingValues = <bool>[];
      // Human plays white so AI (black) moves first when game starts.
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        humanColor: StoneColor.white,
        minMoveDelay: const Duration(milliseconds: 50),
        maxMoveDelay: const Duration(milliseconds: 200),
      );
      // Register listener before microtask queue drains so we capture every
      // isAiThinking transition.
      provider.addListener(() => thinkingValues.add(provider.isAiThinking));

      // Wait long enough for the minimum delay plus scheduling overhead.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // isAiThinking should have been true at some point (thinking started).
      expect(thinkingValues, contains(true));
      // And back to false once the move is placed.
      expect(provider.isAiThinking, isFalse);
      expect(provider.moveLog, isNotEmpty); // AI actually placed a stone
    });

    test('AI places a stone after placeStone with minMoveDelay: Duration.zero',
        () async {
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        minMoveDelay: Duration.zero,
      );

      final initialMoveCount = provider.moveLog.length;
      await provider.placeStone(4, 4);

      // Human placed one stone; AI should have responded with exactly one more.
      expect(provider.moveLog.length, equals(initialMoveCount + 2));
      expect(provider.isAiThinking, isFalse);
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
        minMoveDelay: Duration.zero,
      );
      final settings = SettingsProvider();

      await tester.pumpWidget(
        CupertinoApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider.value(value: provider),
            ],
            child: const CaptureGamePlayScreen(
              aiRank: AiRankLevel.min,
              captureTarget: 5,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.slider_horizontal_3), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
      await tester.pumpAndSettle();

      expect(find.text('对局配置'), findsOneWidget);
      expect(find.text('随机'), findsOneWidget);

      await tester.tap(find.text('随机'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('稳守 · 先补强自己，再等反击'));
      await tester.pumpAndSettle();

      expect(provider.aiStyle, CaptureAiStyle.counter);
    });
  });
}
