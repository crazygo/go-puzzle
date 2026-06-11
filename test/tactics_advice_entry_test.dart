import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/capture_ai_tactics.dart';
import 'package:go_puzzle/game/tactics_advice_entry.dart';
import 'package:go_puzzle/game/tactics_advice_snapshot.dart';

CaptureAiTacticsProblem _sampleProblem() {
  return CaptureAiTacticsProblem.fromJson(
    {
      'id': 'gf-9-001',
      'category': 'group_fate',
      'boardSize': 9,
      'currentPlayer': 'black',
      'capturedByBlack': 2,
      'capturedByWhite': 1,
      'diagram': [
        '..W......',
        '.WB.B....',
        '..B......',
        '...BWB...',
        '...BWB...',
        '....B....',
        '.....W...',
        '....B....',
        '.........',
      ],
      'notes': 'Black can settle by capturing.',
    },
    index: 0,
  );
}

void main() {
  test('runTacticsAdvice returns style suggestions and oracle moves', () {
    final problem = _sampleProblem();
    final raw = runTacticsAdvice({'problem': problem.toJson()});
    final advice = TacticsAdviceSnapshot.fromMap(raw);

    expect(advice.aiSuggestions.length, CaptureAiStyle.values.length);
    expect(advice.aiSuggestions.every((s) => s.style.label.isNotEmpty), isTrue);
    expect(advice.oracleRankedMoves, isNotEmpty);
    expect(advice.primaryMove, isNotNull);
  });
}
