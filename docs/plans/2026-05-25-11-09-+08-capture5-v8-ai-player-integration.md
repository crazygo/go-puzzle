# Capture5 v8 AI Player Integration

## Background

### Context

Go Puzzle 1.3.0 currently exposes capture-five AI players through
`AiAlgorithmRegistry` and the setup screen's named opponent list. Existing
native players include heuristic, MCTS, hybrid tactical, and KataGo ONNX
configs. KataGo is treated as an async ONNX-backed config with explicit
no-fallback behavior when the model is unavailable.

The `go-puzzle-ml` repository now provides a released Capture5 v8 model at:

```text
/Users/admin/Code/go-puzzle-ml/models/released/capture5_13x13_policy_only_v8.onnx
```

The metadata file reports:

- model id: `capture5_13x13_policy_only_v8`
- architecture: `capture5_cnn_phase0_frozen_v1`
- ONNX size: `11,495,763` bytes
- ONNX SHA-256:
  `98441223424eef68eaeab35c715f56add24ff0207c0d59ab66a85fdaed4f48c6`
- training mode: policy supervised
- reported release results: strong arena and tactical-fixture performance

The current KB draft describes the model as a 13x13 capture-five policy-only
ONNX model with `features` and `globals` inputs, but its output contract is
incorrect. Local ONNX inspection and the ML repo constants confirm the policy
head is `[1,170]`: indices `0..168` are board points, and index `169` is the
ML rules engine's pass move. Go Puzzle's capture-five UI does not currently
offer pass as an in-game action, so the first app integration must ignore
policy index `169` and choose only legal board moves.

### Problem

The app cannot currently expose this model as a selectable AI player because:

- The model file is not present in `assets/models/`.
- The app has no Capture5 feature encoder for the model's `features` and
  `globals` inputs.
- The app has no Capture5 ONNX adapter.
- The async AI dispatch path is currently KataGo-specific.
- The setup UI does not have board-size-aware player filtering for a 13x13-only
  capture-five player.
- The model download/release-asset path has not been defined for this ONNX file.
- No in-app arena validation has measured Capture5 v8 against the current MCTS
  player under the app's actual runtime path.
- The existing KB draft and sample adapter code use stale app API assumptions:
  `KatagoPolicyCandidate` uses `position`, `score`, `probability`, `rank`, and
  `policyPlane`, while `KatagoModelEvaluation.value` is a
  `KatagoValueEstimate?`, not a raw `double`.

### Motivation

Capture5 v8 should give users a stronger 13x13 capture-five opponent without
adding outer MCTS or hand-written tactical overrides. The integration should be
truthful about model scope: it is available only for 13x13 capture-five games,
hidden everywhere else, and unavailable models should fail visibly rather than
falling back to another AI.

## Goals

- Integrate Capture5 v8 as a new selectable AI player for capture-five 13x13
  games only.
- Use the ONNX policy model directly, without adding MCTS, tactical override, or
  heuristic fallback on top of its move choice.
- Treat the model's 170th policy output as pass and exclude it from app move
  selection until pass is intentionally supported in capture-five gameplay.
- Keep 9x9, 19x19, and territory mode free of Capture5 v8 UI entries.
- Download/copy the model into `assets/models/` for local/runtime use without
  committing the ONNX file to git.
- Add repeatable arena validation that reports Capture5 v8 win rate against the
  current MCTS standard player.
- Preserve existing KataGo, MCTS, heuristic, and hybrid player behavior.

## Implementation Plan

1. Verify the released model contract.
   - Copy the local ONNX file into `assets/models/capture5_13x13_policy_only_v8.onnx`
     for development use only.
   - Confirm SHA-256 equals
     `98441223424eef68eaeab35c715f56add24ff0207c0d59ab66a85fdaed4f48c6`.
   - Document the verified ONNX inputs and outputs:
     `features [batch,9,13,13]`, `globals [batch,6]`,
     `policy [batch,170]`, `value [batch,1]`,
     `capture_delta [batch,1]`, and `group_risk [batch,1]`.
   - Treat policy index `169` as pass because ML constants define
     `PASS_MOVE = POINT_COUNT` and `POLICY_SIZE = POINT_COUNT + 1`.
   - Exclude pass from first-phase app move selection; rank only legal board
     moves in `0..168`.

2. Define the product and technical contract.
   - Add a specs map entry stating Capture5 v8 appears only in capture-five
     13x13 setup.
   - State that Capture5 v8 uses its policy-only ONNX output directly without
     MCTS or tactical fallback.
   - State that missing/unloadable Capture5 v8 models report unavailable instead
     of silently falling back.
   - Reference the spec from fragile code boundaries and tests.

3. Add model asset bootstrap support.
   - Add the Capture5 v8 model to the local download/bootstrap path as a release
     asset, not as a git-tracked ONNX file.
   - Update `assets/models/README.txt` with source, expected filename, size, and
     SHA-256.
   - Prefer a GitHub release asset download URL once the asset is uploaded.
   - Ensure `assets/models/` remains the Flutter asset directory, so adding the
     individual ONNX file to git is unnecessary.

4. Implement Capture5 feature encoding and adapter.
   - Add a `Capture5FeatureEncoder` that matches the ML repo's encoder:
     stone planes, current-player plane, legal-move plane, liberty-risk planes,
     and six global values.
   - Add a public `SimBoard.koIndex` getter if needed to encode ko accurately;
     otherwise document and test the temporary omission.
   - Add an async Capture5 ONNX adapter that loads the model, runs
     `features/globals`, ranks legal moves by policy logits, applies
     temperature only within legal board moves, and returns the existing app
     evaluation types correctly.
   - Build `KatagoPolicyCandidate` with `BoardPosition`, `score`,
     `probability`, `rank`, and `policyPlane`; do not use stale
     `moveIndex/prior/row/col` fields from the draft KB.
   - If auxiliary heads are surfaced, map `value` to `KatagoValueEstimate` or
     leave it unset until the value-head semantics are product-defined; do not
     store a raw `double` in `KatagoModelEvaluation.value`.
   - Keep selected moves legal-checked before applying them.
   - If the top model logit is pass, skip it and continue to the best legal
     board move. If no legal board move exists, report a clear unavailable
     reason rather than applying pass implicitly.

5. Register Capture5 v8 as an AI config.
   - Add `AiAlgorithmFrameworkId.capture5`.
   - Add a native async config such as `capture5_v8_standard`.
   - Use model parameters similar to:
     `modelAsset`, `timeBudgetMillis`, `policyTemperature`, and
     `candidateLimit`.
   - Keep default selection deterministic or near-deterministic so the player
     represents model strength rather than sampling noise.
   - Ensure `AiAlgorithmRegistry.createAsyncAgent()` can dispatch Capture5 v8
     through its adapter without reusing KataGo-specific assumptions.

6. Make setup UI filtering board-size and mode aware.
   - Show Capture5 v8 only when `GameMode.capture` and board size is `13`.
   - Hide Capture5 v8 for 9x9, 19x19, and territory mode.
   - If a saved selected config becomes invalid after mode or board-size change,
     migrate to the current valid default opponent.
   - Add a clear display name, subtitle, and summary for the new player.

7. Add tests and validation harnesses.
   - Unit-test the feature encoder shapes and key planes on known boards.
   - Unit-test adapter behavior with fake ONNX/runtime seams where practical.
   - Widget-test setup filtering for 13x13 capture, 9x9 capture, 19x19 capture,
     and territory mode.
   - Provider-test that Capture5 v8 applies its adapter move directly and does
     not fall back to runner/default AI on adapter failure.
   - Arena-test or tool-test that Capture5 v8 can complete repeated games with
     zero illegal moves.

8. Run Capture5 v8 versus current MCTS standard evaluation.
   - Compare `capture5_v8_standard` against `mcts_counter_standard_v1`.
   - Use 13x13, capture target 5, fixed deterministic openings, and both
     first-player directions.
   - Run at least 30 games per first-player direction, 60 games total.
   - Record wins, losses, draws, illegal moves, timeouts, fallback count, and
     failure reasons.
   - Save the output under `docs/ai_eval/runs/` or another existing arena output
     location, and summarize the result in a KB/eval note.

## Acceptance Criteria

- `capture5_13x13_policy_only_v8.onnx` is available locally through the model
  bootstrap/download path, but the ONNX file itself is not committed to git.
- The integrated model SHA-256 matches
  `98441223424eef68eaeab35c715f56add24ff0207c0d59ab66a85fdaed4f48c6`.
- ONNX input/output shape verification is documented, including the final
  decision that policy index `169` is pass and is ignored by first-phase app
  move selection.
- Capture5 v8 appears in the setup AI player picker only for capture-five 13x13
  games.
- Capture5 v8 is hidden for capture-five 9x9, capture-five 19x19, and territory
  games.
- Capture5 v8 uses model policy selection directly, with no MCTS overlay,
  tactical override, or silent fallback to another player.
- Capture5 v8 never maps policy index `169` to a board coordinate and never
  applies pass implicitly in the current capture-five game UI.
- Missing or failed Capture5 v8 model inference reports a clear unavailable
  reason to the provider/UI path.
- Existing KataGo, MCTS, heuristic, hybrid, and training-coach tests continue to
  pass.
- Capture5 v8 completes at least 60 arena games against
  `mcts_counter_standard_v1` on 13x13 capture-five with:
  - 0 illegal moves
  - 0 silent fallbacks
  - 0 unhandled adapter failures
  - win-rate statistics recorded for both first-player directions
- The Capture5 v8 versus MCTS standard win-rate report is saved and includes
  seeds, opening policy, board size, capture target, config ids, first-player
  directions, wins/losses/draws, and failure counts.

## Validation Commands

- `shasum -a 256 assets/models/capture5_13x13_policy_only_v8.onnx`
- `python3 - <<'PY' ... inspect ONNX input/output shapes ... PY`
- `flutter test test/capture5_onnx_features_test.dart`
- `flutter test test/ai_algorithm_framework_test.dart`
- `flutter test test/capture_setup_screen_test.dart`
- `flutter test test/capture_game_provider_test.dart --name "Capture5"`
- `flutter test test/ai_arena_executor_test.dart --name "Capture5|MCTS"`
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `dart run tool/capture_ai_framework_probe.dart --configs capture5_v8_standard,mcts_counter_standard_v1 --board-size 13 --capture-target 5 --rounds 60 --opening-policy <fixed_13x13_policy> --match-seed <seed>`
