---
name: capture-ai-strength-matrix
description: Use when running or updating repeatable capture-go AI strength evaluations in this repo, especially the five-capture full matrix over algorithm configs with Flutter ONNX KataGo. Guides agents to use the Run -> Pair -> Cell -> Game hierarchy, deterministic openings, first-player swaps, repeated games, and validation gates for illegal moves, timeouts, fallback, and failure reasons.
---

# Capture AI Strength Matrix

Use this skill when the user asks to rerun, compare, tune, or report capture-go AI strength results.

The goal is a reproducible strength evaluation, not only a smoke test. Preserve the explicit evaluation hierarchy and report at both aggregate and pair/cell levels.

## Evaluation Model

Use these terms consistently:

```text
Evaluation Run
  Pair: unordered configA vs configB
    Cell: opening + firstConfigId
      Game repeat #1
      Game repeat #2
```

- **Evaluation Run**: one complete arena execution over a selected config set.
- **Pair**: one unordered comparison between two AI configs.
- **Cell**: fixed conditions for a pair: two configs, opening, and first-player direction. Repeated games inside a cell vary by game seed only.
- **Game**: one played repeat inside a cell.
- **Opening**: deterministic initial setup; use `empty`, `cross`, and `twistCross` unless the user asks otherwise.
- **First-player direction**: which config is assigned to move first for the cell.

## Default Full Matrix

For the standard all-config five-capture matrix:

- Board: `9x9` for the fast baseline.
- Rule: `captureTarget = 5`.
- Openings: `empty`, `cross`, `twistCross`; no random opening.
- Repeat: `2` games per cell.
- First-player coverage: both directions for every pair and opening.
- Expected shape for 8 configs: `28 pairs x 3 openings x 2 first directions = 168 cells`, `336 games`.
- Timeout policy: non-KataGo uses the arena default `5s`; KataGo uses config `timeBudgetMillis`, currently `10000`.
- KataGo must use Flutter ONNX adapter only; no Python path and no fallback.

## Board Sizes

Use board size as an explicit evaluation dimension.

- **9x9 baseline**: required for every standard full-matrix run because it is fast enough to cover all configs.
- **13x13 extension**: required before claiming a tuning change generalizes beyond the small board. It may run over selected configs or high-value pairs when the full all-config matrix is too slow.
- **19x19 extension**: required before claiming production-strength behavior. It may run as a targeted pair matrix first, especially for expensive KataGo or MCTS comparisons.

For 13x13 and 19x19 runs, keep the same structure unless the user asks otherwise:

- `captureTarget = 5`.
- Openings: `empty`, `cross`, `twistCross`, adapted to the board size by the arena opening builder.
- Both first-player directions.
- Repeat at least `2` games per cell.
- Same validation gates: no illegal moves, no fallback, no unexpected failures, and timeouts must be explicitly reported with the responsible config and budget.

When reporting strength, do not combine board sizes into one unlabelled score. Report separate tables for 9x9, 13x13, and 19x19, then add a short cross-board summary.

## Commands

### Headless Strength Matrix

Use the headless path for repeated strength evaluation. Dart owns the arena,
rules, configs, seeds, cells, merge, and reporting. Node owns only ONNX
inference through `onnxruntime-node`.

From repo root, ensure Flutter is available first:

```bash
export PATH="$PWD/.local/flutter/bin:/Users/admin/.local/tools/flutter/bin:$PATH"
```

Run a parallel headless matrix:

```bash
dart run tool/headless_full_matrix_arena_probe.dart --workers 4 --board-size 9
```

`--workers N` starts N Dart isolate workers. Each worker sequentially consumes
assigned cells and owns its own Node ONNX worker/session. Do not start one OS
process per cell; keep cells independent in the artifact, but batch execution
inside long-lived workers for speed and model-session reuse.

For selected configs:

```bash
dart run tool/headless_full_matrix_arena_probe.dart \
  --configs katago_onnx_standard_v1,mcts_counter_standard_v1 \
  --workers 4 \
  --board-size 9
```

For cross-board strength checks:

```bash
dart run tool/headless_full_matrix_arena_probe.dart --workers 4 --board-sizes 9,13,19
```

The headless runner must fail loudly if `onnxruntime-node`, the Node worker,
or the model cannot load. It must not fallback, skip KataGo, or convert backend
errors into ordinary losses.

### Browser Integration Smoke

Use the browser path only to verify the Flutter Web integration path can load
and execute each config. Do not use it as the default high-volume strength loop.

Build the browser target:

```bash
flutter build web -t tool/flutter_full_matrix_arena_probe.dart
```

Serve the built output as static files:

```bash
python3 -m http.server 8092 --bind 127.0.0.1 --directory build/web
```

Capture the full matrix in small shards:

```bash
FULL_MATRIX_SHARD_SIZE=3 node tool/capture_full_matrix_arena_probe.js
```

If one shard has a transient runtime failure, rerun only that range and merge with existing shards:

```bash
FULL_MATRIX_SHARD_SIZE=3 \
FULL_MATRIX_START_CELL=<start> \
FULL_MATRIX_END_CELL=<end> \
FULL_MATRIX_MERGE_EXISTING=1 \
node tool/capture_full_matrix_arena_probe.js
```

## Validation Gates

Do not treat the run as complete until the merged artifact validates:

- `cells == expectedCells`.
- `games == expectedGames`.
- `randomGames == 0`.
- `illegalMoves == 0`.
- `timeouts == 0`.
- `fallbackGames == 0`.
- `failureReasons == 0`, except when the task is explicitly to investigate failures.
- `badRepeatCells == 0`.
- `badDimensionCells == 0`.

Use `jq` for a fast audit:

```bash
jq '{metadata,validation,rankingCount:(.rankings|length),pairwiseCount:(.pairwiseOverall|length),openingRows:(.perOpeningPerformance|length),firstPlayerRows:(.perFirstPlayerPerformance|length)}' docs/ai_eval/runs/2026-05-19-flutter-full-matrix-arena-probe.json
```

## Reporting

Always include:

- Run summary: configs, pairs, cells, games, openings, repeat count, board size, capture target.
- Overall rankings: match W-L-D and game W-L-D.
- Pair-level results for requested configs.
- Cell-level table when explaining a pair: `opening x firstConfigId`.
- Status counts: illegal, timeout, fallback, failure reasons.

When interpreting totals, warn that a config's overall `W-L-D` includes every opponent. For example, if two KataGo configs are tied internally but lose to all non-KataGo configs, their overall totals may be identical.

## Tuning Notes

Record completed runs and TODOs in:

```text
docs/ai_eval/capture-ai-framework-tuning-notes.md
```

Keep unsuccessful tuning attempts. They are useful evidence when later runs appear surprising.
