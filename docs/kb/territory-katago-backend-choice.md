# Territory AI backend choice

This change evaluates the mobile KataGo integration paths and selects **native iOS ONNX inference with Dart fallback** as the implementation direction for territory mode.

## Compared options

1. **Flutter ONNX plugin**
   - Pros: least native code, faster initial integration.
   - Cons: common plugins either raise the iOS floor to 14/16 or require static-linkage Podfile changes that are riskier for this repo.

2. **Native iOS ONNX bridge** ✅
   - Pros: keeps the app-side search orchestration in Flutter, preserves control over iOS 13 support, allows CoreML execution-provider use when available, and matches the existing “small ONNX model” direction.
   - Cons: more Swift code to maintain, plus a custom feature-encoding contract between Dart and iOS.

3. **Upstream KataGo native engine**
   - Pros: closest to stock KataGo.
   - Cons: KataGo upstream ships `.bin.gz` models and desktop/server backends, not an iOS-ready Flutter embedding path; integrating the full C++ engine on iPhone is far heavier than this app needs.

## Why this repo chooses native iOS ONNX

- The repository is already Flutter-first and currently has no native AI bridge.
- Territory mode only needs a strong move prior / evaluator on phone, not the full upstream KataGo executable stack.
- A native ONNX bridge lets the app prefer iOS-native inference when the packaged small model exists, while keeping a pure-Dart fallback for unsupported targets and for local validation.

## Current runtime behavior

- **iOS + packaged board-size model**
  - `assets/models/katago_territory_9x9.onnx`
  - `assets/models/katago_territory_13x13.onnx`
  - `assets/models/katago_territory_19x19.onnx`
  - the app will attempt native ONNX inference first for the matching board size.
- **No packaged matching model / non-iOS / native error**: the app safely falls back to the Dart territory search engine.
