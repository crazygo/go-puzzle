# Capture AI Framework Arena

## Background

### Context

The app already has capture-go AI code, a pure-Dart simulation board, heuristic and hybrid-MCTS robot configurations, an arena executor, ladder/result models, CLI probes, and tests for deterministic arena execution. The current model is still centered on `CaptureAiStyle` and `DifficultyLevel`, with `CaptureAiEngine` acting as a local implementation detail rather than a stable algorithm-framework abstraction.

### Problem

The requested evaluation system needs to compare algorithm frameworks consistently: heuristic, MCTS, hybrid/tactical, KataGo, and future frameworks. Each framework must expose multiple runnable strength configurations, and the arena must report reproducible, failure-aware results under the five-capture rule across empty, cross, and twist-cross openings. The current arena is close, but it does not yet model frameworks/configurations as first-class comparable objects, does not treat KataGo as a capture-go framework, does not expose cross as a first-class opening, and does not report enough structured failure/per-opening data.

### Motivation

The goal is to make AI experiments auditable. Every runnable configuration should have a stable identity, explicit parameters, repeatable match output, and recorded tuning notes. This lets weak and strong configurations inside the same framework be compared through Git history and arena artifacts rather than through ad hoc manual interpretation.

## Goals

- Introduce a unified algorithm framework/configuration architecture for capture-go bots under the five-capture rule.
- Represent heuristic, MCTS, hybrid/tactical, and KataGo as algorithm frameworks, not one-off hard-coded bots.
- Provide at least two runnable configurations per supported framework, with real strength parameters.
- Extend the arena to run reproducible pairwise matches across empty, cross, and twist-cross openings with color swaps and fixed seeds.
- Report per-match facts, pairwise win rates, overall ranking, per-opening performance, illegal move and timeout status, and clear failure reasons.
- Add a conservative `TacticalAnalyzer` extension point for future ladder, twist-clamp, and loss-cutting analysis.
- Keep an experiment notebook that records tuning attempts, good configurations, bad configurations, commands, results, and reasons.
- Commit before and after every generated or tuned configuration so each config has a comparable Git history slice.

## Implementation Plan

1. Establish the tracking artifacts.
   - Add this implementation plan.
   - Add a tuning notebook under `docs/ai_eval/` or `docs/kb/` with a table for config ID, framework, parameters, purpose, command, result, verdict, and notes.
   - Make a baseline checkpoint commit before generating or tuning any AI configuration.

2. Define the framework and configuration model.
   - Add stable types for algorithm framework IDs, configuration IDs, strength labels, parameter maps, and failure behavior.
   - Keep display names separate from stable storage IDs.
   - Add a registry that can list frameworks and runnable configurations.
   - Adapt existing heuristic and hybrid-MCTS configs into this registry without removing existing app-facing behavior.

3. Add tactical analysis extension point.
   - Define `TacticalAnalyzer`, neutral analysis output, confidence fields, and conservative risk signal fields.
   - Wire neutral analysis so it does not change current decisions.
   - Add tests proving low-confidence or neutral analysis does not force a move.

4. Add framework-backed arena execution.
   - Update the arena executor to build agents from framework configurations instead of only style/difficulty.
   - Add explicit opening support for `empty`, `cross`, and `twistCross`.
   - Preserve color swaps, fixed seeds, repeated games, deterministic output, and max-move limits.
   - Add decision timeout accounting even if the first implementation uses synchronous elapsed-time checks.

5. Add failure-aware output and summaries.
   - Extend game records with legal/illegal status, timeout status, fallback status, framework/config IDs, failure reason, and opening name.
   - Add pairwise and per-opening aggregation.
   - Add overall ranking based on completed games, while surfacing invalid/timeout/fallback counts separately.

6. Add KataGo as an algorithm framework.
   - Add KataGo framework metadata and at least two runnable configurations.
   - In this phase, allow KataGo configs to use a legal fallback or structured failure path when the native/model backend is unavailable.
   - Ensure KataGo receives a capture-go `SimBoard` state and never crashes the arena.

7. Add and tune initial configurations with Git checkpoints.
   - Before each generated or tuned config, commit the current state.
   - Add or adjust one config at a time.
   - Run a small reproducible arena command.
   - Record the result in the tuning notebook.
   - Commit the config, test, and notebook entry after validation.

8. Prove basic strength and reproducibility.
   - Run repeated games showing at least one MCTS or hybrid-MCTS configuration beats a random/basic weak configuration without illegal moves, crashes, or decision timeouts.
   - Keep the run small enough for CI/local iteration but large enough to demonstrate directionally meaningful behavior.

## Acceptance Criteria

- The codebase exposes first-class algorithm frameworks and framework configurations with stable IDs and explicit parameters.
- Heuristic, MCTS, hybrid/tactical, and KataGo each have at least two runnable configurations.
- The weaker configuration in each framework returns legal moves or a clear structured fallback/failure and can complete bounded arena games without crashing.
- KataGo is represented as a framework and can participate in arena runs through legal fallback or clear failure reporting when backend inference is unavailable.
- The arena can run pairwise matches under capture target 5 across empty, cross, and twist-cross openings.
- Arena matches support color swaps, fixed seeds, repeated games, and reproducible JSON-compatible output.
- Arena output includes per-match results, pairwise win rates, overall ranking, per-opening performance, illegal move status, timeout status, fallback status, and failure reasons.
- At least one MCTS or hybrid-MCTS configuration demonstrates strength above a random/basic weak configuration across repeated games, with no illegal moves, crashes, or decision timeouts.
- `TacticalAnalyzer` exists as an extension point, and neutral or low-confidence analysis does not change existing decisions.
- Every generated/tuned configuration has a before and after Git commit.
- The tuning notebook records both good and bad experiments with commands, parameters, results, and verdicts.

## Validation Commands

- `flutter pub get`
- `dart format lib/game test tool`
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test test/ai_arena_executor_test.dart test/ai_arena_resume_test.dart test/ai_arena_ladder_test.dart test/capture_ai_robot_config_test.dart test/capture_ai_rating_test.dart`
- `dart run tool/capture_ai_strength_probe.dart --style counter --board-sizes 9 --openings empty,twistCross --rounds-per-opening 1 --max-moves 80 --capture-target 5 --pair advanced:beginner --min-win-rate 0.0`
- A new arena smoke command for framework configs once the framework runner exists.
