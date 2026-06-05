import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_algorithm_framework.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/capture5_onnx_features.dart';
import 'package:go_puzzle/game/katago_model_adapter.dart';
import 'package:go_puzzle/game/mcts_engine.dart';
import 'package:go_puzzle/models/board_position.dart';

void main() {
  group('AI algorithm framework registry', () {
    test('registers every required framework with runnable configs', () {
      expect(
        AiAlgorithmRegistry.frameworks.map((framework) => framework.id).toSet(),
        AiAlgorithmFrameworkId.values.toSet(),
      );

      for (final frameworkId in AiAlgorithmFrameworkId.values) {
        final configs = AiAlgorithmRegistry.configsFor(frameworkId);
        if (frameworkId == AiAlgorithmFrameworkId.capture5) {
          expect(configs, hasLength(1));
          expect(configs.single.id, kCapture5ModelId);
        } else {
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
        if (frameworkId == AiAlgorithmFrameworkId.capture5) continue;
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

    test('native playable configs produce legal opening moves', () {
      for (final config in AiAlgorithmRegistry.configs) {
        if (config.frameworkId == AiAlgorithmFrameworkId.katago ||
            config.frameworkId == AiAlgorithmFrameworkId.capture5 ||
            config.frameworkId == AiAlgorithmFrameworkId.mctsCapture5) {
          continue;
        }
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

    test('KataGo exposes only native ONNX framework configs', () {
      final katagoConfigs =
          AiAlgorithmRegistry.configsFor(AiAlgorithmFrameworkId.katago);
      final onnxConfigs = katagoConfigs
          .where((config) => config.parameters['backend'] == 'onnx')
          .toList(growable: false);

      expect(katagoConfigs, hasLength(2));
      expect(onnxConfigs, hasLength(greaterThanOrEqualTo(2)));
      for (final config in onnxConfigs) {
        expect(config.usesFallback, isFalse);
        expect(config.runtimeMode, AiAlgorithmRuntimeMode.native);
        expect(config.failureMode, isNull);
        expect(config.parameters['modelAsset'], kKatagoDefaultModelAsset);
        expect(config.parameters.containsKey('visits'), isFalse);
        expect(config.parameters.containsKey('captureSearchDepth'), isFalse);
        expect(config.parameters['timeBudgetMillis'], 10000);
        expect(config.parameters['policyTemperature'], isA<num>());
        expect(config.parameters['candidateLimit'], isA<int>());
      }
    });

    test('Capture5 exposes one 13x13 11-plane policy-only ONNX config', () {
      final configs =
          AiAlgorithmRegistry.configsFor(AiAlgorithmFrameworkId.capture5);
      final config = configs.single;

      expect(config.id, kCapture5ModelId);
      expect(config.usesFallback, isFalse);
      expect(config.runtimeMode, AiAlgorithmRuntimeMode.native);
      expect(config.failureMode, isNull);
      expect(config.parameters['backend'], 'onnx');
      expect(config.parameters['modelId'], kCapture5ModelId);
      expect(config.parameters['modelAsset'], kCapture5ModelAsset);
      expect(config.parameters['metadataAsset'], kCapture5ModelMetadataAsset);
      expect(config.parameters['featureSchemaId'], kCapture5FeatureSchemaId);
      expect(config.parameters['architecture'], 'capture5_resnet_phase1_v1');
      expect(config.parameters['boardSize'], 13);
      expect(config.parameters['captureTarget'], 5);
      expect(config.parameters['inputPlanes'], 11);
      expect(config.parameters['policySize'], 170);
      expect(config.parameters['passMoveIndex'], 169);
      expect(config.parameters['onnxSha256'], kCapture5ModelSha256);
      expect(config.parameters.containsKey('visits'), isFalse);
      expect(config.parameters.containsKey('captureSearchDepth'), isFalse);
    });

    test('MCTS+Capture5 exposes two ONNX-guided MCTS configs', () {
      final configs =
          AiAlgorithmRegistry.configsFor(AiAlgorithmFrameworkId.mctsCapture5);

      expect(
        configs.map((config) => config.id),
        ['mcts_capture5_weak_v1', 'mcts_capture5_standard_v1'],
      );
      for (final config in configs) {
        expect(config.usesFallback, isFalse);
        expect(config.runtimeMode, AiAlgorithmRuntimeMode.native);
        expect(config.parameters['backend'], 'onnx');
        expect(config.parameters['modelId'], kCapture5ModelId);
        expect(config.parameters['modelAsset'], kCapture5ModelAsset);
        expect(config.parameters['featureSchemaId'], kCapture5FeatureSchemaId);
        expect(config.parameters['inputPlanes'], 11);
        expect(config.parameters['policySize'], 170);
        expect(config.parameters['passMoveIndex'], 169);
        expect(config.parameters['mctsPlayouts'], isA<int>());
        expect(config.parameters['mctsRolloutDepth'], isA<int>());
        expect(config.parameters['mctsCandidateLimit'], isA<int>());
        expect(config.parameters['policyPriorWeight'], isA<num>());
        expect(config.robotConfig.engine, CaptureAiEngine.mcts);
      }
    });

    test('MCTS+Capture5 standard keeps bounded tactical search enabled', () {
      final guidedStandard =
          AiAlgorithmRegistry.configById('mcts_capture5_standard_v1');

      expect(guidedStandard.parameters['mctsPlayouts'], 4);
      expect(guidedStandard.parameters['mctsRolloutDepth'], 4);
      expect(guidedStandard.parameters['mctsCandidateLimit'], 6);
      expect(guidedStandard.parameters['rolloutTemperature'], 3.0);
      expect(guidedStandard.parameters['captureSearchDepth'], 2);
      expect(guidedStandard.robotConfig.mctsPlayouts, 4);
      expect(guidedStandard.robotConfig.mctsRolloutDepth, 4);
      expect(guidedStandard.robotConfig.mctsCandidateLimit, 6);
    });

    test('KataGo ONNX config reports unavailable when model is missing', () {
      final config = AiAlgorithmRegistry.configById('katago_onnx_weak_v1');
      final board = SimBoard(9, captureTarget: 5);
      final agent = AiAlgorithmRegistry.createAgent(
        config,
        katagoModelAdapter: const UnavailableKatagoOnnxModelAdapter(),
      );
      final move = agent.chooseMove(board);

      expect(move, isNull);
    });

    test('KataGo ONNX adapter move is used when legal', () {
      final config = AiAlgorithmRegistry.configById('katago_onnx_standard_v1');
      final agent = AiAlgorithmRegistry.createAgent(
        config,
        katagoModelAdapter: const _FixedKatagoModelAdapter(
          BoardPosition(4, 4),
        ),
      );
      final move = agent.chooseMove(SimBoard(9, captureTarget: 5));

      expect(move, isNotNull);
      expect(move!.position.row, 4);
      expect(move.position.col, 4);
    });

    test('KataGo ONNX adapter move ignores tactical analyzer override', () {
      final config = AiAlgorithmRegistry.configById('katago_onnx_standard_v1');
      final agent = AiAlgorithmRegistry.createAgent(
        config,
        katagoModelAdapter: const _FixedKatagoModelAdapter(
          BoardPosition(4, 4),
        ),
        tacticalAnalyzer: const _FixedTacticalAnalyzer(
          TacticalAnalysis(
            signal: TacticalSignal.ladderRisk,
            confidence: 1,
            recommendedMove: BoardPosition(0, 0),
            reason: 'force a different move',
          ),
        ),
      );
      final move = agent.chooseMove(SimBoard(9, captureTarget: 5));

      expect(move, isNotNull);
      expect(move!.position.row, 4);
      expect(move.position.col, 4);
    });

    test('async KataGo ONNX adapter move ignores tactical analyzer override',
        () async {
      final config = AiAlgorithmRegistry.configById('katago_onnx_standard_v1');
      final agent = AiAlgorithmRegistry.createAsyncAgent(
        config,
        katagoModelAdapter: const _FixedAsyncKatagoModelAdapter(
          BoardPosition(4, 4),
        ),
        tacticalAnalyzer: const _FixedTacticalAnalyzer(
          TacticalAnalysis(
            signal: TacticalSignal.ladderRisk,
            confidence: 1,
            recommendedMove: BoardPosition(0, 0),
            reason: 'force a different move',
          ),
        ),
      );
      final move = await agent.chooseMove(SimBoard(9, captureTarget: 5));

      expect(move, isNotNull);
      expect(move!.position.row, 4);
      expect(move.position.col, 4);
    });

    test('async Capture5 adapter move is used directly when legal', () async {
      final config = AiAlgorithmRegistry.configById(kCapture5ModelId);
      final agent = AiAlgorithmRegistry.createAsyncAgent(
        config,
        katagoModelAdapter: const _FixedAsyncKatagoModelAdapter(
          BoardPosition(6, 6),
        ),
        tacticalAnalyzer: const _FixedTacticalAnalyzer(
          TacticalAnalysis(
            signal: TacticalSignal.ladderRisk,
            confidence: 1,
            recommendedMove: BoardPosition(0, 0),
            reason: 'force a different move',
          ),
        ),
      );
      final move = await agent.chooseMove(SimBoard(13, captureTarget: 5));

      expect(move, isNotNull);
      expect(move!.position.row, 6);
      expect(move.position.col, 6);
    });

    test('async MCTS+Capture5 requests Capture5 policy and returns legal move',
        () async {
      final config = AiAlgorithmRegistry.configById('mcts_capture5_weak_v1');
      final adapter = _PolicyAsyncKatagoModelAdapter([
        const KatagoPolicyCandidate(
          position: BoardPosition(6, 6),
          score: 4,
          probability: 0.70,
          rank: 1,
          policyPlane: 0,
        ),
        const KatagoPolicyCandidate(
          position: BoardPosition(5, 5),
          score: 3,
          probability: 0.20,
          rank: 2,
          policyPlane: 0,
        ),
      ]);
      final agent = AiAlgorithmRegistry.createAsyncAgent(
        config,
        katagoModelAdapter: adapter,
      );
      final board = SimBoard(13, captureTarget: 5);

      final move = await agent.chooseMove(board);

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.modelAsset, kCapture5ModelAsset);
      expect(adapter.requests.single.candidateLimit, 18);
      expect(move, isNotNull);
      expect(
        board.analyzeMove(move!.position.row, move.position.col).isLegal,
        isTrue,
      );
    });

    test('async MCTS+Capture5 standard can override a bad model prior',
        () async {
      final board = _twistLadderCaseAfterBlackI5();
      final blunderIndex = _sgfIndex(board.size, 'jf'); // J6
      final config =
          AiAlgorithmRegistry.configById('mcts_capture5_standard_v1');
      final adapter = _PolicyAsyncKatagoModelAdapter([
        KatagoPolicyCandidate(
          position: BoardPosition(
            blunderIndex ~/ board.size,
            blunderIndex % board.size,
          ),
          score: 10,
          probability: 0.95,
          rank: 1,
          policyPlane: 0,
        ),
        const KatagoPolicyCandidate(
          position: BoardPosition(6, 6),
          score: 2,
          probability: 0.03,
          rank: 2,
          policyPlane: 0,
        ),
      ]);
      final agent = AiAlgorithmRegistry.createAsyncAgent(
        config,
        katagoModelAdapter: adapter,
      );

      final move = await agent.chooseMove(SimBoard.copy(board));

      expect(move, isNotNull);
      final moveIndex = board.idx(move!.position.row, move.position.col);
      expect(
        moveIndex,
        isNot(blunderIndex),
        reason:
            'Capture-search scoring must be strong enough to reject a model '
            'prior that prefers the proven doomed J6 ladder extension.',
      );
    });

    test('neutral tactical analysis does not change selected move', () {
      final config =
          AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1');
      final baseline = AiAlgorithmRegistry.createAgent(config, seedOverride: 7);
      final analyzed = AiAlgorithmRegistry.createAgent(
        config,
        seedOverride: 7,
        tacticalAnalyzer: const NeutralTacticalAnalyzer(),
      );

      final baselineMove =
          baseline.chooseMove(SimBoard(9, captureTarget: 5))!.position;
      final analyzedMove =
          analyzed.chooseMove(SimBoard(9, captureTarget: 5))!.position;

      expect(analyzedMove.row, baselineMove.row);
      expect(analyzedMove.col, baselineMove.col);
    });

    test('low-confidence tactical analysis does not force a move', () {
      final config =
          AiAlgorithmRegistry.configById('heuristic_adaptive_weak_v1');
      final baseline =
          AiAlgorithmRegistry.createAgent(config, seedOverride: 11);
      final analyzed = AiAlgorithmRegistry.createAgent(
        config,
        seedOverride: 11,
        tacticalAnalyzer: const _FixedTacticalAnalyzer(
          TacticalAnalysis(
            signal: TacticalSignal.ladderRisk,
            confidence: 0.40,
            recommendedMove: BoardPosition(0, 0),
            reason: 'low confidence probe',
          ),
        ),
      );

      final baselineMove =
          baseline.chooseMove(SimBoard(9, captureTarget: 5))!.position;
      final analyzedMove =
          analyzed.chooseMove(SimBoard(9, captureTarget: 5))!.position;

      expect(analyzedMove.row, baselineMove.row);
      expect(analyzedMove.col, baselineMove.col);
    });

    test('standard configs defend a two-liberty ladder chain instead of tenuki',
        () {
      for (final id in const [
        'mcts_counter_standard_v1',
        'hybrid_tactical_counter_standard_v1',
        'heuristic_counter_standard_v1',
      ]) {
        final board = _sadakoLadderCaseAfterBlackG12();
        final config = AiAlgorithmRegistry.configById(id);
        final agent = AiAlgorithmRegistry.createAgent(config);

        final move = agent.chooseMove(board);

        expect(move, isNotNull, reason: id);
        final moveIndex = board.idx(move!.position.row, move.position.col);
        expect(
          moveIndex,
          isIn({
            _sgfIndex(board.size, 'fk'), // F11
            _sgfIndex(board.size, 'hk'), // H11
          }),
          reason:
              '$id must address the lower G9-G10-G11 chain before Black H11 '
              'starts a forced capture race.',
        );
      }
    });

    test('doomed rescue scorer flags the twist ladder entry move', () {
      final board = _twistLadderCaseAfterBlackI5();
      final moveIndex = _sgfIndex(board.size, 'jf'); // J6
      final analysis = board.analyzeMove(
        moveIndex ~/ board.size,
        moveIndex % board.size,
      );

      expect(analysis.isLegal, isTrue);
      expect(
        scoreDoomedAtariExtensionPenalty(board, moveIndex, analysis),
        greaterThan(0),
        reason: 'J6 saves the I6 stone, but Black can keep the group in atari '
            'until M3 captures a seven-stone chain.',
      );
    });

    test('doomed rescue scorer does not penalize the required lower defense',
        () {
      final board = _sadakoLadderCaseAfterBlackG12();
      for (final point in const ['fk', 'hk']) {
        final moveIndex = _sgfIndex(board.size, point);
        final analysis = board.analyzeMove(
          moveIndex ~/ board.size,
          moveIndex % board.size,
        );

        expect(analysis.isLegal, isTrue, reason: point);
        expect(
          scoreDoomedAtariExtensionPenalty(board, moveIndex, analysis),
          0,
          reason: '$point is a required defense, not a doomed rescue.',
        );
        expect(
          scoreCriticalOwnGroupDefense(board, moveIndex, analysis),
          greaterThan(0),
          reason: '$point should still receive the positive defense signal.',
        );
      }
    });

    test('immediate opponent capture scorer flags snapback captures', () {
      final corpus = jsonDecode(
        File('docs/ai_eval/tactics/tactical_trap_corpus.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final sample = (corpus['samples'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .singleWhere(
              (sample) => sample['id'] == 'trap-throw-in-snapback-9x9-001');
      final board = _replayTrapEntry(sample);
      final blunderMove =
          (sample['blunderMoves'] as List<dynamic>).single as String;
      final point =
          RegExp(r'\[([a-z]{2})\]').firstMatch(blunderMove)!.group(1)!;
      final moveIndex = _sgfIndex(board.size, point);
      final analysis = board.analyzeMove(
        moveIndex ~/ board.size,
        moveIndex % board.size,
      );

      expect(analysis.isLegal, isTrue);
      expect(analysis.whiteCaptureDelta, 1);
      expect(
        scoreImmediateOpponentCapturePenalty(board, moveIndex, analysis),
        greaterThan(0),
        reason:
            'Capturing the thrown-in stone lets Black immediately play back '
            'at the throw-in point and capture the surrounding white chain.',
      );
    });

    test('mcts standard avoids extending a doomed twist ladder chain', () {
      final board = _twistLadderCaseAfterBlackI5();
      final config = AiAlgorithmRegistry.configById('mcts_counter_standard_v1');
      final agent = AiAlgorithmRegistry.createAgent(config);

      final move = agent.chooseMove(board);

      expect(move, isNotNull);
      final moveIndex = board.idx(move!.position.row, move.position.col);
      expect(
        moveIndex,
        isNot(_sgfIndex(board.size, 'jf')), // J6
        reason:
            'White J6 starts saving the atari stone at I6, which lets Black '
            'force K6, J5, J4, K3, L4, M4, L3, L2 and eventually M3 to '
            'capture a seven-stone chain.',
      );
    });

    test('mcts standard avoids generated proven twist-ladder failures', () {
      final corpus = jsonDecode(
        File('docs/ai_eval/tactics/tactical_trap_corpus.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final samples = (corpus['samples'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((sample) => const {
                'trap-twist-ladder-13x13-021',
                'trap-twist-ladder-13x13-029',
                'trap-twist-ladder-13x13-083',
              }.contains(sample['id']))
          .toList(growable: false);
      expect(samples, hasLength(3));

      final config = AiAlgorithmRegistry.configById('mcts_counter_standard_v1');
      final agent = AiAlgorithmRegistry.createAgent(config);
      for (final sample in samples) {
        final board = _replayTrapEntry(sample);
        final blunderMoves =
            (sample['blunderMoves'] as List<dynamic>).cast<String>().toSet();

        final move = agent.chooseMove(SimBoard.copy(board));

        expect(move, isNotNull, reason: sample['id'] as String);
        final selected = _moveText(
          board.currentPlayer,
          board.size,
          move!.position.row,
          move.position.col,
        );
        expect(
          selected,
          isNot(isIn(blunderMoves)),
          reason:
              '${sample['id']} has a replay-proven five-capture failure line.',
        );
      }
    });

    test('mcts standard avoids generated snapback capture failures', () {
      final corpus = jsonDecode(
        File('docs/ai_eval/tactics/tactical_trap_corpus.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final samples = (corpus['samples'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((sample) => const {
                'trap-throw-in-snapback-9x9-001',
                'trap-throw-in-snapback-9x9-008',
                'trap-throw-in-snapback-13x13-001',
                'trap-throw-in-snapback-13x13-015',
              }.contains(sample['id']))
          .toList(growable: false);
      expect(samples, hasLength(4));

      final config = AiAlgorithmRegistry.configById('mcts_counter_standard_v1');
      final agent = AiAlgorithmRegistry.createAgent(config);
      for (final sample in samples) {
        final board = _replayTrapEntry(sample);
        final blunderMoves =
            (sample['blunderMoves'] as List<dynamic>).cast<String>().toSet();

        final move = agent.chooseMove(SimBoard.copy(board));

        expect(move, isNotNull, reason: sample['id'] as String);
        final selected = _moveText(
          board.currentPlayer,
          board.size,
          move!.position.row,
          move.position.col,
        );
        expect(
          selected,
          isNot(isIn(blunderMoves)),
          reason:
              '${sample['id']} captures a throw-in stone and allows snapback.',
        );
      }
    });
  });
}

SimBoard _sadakoLadderCaseAfterBlackG12() {
  final board = SimBoard(13, captureTarget: 5);
  for (final point in ['gf', 'gh']) {
    board.cells[_sgfIndex(board.size, point)] = SimBoard.black;
  }
  for (final point in ['fg', 'hg']) {
    board.cells[_sgfIndex(board.size, point)] = SimBoard.white;
  }
  board.currentPlayer = SimBoard.black;

  final moves = <(int, String)>[
    (SimBoard.black, 'gg'),
    (SimBoard.white, 'ff'),
    (SimBoard.black, 'ig'),
    (SimBoard.white, 'hf'),
    (SimBoard.black, 'he'),
    (SimBoard.white, 'hh'),
    (SimBoard.black, 'fe'),
    (SimBoard.white, 'fh'),
    (SimBoard.black, 'ef'),
    (SimBoard.white, 'gi'),
    (SimBoard.black, 'ge'),
    (SimBoard.white, 'if'),
    (SimBoard.black, 'hi'),
    (SimBoard.white, 'ih'),
    (SimBoard.black, 'jg'),
    (SimBoard.white, 'ii'),
    (SimBoard.black, 'hj'),
    (SimBoard.white, 'gj'),
    (SimBoard.black, 'ij'),
    (SimBoard.white, 'jf'),
    (SimBoard.black, 'fi'),
    (SimBoard.white, 'jh'),
    (SimBoard.black, 'ej'),
    (SimBoard.white, 'kg'),
    (SimBoard.black, 'fj'),
    (SimBoard.white, 'gk'),
    (SimBoard.black, 'gl'),
  ];

  for (final move in moves) {
    final moveIndex = _sgfIndex(board.size, move.$2);
    expect(board.currentPlayer, move.$1, reason: 'before ${move.$2}');
    expect(
      board.applyMove(moveIndex ~/ board.size, moveIndex % board.size),
      isTrue,
      reason: move.$2,
    );
  }
  return board;
}

SimBoard _twistLadderCaseAfterBlackI5() {
  final board = SimBoard(13, captureTarget: 5);
  for (final point in ['gf', 'gh']) {
    board.cells[_sgfIndex(board.size, point)] = SimBoard.black;
  }
  for (final point in ['fg', 'hg']) {
    board.cells[_sgfIndex(board.size, point)] = SimBoard.white;
  }
  board.currentPlayer = SimBoard.black;

  final moves = <(int, String)>[
    (SimBoard.black, 'hf'),
    (SimBoard.white, 'gg'),
    (SimBoard.black, 'ig'),
    (SimBoard.white, 'ff'),
    (SimBoard.black, 'fe'),
    (SimBoard.white, 'fh'),
    (SimBoard.black, 'ef'),
    (SimBoard.white, 'hh'),
    (SimBoard.black, 'gi'),
    (SimBoard.white, 'ih'),
    (SimBoard.black, 'jh'),
    (SimBoard.white, 'if'),
    (SimBoard.black, 'jg'),
    (SimBoard.white, 'ge'),
    (SimBoard.black, 'he'),
    (SimBoard.white, 'gd'),
    (SimBoard.black, 'ie'),
  ];

  for (final move in moves) {
    final moveIndex = _sgfIndex(board.size, move.$2);
    expect(board.currentPlayer, move.$1, reason: 'before ${move.$2}');
    expect(
      board.applyMove(moveIndex ~/ board.size, moveIndex % board.size),
      isTrue,
      reason: move.$2,
    );
  }
  return board;
}

int _sgfIndex(int size, String sgfPoint) {
  final col = sgfPoint.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final row = sgfPoint.codeUnitAt(1) - 'a'.codeUnitAt(0);
  return row * size + col;
}

SimBoard _replayTrapEntry(Map<String, dynamic> sample) {
  final sgf = sample['sgf'] as String;
  final size = int.parse(RegExp(r'SZ\[(\d+)\]').firstMatch(sgf)!.group(1)!);
  final board = SimBoard(size, captureTarget: sample['captureTarget'] as int);
  final setup =
      RegExp(r'^\(;FF\[4\]GM\[1\]SZ\[\d+\]([^;]*)').firstMatch(sgf)!.group(1)!;
  for (final point in _setupPoints(setup, 'AB')) {
    board.cells[_sgfIndex(size, point)] = SimBoard.black;
  }
  for (final point in _setupPoints(setup, 'AW')) {
    board.cells[_sgfIndex(size, point)] = SimBoard.white;
  }
  board.currentPlayer = SimBoard.black;

  final entryPly = sample['entryPly'] as int;
  var playedMoves = 0;
  for (final move in RegExp(r';([BW])\[([a-z]{2})\]').allMatches(sgf)) {
    if (playedMoves >= entryPly) break;
    final moveIndex = _sgfIndex(size, move.group(2)!);
    expect(
      board.applyMove(moveIndex ~/ size, moveIndex % size),
      isTrue,
      reason: '${sample['id']} replay ${move.group(0)}',
    );
    playedMoves++;
  }
  return board;
}

Iterable<String> _setupPoints(String setup, String property) sync* {
  final match = RegExp('$property((?:\\[[a-z]{2}\\])+)', multiLine: false)
      .firstMatch(setup);
  if (match == null) return;
  for (final point in RegExp(r'\[([a-z]{2})\]').allMatches(match.group(1)!)) {
    yield point.group(1)!;
  }
}

String _moveText(int color, int size, int row, int col) {
  final prefix = color == SimBoard.black ? 'B' : 'W';
  return '$prefix[${String.fromCharCodes([
        col + 'a'.codeUnitAt(0),
        row + 'a'.codeUnitAt(0),
      ])}]';
}

class _FixedKatagoModelAdapter implements KatagoModelAdapter {
  const _FixedKatagoModelAdapter(this.move);

  final BoardPosition move;

  @override
  KatagoModelEvaluation chooseMove(KatagoModelRequest request) {
    return KatagoModelEvaluation(
      status: KatagoBackendStatus.ready,
      move: move,
    );
  }
}

class _FixedAsyncKatagoModelAdapter implements AsyncKatagoModelAdapter {
  const _FixedAsyncKatagoModelAdapter(this.move);

  final BoardPosition move;

  @override
  Future<void> preload(Iterable<KatagoModelRequest> requests) async {}

  @override
  Future<KatagoModelEvaluation> chooseMove(KatagoModelRequest request) async {
    return KatagoModelEvaluation(
      status: KatagoBackendStatus.ready,
      move: move,
    );
  }
}

class _PolicyAsyncKatagoModelAdapter implements AsyncKatagoModelAdapter {
  _PolicyAsyncKatagoModelAdapter(this.candidates);

  final List<KatagoPolicyCandidate> candidates;
  final List<KatagoModelRequest> requests = [];

  @override
  Future<void> preload(Iterable<KatagoModelRequest> requests) async {}

  @override
  Future<KatagoModelEvaluation> chooseMove(KatagoModelRequest request) async {
    requests.add(request);
    return KatagoModelEvaluation(
      status: KatagoBackendStatus.ready,
      move: candidates.first.position,
      policyCandidates: candidates,
    );
  }
}

class _FixedTacticalAnalyzer implements TacticalAnalyzer {
  const _FixedTacticalAnalyzer(this.analysis);

  final TacticalAnalysis analysis;

  @override
  TacticalAnalysis analyze({
    required SimBoard board,
    required AiAlgorithmConfig config,
  }) {
    return analysis;
  }
}
