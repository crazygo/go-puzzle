// ignore_for_file: avoid_print
import 'dart:convert' show JsonEncoder, jsonDecode;
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
///   --manifest <path>      Path for run manifest JSON (default: build/ai_arena/manifest.json)
///   --force                Discard any prior results and start fresh
void main(List<String> args) {
  final opts = _parseArgs(args);

  final outputPath =
      opts['output'] as String? ?? 'build/ai_arena/matches.jsonl';
  final snapshotPath =
      opts['snapshot'] as String? ?? 'build/ai_arena/ladder.json';
  final manifestPath =
      opts['manifest'] as String? ?? 'build/ai_arena/manifest.json';
  final rounds = int.tryParse(opts['rounds'] as String? ?? '10') ?? 10;
  final promotionThreshold =
      int.tryParse(opts['promotion-threshold'] as String? ?? '7') ?? 7;
  final boardSize =
      int.tryParse(opts['board-size'] as String? ?? '9') ?? 9;
  final captureTarget =
      int.tryParse(opts['capture-target'] as String? ?? '5') ?? 5;
  final isSmoke = opts['smoke'] as bool? ?? false;
  final force = opts['force'] as bool? ?? false;
  const baseSeed = 20260430;

  final candidates = isSmoke ? _smokeCandidates() : _defaultCandidates();
  final sortedIds = (candidates.map((c) => c.id).toList()..sort());

  final currentManifest = AiArenaRunManifest(
    candidateIds: sortedIds,
    boardSize: boardSize,
    captureTarget: captureTarget,
    rounds: rounds,
    promotionThreshold: promotionThreshold,
    baseSeed: baseSeed,
  );

  print('=== AI Arena Ladder Runner ===');
  print('Candidates: ${candidates.map((c) => c.id).join(', ')}');
  print('Rounds per match: $rounds');
  print('Promotion threshold: $promotionThreshold');
  print('Board: ${boardSize}x$boardSize, capture target: $captureTarget');
  print('Config hash: ${currentManifest.configHash}');
  print('');

  // --- Ensure output directories exist ---
  _ensureDir(outputPath);
  _ensureDir(snapshotPath);
  _ensureDir(manifestPath);

  // --- Resume detection ---
  final manifestFile = File(manifestPath);
  final outputFile = File(outputPath);

  int priorMatchCount = 0;
  AiLadderSnapshot? resumedLadder;

  if (!force && manifestFile.existsSync() && outputFile.existsSync()) {
    final savedManifestJson =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final savedManifest = AiArenaRunManifest.fromJson(savedManifestJson);

    if (!currentManifest.isCompatibleWith(savedManifest)) {
      print('ERROR: Saved manifest (${savedManifest.configHash}) does not '
          'match current config (${currentManifest.configHash}).');
      print('       Use --force to discard prior results and start fresh.');
      exitCode = 1;
      return;
    }

    // Config matches — attempt to resume.
    final savedJsonl = outputFile.readAsStringSync();
    try {
      final resumeState = buildResumeState(
        currentManifest: currentManifest,
        savedManifest: savedManifest,
        savedJsonl: savedJsonl,
        initialLadderIds: sortedIds,
      );

      if (!resumeState.isEmpty) {
        priorMatchCount = resumeState.matchCounterOffset;
        resumedLadder = resumeState.reconstructedLadder;
        print(
          'Resuming from prior run: '
          '${priorMatchCount} match(es) already completed.',
        );
        print('Reconstructed ladder: ${resumedLadder.ids.join(' > ')}');
        print('');
      }
    } on AiArenaConfigMismatchException catch (e) {
      // Should not happen since we checked above, but be safe.
      print('ERROR: $e');
      exitCode = 1;
      return;
    }
  }

  // Write (or overwrite) manifest for this run.
  if (force || !manifestFile.existsSync()) {
    manifestFile.writeAsStringSync(_prettyJson(currentManifest.toJson()));
  }

  // --- Build executor and scheduler ---
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
    baseSeed: baseSeed,
    matchCounterOffset: priorMatchCount,
  );

  // If resuming, restore the scheduler's ladder to the reconstructed state.
  if (resumedLadder != null) {
    scheduler.restoreLadder(resumedLadder);
  }

  final initialLadder = scheduler.ladder.copy();

  print('Initial ladder: ${initialLadder.ids.join(' > ')}');
  print('');

  // --- Run all adjacent pairs once (from index 0 to end) ---
  final newEvents = <AiLadderEvent>[];
  final allPairs = <(String, String)>[];
  final currentIds = List<String>.from(sortedIds);

  for (var i = 0; i < currentIds.length - 1; i++) {
    allPairs.add((currentIds[i], currentIds[i + 1]));
  }

  // Skip the first [priorMatchCount] pairs — they are already persisted.
  final remainingPairs = allPairs.skip(priorMatchCount).toList();

  for (final (higherId, lowerId) in remainingPairs) {
    final configA = candidates.firstWhere((c) => c.id == lowerId);
    final configB = candidates.firstWhere((c) => c.id == higherId);
    final event = scheduler.runMatch(configA, configB);
    newEvents.add(event);
    print(
      'Match ${priorMatchCount + newEvents.length}: '
      '${configA.id} vs ${configB.id} → '
      '${event.schedulerDecision.decision} '
      '(a:${event.rawResult.aWins} b:${event.rawResult.bWins} '
      'd:${event.rawResult.draws})',
    );
  }

  final finalLadder = scheduler.ladder;

  print('');
  print('Final ladder: ${finalLadder.ids.join(' > ')}');
  print('Final ladder hash: ${finalLadder.hash}');
  print(
    'Total matches: ${priorMatchCount + newEvents.length} '
    '(${priorMatchCount} prior + ${newEvents.length} new)',
  );

  // --- Append new events to JSONL (preserve prior results on resume) ---
  if (newEvents.isNotEmpty) {
    // When resuming, append to the existing log.
    // When starting fresh (force or first run), overwrite so old results
    // from an incompatible run are not mixed in.
    final mode =
        priorMatchCount > 0 ? FileMode.append : FileMode.write;
    final sink = outputFile.openWrite(mode: mode);
    for (final event in newEvents) {
      sink.writeln(event.toJsonLine());
    }
    sink.closeSync();
  } else if (force) {
    // force flag with no new events → truncate to empty.
    outputFile.writeAsStringSync('');
  }

  // Write ladder snapshot (always overwrite with final state).
  File(snapshotPath).writeAsStringSync(_prettyJson(finalLadder.toJson()));

  print('');
  print('Output: $outputPath');
  print('Snapshot: $snapshotPath');
  print('Manifest: $manifestPath');

  // --- Decision replay verification (all events, including prior) ---
  final allEvents = parseJsonlEvents(outputFile.readAsStringSync());
  final replayInitialLadder = AiLadderSnapshot(sortedIds);
  final replayResult = AiArenaReplayer.replay(
    initialLadder: replayInitialLadder,
    events: allEvents,
    promotionThreshold: promotionThreshold,
  );

  print('');
  if (replayResult.passed) {
    final hashMatch = replayResult.finalLadder.hash == finalLadder.hash;
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
  final matchesContent = outputFile.readAsStringSync();
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
    if (arg == '--smoke' || arg == '--force') {
      opts[arg.substring(2)] = true;
    } else if (arg.startsWith('--') && i + 1 < args.length) {
      opts[arg.substring(2)] = args[i + 1];
      i++;
    }
  }
  return opts;
}
