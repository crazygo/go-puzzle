import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/game_mode.dart';
import 'package:go_puzzle/game/katago_model_adapter.dart';
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

class _StructuredTrainingSuggestionRunner implements TrainingSuggestionRunner {
  final requests = <TrainingSuggestionRequest>[];

  @override
  Future<TrainingSuggestionSearchResult> search(
    TrainingSuggestionRequest request,
  ) async {
    requests.add(request);
    return TrainingSuggestionSearchResult(
      requestId: request.id,
      structuredSuggestions: const [
        {
          'row': 2,
          'col': 3,
          'winRate': 0.64,
          'policyScore': 4.2,
          'policyProbability': 0.72,
          'valueDelta': 0.08,
          'scoreLead': 3.5,
          'scoreUncertainty': 7.0,
          'strategyLabel': '穩定推薦',
          'explanationSignals': ['穩定推薦第 1 選', '策略偏好 72%'],
          'source': 'katago',
        },
      ],
    );
  }

  @override
  void cancel(TrainingSuggestionRequestId requestId) {}

  @override
  void dispose() {}
}

class _CoachKatagoAdapter implements AsyncKatagoModelAdapter {
  final requests = <KatagoModelRequest>[];

  @override
  Future<void> preload(Iterable<KatagoModelRequest> requests) async {}

  @override
  Future<KatagoModelEvaluation> chooseMove(KatagoModelRequest request) async {
    requests.add(request);
    return KatagoModelEvaluation(
      status: KatagoBackendStatus.ready,
      move: const BoardPosition(0, 0),
      policyCandidates: [
        KatagoPolicyCandidate(
          position: const BoardPosition(0, 0),
          score: 3,
          probability: 0.7,
          rank: 1,
          policyPlane: request.policyPlane,
        ),
        KatagoPolicyCandidate(
          position: const BoardPosition(0, 1),
          score: 2,
          probability: 0.3,
          rank: 2,
          policyPlane: request.policyPlane,
        ),
      ],
      value: const KatagoValueEstimate(win: 0.62, loss: 0.34, noResult: 0.04),
      scoreBelief: const KatagoScoreBeliefSummary(mean: 4.5, stdev: 8.0),
    );
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

    test('uses fixed KataGo coach in territory mode on native adapter path',
        () async {
      // Spec: docs/specs_map/main_game_flow.yaml#training_coach_katago
      final runner = _FakeTrainingSuggestionRunner();
      final katago = _CoachKatagoAdapter();
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        gameMode: GameMode.territory,
        aiAlgorithmConfig:
            AiAlgorithmRegistry.configById('katago_onnx_standard_v1'),
        katagoModelAdapter: katago,
        trainingSuggestionRunner: runner,
      );

      final suggestions = await provider.suggestMovesWithWinRateAsync(
        count: 2,
        policyPlane: KatagoPolicyPlane.shortTermOptimistic,
      );

      expect(runner.requests, isEmpty);
      expect(katago.requests, isNotEmpty);
      expect(
        katago.requests.first.modelAsset,
        kKatagoDefaultModelAsset,
      );
      expect(katago.requests.first.policyTemperature, 0);
      expect(katago.requests.first.candidateLimit, 2);
      expect(katago.requests.first.policyPlane,
          KatagoPolicyPlane.shortTermOptimistic.index);
      expect(suggestions, hasLength(2));
      expect(suggestions.first.position, const BoardPosition(0, 0));
      expect(suggestions.first.source, 'katago');
      expect(suggestions.first.policyProbability, 0.7);
      expect(suggestions.first.strategyLabel, '短期樂觀');
      expect(suggestions.first.explanationSignals, isNotEmpty);
      expect(suggestions.first.winRate, closeTo(0.34, 0.001));

      provider.dispose();
    });

    test('maps structured worker suggestions to coach explanation data',
        () async {
      // Spec: docs/specs_map/main_game_flow.yaml#training_coach_katago
      final runner = _StructuredTrainingSuggestionRunner();
      final provider = CaptureGameProvider(
        boardSize: 9,
        captureTarget: 5,
        difficulty: DifficultyLevel.beginner,
        gameMode: GameMode.territory,
        trainingSuggestionRunner: runner,
      );

      final suggestions = await provider.suggestMovesWithWinRateAsync(count: 3);

      expect(runner.requests, hasLength(1));
      expect(runner.requests.single.params['coachBackend'], 'katago_onnx');
      expect(
        runner.requests.single.params['modelAsset'],
        kKatagoDefaultModelAsset,
      );
      expect(runner.requests.single.params['policyTemperature'], 0);
      expect(runner.requests.single.params['candidateLimit'], 3);
      expect(suggestions, hasLength(1));
      expect(suggestions.single.position, const BoardPosition(2, 3));
      expect(suggestions.single.winRate, 0.64);
      expect(suggestions.single.policyProbability, 0.72);
      expect(suggestions.single.strategyLabel, '穩定推薦');
      expect(suggestions.single.explanationSignals, contains('策略偏好 72%'));
      expect(suggestions.single.source, 'katago');

      provider.dispose();
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
