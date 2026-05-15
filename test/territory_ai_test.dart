import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/difficulty_level.dart';
import 'package:go_puzzle/game/game_mode.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/game/territory_ai.dart';

void main() {
  group('Territory AI', () {
    test('advanced territory engine chooses a legal opening move', () {
      final board = SimBoard(9, captureTarget: 5, gameMode: GameMode.territory);
      final move = TerritoryAiEngine(difficulty: DifficultyLevel.advanced)
          .chooseMove(board);
      expect(move, isNot(territoryPassMove));
      expect(board.analyzeMove(move.row, move.col).isLegal, isTrue);
    });
  });
}
