import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/training_suggestion_runner.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:go_puzzle/providers/capture_game_provider.dart';

class _FakeTrainingSuggestionRunner implements TrainingSuggestionRunner {
  final List<TrainingSuggestionRequest> requests = [];
  final List<TrainingSuggestionRequestId> cancelledIds = [];
  bool disposed = false;

  @override
  Future<TrainingSuggestionSearchResult> search(
    TrainingSuggestionRequest request,
  ) async {
    requests.add(request);
    return TrainingSuggestionSearchResult(
      requestId: request.id,
      suggestions: const [
        [1, 2, 570],
        [3, 4, 625],
      ],
    );
  }

  @override
  void cancel(TrainingSuggestionRequestId requestId) {
    cancelledIds.add(requestId);
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class _BlockingTrainingSuggestionRunner implements TrainingSuggestionRunner {
  final Map<TrainingSuggestionRequestId,
      Completer<TrainingSuggestionSearchResult>> completers = {};
  final List<TrainingSuggestionRequestId> cancelledIds = [];
  bool disposed = false;

  @override
  Future<TrainingSuggestionSearchResult> search(
    TrainingSuggestionRequest request,
  ) {
    final completer = Completer<TrainingSuggestionSearchResult>();
    completers[request.id] = completer;
    return completer.future;
  }

  @override
  void cancel(TrainingSuggestionRequestId requestId) {
    cancelledIds.add(requestId);
    final completer = completers.remove(requestId);
    completer?.complete(TrainingSuggestionSearchResult(requestId: requestId));
  }

  @override
  void dispose() {
    disposed = true;
    for (final entry in completers.entries) {
      entry.value.complete(
        TrainingSuggestionSearchResult(
          requestId: entry.key,
          error: 'Runner disposed',
        ),
      );
    }
    completers.clear();
  }
}

void main() {
  group('CaptureGameProvider training suggestion runner', () {
    test('uses injected runner and maps raw suggestions to board positions',
        () async {
      final runner = _FakeTrainingSuggestionRunner();
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        trainingSuggestionRunner: runner,
      );

      final suggestions = await provider.suggestMovesWithWinRateAsync(count: 3);

      expect(runner.requests, hasLength(1));
      expect(runner.requests.single.params['count'], 3);
      expect(suggestions, hasLength(2));
      expect(suggestions[0].position.row, 1);
      expect(suggestions[0].position.col, 2);
      expect(suggestions[0].winRate, 0.57);
      expect(suggestions[1].position.row, 3);
      expect(suggestions[1].position.col, 4);
      expect(suggestions[1].winRate, 0.625);

      provider.dispose();
      expect(runner.disposed, isTrue);
    });

    test('cancels the pending suggestion request without touching AI runner',
        () async {
      final runner = _BlockingTrainingSuggestionRunner();
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        trainingSuggestionRunner: runner,
      );

      final future = provider.suggestMovesWithWinRateAsync(count: 3);
      await Future<void>.microtask(() {});

      expect(runner.completers, hasLength(1));
      final requestId = runner.completers.keys.single;

      provider.cancelTrainingSuggestions();

      expect(runner.cancelledIds, [requestId]);
      expect(await future, isEmpty);

      provider.dispose();
    });

    test('does not start suggestion search after the game is finished',
        () async {
      const boardSize = 9;
      final board = List.generate(
        boardSize,
        (_) => List<StoneColor>.filled(boardSize, StoneColor.empty),
      );
      board[3][4] = StoneColor.black;
      board[4][3] = StoneColor.black;
      board[4][5] = StoneColor.black;
      board[4][4] = StoneColor.white;

      final runner = _FakeTrainingSuggestionRunner();
      final provider = CaptureGameProvider(
        boardSize: boardSize,
        captureTarget: 1,
        difficulty: DifficultyLevel.beginner,
        initialBoardOverride: board,
        trainingSuggestionRunner: runner,
      );

      await provider.placeStone(5, 4);

      expect(provider.result, CaptureGameResult.blackWins);
      expect(await provider.suggestMovesWithWinRateAsync(count: 3), isEmpty);
      expect(runner.requests, isEmpty);

      provider.dispose();
    });
  });
}
