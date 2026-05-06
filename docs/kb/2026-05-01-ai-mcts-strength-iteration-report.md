# AI MCTS Strength Iteration Report

Timestamp: 2026-05-01 19:11:09 +08

## Background

The goal of this iteration was to build a stronger AI path for capture Go so the three difficulty tiers are meaningfully ordered:

- `beginner < intermediate < advanced`
- Across 9/13/19 boards
- Across empty, twist-cross, and random starts
- Without weakening `beginner`

The prior strategy we recovered and used was not a single-algorithm ladder. It was a mixed strategy:

- Keep `beginner` as the existing heuristic baseline.
- Use a hybrid tactical/MCTS layer for `intermediate`.
- Use a higher-budget hybrid MCTS layer for `advanced`.
- Use multiple opening policies in arena validation so strength is not overfit to empty-board games.

## Implementation Attempts

### 1. Arena Opening Coverage

Changed the arena default opening policy from `empty_twist_cross_v1` to `empty_twist_cross_random_v1`.

The arena now rotates through:

- `empty`
- `twistCrossA/B/C/D`
- `random`

The arena also records `openingPolicy` and passes deterministic per-game seeds into agents:

- black agent seed: `gameSeed * 2`
- white agent seed: `gameSeed * 2 + 1`

This made arena games more reproducible and exposed several strength regressions that were hidden by simpler starts.

### 2. twistCross Redesign

The old twist-cross opening was a single fixed adjacent cross. It created strong local tactical bias and often favored one style or color.

I changed it into four variants:

- vertical black / horizontal white
- horizontal black / vertical white
- main diagonal black / anti-diagonal white
- anti-diagonal black / main diagonal white

I also changed the arm length to `3`, including on 9x9, so the stones are farther apart and less immediately tactical.

Effect:

- `twistCross intermediate>beginner` improved from repeated failures to passing in later probes.
- `twistCross advanced>beginner` also became passable with 3 paired samples after additional advanced baseline changes.

### 3. Strength Probe Tool

Added `tool/capture_ai_strength_probe.dart`.

It supports:

- `--style`
- `--board-sizes`
- `--openings`
- `--pair`
- `--rounds-per-opening`
- `--max-moves`
- `--capture-target`
- `--min-win-rate`
- `--verbose`

Important correction: random and twist-cross probes now use paired color games from the same opening seed. One sample is two games with colors swapped. If wins split, the probe falls back to total capture advantage. This reduced false conclusions from color/opening bias.

### 4. AI Tier Tuning

`beginner` was kept as heuristic and was not intentionally weakened.

Current tier shape:

- `beginner`
  - `CaptureAiEngine.heuristic`
  - `heuristicPlayouts: 12`
  - no MCTS playout budget

- `intermediate`
  - `CaptureAiEngine.hybridMcts`
  - heuristic baseline plus tactical/MCTS candidate selection
  - MCTS budget: `24` playouts, rollout depth `14`, candidate limit `11`
  - safety gate prevents MCTS from replacing the heuristic move unless it is at least as safe and meaningfully better

- `advanced`
  - `CaptureAiEngine.hybridMcts`
  - higher-budget MCTS: `72` playouts, rollout depth `20`, candidate limit `14`
  - stronger profile weights
  - sparse-opening baseline path delegates to the intermediate strategy early, then allows advanced search later

### 5. MCTS / Tactical Safety Changes

Several attempted directions were tested:

- Pure higher-budget MCTS for advanced.
- Deterministic tactical intermediate with MCTS disabled.
- Conservative MCTS takeover thresholds.
- Advanced using intermediate heuristic baseline.
- Advanced using intermediate full-strategy baseline during sparse openings.

Observed results:

- Pure advanced MCTS was not reliably stronger. It could beat `intermediate` but still lose directly to `beginner` on random/twist-cross starts.
- Disabling intermediate MCTS made intermediate worse than beginner.
- Conservative hybrid gating helped prevent severe tactical collapses.
- Sparse-opening intermediate baseline helped advanced somewhat, especially on twist-cross, but did not fully solve random direct advanced-vs-beginner.

## Validation Results

Static and unit validation passed:

```sh
dart analyze lib/game/capture_ai.dart lib/game/mcts_engine.dart lib/game/ai_arena_executor.dart lib/game/ai_arena_scheduler.dart tool/capture_ai_arena_runner.dart tool/capture_ai_strength_probe.dart test/capture_ai_robot_config_test.dart test/ai_arena_executor_test.dart test/ai_arena_resume_test.dart
```

Result: `No issues found!`

```sh
flutter test test/ai_arena_executor_test.dart test/capture_ai_robot_config_test.dart test/ai_arena_resume_test.dart
```

Result: `All tests passed!`

Strength probe results observed during this iteration:

```text
PASS adaptive 9x9 empty      intermediate>beginner: 3-0-0
PASS adaptive 9x9 empty      advanced>intermediate: 2-0-0
PASS adaptive 9x9 twistCross intermediate>beginner: 2-1-0
PASS adaptive 9x9 twistCross advanced>beginner: 2-1-0
PASS adaptive 9x9 random     intermediate>beginner: 2-0-0
PASS adaptive 9x9 random     advanced>intermediate: 2-0-0
```

Known failing or unstable probe:

```text
FAIL adaptive 9x9 random     advanced>beginner: 1-2-0
```

## Current Problem

The tier relationship is still not fully transitive under all starts.

The most important remaining issue:

- `advanced` can beat `intermediate` on random starts.
- `intermediate` can beat `beginner` on random starts.
- But `advanced` still failed direct `advanced>beginner` on 9x9 random in the latest 3-sample paired probe.

This indicates a non-transitive strategy interaction:

- `advanced` is not universally stronger.
- Some advanced MCTS choices are still worse against the stable beginner heuristic than the intermediate hybrid choices.
- Random sparse openings remain the hardest test case.

I have not validated the full 9/13/19 matrix yet. Current evidence is mainly from 9x9 targeted probes because full-board multi-opening probes are slow.

## Current Assessment

The code is in a better engineering state:

- Arena starts are broader and reproducible.
- Tests and analyzer pass.
- The probe tool can now reproduce and expose strength failures.
- `beginner` remains preserved.
- Several 9x9 tier checks now pass.

But the product goal is not fully complete:

- We cannot yet claim `beginner < intermediate < advanced` across all requested board sizes and starts.
- The main unresolved case is `advanced>beginner` under random starts.
- 13x13 and 19x19 still need full targeted validation after the 9x9 random issue is fixed.

## Recommended Next Steps

1. Add a debug mode to record move-by-move decisions for failing `advanced>beginner` random seeds.
2. Compare advanced candidate choice against intermediate candidate choice at the exact divergence point.
3. Add a stronger advanced fallback rule:
   - If advanced MCTS chooses a different move from intermediate in sparse random starts, require deeper safety proof or capture-margin superiority.
4. Re-run 9x9 random `advanced>beginner` until it passes at least 3 paired samples.
5. Then run the full matrix:
   - 9/13/19
   - empty/twistCross/random
   - intermediate>beginner
   - advanced>intermediate
   - advanced>beginner

The next useful engineering target is not more broad tuning. It is seed-level diagnosis of the failing random advanced-vs-beginner games.
