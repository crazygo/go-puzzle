import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/capture_ai_scripted_trials.dart';
import 'package:go_puzzle/game/difficulty_level.dart';
import 'package:go_puzzle/game/mcts_engine.dart';

void main() {
  group('Capture AI scripted trials', () {
    test('default catalog covers every opening and scripted tactic combination',
        () {
      final trials = CaptureAiScriptedTrialCatalog.defaults();
      final expectedCount = CaptureAiTrialOpening.values.length *
          CaptureAiScriptedTactic.values.length;

      expect(trials, hasLength(expectedCount));
      expect(
        trials.map((trial) => trial.opening).toSet(),
        CaptureAiTrialOpening.values.toSet(),
      );
      expect(
        trials.map((trial) => trial.tactic).toSet(),
        CaptureAiScriptedTactic.values.toSet(),
      );
    });

    test('default catalog includes the full practical trick set', () {
      expect(
        CaptureAiScriptedTactic.values.map((tactic) => tactic.name).toSet(),
        containsAll({
          'captureFirst',
          'atariFirst',
          'rescueFirst',
          'counterAtari',
          'selfAtariBait',
          'edgeClamp',
          'ladderChase',
          'netContain',
          'snapback',
          'libertyShortage',
          'connectAndDie',
          'sacrificeRace',
          'koFight',
          'throwIn',
        }),
      );
    });

    test('every scripted tactic has a fixture where its policy fires', () {
      final fixtures = <CaptureAiScriptedTactic, SimBoard Function()>{
        CaptureAiScriptedTactic.captureFirst: _captureFixture,
        CaptureAiScriptedTactic.atariFirst: _atariFixture,
        CaptureAiScriptedTactic.rescueFirst: _rescueFixture,
        CaptureAiScriptedTactic.counterAtari: _rescueFixture,
        CaptureAiScriptedTactic.selfAtariBait: _baitFixture,
        CaptureAiScriptedTactic.edgeClamp: _edgeFixture,
        CaptureAiScriptedTactic.ladderChase: _ladderFixture,
        CaptureAiScriptedTactic.netContain: _netFixture,
        CaptureAiScriptedTactic.snapback: _baitFixture,
        CaptureAiScriptedTactic.libertyShortage: _atariFixture,
        CaptureAiScriptedTactic.connectAndDie: _connectFixture,
        CaptureAiScriptedTactic.sacrificeRace: _atariFixture,
        CaptureAiScriptedTactic.koFight: _koFixture,
        CaptureAiScriptedTactic.throwIn: _baitFixture,
      };

      for (final tactic in CaptureAiScriptedTactic.values) {
        final board = fixtures[tactic]!();
        final policy = policyForTactic(tactic);
        final move = policy.chooseTacticalMove(board);

        expect(move, isNotNull, reason: '${policy.id} should find a tactic');
        expect(
          board.analyzeMove(move!.position.row, move.position.col).isLegal,
          isTrue,
          reason: '${policy.id} must choose a legal tactic move',
        );
      }
    });

    test('all default trial openings create legal non-terminal boards', () {
      for (final trial in CaptureAiScriptedTrialCatalog.defaults()) {
        final board = trial.buildInitialBoard();

        expect(board.size, trial.boardSize, reason: trial.id);
        expect(board.captureTarget, trial.captureTarget, reason: trial.id);
        expect(board.currentPlayer, 1, reason: trial.id);
        expect(board.isTerminal, isFalse, reason: trial.id);
        expect(board.getLegalMoves(), isNotEmpty, reason: trial.id);
      }
    });

    test('runner records a deterministic scripted trial result', () {
      final runner = CaptureAiScriptedTrialRunner(
        aiConfig: CaptureAiRobotConfig.forStyle(
          CaptureAiStyle.hunter,
          DifficultyLevel.beginner,
        ),
      );
      const trial = CaptureAiScriptedTrial(
        id: 'smoke_empty_capture_first',
        opening: CaptureAiTrialOpening.empty,
        tactic: CaptureAiScriptedTactic.captureFirst,
        maxMoves: 24,
      );

      final first = runner.run(trial);
      final replay = runner.run(trial);

      expect(first.endReason, isNot(CaptureAiMatchEndReason.invalidMove));
      expect(first.totalMoves, greaterThan(0));
      expect(first.totalMoves, lessThanOrEqualTo(trial.maxMoves));
      expect(first.winner, replay.winner);
      expect(first.endReason, replay.endReason);
      expect(first.totalMoves, replay.totalMoves);
      expect(first.blackCaptures, replay.blackCaptures);
      expect(first.whiteCaptures, replay.whiteCaptures);
    });
  });
}

SimBoard _board([
  List<(int row, int col, int color)> stones = const [],
  int currentPlayer = SimBoard.black,
]) {
  final board = SimBoard(9, captureTarget: 5);
  for (final stone in stones) {
    board.cells[board.idx(stone.$1, stone.$2)] = stone.$3;
  }
  board.currentPlayer = currentPlayer;
  return board;
}

SimBoard _captureFixture() {
  return _board([
    (1, 1, SimBoard.white),
    (0, 1, SimBoard.black),
    (1, 0, SimBoard.black),
    (2, 1, SimBoard.black),
  ]);
}

SimBoard _atariFixture() {
  return _board([
    (1, 1, SimBoard.white),
    (0, 1, SimBoard.black),
    (1, 0, SimBoard.black),
  ]);
}

SimBoard _rescueFixture() {
  return _board([
    (1, 1, SimBoard.black),
    (0, 1, SimBoard.white),
    (1, 0, SimBoard.white),
    (2, 1, SimBoard.white),
  ]);
}

SimBoard _edgeFixture() {
  return _board([
    (0, 2, SimBoard.white),
    (1, 1, SimBoard.black),
    (1, 3, SimBoard.black),
  ]);
}

SimBoard _ladderFixture() {
  return _board([
    (2, 2, SimBoard.white),
    (1, 2, SimBoard.black),
    (2, 1, SimBoard.black),
    (3, 3, SimBoard.black),
  ]);
}

SimBoard _netFixture() {
  return _board([
    (3, 3, SimBoard.white),
    (2, 2, SimBoard.black),
    (2, 4, SimBoard.black),
    (4, 2, SimBoard.black),
  ]);
}

SimBoard _connectFixture() {
  return _board([
    (3, 3, SimBoard.white),
    (3, 5, SimBoard.white),
    (2, 4, SimBoard.black),
    (4, 4, SimBoard.black),
  ]);
}

SimBoard _baitFixture() {
  return _board([
    (1, 2, SimBoard.white),
    (2, 1, SimBoard.white),
    (2, 3, SimBoard.white),
    (1, 1, SimBoard.black),
    (1, 3, SimBoard.black),
    (3, 1, SimBoard.black),
    (3, 3, SimBoard.black),
  ]);
}

SimBoard _koFixture() {
  return _board([
    (1, 1, SimBoard.white),
    (0, 1, SimBoard.black),
    (1, 0, SimBoard.black),
    (2, 1, SimBoard.black),
    (0, 2, SimBoard.white),
    (2, 2, SimBoard.white),
  ]);
}
