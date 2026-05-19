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
| arena-output-v1 | 2026-05-19 | framework arena | existing framework configs | Add failure-aware result fields and per-opening performance summaries for later ranking/evaluation output | `illegalMove`, `timedOut`, `fallbackUsed`, `failureReason`, `openingPerformance` | `flutter test test/ai_arena_executor_test.dart test/ai_arena_resume_test.dart` | 28 tests passed | Good reporting slice | This does not tune a bot config. It makes timeout/fallback/failure evidence visible so future strength experiments can be compared without reading raw game logs. |
| framework-evaluation-summary-v1 | 2026-05-19 | framework arena | existing framework configs | Add selected-config round-robin aggregation with pairwise summaries and overall ranking output | Pairwise once per selected config pair; deterministic per-pair seed offsets; ranking by match wins, game win rate, then config id | `flutter test test/ai_arena_executor_test.dart test/ai_arena_ladder_test.dart test/ai_arena_resume_test.dart` | 50 tests passed | Good reporting slice | The first assertion over-constrained opening count; shifted seeds correctly expanded aggregate openings. Final test checks required openings and schema fields instead. |
| hybrid-strength-proof-v1 | 2026-05-19 | hybridTactical | `hybrid_tactical_counter_weak_v1` vs `heuristic_adaptive_weak_v1` | Find a fast repeated-game proof that a hybrid/MCTS-family config beats a basic weak config under capture target 5 | Fast regression: 9x9, capture target 5, rounds 2, max moves 80, opening seed 1. Broader probe: rounds 4, opening seed 0 | Fast: `dart run tool/capture_ai_framework_probe.dart --configs hybrid_tactical_counter_weak_v1,heuristic_adaptive_weak_v1 --rounds 2 --max-moves 80 --capture-target 5 --opening-policy empty_cross_twist_cross_random_v1 --match-seed 20260519 --opening-seed 1 --expected-winner hybrid_tactical_counter_weak_v1 --min-win-rate 0.50`; broader: same command with `--rounds 4 --opening-seed 0` | Fast proof won 2-0 on cross color swap; broader proof won 3-1. Both had no illegal moves, no timeouts, no fallback | Good strength proof | The unit regression uses the faster 2-game proof. The 4-game probe remains supporting evidence across empty/cross. |
| opening-first-matrix-v1 | 2026-05-19 | framework arena | `heuristic_counter_standard_v1` vs `heuristic_adaptive_weak_v1` | Add multidimensional evaluation: opening x first algorithm x 4 games | Matrix mode, 9x9, capture target 1, max moves 80, openings empty/cross/twist-cross, both first-player orders, 4 games per cell | `dart run tool/capture_ai_framework_probe.dart --matrix --configs heuristic_counter_standard_v1,heuristic_adaptive_weak_v1 --rounds 4 --max-moves 80 --capture-target 1 --match-seed 20260519 --opening-seed 0` | 24 games completed, standard aggregate 16-8, illegal 0, timeout 0 | Good evaluation-surface slice | This proves the requested matrix shape and fixed-first execution. Five-capture strength calibration still needs heavier runtime handling before applying the same matrix to hybrid/MCTS configs. |

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
- `arena-output-v1`: exposes per-game failure causes and per-opening aggregate
  status, making weak/fallback experiments auditable without changing bot
  behavior.
- `framework-evaluation-summary-v1`: produces a stable comparison artifact for
  selected framework configs, including raw matches, pairwise rates, rankings,
  and aggregate opening performance.
- `hybrid-strength-proof-v1`: establishes a repeatable hybrid/MCTS-family
  strength signal over the basic weak heuristic config without failures.
- `opening-first-matrix-v1`: adds the requested opening-by-first-player-by-4
  evaluation matrix and verifies it with a full 24-game heuristic run.

## Bad Experiments

- CLI argument form: `tool/capture_ai_strength_probe.dart` ignores
  `--key=value` and expects `--key value`. This can accidentally launch the
  default broad matrix. Use space-separated arguments for repeatable probes.
- Slow structural test attempt: using `hybrid_tactical_counter_standard_v1`
  against `katago_fallback_weak_v1` with capture target 5 made the unit-level
  framework replay test take about a minute. Structural tests now use weak
  configs; strength proof should run as an explicit experiment.
- Over-specific aggregate opening assertion: assuming three pairwise matches
  with shifted seeds would only include `empty` and `cross` was wrong. The
  aggregate may include random and twist-cross variants; tests now assert
  required coverage rather than an exact two-opening list.
- Slow MCTS standard proof: `mcts_counter_standard_v1` vs
  `heuristic_adaptive_weak_v1` at 12 rounds / max moves 160 was stopped after
  more than two minutes. Keep standard-strength proof as an explicit longer
  benchmark, not a fast validation check.
- Weak MCTS tie: `mcts_counter_weak_v1` vs `heuristic_adaptive_weak_v1` at
  4 rounds / max moves 80 produced a 2-2 tie, which is useful evidence but not
  sufficient for the required above-baseline proof.
- Too-low max moves: reducing the hybrid proof to max moves 40 produced four
  timeouts; max moves 60 still produced three timeouts. The fast proof keeps
  max moves 80 to avoid decision failures.
- Heavy five-capture matrix: running `hybrid_tactical_counter_weak_v1` vs
  `heuristic_adaptive_weak_v1` with matrix mode, capture target 5, rounds 4,
  and max moves 80 was stopped after about two minutes. The matrix shape is
  valid, but heavier configs need batching or tighter per-decision budgets.

## Open Questions

- Decide whether new arena JSON artifacts should live under `docs/ai_eval/` or
  `docs/ai_arena/`.
- Decide the exact timeout threshold for synchronous Dart agents in local tests.
- Decide whether the first KataGo fallback config should prefer native ONNX,
  heuristic fallback, or explicit structured failure when no model is present.
