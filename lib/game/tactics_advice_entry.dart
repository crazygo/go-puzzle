// Platform-agnostic tactics advice computation entry point.
//
// Must not import Flutter framework code so it can run in native isolates
// and browser DedicatedWorkers.

import 'capture_ai.dart';
import 'capture_ai_tactics.dart';
import 'difficulty_level.dart';
import 'mcts_engine.dart';

/// Builds AI style suggestions and oracle rankings for a tactics problem.
///
/// [params] must contain a serialised `problem` map from
/// [CaptureAiTacticsProblem.toJson].
Map<String, dynamic> runTacticsAdvice(Map<String, dynamic> params) {
  final rawProblem = params['problem'];
  if (rawProblem is! Map) {
    throw ArgumentError('Missing problem map in tactics advice params');
  }
  final problem = CaptureAiTacticsProblem.fromJson(
    Map<String, dynamic>.from(rawProblem),
    index: 0,
  );

  final baseBoard = problem.toBoard();
  final aiSuggestions = <Map<String, dynamic>>[];
  for (final style in CaptureAiStyle.values) {
    final agent = CaptureAiRegistry.create(
      style: style,
      difficulty: DifficultyLevel.advanced,
    );
    final move = agent.chooseMove(SimBoard.copy(baseBoard));
    aiSuggestions.add({
      'style': style.name,
      'row': move?.position.row,
      'col': move?.position.col,
      'score': move?.score,
    });
  }

  const oracleConfig = CaptureAiTacticalOracleConfig(
    depth: 2,
    candidateHorizon: 6,
    maxNodes: 3000,
    acceptScoreDelta: 80,
    topNAccepted: 3,
    maxAcceptedMoveRatio: 0.25,
    minConfidenceGap: 80,
  );
  final oracle =
      const CaptureAiTacticalOracle(config: oracleConfig).rankMoves(problem);

  return {
    'aiSuggestions': aiSuggestions,
    'oracleAuthoritative': oracle.authoritative,
    'oracleRankedMoves': [
      for (final move in oracle.rankedMoves.take(3))
        {
          'row': move.position.row,
          'col': move.position.col,
          'score': move.score,
        },
    ],
  };
}
