import 'dart:async';

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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CaptureGameProvider', () {
    test('initial cross layout uses plus-shaped stones', () {
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
      );
      final board = provider.gameState.board;
      const center = 4;
      expect(board[center - 1][center], StoneColor.black);
      expect(board[center + 1][center], StoneColor.black);
      expect(board[center][center - 1], StoneColor.white);
      expect(board[center][center + 1], StoneColor.white);
    });

    test('initial twistCross layout uses twisted 2x2 stones', () {
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        initialMode: CaptureInitialMode.twistCross,
      );
      final board = provider.gameState.board;
      const center = 4;
      expect(board[center][center], StoneColor.black);
      expect(board[center][center + 1], StoneColor.white);
      expect(board[center - 1][center], StoneColor.white);
      expect(board[center - 1][center + 1], StoneColor.black);
    });

    test('persisted opening keys keep legacy twistCross compatibility', () {
      expect(
        captureInitialModeStorageKey(CaptureInitialMode.cross),
        'twistCross',
      );
      expect(
        captureInitialModeStorageKey(CaptureInitialMode.twistCross),
        'twistCross2x2',
      );
      expect(
        captureInitialModeFromStorageKey('twistCross'),
        CaptureInitialMode.cross,
      );
      expect(
        captureInitialModeFromStorageKey('cross'),
        CaptureInitialMode.cross,
      );
      expect(
        captureInitialModeFromStorageKey('twistCross2x2'),
        CaptureInitialMode.twistCross,
      );
    });

    test('legacy and new persisted keys reconstruct their respective layouts',
        () {
      const boardSize = 9;
      final legacyBoard = List.generate(
          boardSize, (_) => List.filled(boardSize, StoneColor.empty));
      final newBoard = List.generate(
          boardSize, (_) => List.filled(boardSize, StoneColor.empty));
      final legacyMode = captureInitialModeFromStorageKey('twistCross');
      final newMode = captureInitialModeFromStorageKey('twistCross2x2');

      applyCaptureInitialLayout(
        legacyBoard,
        legacyMode,
      );
      applyCaptureInitialLayout(
        newBoard,
        newMode,
      );

      const center = 4;
      expect(legacyMode, CaptureInitialMode.cross);
      expect(newMode, CaptureInitialMode.twistCross);
      expect(legacyBoard[center][center], StoneColor.empty);
      expect(legacyBoard[center - 1][center], StoneColor.black);
      expect(legacyBoard[center + 1][center], StoneColor.black);
      expect(legacyBoard[center][center - 1], StoneColor.white);
      expect(legacyBoard[center][center + 1], StoneColor.white);
      expect(newBoard[center][center], StoneColor.black);
      expect(newBoard[center + 1][center], StoneColor.empty);
      expect(newBoard[center][center + 1], StoneColor.white);
      expect(newBoard[center - 1][center], StoneColor.white);
      expect(newBoard[center - 1][center + 1], StoneColor.black);
    });

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

    test('rejects negative minMoveDelay', () {
      expect(
        () => CaptureGameProvider(
          boardSize: 9,
          captureTarget: 5,
          difficulty: DifficultyLevel.beginner,
          minMoveDelay: const Duration(milliseconds: -1),
          maxMoveDelay: Duration.zero,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects negative maxMoveDelay', () {
      expect(
        () => CaptureGameProvider(
          boardSize: 9,
          captureTarget: 5,
          difficulty: DifficultyLevel.beginner,
          minMoveDelay: Duration.zero,
          maxMoveDelay: const Duration(milliseconds: -1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects maxMoveDelay less than minMoveDelay', () {
      expect(
        () => CaptureGameProvider(
          boardSize: 9,
          captureTarget: 5,
          difficulty: DifficultyLevel.beginner,
          minMoveDelay: const Duration(milliseconds: 500),
          maxMoveDelay: const Duration(milliseconds: 100),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('stale AI move is discarded after new game starts during delay',
        () async {
      // Create provider where human is white so AI (black) goes first.
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        humanColor: StoneColor.white,
        minMoveDelay: const Duration(milliseconds: 100),
        maxMoveDelay: const Duration(milliseconds: 200),
      );

      // Start a new game while the first AI move is still in its delay window.
      // The in-flight move must not be applied to the new game.
      provider.newGame();
      final moveCountAfterNewGame = provider.moveLog.length;

      // Wait for both the old and new AI tasks to finish.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // The new game's AI move may have run, but the old stale move must not
      // have been written, so log should reflect at most one AI move (the one
      // belonging to the new game).
      expect(provider.moveLog.length,
          lessThanOrEqualTo(moveCountAfterNewGame + 1));
      expect(provider.isAiThinking, isFalse);
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
      // Complete as soon as the AI finishes thinking (isAiThinking → false).
      final doneCompleter = Completer<void>();
      provider.addListener(() {
        thinkingValues.add(provider.isAiThinking);
        if (!provider.isAiThinking && !doneCompleter.isCompleted) {
          doneCompleter.complete();
        }
      });

      // Wait deterministically for the AI move to complete, with a 5 s guard.
      await doneCompleter.future
          .timeout(const Duration(seconds: 5), onTimeout: () {});

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

      // Register the listener BEFORE triggering the action so we don't miss
      // any state transitions that fire before or immediately after await.
      final doneCompleter = Completer<void>();
      provider.addListener(() {
        if (!provider.isAiThinking &&
            provider.moveLog.length >= initialMoveCount + 2 &&
            !doneCompleter.isCompleted) {
          doneCompleter.complete();
        }
      });

      await provider.placeStone(4, 4);
      // Human move should render immediately without waiting for AI work.
      expect(provider.moveLog.length, equals(initialMoveCount + 1));
      expect(provider.isAiThinking, isFalse);

      // No onTimeout callback — let the timeout throw so the test fails fast
      // rather than silently masking a missing AI response.
      await doneCompleter.future.timeout(const Duration(seconds: 5));

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

      expect(find.text('操作'), findsOneWidget);
      expect(find.text('AI 22 级'), findsNothing);

      await tester.tap(find.text('操作'));
      await tester.pumpAndSettle();

      expect(find.text('AI 风格：战力优先'), findsOneWidget);
      expect(find.text('吃子预警：开'), findsOneWidget);

      await tester.tap(find.text('AI 风格：战力优先'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('稳守 · 先补强自己，再等反击'));
      await tester.pumpAndSettle();

      expect(provider.aiStyle, CaptureAiStyle.counter);
    });

    testWidgets('shows move coordinates above the board and highlights marks',
        (tester) async {
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        initialMode: CaptureInitialMode.setup,
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
              initialMode: CaptureInitialMode.setup,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('轮到你（黑棋）落子'), findsOneWidget);
      expect(find.text('等待黑棋落子'), findsNothing);
      expect(find.text('落子记录：'), findsNothing);
      expect(find.text('操作'), findsOneWidget);
      expect(find.text('后退一手'), findsNothing);
      expect(find.text('提示一手'), findsNothing);

      await provider.placeStone(8, 0);
      await provider.placeStone(7, 1);
      await tester.pumpAndSettle();

      expect(find.text('等待黑棋落子'), findsNothing);
      expect(find.text('1 A1'), findsNothing);
      expect(find.text('2 B2'), findsNothing);
      expect(find.text('记录'), findsNothing);

      await tester.tap(find.text('操作'));
      await tester.pumpAndSettle();

      expect(find.text('显示棋谱'), findsOneWidget);

      await tester.tap(find.text('显示棋谱'));
      await tester.pumpAndSettle();

      expect(find.text('1 A1'), findsOneWidget);
      expect(find.text('2 B2'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('2 B2')).style?.fontWeight,
        FontWeight.w500,
      );

      await tester.tap(find.text('操作'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('打标此手'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text('2 B2')).style?.fontWeight,
        FontWeight.w700,
      );

      await tester.tap(find.text('操作'));
      await tester.pumpAndSettle();

      expect(find.text('取消打标此手'), findsOneWidget);
      expect(find.text('后退一手'), findsOneWidget);
      expect(find.text('提示一手'), findsOneWidget);

      await tester.tap(find.text('后退一手'));
      await tester.pumpAndSettle();

      expect(find.text('1 A1'), findsOneWidget);
      expect(find.text('2 B2'), findsNothing);
    });
  });
}
