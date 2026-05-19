# Full AI Config Matrix Evaluation

## Background

### Context

The current arena has a unified algorithm registry with heuristic, MCTS,
hybrid tactical, and KataGo ONNX configs. The Flutter Web probe proves real
`flutter_onnxruntime` execution for KataGo, while native Dart configs already
run through the same framework arena. The previous probe used a selected
5-config subset and the mixed opening policy
`empty_cross_twist_cross_random_v1`, which is good for smoke coverage but does
not fully expand the requested evaluation dimensions across every config.

### Problem

The current artifact does not include every registered configuration, and it
does not run every non-random opening against every first-player direction with
an equal repeat count. Because each pairwise match has only four games under a
rotating opening policy, per-opening and first-player effects are not fully
balanced.

### Motivation

A full matrix makes the reported win rates easier to trust and explain:
`opening x first algorithm x opponent x repeat`. Removing random openings keeps
the sample space deterministic and interpretable.

## Goals

- Run all registered AI algorithm configurations through one full evaluation
  matrix under the five-capture rule.
- Use real Flutter ONNX KataGo evaluation with no Python inference path and no
  fallback moves for KataGo configs.
- Cover only the deterministic openings: `empty`, `cross`, and `twist-cross`.
- For every unordered algorithm pair, run both first-player directions.
- Repeat every unique `opening x first-player direction x algorithm pair`
  combination exactly 2 times.
- Produce a JSON artifact with raw games, pairwise win rates, rankings,
  per-opening performance, per-first-player performance, illegal move counts,
  timeout counts, fallback counts, and failure reasons.

## Implementation Plan

1. Add a full-matrix mode to the Flutter arena probe or create a dedicated
   Flutter Web probe target that explicitly expands:
   `pair x opening x first-player direction x repeat`.
2. Use every current config in `AiAlgorithmRegistry.configs`:
   `heuristic_adaptive_weak_v1`,
   `heuristic_counter_standard_v1`,
   `mcts_counter_weak_v1`,
   `mcts_counter_standard_v1`,
   `hybrid_tactical_counter_weak_v1`,
   `hybrid_tactical_counter_standard_v1`,
   `katago_onnx_weak_v1`, and
   `katago_onnx_standard_v1`.
3. Use deterministic openings only:
   `empty_v1`, `cross_v1`, and `twist_cross_v1`.
4. Use repeat count `2`, producing:
   `C(8,2) x 3 openings x 2 first-player directions x 2 repeats = 336 games`.
5. Preserve the existing timeout policy:
   non-KataGo decisions use 5 seconds, KataGo decisions use
   `timeBudgetMillis = 10000`.
   Use `captureTarget = 5` for the five-capture rule.
6. Run the Flutter Web probe from `build/web` through a real browser and save
   the output under `docs/ai_eval/runs/`.
7. Add or update a small summarizer so the final output clearly reports:
   pairwise score, overall ranking, per-opening score, per-first-player score,
   and failure status.
8. Update `docs/ai_eval/capture-ai-framework-tuning-notes.md` with the command,
   artifact path, result summary, and notes on good or bad parameter behavior.
9. Commit after the full-matrix probe and notes are generated.

## Acceptance Criteria

- The full matrix artifact contains 336 games.
- No game uses the `random` opening.
- Every unordered config pair appears under `empty`, `cross`, and
  `twist-cross`.
- Every `pair x opening` combination includes both first-player directions.
- Every `pair x opening x first-player direction` combination has exactly
  2 repeated games.
- The artifact reports `illegalMoves = 0`, `fallbackGames = 0`, and no
  unexpected failures.
- Timeout counts are zero, or any timeout is reported with the responsible
  config and decision budget.
- KataGo games use the Dart/Flutter ONNX adapter, not Python or fallback.
- The tuning notes include the real win rates and the artifact path.

## Result

Completed in `docs/ai_eval/runs/2026-05-19-flutter-full-matrix-arena-probe.json`.

- Matrix shape: 8 configs, 28 unordered pairs, 3 deterministic openings,
  2 first-player directions, repeat count 2.
- Games: 168 cells / 336 games.
- Rules: board size 9, capture target 5, max moves 120.
- Status: random games 0, illegal moves 0, timeouts 0, fallback games 0,
  failure reasons 0.
- Ranking by match wins:
  1. `heuristic_counter_standard_v1`: 30-8-4 matches, 61-18-5 games.
  2. `mcts_counter_standard_v1`: 29-10-3 matches, 59-21-4 games.
  3. `heuristic_adaptive_weak_v1`: 28-10-4 matches, 58-23-3 games.
  4. `hybrid_tactical_counter_standard_v1`: 26-12-4 matches,
     55-28-1 games.
  5. `hybrid_tactical_counter_weak_v1`: 21-13-8 matches, 49-34-1 games.
  6. `mcts_counter_weak_v1`: 13-22-7 matches, 33-47-4 games.
  7. `katago_onnx_standard_v1`: 3-39-0 matches, 6-78-0 games.
  8. `katago_onnx_weak_v1`: 3-39-0 matches, 6-78-0 games.

KataGo used the Flutter ONNX adapter with no Python path and no fallback. The
first full-matrix pass had one transient Flutter ONNX inference error in the
KataGo-standard-vs-MCTS-standard twist-cross cell. Rerunning that shard
completed cleanly, and the final merged artifact has zero failure reasons.

## Validation Commands

- `flutter test test/ai_arena_executor_test.dart test/katago_onnx_features_test.dart test/ai_algorithm_framework_test.dart`
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter build web -t tool/flutter_katago_arena_probe.dart`
- `python3 -m http.server 8092 --bind 127.0.0.1 --directory build/web`
- `node <playwright-capture-script-for-full-matrix>`
