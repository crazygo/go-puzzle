# Board Image Recognition Rearchitecture Plan

## Background

### Context
- The current recognizer is implemented in a single file (`lib/game/board_image_recognizer.dart`) with tightly-coupled stages: image scaling, grid candidate search, board-size guess, and stone classification.
- Existing tests (`test/board_image_recognizer_test.dart`) validate only two synthetic images (9x9 and 13x13), and they allow loose spatial tolerance (search radius = 3) and board-size mismatch (`anyOf(9, 13, 19)`).
- Runtime behavior in UI (`lib/screens/capture_game_screen.dart`) already exposes confidence and import preview, which means recognition quality directly affects user trust and setup efficiency.

### Problem
- The current pipeline is brittle for real screenshots/photos with perspective distortion, partial crop, uneven lighting, glare, shadows, and line occlusion by stones.
- Test coverage is optimistic (clean synthetic render), so regressions on real-world captures are hard to detect before release.
- The algorithm structure does not explicitly separate:
  1) board localization,
  2) geometric normalization,
  3) intersection-level evidence extraction,
  4) stone/empty decision with calibrated confidence,
  5) quality diagnostics and fallback behavior.

### Motivation
- A modular recognition architecture enables incremental improvement of each stage without destabilizing the entire system.
- Better validation will provide measurable quality targets (accuracy, calibration, robustness) and prevent accidental regressions.
- Confidence and diagnostics can drive better UX (e.g., auto-accept high confidence, require manual correction for low confidence).

## Goals
- Define a pluggable recognition framework with clear data contracts between stages.
- Keep algorithm implementation details out of this phase; focus on architecture and validation design.
- Build a validation matrix that includes synthetic, transformed synthetic, and real-capture datasets.
- Introduce objective metrics and pass/fail thresholds for CI and local development.

## Implementation Plan

### Phase 1: Pipeline decomposition and interfaces
1. Introduce a staged pipeline abstraction:
   - `BoardDetector` (find board quadrilateral + board size hypotheses)
   - `BoardRectifier` (warp to canonical top-down board space)
   - `GridEstimator` (estimate intersection lattice and alignment score)
   - `StoneClassifier` (predict black/white/empty with per-point confidence)
   - `ResultCalibrator` (aggregate confidences, produce diagnostics)
2. Define immutable DTOs for stage outputs (e.g., `DetectionResult`, `RectifiedBoard`, `GridModel`, `StoneMap`, `RecognitionDiagnostics`).
3. Keep current `BoardImageRecognizer.recognize` as façade orchestrator, delegating to injected stage implementations.

### Phase 2: Strategy slots (algorithm families)
1. For each stage, define at least one baseline strategy and one extension slot:
   - Baseline strategy keeps behavior similar to current implementation.
   - Extension strategy can be swapped in later (e.g., perspective-aware detection, adaptive thresholding, model-assisted classification).
2. Add strategy-selection policy:
   - Fast path for clean screenshots.
   - Robust path for low-quality captures.
3. Add diagnostics schema including:
   - board-size posterior distribution,
   - geometric consistency score,
   - per-intersection uncertainty map,
   - anomaly flags (blur, glare, crop, low contrast).

### Phase 3: Test architecture redesign (no algorithm details)
1. Split tests into layers:
   - Unit tests per stage with deterministic fixtures.
   - Pipeline integration tests with expected board output.
   - Regression tests on fixed dataset snapshots.
2. Strengthen current assertions:
   - Board size must match expected size for synthetic fixtures (remove permissive `anyOf`).
   - Exact coordinate checks in canonical board space where feasible; keep neighborhood tolerance only for transformed/noisy cases.
3. Introduce fixture families:
   - Clean synthetic (current style).
   - Synthetic with controlled transforms: rotation, perspective warp, blur, noise, brightness shift, occlusion.
   - Real captures (anonymized, curated) with hand-labeled ground truth.

### Phase 4: Validation tooling and quality gates
1. Add evaluation command/tooling to output:
   - intersection classification accuracy,
   - per-class precision/recall/F1,
   - board-size accuracy,
   - confidence calibration error (e.g., ECE bins),
   - top-k ambiguous points for manual review.
2. Define quality gates:
   - CI hard gate on synthetic + transformed synthetic.
   - Nightly/optional gate on larger real-capture benchmark.
3. Add drift checks:
   - Compare candidate branch metrics against baseline branch and fail on significant degradation.

### Phase 5: UX-oriented verification linkage
1. Connect diagnostics to preview UI states:
   - “Auto accept” threshold,
   - “Needs manual review” threshold,
   - highlighted uncertain intersections.
2. Add scenario tests for import flow to verify low-confidence behavior and correction ergonomics.

## Acceptance Criteria
- Architecture
  - `BoardImageRecognizer` is orchestrator-only; each stage has independent interface and test surface.
  - Stage outputs include machine-readable diagnostics used by both tests and UI.
- Validation
  - Test suite includes at least three fixture categories: clean synthetic, transformed synthetic, real captures.
  - Board-size accuracy and per-intersection classification metrics are reported in a reproducible format.
  - CI enforces predefined thresholds for core metrics.
- Developer workflow
  - Validation can be run from repo root with explicit commands:
    - `flutter pub get`
    - `flutter analyze --no-fatal-infos --no-fatal-warnings`
    - `flutter test`
    - `flutter test test/board_image_recognizer_test.dart`
  - Benchmark/evaluation command is documented and produces version-comparable output.
