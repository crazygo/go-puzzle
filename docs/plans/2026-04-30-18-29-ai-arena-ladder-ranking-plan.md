# AI Arena Ladder Ranking Plan

## Background

### Context

The capture-go AI already has an internal arena layer:

- `CaptureAiArena.playMatch(...)` can run one complete AI-vs-AI game.
- `CaptureAiArena.runRoundRobin(...)` can run style-vs-style batches.
- `CaptureAiArenaResult` records winner, move count, captures, and end reason.
- `CaptureAiEvaluationReport` can summarize standings, pairings, win rate, captures, and a simple Elo-like score.

PR #68 adds the product-facing 28-rank system and adaptive AI style selection, but the underlying AI strength is still mostly represented as `CaptureAiStyle + DifficultyLevel`. The next calibration step needs an experimental arena that can compare concrete AI configurations, record match results, and derive a stable ordering from repeated head-to-head battles.

The desired calibration workflow is similar to public model arenas: candidate configurations are compared in repeated pairings, the stronger configuration advances in a ranking ladder, and every match is auditable through append-only logs.

### Problem

The current arena is useful for smoke tests and round-robin summaries, but it is not yet sufficient for locking down an AI ranking table:

1. It does not expose a durable configuration identity for arbitrary AI parameter sets.
2. It does not write append-only JSONL match logs.
3. It does not separate match execution from ranking decisions.
4. Repeated matches against weaker opponents could distort a naive numeric rank if the system simply increments a winner each time.
5. The existing round-robin shape does not model a ladder where a lower-ranked candidate only moves when it defeats a higher-ranked candidate convincingly.
6. Ten-game matches are fast enough for early iteration, but 10 games also need a clear promotion threshold to avoid noisy sorting.

### Motivation

The goal is to make AI ranking reproducible and stable before the behavior parameters are finalized. A ladder-based arena gives the team a practical way to answer:

- Which configuration is stronger within the same style?
- Which style is stronger at the same nominal rank or difficulty?
- Which candidates deserve promotion into the next rank slot?
- Which match results are too close and should be retested?

The ranking system should never inflate a configuration just because it repeatedly beats weaker opponents. A candidate should only move when a match provides new ordering information.

## Goals

1. Define an arena architecture with a **scheduler** that owns ranking decisions and an **executor** that only runs matches.
2. Define a durable `AiBattleConfig` concept that can identify style, difficulty, rank, and future full parameter profiles.
3. Record every 10-game head-to-head comparison as one JSONL line.
4. Use a promotion threshold of **7 wins out of 10 games**.
5. Update rankings through relative list movement, not unbounded numeric increments.
6. Support both per-style ladders and a global cross-style ladder.
7. Keep the first implementation scoped to developer tooling and tests, with no user-facing UI changes.

## Implementation Plan

### Phase A - Data Model and Log Format

Define an `AiBattleConfig` structure for arena experiments. It should include enough metadata to identify a candidate unambiguously:

- `id`: stable unique identifier, such as `hunter_r03_v1` or `adaptive_beginner_v1`.
- `style`: `CaptureAiStyle.name`.
- `rank`: optional 1-28 rank when available.
- `difficulty`: current `DifficultyLevel.name` bridge for existing AI.
- `profileVersion`: version string for the parameter recipe.
- `parameters`: future-compatible object for explicit weights, playouts, blunder rates, and candidate limits.

Define an `AiMatchLogEntry` JSONL schema. Each line represents one 10-game match:

```json
{"schemaVersion":1,"matchId":"20260430T182900Z_hunter_r03_vs_trapper_r03","createdAt":"2026-04-30T18:29:00+08:00","boardSize":9,"captureTarget":5,"rounds":10,"promotionThreshold":7,"configA":{"id":"hunter_r03_v1","style":"hunter","rank":3,"difficulty":"beginner"},"configB":{"id":"trapper_r03_v1","style":"trapper","rank":3,"difficulty":"beginner"},"aWins":7,"bWins":3,"draws":0,"aWinRate":0.7,"bWinRate":0.3,"winner":"a","decision":"promote_a","games":[{"index":0,"black":"a","winner":"a","moves":43,"blackCaptures":5,"whiteCaptures":2,"endReason":"captureTargetReached"}]}
```

The exact implementation can keep per-game entries compact, but each match line must include enough information to audit:

- which configs played;
- who had black in each game;
- win counts;
- draw count;
- end reasons;
- promotion decision;
- ranking snapshot reference or sequence number.

### Phase B - Executor

Add an arena executor that receives two `AiBattleConfig` values and runs exactly 10 games.

Execution rules:

- Run 10 games per match by default.
- Alternate colors: config A plays black in 5 games and white in 5 games.
- Use the same board size, capture target, and max moves across all games in the match.
- Return an `AiMatchLogEntry`-compatible result object.
- Do not update rankings inside the executor.
- Do not interpret "promotion" inside the executor beyond reporting raw counts.

The executor should initially wrap `CaptureAiArena.playMatch(...)` and `CaptureAiRegistry.create(...)` so it can reuse the current AI implementation.

### Phase C - Scheduler and Ladder Rules

Add a scheduler that owns the ranking list and chooses matchups.

The ladder is an ordered list from strongest to weakest:

```text
[strongest, ..., weakest]
```

After each 10-game match:

- If config A wins at least 7 games, A is the match winner.
- If config B wins at least 7 games, B is the match winner.
- Otherwise the match is inconclusive and the ladder remains unchanged.

Ranking update rules:

1. If the winner is already ranked above the loser, do nothing.
2. If the winner is ranked below the loser, remove the winner from its current position and insert it immediately before the loser.
3. If either config is new, insert it at the weakest end first, then apply the same movement rule.
4. A winner never jumps above configurations it has not defeated.
5. Repeated wins over lower-ranked opponents never increase rank.
6. Inconclusive matches are logged and may be scheduled again, but they do not change the ladder.

This prevents unbounded rank inflation. A strong config can only move upward by beating the next stronger evidence point in the list.

### Phase D - Scheduling Strategy

Start with a simple deterministic scheduler:

1. Build per-style ladders first.
2. For each style, compare neighboring candidates.
3. If a lower candidate beats a higher candidate by 7/10 or better, move it up and reschedule around its new neighbors.
4. Stop when one full pass over adjacent pairs produces no changes.
5. Build a global ladder by taking the top candidates from each per-style ladder and applying the same adjacent-pair process.

Later iterations can add:

- retest queues for 6-4 and 5-5 results;
- periodic champion-vs-contender matches;
- randomized but seeded openings;
- larger validation matches, such as 20 or 50 games, for final rank publication.

### Phase E - Persistence

Persist two artifacts:

1. Append-only match log:

```text
build/ai_arena/matches.jsonl
```

2. Current ladder snapshot:

```text
build/ai_arena/ladder.json
```

`matches.jsonl` is the audit trail. `ladder.json` is derived state and can be regenerated from the JSONL log.

The scheduler should be able to resume from existing JSONL logs by replaying decisions in order.

### Phase F - Developer Entry Point

Add a developer-only runner in a later implementation phase, for example:

```text
dart run tool/capture_ai_arena_runner.dart
```

Planned options:

- `--rounds 10`
- `--promotion-threshold 7`
- `--board-size 9`
- `--capture-target 5`
- `--mode per-style`
- `--mode global`
- `--output build/ai_arena/matches.jsonl`
- `--snapshot build/ai_arena/ladder.json`

The first implementation should not wire this into app UI.

## Acceptance Criteria

1. A plan exists for a scheduler/executor split where the executor only runs matches and the scheduler alone updates ranking.
2. The planned match size is 10 games.
3. The planned promotion threshold is 7 wins out of 10 games.
4. The planned ranking update is relative list movement, not numeric rank increment.
5. A higher-ranked config beating a lower-ranked config leaves the ladder unchanged.
6. A lower-ranked config beating a higher-ranked config by at least 7/10 moves immediately before the defeated config, but no higher.
7. Replaying the same JSONL match log produces the same ladder snapshot.
8. Repeated wins over already-lower-ranked opponents do not change rank.
9. Inconclusive results, including 6-4, 5-5, and draw-heavy outcomes without a 7-win side, are logged but do not update the ladder.
10. The future implementation should validate with:

```text
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```
