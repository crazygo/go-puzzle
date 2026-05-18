import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/mcts_engine.dart';

void main() {
  group('AI algorithm framework registry', () {
    test('registers every required framework with at least two configs', () {
      expect(
        AiAlgorithmRegistry.frameworks.map((framework) => framework.id).toSet(),
        AiAlgorithmFrameworkId.values.toSet(),
      );

      for (final frameworkId in AiAlgorithmFrameworkId.values) {
        final configs = AiAlgorithmRegistry.configsFor(frameworkId);
        expect(
          configs,
          hasLength(greaterThanOrEqualTo(2)),
          reason: '${frameworkId.name} must expose at least two configs',
        );
        expect(
          configs.map((config) => config.strengthTier).toSet(),
          containsAll([AiAlgorithmStrengthTier.weak]),
          reason: '${frameworkId.name} needs a weak runnable config',
        );
      }
    });

    test('uses stable unique config ids and explicit parameters', () {
      final configs = AiAlgorithmRegistry.configs;

      expect(
        configs.map((config) => config.id).toSet(),
        hasLength(configs.length),
      );
      for (final config in configs) {
        expect(config.parameters, isNotEmpty, reason: config.id);
        expect(config.toJson()['id'], config.id);
        expect(config.toJson()['frameworkId'], config.frameworkId.name);
      }
    });

    test('stronger configs differ by real parameters within each framework',
        () {
      for (final frameworkId in AiAlgorithmFrameworkId.values) {
        final configs = AiAlgorithmRegistry.configsFor(frameworkId);
        final parameterSets =
            configs.map((config) => config.parameters.toString()).toSet();
        expect(
          parameterSets.length,
          greaterThan(1),
          reason: '${frameworkId.name} configs must differ by parameters',
        );
      }
    });

    test('all current framework configs produce legal opening moves', () {
      for (final config in AiAlgorithmRegistry.configs) {
        final board = SimBoard(9, captureTarget: 5);
        final agent = AiAlgorithmRegistry.createAgent(config);
        final move = agent.chooseMove(board);

        expect(move, isNotNull, reason: config.id);
        expect(
          board.applyMove(move!.position.row, move.position.col),
          isTrue,
          reason: '${config.id} should choose a legal move',
        );
      }
    });

    test('KataGo configs are represented as fallback-capable framework configs',
        () {
      final katagoConfigs =
          AiAlgorithmRegistry.configsFor(AiAlgorithmFrameworkId.katago);

      expect(katagoConfigs, hasLength(greaterThanOrEqualTo(2)));
      for (final config in katagoConfigs) {
        expect(config.usesFallback, isTrue);
        expect(config.failureMode, isNotNull);
        expect(config.parameters['backend'], 'fallback');
      }
    });
  });
}
