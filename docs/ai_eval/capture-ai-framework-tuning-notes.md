# Capture AI Framework Tuning Notes

This notebook records the tuning process for unified capture-go AI algorithm
frameworks under the five-capture rule.

## Process Rules

- Commit before generating or tuning each AI configuration.
- Commit after each generated or tuned AI configuration, including code, tests,
  validation output summary, and this notebook entry.
- Record unsuccessful experiments as well as successful ones.
- Treat a configuration as runnable only when it returns legal moves or reports
  a clear structured failure without crashing the arena.
- KataGo must not use a heuristic/hybrid fallback. If its model adapter cannot
  load a model, it must report unavailable and the arena must surface the
  failure.
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
| decision-timeout-v1 | 2026-05-19 | arena | all configs | Enforce and report per-decision time budget | Default decision timeout 10 seconds; runtime-only max decision measurement; deterministic JSON excludes measured milliseconds | `flutter test test/ai_arena_executor_test.dart test/ai_algorithm_framework_test.dart`; `flutter analyze --no-fatal-infos --no-fatal-warnings` | 17 focused tests passed; analyzer completed with existing warnings/infos | Good safety slice | `decisionTimeout` is reported as timeout/failure reason without making reproducible JSON unstable. |
| mcts-matrix-tuning-v1 | 2026-05-19 | mcts | `mcts_counter_standard_v1` vs `mcts_counter_weak_v1` | Make MCTS standard beat weak in the full opening x first-player matrix | Weak: adaptive/beginner MCTS, playouts 1, depth 2, candidates 3, temp 30, randomLegalMoveRate 0.85. Standard: counter/intermediate MCTS, playouts 4, depth 4, candidates 5, temp 2 | `dart run tool/capture_ai_framework_probe.dart --matrix --configs mcts_counter_standard_v1,mcts_counter_weak_v1 --rounds 4 --max-moves 120 --capture-target 5 --match-seed 20260519 --opening-seed 0 --expected-winner mcts_counter_standard_v1 --min-win-rate 0.55` | Standard won 24-0, illegal 0, timeout 0 | Good tuning slice | Earlier pure-budget-only MCTS tied 12-12 because first-player advantage dominated; explicit weak randomness produced a legal but meaningfully weaker bot. |
| hybrid-matrix-tuning-v1 | 2026-05-19 | hybridTactical | `hybrid_tactical_counter_standard_v1` vs `hybrid_tactical_counter_weak_v1` | Make Hybrid standard beat weak in the full opening x first-player matrix | Weak keeps intermediate hybrid plus randomLegalMoveRate 0.35. Standard uses intermediate hybrid, heuristicPlayouts 24, mctsPlayouts 8, rolloutDepth 6, candidates 6, temp 3 | `dart run tool/capture_ai_framework_probe.dart --matrix --configs hybrid_tactical_counter_standard_v1,hybrid_tactical_counter_weak_v1 --rounds 4 --max-moves 120 --capture-target 5 --match-seed 20260519 --opening-seed 0 --expected-winner hybrid_tactical_counter_standard_v1 --min-win-rate 0.55` | Standard won 18-6, illegal 0, timeout 0 | Good tuning slice | Advanced hybrid was too slow for matrix iteration; intermediate standard keeps the framework behavior while staying within the per-decision budget. |
| katago-fallback-matrix-v1 | 2026-05-19 | katago | `katago_fallback_standard_v1` vs `katago_fallback_weak_v1` | Complete KataGo fallback two-config scoring and tuning | Weak fallback adaptive/beginner plus randomLegalMoveRate 0.85. Standard fallback counter/intermediate | `dart run tool/capture_ai_framework_probe.dart --matrix --configs katago_fallback_standard_v1,katago_fallback_weak_v1 --rounds 4 --max-moves 120 --capture-target 5 --match-seed 20260519 --opening-seed 0 --expected-winner katago_fallback_standard_v1 --min-win-rate 0.55` | Standard won 24-0, illegal 0, timeout 0, fallback expected | Rejected | This made KataGo look playable without a model and was removed because fallback hides the real model availability state. |
| katago-onnx-adapter-v1 | 2026-05-19 | katago | `katago_onnx_weak_v1`, `katago_onnx_standard_v1` | Add a native/external backend interface so KataGo is not only a virtual fallback framework | ONNX adapter request includes model asset, visits, and time budget. Initial implementation still used legal fallback when the model was unavailable. | `flutter test test/ai_algorithm_framework_test.dart`; `dart run tool/capture_ai_framework_probe.dart --matrix --configs katago_onnx_standard_v1,katago_onnx_weak_v1 --rounds 4 --max-moves 120 --capture-target 5 --match-seed 20260519 --opening-seed 0 --expected-winner katago_onnx_standard_v1 --min-win-rate 0.55` | 9 framework tests passed. Matrix standard won 24-0, illegal 0, timeout 0 | Rejected fallback behavior | The adapter boundary was useful, but the fallback behavior was removed because it obscured whether a real KataGo model was loaded. |
| reduced-randomness-v1 | 2026-05-19 | mcts, hybridTactical | `mcts_counter_weak_v1`, `hybrid_tactical_counter_weak_v1` | Reduce explicit random weakening while keeping standard stronger than weak in five-capture matrix games | MCTS weak randomLegalMoveRate 0.85 -> 0.55 then 0.25 with visits/depth/candidates/temp still weak. Hybrid weak 0.35 -> 0.20 with intermediate hybrid budget. | MCTS and Hybrid matrix commands above with updated params | MCTS standard won 18-6 at randomLegalMoveRate 0.25. Hybrid standard won 15-9 at randomLegalMoveRate 0.20. All illegal 0, timeout 0 | Good credibility improvement | Hybrid and MCTS now look less artificially weakened while preserving a stable standard-over-weak signal. KataGo was removed from this randomness tuning because it must be model-backed only. |
| all-config-timeout-smoke-v1 | 2026-05-19 | all frameworks | all 10 then-current configs | Prove every config can be evaluated by the arena under the 10s decision budget | Pairwise one-game smoke, capture target 1, maxMoves 120, mixed opening policy | `dart run tool/capture_ai_framework_probe.dart --configs heuristic_adaptive_weak_v1,heuristic_counter_standard_v1,mcts_counter_weak_v1,mcts_counter_standard_v1,hybrid_tactical_counter_weak_v1,hybrid_tactical_counter_standard_v1,katago_fallback_weak_v1,katago_fallback_standard_v1,katago_onnx_weak_v1,katago_onnx_standard_v1 --rounds 1 --max-moves 120 --capture-target 1 --opening-policy empty_cross_twist_cross_random_v1 --match-seed 20260519 --opening-seed 0` | 45 pairwise games completed, illegal 0, timeout 0; fallback reasons reported for fallback and ONNX-unavailable configs | Superseded | This covered the old fallback-inclusive config list. It is kept as historical evidence only and must be replaced by a no-fallback smoke. |
| katago-no-fallback-v1 | 2026-05-19 | katago | `katago_onnx_weak_v1`, `katago_onnx_standard_v1` | Remove all KataGo fallback behavior so missing models are visible to users and evaluators | Only ONNX configs remain. No fallback style, no fallback difficulty, no random weakening. Missing model returns no move and reports `katago_onnx_model_unavailable`. | `flutter test test/ai_algorithm_framework_test.dart test/ai_arena_executor_test.dart`; `dart run tool/capture_ai_framework_probe.dart --configs heuristic_adaptive_weak_v1,heuristic_counter_standard_v1,mcts_counter_weak_v1,mcts_counter_standard_v1,hybrid_tactical_counter_weak_v1,hybrid_tactical_counter_standard_v1,katago_onnx_weak_v1,katago_onnx_standard_v1 --rounds 1 --max-moves 120 --capture-target 1 --opening-policy empty_cross_twist_cross_random_v1 --match-seed 20260519 --opening-seed 0` | 20 focused tests passed. Current 8-config smoke completed 28 pairwise games, illegal 0, timeout 0, fallback 0. KataGo games report `agent_returned_no_legal_move` plus `katago_onnx_model_unavailable`. | Good truthfulness fix | KataGo strength is intentionally not scored until a real model adapter can return moves. This prevents false confidence from heuristic/hybrid fallback. |
| per-framework-timeout-v1 | 2026-05-19 | all frameworks | timeout policy | Align timeout policy with algorithm cost | Non-KataGo framework configs use a 5s arena decision timeout by default. KataGo ONNX configs expose `timeBudgetMillis: 10000`, and framework matches pass that as the KataGo side's per-color timeout. | `flutter test test/ai_algorithm_framework_test.dart test/ai_arena_executor_test.dart` | 21 focused tests passed | Good timeout policy slice | This separates each side's timeout inside one game, so a KataGo-vs-non-KataGo match can apply 10s to KataGo and 5s to the other agent. |
| real-katago-onnx-policy-v1 | 2026-05-19 | katago | `katago_onnx_weak_v1`, `katago_onnx_standard_v1` | Verify a real ONNX model can participate in capture-go arena games without fallback | Downloaded Kaya/KataGo-family uint8 ONNX model through `scripts/download-katago-capture-models.sh`. Weak uses policyTemperature 1.35 and candidateLimit 12; standard uses deterministic top policy with candidateLimit 1. Both use the real model file, no heuristic fallback. | `python3 tool/katago_onnx_move.py <json>`; `dart run tool/capture_ai_framework_probe.dart --real-katago-onnx --configs heuristic_adaptive_weak_v1,mcts_counter_standard_v1,hybrid_tactical_counter_standard_v1,katago_onnx_weak_v1,katago_onnx_standard_v1 --rounds 4 --max-moves 120 --capture-target 1 --opening-policy empty_cross_twist_cross_random_v1 --match-seed 20260519 --opening-seed 0` | Model helper returned a legal move. 5-config cross arena completed 40 games, illegal 0, timeout 0, fallback 0. KataGo weak and standard each scored 2-14 overall and tied each other 2-2. | Superseded by Flutter ONNX direction | This proved real model inference but used a Python process adapter. It is kept only as historical/debug evidence because the product path should use Dart/Flutter ONNX. |
| flutter-onnx-adapter-v1 | 2026-05-19 | katago | `katago_onnx_weak_v1`, `katago_onnx_standard_v1` | Replace Python process inference with a Dart/Flutter ONNX adapter boundary | `FlutterKatagoOnnxModelAdapter` loads model assets through `flutter_onnxruntime`, encodes `bin_input [1,22,N,N]` and `global_input [1,19]`, reads policy output, and selects legal moves by temperature/candidate limit. Async arena requires an injected adapter for KataGo configs; no default fallback is allowed. Web runtime loads `onnxruntime-web` before Flutter bootstrap and maps Flutter asset keys to web asset URLs. | `flutter test test/ai_arena_executor_test.dart test/katago_onnx_features_test.dart test/ai_algorithm_framework_test.dart`; `flutter build web -t tool/flutter_katago_arena_probe.dart`; `python3 -m http.server 8092 --bind 127.0.0.1 --directory build/web`; Playwright capture of `tool/flutter_katago_arena_probe.dart` output to `docs/ai_eval/runs/2026-05-19-flutter-katago-arena-probe.json` | Focused tests passed. Web probe completed 10 pairwise matches / 40 games, illegal 0, timeout 0, fallback 0, failure 0. KataGo weak and standard each scored 2-14 overall and tied each other 2-2. | Real but weak | This replaces the Python arena path with Dart/Flutter ONNX evidence. The model is playable and truthful, but weak because the current encoder/search is minimal; use this as architecture proof, not strength proof. |

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
- `mcts-matrix-tuning-v1` and `hybrid-matrix-tuning-v1`: produce full
  five-capture matrix wins for standard over weak with no illegal moves and no
  timeouts.
- `katago-onnx-adapter-v1`: adds a native/external KataGo adapter boundary and
  native-mode ONNX configs. The first fallback behavior was rejected; the
  adapter boundary remains the useful part.
- `reduced-randomness-v1`: reduces explicit weak randomness for MCTS and Hybrid
  while preserving five-capture matrix wins with no illegal moves and no
  timeouts.
- `katago-no-fallback-v1`: removes all KataGo fallback behavior. Missing models
  now produce a clear unavailable failure instead of a fake legal move.
- `real-katago-onnx-policy-v1`: proves a real ONNX model can return legal
  capture-go moves, but it used the rejected Python process path and is now
  historical/debug evidence only.
- `flutter-onnx-adapter-v1`: moves KataGo toward the requested Dart/Flutter
  ONNX path with async adapter injection and no fallback default. The web probe
  generated a reproducible arena artifact with real legal KataGo moves and no
  failures.

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
- Flutter tester real ONNX attempt: `flutter test -d macos` and
  `flutter test -d chrome` with real ONNX tests entered the model/plugin path
  but did not complete. The replacement validation path is the Flutter Web
  probe target served from `build/web`, which produced a structured arena
  artifact instead of hanging.
- Flutter Web ONNX asset path: the first web probe passed Flutter asset keys
  (`assets/models/...`) directly to `onnxruntime-web`, which failed because the
  built URL is `assets/assets/models/...`. The adapter now maps asset keys on
  web before creating the session.
- Too-low max moves: reducing the hybrid proof to max moves 40 produced four
  timeouts; max moves 60 still produced three timeouts. The fast proof keeps
  max moves 80 to avoid decision failures.
- Heavy five-capture matrix: running `hybrid_tactical_counter_weak_v1` vs
  `heuristic_adaptive_weak_v1` with matrix mode, capture target 5, rounds 4,
  and max moves 80 was stopped after about two minutes. The matrix shape is
  valid, but heavier configs need batching or tighter per-decision budgets.
- MCTS budget-only tuning: reducing MCTS standard from 64 to 4 playouts and
  weak from 16 to 1 playout still produced a 12-12 matrix tie because first
  player advantage dominated. Added explicit weak randomness instead.
- Random weak legality bug: the first random legal wrapper used
  `getLegalMoves()` directly and produced invalid moves in five-capture
  matrix runs. It now filters with `analyzeMove(...).isLegal`.
- Partial randomness reduction: MCTS and KataGo still win 24-0 after reducing
  weak randomness to 0.55. This is legal and stable but still too separated to
  call the weak configs naturally calibrated; later tuning should try lower
  rates or more natural parameter-only deltas.
- Too-low all-config smoke maxMoves: the first full-config smoke used
  maxMoves 20 and many games hit `max_moves_reached`. It was not a decision
  timeout or illegal-move failure, but the probe correctly failed it as an
  incomplete evaluation. The passing smoke uses maxMoves 120.
- KataGo fallback configs: `katago_fallback_*_v1` and the first ONNX fallback
  path made missing-model KataGo appear playable. This was rejected because it
  hides the real model availability state.
- KataGo fallback-path matrix with randomLegalMoveRate 0.25 produced a 16-7-1
  standard-over-weak result, illegal 0, timeout 0, but it is invalid evidence
  because it still used fallback instead of a loaded model.
- Real Kaya/KataGo ONNX with minimal feature planes lost heavily to local
  capture-go bots at capture target 1. This is not a model-loading failure; it
  is an encoding/search-quality problem to fix before treating KataGo as a
  strong baseline.

## Open Questions

- Decide whether new arena JSON artifacts should live under `docs/ai_eval/` or
  `docs/ai_arena/`.
- Decide the exact timeout threshold for synchronous Dart agents in local tests.
- Wire a real KataGo ONNX model asset into `KatagoModelAdapter` when a capture-go
  compatible model is available.
