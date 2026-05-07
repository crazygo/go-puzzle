import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_search_runner.dart';
import 'package:go_puzzle/providers/capture_game_provider.dart';
import 'package:go_puzzle/models/board_position.dart';
import 'package:go_puzzle/game/capture_ai.dart';

// ---------------------------------------------------------------------------
// Fake / test-double AiSearchRunner implementations
// ---------------------------------------------------------------------------

/// A runner that completes searches after a configurable delay with a fixed
/// move.  Supports simulated cancellation.
class _FakeAiSearchRunner implements AiSearchRunner {
  _FakeAiSearchRunner({
    this.moveRow = 0,
    this.moveCol = 0,
    this.throwError = false,
  });

  final int moveRow;
  final int moveCol;
  final bool throwError;

  final Set<AiSearchRequestId> _cancelled = {};
  final List<AiSearchRequestId> cancelledIds = [];
  int searchCallCount = 0;
  bool disposed = false;

  @override
  Future<AiSearchResult> search(AiSearchRequest request) async {
    searchCallCount++;
    if (disposed) {
      return AiSearchResult(
        requestId: request.id,
        error: 'Runner disposed',
      );
    }
    // yield to the event loop so listeners fire before the result lands
    await Future<void>.microtask(() {});

    if (_cancelled.remove(request.id)) {
      return AiSearchResult(requestId: request.id);
    }
    if (throwError) {
      return AiSearchResult(requestId: request.id, error: 'Forced error');
    }
    return AiSearchResult(
      requestId: request.id,
      move: [moveRow, moveCol],
    );
  }

  @override
  void cancel(AiSearchRequestId requestId) {
    _cancelled.add(requestId);
    cancelledIds.add(requestId);
  }

  @override
  void dispose() {
    disposed = true;
    _cancelled.clear();
  }
}

/// A runner that never completes its search (blocks indefinitely).
class _BlockingAiSearchRunner implements AiSearchRunner {
  final List<AiSearchRequestId> cancelledIds = [];
  final Map<AiSearchRequestId, Completer<AiSearchResult>> _completers = {};
  bool disposed = false;

  @override
  Future<AiSearchResult> search(AiSearchRequest request) {
    final completer = Completer<AiSearchResult>();
    _completers[request.id] = completer;
    return completer.future;
  }

  @override
  void cancel(AiSearchRequestId requestId) {
    cancelledIds.add(requestId);
    final completer = _completers.remove(requestId);
    completer?.complete(AiSearchResult(requestId: requestId));
  }

  @override
  void dispose() {
    disposed = true;
    for (final entry in _completers.entries) {
      entry.value.complete(
        AiSearchResult(requestId: entry.key, error: 'Runner disposed'),
      );
    }
    _completers.clear();
  }
}

// ---------------------------------------------------------------------------
// Helper to build minimal AI search params
// ---------------------------------------------------------------------------

Map<String, dynamic> _minimalParams({
  int boardSize = 9,
  int captureTarget = 5,
}) {
  final cells = List<int>.filled(boardSize * boardSize, 0);
  return {
    'boardSize': boardSize,
    'captureTarget': captureTarget,
    'cells': cells,
    'capturedByBlack': 0,
    'capturedByWhite': 0,
    'currentPlayer': StoneColor.black.index,
    'aiStyle': CaptureAiStyle.adaptive.name,
    'difficulty': DifficultyLevel.beginner.name,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // AiSearchResult
  // ─────────────────────────────────────────────────────────────────────────
  group('AiSearchResult', () {
    test('hasError is false when error is null', () {
      expect(
        const AiSearchResult(requestId: 'r1').hasError,
        isFalse,
      );
    });

    test('hasError is true when error is set', () {
      expect(
        const AiSearchResult(requestId: 'r1', error: 'boom').hasError,
        isTrue,
      );
    });

    test('move is accessible when set', () {
      const result = AiSearchResult(requestId: 'r1', move: [3, 4]);
      expect(result.move, equals([3, 4]));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Runner contract — normal return
  // ─────────────────────────────────────────────────────────────────────────
  group('Runner contract — normal return', () {
    test('returns move with correct requestId', () async {
      final runner = _FakeAiSearchRunner(moveRow: 2, moveCol: 3);
      final result = await runner.search(
        AiSearchRequest(id: 'req_1', params: _minimalParams()),
      );

      expect(result.requestId, equals('req_1'));
      expect(result.move, equals([2, 3]));
      expect(result.hasError, isFalse);

      runner.dispose();
    });

    test('disposed runner returns error result', () async {
      final runner = _FakeAiSearchRunner();
      runner.dispose();

      final result = await runner.search(
        AiSearchRequest(id: 'req_2', params: _minimalParams()),
      );

      expect(result.requestId, equals('req_2'));
      expect(result.hasError, isTrue);
    });

    test('error runner surfaces error in result', () async {
      final runner = _FakeAiSearchRunner(throwError: true);
      final result = await runner.search(
        AiSearchRequest(id: 'req_3', params: _minimalParams()),
      );

      expect(result.requestId, equals('req_3'));
      expect(result.hasError, isTrue);
      expect(result.move, isNull);

      runner.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Runner contract — cancellation
  // ─────────────────────────────────────────────────────────────────────────
  group('Runner contract — cancel', () {
    test('cancel after search completes is a no-op', () async {
      final runner = _FakeAiSearchRunner(moveRow: 1, moveCol: 1);
      final result = await runner.search(
        AiSearchRequest(id: 'done', params: _minimalParams()),
      );
      // Already completed — cancel must not throw.
      expect(() => runner.cancel('done'), returnsNormally);
      expect(result.move, equals([1, 1]));
      runner.dispose();
    });

    test('cancel while pending: result has no move', () async {
      final runner = _BlockingAiSearchRunner();

      final resultFuture = runner.search(
        AiSearchRequest(id: 'pending', params: _minimalParams()),
      );

      runner.cancel('pending');
      final result = await resultFuture;

      expect(result.requestId, equals('pending'));
      expect(result.move, isNull);
      expect(result.hasError, isFalse);

      runner.dispose();
    });

    test('cancel records the cancelled request id', () async {
      final runner = _BlockingAiSearchRunner();

      unawaited(
        runner.search(AiSearchRequest(id: 'cid', params: _minimalParams())),
      );
      runner.cancel('cid');

      expect(runner.cancelledIds, contains('cid'));
      runner.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Runner contract — expired / stale result discard via CaptureGameProvider
  // ─────────────────────────────────────────────────────────────────────────
  group('Runner contract — stale result discard', () {
    test(
      'provider discards stale result when new game starts during AI delay',
      () async {
        // Use a blocking runner so we control when the search completes.
        final blockingRunner = _BlockingAiSearchRunner();

        // Human is white so AI (black) moves first.
        final provider = CaptureGameProvider(
          boardSize: 9,
          captureTarget: 5,
          difficulty: DifficultyLevel.beginner,
          humanColor: StoneColor.white,
          minMoveDelay: Duration.zero,
          maxMoveDelay: Duration.zero,
          runner: blockingRunner,
        );

        // Allow the first _doAiMove microtask to run and call search().
        await Future<void>.microtask(() {});

        // The search is now blocking.  Start a new game — this must cancel
        // the in-flight request.
        provider.newGame();

        // The cancel should have been called.
        expect(blockingRunner.cancelledIds, isNotEmpty);

        // Allow any pending microtasks to flush.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // moveLog should be empty — the stale AI move must NOT be applied.
        expect(provider.moveLog, isEmpty);
        expect(provider.isAiThinking, isFalse);

        provider.dispose();
      },
    );

    test('provider discards result when disposed during AI delay', () async {
      final blockingRunner = _BlockingAiSearchRunner();

      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        humanColor: StoneColor.white,
        minMoveDelay: Duration.zero,
        maxMoveDelay: Duration.zero,
        runner: blockingRunner,
      );

      await Future<void>.microtask(() {});
      provider.dispose();

      expect(blockingRunner.cancelledIds, isNotEmpty);
      expect(blockingRunner.disposed, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // CaptureGameProvider integration with injected runner
  // ─────────────────────────────────────────────────────────────────────────
  group('CaptureGameProvider with injected runner', () {
    test('AI places stone using move from runner', () async {
      final runner = _FakeAiSearchRunner(moveRow: 3, moveCol: 3);
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        minMoveDelay: Duration.zero,
        maxMoveDelay: Duration.zero,
        runner: runner,
      );

      final doneCompleter = Completer<void>();
      provider.addListener(() {
        if (!provider.isAiThinking &&
            provider.moveLog.length >= 2 &&
            !doneCompleter.isCompleted) {
          doneCompleter.complete();
        }
      });

      await provider.placeStone(4, 4);

      // Human move placed immediately.
      expect(provider.moveLog.length, equals(1));

      await doneCompleter.future.timeout(const Duration(seconds: 3));

      // AI placed its move at [3, 3] as returned by the fake runner.
      expect(provider.moveLog.length, equals(2));
      expect(provider.moveLog.last, equals([3, 3]));
      expect(provider.isAiThinking, isFalse);

      provider.dispose();
    });

    test('AI error result does not apply a move', () async {
      final runner = _FakeAiSearchRunner(throwError: true);
      // Human is white so AI goes first.
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        humanColor: StoneColor.white,
        minMoveDelay: Duration.zero,
        maxMoveDelay: Duration.zero,
        runner: runner,
      );

      // Wait for the AI task to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Error result must not apply a move.
      expect(provider.moveLog, isEmpty);
      expect(provider.isAiThinking, isFalse);

      provider.dispose();
    });

    test('runner.search() is called once per AI turn', () async {
      final runner = _FakeAiSearchRunner(moveRow: 2, moveCol: 2);
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        minMoveDelay: Duration.zero,
        maxMoveDelay: Duration.zero,
        runner: runner,
      );

      final doneCompleter = Completer<void>();
      provider.addListener(() {
        if (!provider.isAiThinking &&
            provider.moveLog.length >= 2 &&
            !doneCompleter.isCompleted) {
          doneCompleter.complete();
        }
      });

      await provider.placeStone(4, 4);
      await doneCompleter.future.timeout(const Duration(seconds: 3));

      // Exactly one search call for the one AI turn.
      expect(runner.searchCallCount, equals(1));

      provider.dispose();
    });
  });
}
