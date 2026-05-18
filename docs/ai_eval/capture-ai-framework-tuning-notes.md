# Capture AI Framework Tuning Notes

This notebook records the tuning process for unified capture-go AI algorithm
frameworks under the five-capture rule.

## Process Rules

- Commit before generating or tuning each AI configuration.
- Commit after each generated or tuned AI configuration, including code, tests,
  validation output summary, and this notebook entry.
- Record unsuccessful experiments as well as successful ones.
- Treat a configuration as runnable only when it returns legal moves or reports
  a clear structured fallback/failure without crashing the arena.
- Do not let low-confidence tactical analysis force a move choice.

## Experiment Log

| ID | Date | Framework | Config | Purpose | Parameters | Command | Result | Verdict | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline-env | 2026-05-19 | existing | existing arena/probes | Verify environment and current arena baseline before framework work | Existing `CaptureAiStyle`/`DifficultyLevel` configs | `flutter test test/ai_arena_executor_test.dart test/capture_ai_rating_test.dart`; `dart run tool/capture_ai_strength_probe.dart --style counter --board-sizes 9 --openings empty,twistCross --rounds-per-opening 1 --max-moves 80 --capture-target 5 --pair advanced:beginner --min-win-rate 0.0`; `flutter analyze --no-fatal-infos --no-fatal-warnings` | Focused tests passed; strength probe passed; analyzer exited successfully with non-fatal existing warnings/infos | Good baseline | Existing arena is runnable, but architecture is still style/difficulty based rather than framework/config based. |
| framework-registry-v1 | 2026-05-19 | heuristic, mcts, hybridTactical, katago | `heuristic_*_v1`, `mcts_*_v1`, `hybrid_tactical_*_v1`, `katago_fallback_*_v1` | Create first framework/config registry and prove each framework has at least two parameter-distinct configs | Heuristic configs vary style/playouts; MCTS configs vary visits/depth/candidate limit/temperature; hybrid configs vary existing difficulty search budgets; KataGo configs use explicit fallback parameters | `flutter test test/ai_algorithm_framework_test.dart` | 5 tests passed | Good architecture start | KataGo is represented as fallback-capable metadata and legal fallback agent construction, not native capture-go inference yet. |
| framework-arena-v1 | 2026-05-19 | framework arena | existing framework configs | Prove arena can run framework configs directly and cover the `cross` opening in the default mixed policy | `empty_cross_twist_cross_random_v1`; `cross_v1`; framework agent seed overrides per game | `flutter test test/ai_arena_executor_test.dart test/ai_algorithm_framework_test.dart test/ai_arena_resume_test.dart`; `flutter analyze --no-fatal-infos --no-fatal-warnings` | 32 tests passed; analyzer exited successfully with non-fatal existing warnings/infos | Good structural slice | Initial framework smoke uses weak configs for speed. A heavier hybrid-vs-weak strength proof remains a separate experiment. |
| tactical-analyzer-v1 | 2026-05-19 | hybridTactical extension | neutral/default analyzer | Add extension point for ladder, twist-clamp, and loss-cutting analysis without changing existing move choices | `NeutralTacticalAnalyzer`; low-confidence `ladderRisk` probe with confidence 0.40 | `flutter test test/ai_algorithm_framework_test.dart`; `flutter analyze --no-fatal-infos --no-fatal-warnings` | 7 tests passed; analyzer exited successfully with non-fatal existing warnings/infos | Good extension slice | Neutral and low-confidence tactical analysis are verified to defer to the wrapped bot. |

## Good Experiments

- `baseline-env`: confirms the current toolchain, focused arena tests, and a
  small strength probe are usable before architecture changes.
- `framework-registry-v1`: establishes stable framework/config identities and
  verifies every initial config can produce a legal opening move.
- `framework-arena-v1`: framework configs can be run through arena execution,
  `cross` is part of the default mixed opening policy, and replay is
  deterministic.
- `tactical-analyzer-v1`: creates the tactical extension point while preserving
  existing decisions for neutral and low-confidence results.

## Bad Experiments

- CLI argument form: `tool/capture_ai_strength_probe.dart` ignores
  `--key=value` and expects `--key value`. This can accidentally launch the
  default broad matrix. Use space-separated arguments for repeatable probes.
- Slow structural test attempt: using `hybrid_tactical_counter_standard_v1`
  against `katago_fallback_weak_v1` with capture target 5 made the unit-level
  framework replay test take about a minute. Structural tests now use weak
  configs; strength proof should run as an explicit experiment.

## Open Questions

- Decide whether new arena JSON artifacts should live under `docs/ai_eval/` or
  `docs/ai_arena/`.
- Decide the exact timeout threshold for synchronous Dart agents in local tests.
- Decide whether the first KataGo fallback config should prefer native ONNX,
  heuristic fallback, or explicit structured failure when no model is present.
