import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/providers/capture_game_provider.dart';

void main() {
  const boardSizes = [9, 13, 19];

  group('Capture AI robot configs', () {
    test('registered configs cover every style and difficulty', () {
      final configs = CaptureAiRegistry.registeredConfigs;

      expect(
        configs.map((config) => config.id).toSet(),
        hasLength(CaptureAiStyle.values.length * DifficultyLevel.values.length),
      );
      expect(
        configs.where((config) => config.engine == CaptureAiEngine.heuristic),
        isNotEmpty,
      );
      expect(
        configs.where((config) => config.engine == CaptureAiEngine.hybridMcts),
        isNotEmpty,
      );
      expect(
        configs.where((config) =>
            config.engine == CaptureAiEngine.hybridMcts &&
            config.mctsPlayouts > 0),
        isNotEmpty,
      );
    });

    test('difficulty tiers preserve beginner and increase search budget',
        () {
      for (final style in CaptureAiStyle.values) {
        final beginner = CaptureAiRegistry.resolveConfig(
          style: style,
          difficulty: DifficultyLevel.beginner,
        );
        final intermediate = CaptureAiRegistry.resolveConfig(
          style: style,
          difficulty: DifficultyLevel.intermediate,
        );
        final advanced = CaptureAiRegistry.resolveConfig(
          style: style,
          difficulty: DifficultyLevel.advanced,
        );

        expect(beginner.engine, CaptureAiEngine.heuristic);
        expect(beginner.heuristicPlayouts, 12);
        expect(beginner.mctsPlayouts, 0);
        expect(beginner.mctsRolloutDepth, 0);

        expect(intermediate.engine, CaptureAiEngine.hybridMcts);
        expect(
          intermediate.heuristicPlayouts,
          greaterThanOrEqualTo(beginner.heuristicPlayouts),
        );
        expect(intermediate.mctsPlayouts, greaterThan(0));
        expect(intermediate.mctsRolloutDepth, greaterThan(0));

        expect(advanced.engine, CaptureAiEngine.hybridMcts);
        expect(
          advanced.heuristicPlayouts,
          greaterThan(intermediate.heuristicPlayouts),
        );
        expect(advanced.mctsPlayouts, greaterThan(intermediate.mctsPlayouts));
        expect(
          advanced.mctsRolloutDepth,
          greaterThan(intermediate.mctsRolloutDepth),
        );
        expect(
          advanced.mctsCandidateLimit,
          greaterThan(intermediate.mctsCandidateLimit),
        );
        expect(
          advanced.rolloutTemperature,
          lessThan(intermediate.rolloutTemperature),
        );
      }
    });

    test(
        'each registered config chooses legal moves for empty and twist-cross openings',
        () {
      for (final boardSize in boardSizes) {
        for (final config in CaptureAiRegistry.registeredConfigs) {
          for (final board in [
            SimBoard(boardSize, captureTarget: 5),
            _twistCrossBoard(boardSize),
          ]) {
            final agent =
                CaptureAiRegistry.createFromConfig(_fastConfig(config));
            final move = agent.chooseMove(board);

            expect(
              move,
              isNotNull,
              reason:
                  '${config.id} should choose a move on ${boardSize}x$boardSize',
            );
            expect(
              board.applyMove(move!.position.row, move.position.col),
              isTrue,
              reason:
                  '${config.id} should choose a legal move on ${boardSize}x$boardSize',
            );
          }
        }
      }
    });

    test(
        'representative engines can play bounded sequences without invalid moves',
        () {
      final configs = [
        CaptureAiRegistry.resolveConfig(
          style: CaptureAiStyle.adaptive,
          difficulty: DifficultyLevel.beginner,
        ),
        CaptureAiRegistry.resolveConfig(
          style: CaptureAiStyle.hunter,
          difficulty: DifficultyLevel.intermediate,
        ),
        CaptureAiRegistry.resolveConfig(
          style: CaptureAiStyle.counter,
          difficulty: DifficultyLevel.advanced,
        ),
      ];

      for (final boardSize in boardSizes) {
        for (final config in configs) {
          for (final board in [
            SimBoard(boardSize, captureTarget: 5),
            _twistCrossBoard(boardSize),
          ]) {
            _expectBoundedPlay(
              board: board,
              blackAgent:
                  CaptureAiRegistry.createFromConfig(_fastConfig(config)),
              whiteAgent: CaptureAiRegistry.create(
                style: CaptureAiStyle.trapper,
                difficulty: DifficultyLevel.beginner,
              ),
              maxMoves: 12,
              reason: '${config.id} bounded play on ${boardSize}x$boardSize',
            );
          }
        }
      }
    });

    test('seeded MCTS robot choices are reproducible', () {
      final configA = CaptureAiRegistry.resolveConfig(
        style: CaptureAiStyle.counter,
        difficulty: DifficultyLevel.advanced,
        seed: 4242,
      );
      final configB = CaptureAiRegistry.resolveConfig(
        style: CaptureAiStyle.counter,
        difficulty: DifficultyLevel.advanced,
        seed: 4242,
      );

      final moveA = CaptureAiRegistry.createFromConfig(_fastConfig(configA))
          .chooseMove(_twistCrossBoard(13));
      final moveB = CaptureAiRegistry.createFromConfig(_fastConfig(configB))
          .chooseMove(_twistCrossBoard(13));

      expect(moveA, isNotNull);
      expect(moveB, isNotNull);
      expect(moveA!.position.row, moveB!.position.row);
      expect(moveA.position.col, moveB.position.col);
    });
  });
}

CaptureAiRobotConfig _fastConfig(CaptureAiRobotConfig config) {
  if (config.engine == CaptureAiEngine.heuristic) return config;
  return config.copyWith(
    mctsPlayouts: 4,
    mctsRolloutDepth: 6,
    mctsCandidateLimit: 4,
    rolloutTemperature: 0,
  );
}

SimBoard _twistCrossBoard(int boardSize) {
  final board = SimBoard(boardSize, captureTarget: 5);
  final center = boardSize ~/ 2;
  board.cells[board.idx(center - 1, center)] = SimBoard.black;
  board.cells[board.idx(center + 1, center)] = SimBoard.black;
  board.cells[board.idx(center, center - 1)] = SimBoard.white;
  board.cells[board.idx(center, center + 1)] = SimBoard.white;
  board.currentPlayer = SimBoard.black;
  return board;
}

void _expectBoundedPlay({
  required SimBoard board,
  required CaptureAiAgent blackAgent,
  required CaptureAiAgent whiteAgent,
  required int maxMoves,
  required String reason,
}) {
  var moves = 0;
  while (!board.isTerminal && moves < maxMoves) {
    final agent =
        board.currentPlayer == SimBoard.black ? blackAgent : whiteAgent;
    final move = agent.chooseMove(board);
    if (move == null) break;
    expect(
      board.applyMove(move.position.row, move.position.col),
      isTrue,
      reason: reason,
    );
    moves++;
  }

  expect(moves, greaterThan(0), reason: reason);
  expect(moves, lessThanOrEqualTo(maxMoves), reason: reason);
}
