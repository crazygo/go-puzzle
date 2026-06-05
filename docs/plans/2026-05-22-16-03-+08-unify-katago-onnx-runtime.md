# Unify KataGo ONNX Runtime

## Background

### Context

The current codebase has three overlapping KataGo ONNX concepts:

- Capture-mode player configs use `katago_onnx_weak_v1` and `katago_onnx_standard_v1`, both pointing to separate local filenames that currently have the same SHA-256 hash.
- The training coach path uses `katago_onnx_standard_v1` as a fixed coach config and a separate Web Worker wrapper for structured suggestions.
- Territory mode has native iOS bridge paths for `katago_territory_9x9.onnx`, `katago_territory_13x13.onnx`, and `katago_territory_19x19.onnx`, but `scripts/init-dev.sh` defaults all three URLs to the same shared Kaya/KataGo ONNX model.

Local inspection of `assets/models/katago_capture_standard.onnx` shows dynamic model axes:

- `bin_input`: `[batch_size, 22, height, width]`
- `global_input`: `[batch_size, 19]`
- `policy`: `[batch_size, 6, height*width + 1]`
- spatial outputs such as `ownership`, `scoring`, `futurepos`, and `seki` also preserve dynamic `height` and `width`.

Local ONNX Runtime smoke checks succeeded for 9x9, 13x13, and 19x19 boards against the same model file. This supports treating board size as request data, not as separate model identity.

External source checks also support this direction:

- Kaya describes its ONNX models as converted KataGo checkpoints with dynamic batch and board height/width axes, and documents policy, value, ownership, scoring, future-position, seki, and score-belief outputs.
- KataGo training pages identify `b18c384nbt` as an 18 nested-block net with improved output heads.
- KataGo upstream recommends recent `b18c384nbt` nets as a good b18-sized default for many machines.

### Problem

The current naming and runtime split makes the product architecture harder to reason about:

- `katago_capture_standard.onnx`, `katago_capture_weak.onnx`, and `katago_territory_*.onnx` imply multiple model assets even when they can be the same neural net.
- The coach worker, capture player adapter, and territory bridge parse the same model family through separate pathways.
- Player selection is not mode-specific enough: capture-five can have many players, while territory should only expose KataGo-backed territory play.
- Specs currently say the coach is tied to capture mode, while product direction is to make coach availability depend on whether the current model is valid for the selected game mode.

### Motivation

The goal is to make the model layer truthful and reusable:

- One model file should represent one neural network architecture/weight set.
- Different product roles should share the same model loader and evaluator wrapper.
- Strength tiers and coach views should be strategies over one evaluation result, not separate model wrappers.
- Game-mode-specific player lists should prevent users from selecting invalid engines.

## Goals

- Replace duplicate board-size and strength-specific model filenames with one architecture-based model asset.
- Use a clearer model filename based on architecture and runtime format, not vague labels like `small` or source labels like `kaya`.
- Consolidate KataGo ONNX loading, feature encoding, inference, and output parsing behind one wrapper contract.
- Let capture-five and territory modes expose different AI player lists.
- Keep current user-facing behavior honest while preserving a path to later capture-five-specific coach models.

## Implementation Plan

1. Define the canonical model asset identity.
   - Rename the shared model asset to `katago-kata1-b18c384nbt-batched-fp16.onnx`.
   - Keep source/download metadata in code or docs: source URL, SHA-256, precision, and architecture.
   - Stop creating `katago_territory_9x9.onnx`, `katago_territory_13x13.onnx`, and `katago_territory_19x19.onnx` when they are aliases of the same model.
   - Stop using separate weak/standard model filenames when strength differs only by selection strategy.

2. Add a shared KataGo ONNX evaluation contract.
   - Create one model request/evaluation abstraction for board size, board state, current player, policy plane, candidate limit, and runtime budget.
   - Return structured outputs once: policy candidates, value, score belief, ownership, scoring, future position, and seki.
   - Use the same contract for Web Worker and Flutter/native adapters.

3. Refactor product strategies to sit above the wrapper.
   - Implement `katago-1` and `katago-2` as strategy presets over the shared evaluation output.
   - Implement coach suggestions as a strategy over the same evaluation output.
   - Implement territory move selection as a strategy over the same evaluation output, with Dart territory heuristic fallback only where product requirements allow fallback.

4. Make AI player lists mode-aware.
   - Capture-five mode shows all capture-capable players.
   - Territory mode shows only KataGo territory-capable players.
   - Persist selected AI config per game mode or migrate invalid selections when switching modes.
   - Update setup UI text so the user sees why the list changes.

5. Align coach availability with model validity.
   - Territory mode can expose coach while the current shared KataGo model is considered territory-valid.
   - Capture-five mode keeps the coach disabled with the existing explanation until a capture-five-trained or capture-five-validated coach model exists.
   - Specs must state the availability rule and the reason.

6. Update build and bootstrap paths.
   - Update `scripts/init-dev.sh` to download the canonical single model file once.
   - Update Flutter assets, Web worker model URLs, iOS bridge lookup, and tests.
   - Keep compatibility migration for old local filenames if needed for developer machines, but avoid committing duplicate model files.

7. Validate model and runtime behavior.
   - Add a small model-shape smoke test or tool check proving the canonical file accepts 9x9, 13x13, and 19x19 input shapes.
   - Add unit/widget tests for mode-specific AI player visibility.
   - Add tests that `katago-1`, `katago-2`, and coach requests resolve to the same canonical model asset but different strategy parameters.

## Acceptance Criteria

- The repo references one canonical shared KataGo ONNX model asset for the current Kaya/KataGo b18 model.
- No code path requires separate `katago_territory_9x9.onnx`, `katago_territory_13x13.onnx`, or `katago_territory_19x19.onnx` files when the shared model supports dynamic board sizes.
- `katago-1`, `katago-2`, coach, and territory move selection share one evaluation wrapper contract.
- Capture-five mode and territory mode show different valid AI player lists.
- Capture-five mode keeps training coach disabled with a clear reason until a capture-five-valid coach model is introduced.
- Territory mode can use the shared KataGo model path without a Web-only hard block.
- Specs map entries are updated before or alongside tests; tests are based on the specs definition, not reverse-engineered from implementation.

## Validation Commands

- `python3 tool/katago_onnx_move.py '<9x9 smoke request>'`
- `python3 tool/katago_onnx_move.py '<13x13 smoke request>'`
- `python3 tool/katago_onnx_move.py '<19x19 smoke request>'`
- `bash scripts/compile-web-worker.sh`
- `flutter test test/katago_onnx_features_test.dart`
- `flutter test test/ai_algorithm_framework_test.dart`
- `flutter test test/capture_game_provider_test.dart --name "training mode"`
- `flutter analyze --no-fatal-infos --no-fatal-warnings`

## Research Notes

- Preferred filename: `katago-kata1-b18c384nbt-batched-fp16.onnx`.
- `kata1` identifies the KataGo training run family.
- `b18c384nbt` identifies the neural net architecture family: 18 blocks, 384 channels, NBT architecture variant.
- `batched` identifies the runtime export shape as batch-capable.
- `fp16` identifies the numeric precision/runtime format.
- The model source/provider can be recorded in metadata or docs, but does not need to be part of the filename.

## References

- Kaya Hugging Face model card: https://huggingface.co/kaya-go/kaya
- KataGo training site: https://katagotraining.org/
- KataGo kata1 network list: https://katagotraining.org/networks/
- KataGo upstream repository: https://github.com/lightvector/KataGo
