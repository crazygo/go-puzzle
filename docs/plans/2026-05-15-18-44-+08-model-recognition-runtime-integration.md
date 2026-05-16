# Model Recognition Runtime Integration

## Background

### Context

The project currently has a rule-based screenshot recognizer in Flutter/Dart and a validated YOLO-based experiment pipeline under `tool/yolo/`. The model experiment keeps the current rule recognizer intact and evaluates the model pipeline with `python3 tool/yolo/run_experiment.py eval-full`.

The product has two runtime targets for screenshot import: iOS and Web. There is no server-side inference layer. iOS should load packaged model files from the app bundle. Web should load model binaries from same-origin static files prepared during the dev/build bootstrap. The GitHub Release remains the source of the binaries, but browsers should not fetch Release asset URLs directly because those responses do not reliably expose CORS headers.

### Problem

The validated model pipeline is not yet connected to the production screenshot import flow. The app also needs a user-visible model loading state because Web model loading depends on network speed, while iOS should load quickly from bundled files. A model load failure must not block screenshot import because the rule-based recognizer remains the production default and fallback.

### Motivation

Adding the model recognizer behind a developer-mode setting lets the app validate the model path in real product flows while preserving the existing production behavior. The UI can surface model loading progress and recovery choices without forcing all users onto the experimental recognizer.

## Goals

- Keep the rule-based recognizer as the default production algorithm.
- Add a developer-mode setting that switches screenshot recognition between rule-based and model-based recognition.
- Add a dismissible loading dialog for model loading before image selection when model recognition is selected.
- Let model loading failures recover through either retry or fallback to rule-based recognition.
- Support iOS model loading from bundled ONNX resources.
- Support Web model loading from same-origin static model URLs prepared by the bootstrap script.
- Preserve the existing board text output format used by tests and downstream app logic.
- Keep the full model evaluation command and thresholds as the accuracy gate for model changes.

## Implementation Plan

1. Add a persisted recognition algorithm setting to `SettingsProvider` with two values: rule algorithm and model algorithm. Show the selector only inside developer mode on the settings screen.
2. Introduce a recognition service boundary that keeps the current rule recognizer and adds a model recognizer entry point with platform-specific model loading.
3. Add model loading state handling to the screenshot import flow. When model mode is selected, show a dismissible loading dialog before opening the image picker.
4. Implement failure recovery in the loading dialog with retry and fallback-to-rule actions. Closing the dialog should cancel the current import attempt without changing the saved setting.
5. Add ONNX model resource configuration: iOS loads packaged resources, and Web loads static files copied into `web/recognition_models/` by the model download script.
6. Convert model inference output into the existing `BoardRecognitionResult` structure and board text format so the preview flow remains unchanged.
7. Keep `tool/yolo/run_experiment.py eval-full` as the offline model accuracy gate and add focused Flutter tests for settings persistence and UI behavior.

## Acceptance Criteria

- The app defaults to the rule-based screenshot recognizer on a fresh install.
- Developer mode settings include a selector for `算法識別` and `模型識別`.
- Choosing model recognition changes only the screenshot import recognizer and does not remove or alter the rule recognizer.
- Tapping the screenshot import entry in model mode shows an always-dismissible loading dialog before image selection.
- The loading dialog shows a loading state while model files are being loaded.
- If model loading fails, the dialog offers retry and fallback-to-rule actions.
- Fallback-to-rule continues the existing image selection and recognition flow without requiring the user to reopen the import entry.
- iOS model mode can load ONNX model files from app-packaged resources.
- Web model mode can load ONNX model files from same-origin static URLs in the built Web artifact.
- Model recognition returns the same board size, board matrix, confidence, and text representation shape as the existing flow.
- Offline model accuracy remains above the agreed thresholds: points accuracy >= 95%, stones precision >= 95%, stones recall >= 90%, exact samples >= 85%, and board size accuracy >= 95%.

## Validation Commands

- `flutter pub get`
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
- `python3 tool/yolo/run_experiment.py eval-full`
