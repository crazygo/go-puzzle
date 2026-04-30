// ignore_for_file: avoid_print
import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:go_puzzle/game/ai_arena_ladder.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/ai_arena_scheduler.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/difficulty_level.dart';

/// Developer runner for the AI arena ladder.
///
/// Usage:
///   dart run tool/capture_ai_arena_runner.dart [options]
///
/// Options:
///   --smoke                Run a minimal deterministic smoke test
///   --rounds <n>           Games per match (default: 10)
///   --promotion-threshold  Wins required to promote (default: 7)
///   --board-size <n>       Board size (default: 9)
///   --capture-target <n>   Capture target (default: 5)
///   --output <path>        Path for matches JSONL (default: build/ai_arena/matches.jsonl)
///   --snapshot <path>      Path for ladder snapshot JSON (default: build/ai_arena/ladder.json)
void main(List<String> args) {
  final opts = _parseArgs(args);

  final outputPath =
      opts['output'] as String? ?? 'build/ai_arena/matches.jsonl';
  final snapshotPath =
      opts['snapshot'] as String? ?? 'build/ai_arena/ladder.json';
  final rounds = int.tryParse(opts['rounds'] as String? ?? '10') ?? 10;
  final promotionThreshold =
      int.tryParse(opts['promotion-threshold'] as String? ?? '7') ?? 7;
  final boardSize =
      int.tryParse(opts['board-size'] as String? ?? '9') ?? 9;
  final captureTarget =
      int.tryParse(opts['capture-target'] as String? ?? '5') ?? 5;
  final isSmoke = opts['smoke'] as bool? ?? false;

  final candidates = isSmoke ? _smokeCandidates() : _defaultCandidates();

  final executor = AiArenaExecutor(
    boardSize: boardSize,
    captureTarget: captureTarget,
    rounds: rounds,
    maxMoves: 512,
  );

  final scheduler = AiArenaScheduler(
    candidates: candidates,
    executor: executor,
    promotionThreshold: promotionThreshold,
    baseSeed: 20260430,
  );

  final initialLadder = scheduler.ladder.copy();

  print('=== AI Arena Ladder Runner ===');
  print('Candidates: ${candidates.map((c) => c.id).join(', ')}');
  print('Rounds per match: $rounds');
  print('Promotion threshold: $promotionThreshold');
  print('Board: ${boardSize}x$boardSize, capture target: $captureTarget');
  print('Initial ladder: ${initialLadder.ids.join(' > ')}');
  print('');

  // Run all adjacent pairs once (from index 0 to end).
  final events = <AiLadderEvent>[];
  final currentIds = List<String>.from(scheduler.ladder.ids);

  for (var i = 0; i < currentIds.length - 1; i++) {
    final higherId = currentIds[i];
    final lowerId = currentIds[i + 1];
    final configA = candidates.firstWhere((c) => c.id == lowerId);
    final configB = candidates.firstWhere((c) => c.id == higherId);
    final event = scheduler.runMatch(configA, configB);
    events.add(event);
    print(
      'Match ${events.length}: ${configA.id} vs ${configB.id} → '
      '${event.schedulerDecision.decision} '
      '(a:${event.rawResult.aWins} b:${event.rawResult.bWins} '
      'd:${event.rawResult.draws})',
    );
  }

  final finalLadder = scheduler.ladder;

  print('');
  print('Final ladder: ${finalLadder.ids.join(' > ')}');
  print('Final ladder hash: ${finalLadder.hash}');
  print('Total matches: ${events.length}');

  // --- Persistence ---
  _ensureDir(outputPath);
  _ensureDir(snapshotPath);

  // Write matches JSONL (synchronous).
  final jsonlBuffer = StringBuffer();
  for (final event in events) {
    jsonlBuffer.writeln(event.toJsonLine());
  }
  File(outputPath).writeAsStringSync(jsonlBuffer.toString());

  // Write ladder snapshot (synchronous).
  File(snapshotPath).writeAsStringSync(_prettyJson(finalLadder.toJson()));

  print('');
  print('Output: $outputPath');
  print('Snapshot: $snapshotPath');

  // --- Decision replay verification ---
  final replayResult = AiArenaReplayer.replay(
    initialLadder: initialLadder,
    events: events,
    promotionThreshold: promotionThreshold,
  );

  print('');
  if (replayResult.passed) {
    final hashMatch =
        replayResult.finalLadder.hash == finalLadder.hash;
    print(
      'Decision replay: PASSED ✓  '
      '(hash match: $hashMatch)',
    );
  } else {
    print('Decision replay: FAILED ✗');
    for (final mismatch in replayResult.hashMismatches) {
      print('  $mismatch');
    }
    exitCode = 1;
  }

  // Verify outputs are non-empty.
  final matchesContent = File(outputPath).readAsStringSync();
  final snapshotContent = File(snapshotPath).readAsStringSync();

  if (matchesContent.trim().isEmpty) {
    print('ERROR: matches.jsonl is empty!');
    exitCode = 1;
  } else if (snapshotContent.trim().isEmpty) {
    print('ERROR: ladder.json is empty!');
    exitCode = 1;
  } else {
    print('Artifact check: PASSED ✓ (both files are non-empty)');
  }
}

List<AiBattleConfig> _smokeCandidates() {
  return [
    AiBattleConfig(
      id: 'adaptive_beginner_v1',
      style: CaptureAiStyle.adaptive.name,
      difficulty: DifficultyLevel.beginner.name,
    ),
    AiBattleConfig(
      id: 'hunter_beginner_v1',
      style: CaptureAiStyle.hunter.name,
      difficulty: DifficultyLevel.beginner.name,
    ),
    AiBattleConfig(
      id: 'trapper_beginner_v1',
      style: CaptureAiStyle.trapper.name,
      difficulty: DifficultyLevel.beginner.name,
    ),
  ];
}

List<AiBattleConfig> _defaultCandidates() {
  final configs = <AiBattleConfig>[];
  for (final style in CaptureAiStyle.values) {
    for (final diff in DifficultyLevel.values) {
      configs.add(AiBattleConfig(
        id: '${style.name}_${diff.name}_v1',
        style: style.name,
        difficulty: diff.name,
      ));
    }
  }
  return configs;
}

void _ensureDir(String filePath) {
  final dir = File(filePath).parent;
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
}

String _prettyJson(Map<String, dynamic> json) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(json);
}

Map<String, Object?> _parseArgs(List<String> args) {
  final opts = <String, Object?>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--smoke') {
      opts['smoke'] = true;
    } else if (arg.startsWith('--') && i + 1 < args.length) {
      opts[arg.substring(2)] = args[i + 1];
      i++;
    }
  }
  return opts;
}
