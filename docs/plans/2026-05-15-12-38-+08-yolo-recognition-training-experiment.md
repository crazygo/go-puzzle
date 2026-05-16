# Model-Based Board Recognition Vision

## Background

### Context

The app currently uses a Dart rule-based screenshot recognizer for board size
and stone detection. The real sample set under `test/assets/recognition_samples/`
contains 39 samples with `.txt` board-state labels and `.json` board geometry
sidecars. The current rule-based baseline on this set is:

- Points accuracy: 63.1%
- Stone precision: 34.6%
- Stone recall: 50.5%
- Exact samples: 16/39

### Problem

The current recognizer has several severe failure modes: 9-line boards are
often detected as 19-line boards, some samples are predicted as all white
stones, and some board-size-correct samples miss large groups of stones. The
target is not merely to run YOLO or inspect mAP; the target is a model-based
recognition system that can turn a user screenshot into the existing board text
format with measurable business accuracy.

### Motivation

Keeping the work offline lets us train, tune, and evaluate model-based
recognition without changing the app, without committing model weights, and
without taking on iOS/Web runtime complexity prematurely. A fixed
train/validation split also makes future iterations comparable as samples,
model settings, and post-processing evolve.

## Goals

- Build a reproducible offline recognition workspace under `tool/yolo/`.
- Keep `test/assets/recognition_samples/` as the single human-labeled source of
  truth.
- Train and tune model artifacts until screenshot-to-board-text recognition is
  materially better than the current Dart rule-based baseline.
- Provide a single evaluation path that reports business metrics, not just model
  metrics.
- Preserve future optionality for iOS/Web migration by keeping runtime concerns
  out of this training phase.

The desired end-to-end behavior is:

```text
Input: user screenshot
Output:
  Size 9
  B,D8
  W,C7
  ...
```

## Implementation Plan

1. Maintain fixed train and validation splits inside `tool/yolo/splits/` so all
   model iterations are comparable.
2. Generate training datasets from existing `.txt` and `.json` annotations,
   without asking for duplicate manual labeling.
3. Support model training, interrupted-run recovery, and result inspection from
   `tool/yolo/run_experiment.py`.
4. Convert model predictions into the same board text representation already
   used by the app and tests.
5. Add a full pipeline evaluator that reports rules baseline, model recognition
   metrics, deltas, and failed samples in one command.
6. Tune model choices, image sizes, epochs, confidence thresholds, mapping
   thresholds, and post-processing until validation metrics meet the target.
7. Treat model runtime migration as out of scope until the offline recognition
   metrics are strong enough to justify that work.

## Acceptance Criteria

- `tool/yolo/splits/train.txt` and `tool/yolo/splits/val.txt` exist and cover
  every current recognition sample exactly once.
- The validation split contains representative hard cases, not only easy
  samples.
- JSON geometry validation passes for all current recognition samples.
- Generated training datasets can be produced under `.cache/yolo/` without
  manually editing labels.
- Training runs can start from the menu script and produce `last.pt` and
  `best.pt` under `.cache/yolo/runs/`.
- Interrupted runs can be resumed from `last.pt`.
- A single evaluation command reports:
  - points accuracy
  - stones precision
  - stones recall
  - exact samples
  - failed samples
  - comparison against the Dart rule-based baseline
- The model-based full pipeline meets or exceeds:
  - points accuracy >= 95%
  - stones precision >= 95%
  - stones recall >= 90%
  - exact samples >= 85%
  - board size accuracy >= 95%

## Validation Commands

- `dart run tool/validate_recognition_geometry.dart`
- `dart run tool/recognition_accuracy_report.dart`
- `python tool/yolo/convert_recognition_samples.py --samples test/assets/recognition_samples --splits tool/yolo/splits --out .cache/yolo/dataset`
- `python tool/yolo/convert_board_pose_samples.py --samples test/assets/recognition_samples --splits tool/yolo/splits --out .cache/yolo/board_pose_dataset`
- `python tool/yolo/run_experiment.py check`
- `python tool/yolo/run_experiment.py smoke`
- `python tool/yolo/run_experiment.py board-pose-smoke`
- `python tool/yolo/evaluate_stone_detector.py --model .cache/yolo/runs/go_stones_smoke/weights/best.pt --split tool/yolo/splits/val.txt`
- `python tool/yolo/evaluate_board_pose.py --model .cache/yolo/runs/go_board_pose_smoke/weights/best.pt --split tool/yolo/splits/val.txt`
