# AI Robot Engine Refactor

## Background

### Context

The capture-go AI currently exposes robot identities by style and difficulty,
such as `adaptive_beginner_v1` and `adaptive_advanced_v1`. The arena schedules
matches and updates ladder snapshots, but actual move selection is owned by the
robot agent returned by `CaptureAiRegistry.create(...)`.

Before this refactor, every registered robot used the same deterministic
heuristic agent. Style changed heuristic weights, and difficulty only changed a
short deterministic rollout depth. The codebase also contains a basic UCT MCTS
engine, but it was not connected to registered robots. Issue #78 tracks the
larger need to separate robot engine type, style bias, difficulty strength,
opening coverage, and fast health tests.

### Problem

The existing labels imply meaningful strength differences, but advanced robots
are not powered by a stronger decision system. Arena rankings can be misleading
when deterministic empty-board games repeat exactly, color advantage dominates,
and opening fields are recorded without affecting the actual board. Robot health
checks also need to prove that every registered configuration is usable without
requiring slow full arena smoke runs.

### Motivation

Separating engine type, style preference, difficulty, and search budget gives
the project a stable basis for ranking 9x9, 13x13, and 19x19 robots. It also
keeps beginner robots useful for teaching while allowing intermediate and
advanced robots to become genuinely stronger through hybrid or MCTS-based
search.

## Goals

- Keep the arena as a scheduler and recorder, not an owner of move-selection
  logic.
- Introduce explicit robot engine configuration for heuristic, hybrid MCTS, and
  MCTS robots.
- Preserve existing UI/provider entry points that call `CaptureAiRegistry` by
  style and difficulty.
- Make style a reusable prior or evaluation bias inside heuristic and MCTS
  decisions.
- Add fast robot health tests that cover all registered styles and difficulties
  without running full ladder smoke.
- Prepare the next implementation phase for deterministic empty and twist-cross
  opening coverage in arena runs.

## Implementation Plan

1. Add a robot configuration layer.
   - Define engine identities for `heuristic`, `hybridMcts`, and `mcts`.
   - Add a `CaptureAiRobotConfig` model that resolves style, difficulty, engine,
     search budget, rollout depth, candidate limit, exploration, temperature,
     and seed.
   - Keep display labels separate from stable robot IDs such as
     `<style>_<difficulty>_v1`.

2. Wire robot configs through `CaptureAiRegistry`.
   - Preserve `CaptureAiRegistry.create(style, difficulty)` for existing
     callers.
   - Add `resolveConfig`, `registeredConfigs`, and `createFromConfig` so tests
     and arena code can inspect or instantiate explicit robot configs.
   - Route beginner to heuristic, intermediate to hybrid MCTS, and advanced to
     MCTS as the first concrete strength split.

3. Extend MCTS for robot use.
   - Allow deterministic seeds.
   - Allow candidate limits, rollout depth, exploration, and rollout
     temperature to vary by robot config.
   - Accept a style-aware move scorer so heuristic style preferences can act as
     candidate priors and rollout bias.
   - Keep the implementation as basic UCT MCTS; do not add RAVE/AMAF or neural
     evaluation in this phase.

4. Add fast robot health tests.
   - Cover every registered style and difficulty on 9x9, 13x13, and 19x19.
   - Cover both empty-board and twist-cross board states at the unit level.
   - Verify legal move selection, bounded play without invalid moves, and
     seeded MCTS reproducibility.
   - Use reduced test-only search budgets so this suite stays fast and does not
     become a full arena smoke run.

5. Plan the opening-policy follow-up.
   - Add explicit arena opening support for `empty` and `twistCross`.
   - Replace passive `openingIndex` logging with actual board initialization.
   - Record opening mode and variant in match logs.
   - Run fixed, deterministic opening mixes such as six empty games and six
     twist-cross games before trusting ladder calibration.

6. Calibrate strength after opening support lands.
   - Re-run targeted 9x9, 13x13, and 19x19 comparisons.
   - Tune MCTS playouts, candidate limits, rollout depth, exploration, and
     temperature only after deterministic opening coverage is real.
   - Keep full arena rankings opt-in and separate from the fast health tests.

## Acceptance Criteria

- Each registered capture AI robot resolves to an explicit engine type, style,
  difficulty, search budget, and deterministic seed.
- Existing callers that request a robot by style and difficulty continue to
  compile and receive a `CaptureAiAgent`.
- At least one advanced robot uses MCTS search instead of only deterministic
  heuristic rollout.
- Intermediate robots can use hybrid search while still preserving style-aware
  heuristic behavior.
- The MCTS engine can be seeded and configured without making the arena aware of
  heuristic or search internals.
- Fast robot health tests cover all registered style/difficulty combinations on
  9x9, 13x13, and 19x19 for both empty and twist-cross board states.
- Fast robot health tests validate legal moves, bounded play, and deterministic
  replay without invoking the full arena ladder runner.
- The next opening-policy phase has a clear path to make empty and twist-cross
  openings affect actual arena board state and JSONL artifacts.

## Validation Commands

- `dart analyze lib/game/capture_ai.dart lib/game/mcts_engine.dart test/capture_ai_robot_config_test.dart`
- `flutter test test/capture_ai_robot_config_test.dart`
- `flutter test test/capture_ai_evaluation_test.dart test/capture_ai_rating_test.dart test/ai_arena_artifact_writer_test.dart test/ai_arena_ladder_test.dart test/ai_arena_resume_test.dart`
