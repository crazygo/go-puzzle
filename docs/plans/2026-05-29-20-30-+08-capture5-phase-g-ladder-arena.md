# Capture5 Phase G Ladder Arena

## Background

### Context

The app now has a single active Capture5 ONNX configuration backed by the
Phase G 11-plane ResNet model. The repository already has a headless arena
runner that models evaluations as Evaluation Run -> Pair -> Cell -> Game and
supports deterministic openings, first-player swaps, and repeated games per
cell.

### Problem

The next strength check needs a compact but reproducible ladder-style matrix
that separates opening choice from first-player direction. A single aggregate
win rate would hide whether a result is driven by empty, cross, or twist-cross
opening bias.

### Motivation

A per-opening two-dimensional table lets the current Capture5 model be compared
against representative local AI opponents while preserving enough structure to
debug first-player or opening-specific behavior.

## Goals

- Run a 13x13 capture-five arena over the active Capture5 model and selected
  baseline AI configs.
- Cover every unordered config pair under empty, cross, and twistCross openings.
- For every pair and opening, play both first-player directions with three
  repeated games per direction.
- Produce a Markdown report with exactly three pairwise result tables, one per
  opening, where each cell is the row config's W-L-D record against the column
  config.
- Keep the raw JSON artifact so validation and later analysis can be repeated.

## Implementation Plan

1. Use the headless full-matrix arena runner with these configs:
   `capture5_13x13_11p_resnet_phase_g_tactical005_expected`,
   `mcts_counter_standard_v1`, `hybrid_tactical_counter_standard_v1`, and
   `heuristic_counter_standard_v1`.
2. Run the matrix on `boardSize=13`, `captureTarget=5`, `repeat=3`, and the
   built-in deterministic openings `empty`, `cross`, and `twistCross`.
3. Save the raw arena JSON under `docs/ai_eval/runs/` with a date-stamped
   filename.
4. Generate a Markdown report next to the JSON artifact. The report should
   summarize the run metadata and then render three tables, one each for
   `empty`, `cross`, and `twistCross`.
5. Validate that every expected cell and game is present and that illegal moves,
   timeouts, fallback games, unexpected failure reasons, bad repeat cells, and
   bad dimension cells are all zero.
6. Commit the plan, raw JSON, Markdown report, and any small helper script used
   to generate the report, then push the branch.

## Acceptance Criteria

- The raw JSON artifact records 4 configs, 6 unordered pairs, 3 openings, 2
  first-player directions, 3 repeats per cell, 36 cells, and 108 games.
- The validation section reports zero illegal moves, zero timeouts, zero
  fallback games, zero failure reasons, zero bad repeat cells, and zero bad
  dimension cells.
- The Markdown report contains three two-dimensional tables titled `Empty`,
  `Cross`, and `Twist Cross`.
- Every non-diagonal table cell is shown from the row config's perspective as
  `W-L-D` over 6 games for that opening.
- The committed branch is pushed to `origin/1.3.0`.

## Validation Commands

- `dart run tool/headless_full_matrix_arena_probe.dart --configs capture5_13x13_11p_resnet_phase_g_tactical005_expected,mcts_counter_standard_v1,hybrid_tactical_counter_standard_v1,heuristic_counter_standard_v1 --board-size 13 --capture-target 5 --repeat 3 --workers 4 --out docs/ai_eval/runs/2026-05-29-13x13-capture5-phase-g-ladder.json`
- `jq '{metadata, validation}' docs/ai_eval/runs/2026-05-29-13x13-capture5-phase-g-ladder.json`
- `dart run tool/arena_opening_matrix_report.dart docs/ai_eval/runs/2026-05-29-13x13-capture5-phase-g-ladder.json docs/ai_eval/runs/2026-05-29-13x13-capture5-phase-g-ladder.md`
