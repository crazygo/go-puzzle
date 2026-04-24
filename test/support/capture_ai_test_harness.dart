import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/models/board_position.dart' show StoneColor;
import 'package:go_puzzle/providers/capture_game_provider.dart';

class CaptureAiTestHarness {
  const CaptureAiTestHarness._();

  static CaptureAiArenaResult expectPlayableMatch({
    required CaptureAiStyle blackStyle,
    required CaptureAiStyle whiteStyle,
    DifficultyLevel difficulty = DifficultyLevel.beginner,
    int boardSize = 9,
    int captureTarget = 1,
    int maxMoves = 120,
  }) {
    final result = CaptureAiArena.playMatch(
      blackAgent:
          CaptureAiRegistry.create(style: blackStyle, difficulty: difficulty),
      whiteAgent:
          CaptureAiRegistry.create(style: whiteStyle, difficulty: difficulty),
      boardSize: boardSize,
      captureTarget: captureTarget,
      maxMoves: maxMoves,
    );

    expect(
      result.completedWithoutFlowError,
      isTrue,
      reason:
          'AI match should not terminate due to invalid move: $blackStyle vs $whiteStyle',
    );
    expect(result.totalMoves, greaterThan(0));
    expect(result.blackCaptures, greaterThanOrEqualTo(0));
    expect(result.whiteCaptures, greaterThanOrEqualTo(0));

    if (!result.reachedCaptureTarget) {
      expect(
        result.blackCaptures < captureTarget &&
            result.whiteCaptures < captureTarget,
        isTrue,
        reason: 'Both sides should be below capture target when game did not'
            ' reach it: black=${result.blackCaptures},'
            ' white=${result.whiteCaptures}, target=$captureTarget',
      );
    }

    if (result.reachedCaptureTarget) {
      expect(
        result.winner,
        anyOf(StoneColor.black, StoneColor.white),
      );
      expect(
        result.blackCaptures >= captureTarget ||
            result.whiteCaptures >= captureTarget,
        isTrue,
      );
    }

    return result;
  }

  static CaptureAiSeriesResult expectRoundRobin({
    required List<CaptureAiStyle> styles,
    DifficultyLevel difficulty = DifficultyLevel.beginner,
    int boardSize = 9,
    int captureTarget = 1,
    int maxMoves = 120,
  }) {
    final result = CaptureAiArena.runRoundRobin(
      styles: styles,
      difficulty: difficulty,
      boardSize: boardSize,
      captureTarget: captureTarget,
      maxMoves: maxMoves,
    );

    final expectedMatches = styles.length * (styles.length - 1);
    expect(result.entries, hasLength(expectedMatches));

    for (final entry in result.entries) {
      final match = entry.result;
      expect(
        match.completedWithoutFlowError,
        isTrue,
        reason:
            'Round robin match ended with flow error: ${entry.blackStyle} vs ${entry.whiteStyle}',
      );
      expect(match.totalMoves, greaterThan(0));
      if (match.reachedCaptureTarget) {
        expect(
          match.winner,
          anyOf(StoneColor.black, StoneColor.white),
        );
      }
    }

    return result;
  }

  static void expectAgentCanChooseLegalMove({
    required CaptureAiStyle style,
    required SimBoardBuilder boardBuilder,
    DifficultyLevel difficulty = DifficultyLevel.beginner,
  }) {
    final board = boardBuilder();
    final agent =
        CaptureAiRegistry.create(style: style, difficulty: difficulty);
    final move = agent.chooseMove(board);

    expect(move, isNotNull, reason: 'AI style $style should choose a move.');
    expect(board.applyMove(move!.position.row, move.position.col), isTrue);
  }
}

typedef SimBoardBuilder = SimBoard Function();
