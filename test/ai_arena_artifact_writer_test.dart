import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/ai_arena_ladder.dart';
import 'package:go_puzzle/game/ai_arena_scheduler.dart';

import '../tool/ai_arena_artifact_writer.dart';

void main() {
  test('writes latest ladder and match log to separate artifacts', () {
    final temp = Directory.systemTemp.createTempSync('ai_arena_writer_test_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final writer = AiArenaArtifactWriter(
      ladderPath: '${temp.path}/docs/ai_arena/latest_ladder.json',
      logPath: '${temp.path}/build/ai_arena/matches.jsonl',
      manifestPath: '${temp.path}/build/ai_arena/manifest.json',
    );

    writer.prepare();

    final ladder = AiLadderSnapshot(['alpha', 'beta']);
    const manifest = AiArenaRunManifest(
      candidateIds: ['alpha', 'beta'],
      boardSize: 9,
      captureTarget: 5,
      rounds: 10,
      promotionThreshold: 7,
      baseSeed: 20260430,
    );
    final event = _event(ladder);

    writer.writeManifest(manifest);
    writer.writeLatestLadder(ladder, manifest: manifest, completedMatches: 1);
    writer.writeMatchLogLine(event, append: false);

    expect(writer.ladderFile.readAsStringSync(), contains('"ladder"'));
    expect(writer.ladderFile.readAsStringSync(), contains('"alpha"'));
    expect(
        writer.ladderFile.readAsStringSync(), contains('"completedMatches"'));
    expect(writer.readManifest().configHash, manifest.configHash);
    expect(parseJsonlEvents(writer.readMatchLog()), hasLength(1));
  });

  test('can disable match log writes', () {
    final temp = Directory.systemTemp.createTempSync('ai_arena_writer_test_');
    addTearDown(() => temp.deleteSync(recursive: true));

    final writer = AiArenaArtifactWriter(
      ladderPath: '${temp.path}/docs/ai_arena/latest_ladder.json',
      manifestPath: '${temp.path}/build/ai_arena/manifest.json',
    );

    writer.prepare();
    writer.writeLatestLadder(AiLadderSnapshot(['alpha']));
    writer.writeMatchLogLine(_event(AiLadderSnapshot(['alpha'])),
        append: false);

    expect(writer.writesMatchLog, isFalse);
    expect(writer.readMatchLog(), isEmpty);
    expect(writer.ladderFile.existsSync(), isTrue);
  });
}

AiLadderEvent _event(AiLadderSnapshot ladder) {
  final configA = AiBattleConfig(
    id: ladder.ids.first,
    style: 'hunter',
    difficulty: 'beginner',
  );
  final configB = AiBattleConfig(
    id: ladder.ids.length > 1 ? ladder.ids[1] : ladder.ids.first,
    style: 'hunter',
    difficulty: 'beginner',
  );
  final result = AiMatchResult(
    matchSeed: 1,
    openingSeed: 1,
    openingPolicy: 'fixed_twist_cross_v1',
    boardSize: 9,
    captureTarget: 5,
    rounds: 1,
    maxMoves: 512,
    configA: configA,
    configB: configB,
    aWins: 1,
    bWins: 0,
    draws: 0,
    games: const [
      AiGameRecord(
        index: 0,
        gameSeed: 1000,
        openingIndex: 0,
        black: 'a',
        winner: 'a',
        moves: 10,
        blackCaptures: 5,
        whiteCaptures: 0,
        endReason: 'captureTargetReached',
      ),
    ],
  );

  return AiLadderEvent(
    schemaVersion: 1,
    eventType: 'ladder_match',
    matchId: 'match_1',
    createdAt: '2026-04-30T00:00:00Z',
    schedulerVersion: 'ai_arena_scheduler_v1',
    executorVersion: 'ai_arena_executor_v1',
    configVersion: 'capture_ai_profile_v1',
    matchRules: const {'promotionThreshold': 7},
    initialLadderHash: ladder.hash,
    resultLadderHash: ladder.hash,
    rawResult: result,
    schedulerDecision: AiSchedulerDecision(
      winner: configA.id,
      loser: configB.id,
      decision: 'no_change_winner_already_higher',
      reason: 'test',
      before: ladder.ids,
      after: ladder.ids,
    ),
  );
}
