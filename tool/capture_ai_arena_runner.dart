// ignore_for_file: avoid_print
import 'dart:io';

import 'package:go_puzzle/game/ai_arena_ladder.dart';
import 'package:go_puzzle/game/ai_arena_executor.dart';
import 'package:go_puzzle/game/ai_arena_scheduler.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/game/difficulty_level.dart';

import 'ai_arena_artifact_writer.dart';

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
///   --max-moves <n>        Max playout moves per game (default: 512)
///   --output-log <path>    Path for local matches JSONL (default: build/ai_arena/matches.b<board-size>.jsonl)
///   --output-ladder <path> Path for latest ladder JSON (default: docs/ai_arena/latest_ladder.b<board-size>.json)
///   --no-log               Skip local JSONL match log output and resume
///   --manifest <path>      Path for run manifest JSON (default: build/ai_arena/manifest.b<board-size>.json)
///   --output <path>        Deprecated alias for --output-log
///   --snapshot <path>      Deprecated alias for --output-ladder
///   --force                Discard any prior results and start fresh
void main(List<String> args) {
  final opts = _parseArgs(args);

  if (opts.containsKey('output')) {
    print('DEPRECATED: --output is now --output-log.');
  }
  if (opts.containsKey('snapshot')) {
    print('DEPRECATED: --snapshot is now --output-ladder.');
  }

  final rounds = int.tryParse(opts['rounds'] as String? ?? '10') ?? 10;
  final promotionThreshold =
      int.tryParse(opts['promotion-threshold'] as String? ?? '7') ?? 7;
  final boardSize = int.tryParse(opts['board-size'] as String? ?? '9') ?? 9;
  final captureTarget =
      int.tryParse(opts['capture-target'] as String? ?? '5') ?? 5;
  final maxMoves = int.tryParse(opts['max-moves'] as String? ?? '512') ?? 512;
  final outputLogPath = opts['output-log'] as String? ??
      opts['output'] as String? ??
      _defaultLogPath(boardSize);
  final outputLadderPath = opts['output-ladder'] as String? ??
      opts['snapshot'] as String? ??
      _defaultLadderPath(boardSize);
  final manifestPath =
      opts['manifest'] as String? ?? _defaultManifestPath(boardSize);
  if (maxMoves < 1) {
    stderr.writeln('ERROR: --max-moves must be >= 1 (got $maxMoves).');
    exitCode = 1;
    return;
  }
  final isSmoke = opts['smoke'] as bool? ?? false;
  final force = opts['force'] as bool? ?? false;
  final noLog = opts['no-log'] as bool? ?? false;
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
    maxMoves: maxMoves,
  );

  final artifacts = AiArenaArtifactWriter(
    ladderPath: outputLadderPath,
    logPath: noLog ? null : outputLogPath,
    manifestPath: manifestPath,
  );

  print('=== AI Arena Ladder Runner ===');
  print('Candidates: ${candidates.map((c) => c.id).join(', ')}');
  print('Rounds per match: $rounds');
  print('Promotion threshold: $promotionThreshold');
  print(
      'Board: ${boardSize}x$boardSize, capture target: $captureTarget, max moves: $maxMoves');
  print('Config hash: ${currentManifest.configHash}');
  print('');

  // --- Ensure output directories exist ---
  artifacts.prepare();

  // --- Resume detection ---
  int priorMatchCount = 0;
  AiLadderSnapshot? resumedLadder;

  if (!force && artifacts.canResume) {
    final savedManifest = artifacts.readManifest();

    if (!currentManifest.isCompatibleWith(savedManifest)) {
      print('ERROR: Saved manifest (${savedManifest.configHash}) does not '
          'match current config (${currentManifest.configHash}).');
      print('       Use --force to discard prior results and start fresh.');
      exitCode = 1;
      return;
    }

    // Config matches — attempt to resume.
    final savedJsonl = artifacts.readMatchLog();
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
          '$priorMatchCount match(es) already completed.',
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
  } else if (noLog) {
    print('Match logging disabled; starting from a fresh in-memory run.');
    print('');
  }

  // Write (or overwrite) manifest for this run.
  // Avoid clobbering an existing resumable manifest when --no-log disables
  // resume for the current invocation.
  if (force || !artifacts.manifestFile.existsSync() || !noLog) {
    artifacts.writeManifest(currentManifest);
  }

  // --- Build executor and scheduler ---
  final executor = AiArenaExecutor(
    boardSize: boardSize,
    captureTarget: captureTarget,
    rounds: rounds,
    maxMoves: maxMoves,
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
    final completedMatches = priorMatchCount + newEvents.length;
    if (artifacts.writesMatchLog) {
      artifacts.writeMatchLogLine(
        event,
        append: completedMatches > 1,
      );
    }
    artifacts.writeLatestLadder(
      scheduler.ladder,
      manifest: currentManifest,
      completedMatches: completedMatches,
    );
    print(
      'Match $completedMatches: '
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
    '($priorMatchCount prior + ${newEvents.length} new)',
  );

  // If force produced no new events, truncate any stale local log.
  if (artifacts.writesMatchLog && newEvents.isEmpty && force) {
    artifacts.clearMatchLog();
  }

  // Write ladder snapshot (always overwrite with final state).
  artifacts.writeLatestLadder(
    finalLadder,
    manifest: currentManifest,
    completedMatches: priorMatchCount + newEvents.length,
  );

  print('');
  if (artifacts.writesMatchLog) {
    print('Local match log: $outputLogPath');
  } else {
    print('Local match log: disabled');
  }
  print('Latest ladder: $outputLadderPath');
  print('Manifest: $manifestPath');

  // --- Decision replay verification (all events, including prior) ---
  final allEvents = artifacts.writesMatchLog
      ? parseJsonlEvents(artifacts.readMatchLog())
      : newEvents;
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
  final matchesContent =
      artifacts.writesMatchLog ? artifacts.readMatchLog() : 'disabled';
  final snapshotContent = artifacts.ladderFile.readAsStringSync();

  if (artifacts.writesMatchLog && matchesContent.trim().isEmpty) {
    print('ERROR: match log is empty!');
    exitCode = 1;
  } else if (snapshotContent.trim().isEmpty) {
    print('ERROR: latest ladder JSON is empty!');
    exitCode = 1;
  } else {
    print('Artifact check: PASSED ✓');
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

Map<String, Object?> _parseArgs(List<String> args) {
  final opts = <String, Object?>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--smoke' || arg == '--force' || arg == '--no-log') {
      opts[arg.substring(2)] = true;
    } else if (arg.startsWith('--') && i + 1 < args.length) {
      opts[arg.substring(2)] = args[i + 1];
      i++;
    }
  }
  return opts;
}

String _defaultLadderPath(int boardSize) =>
    'docs/ai_arena/latest_ladder.b$boardSize.json';

String _defaultLogPath(int boardSize) =>
    'build/ai_arena/matches.b$boardSize.jsonl';

String _defaultManifestPath(int boardSize) =>
    'build/ai_arena/manifest.b$boardSize.json';
