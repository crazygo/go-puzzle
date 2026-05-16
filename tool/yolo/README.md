# YOLO Recognition Experiment

This directory contains offline YOLO experiment assets only. It is not part of
the Flutter runtime path.

## Source Data

The canonical human labels live in:

```text
test/assets/recognition_samples/
```

Each sample should have:

```text
<sample>.PNG or <sample>.png
<sample>.txt
<sample>.json
```

The `.txt` file is the existing board-state truth. The `.json` file stores
image dimensions and board corner geometry so training labels can be generated
without re-labeling stones.

## Splits

The fixed split files are:

```text
tool/yolo/splits/train.txt
tool/yolo/splits/val.txt
```

Current split:

```text
train: 31 samples
val:    8 samples
```

The training split includes the only current 19-line sample so the board-pose
model sees that class during training. The validation split keeps 13-line
samples, clean 9-line samples, and current rule-based failure modes such as
board-size confusion, all-white predictions, all-empty predictions, and severe
stone recall failures.

## Generated Outputs

Generated datasets, virtual environments, model weights, and run outputs should
stay under `.cache/yolo/`, which is ignored by git.

Planned layout:

```text
.cache/yolo/
  venv/
  dataset/
    images/train/
    images/val/
    labels/train/
    labels/val/
    data.yaml
  board_pose_dataset/
    images/train/
    images/val/
    labels/train/
    labels/val/
    data.yaml
  runs/
```

## Planned Commands

```bash
python3 -m venv .cache/yolo/venv
source .cache/yolo/venv/bin/activate
pip install -r tool/yolo/requirements.txt

python tool/yolo/convert_recognition_samples.py \
  --samples test/assets/recognition_samples \
  --splits tool/yolo/splits \
  --out .cache/yolo/dataset

yolo detect train \
  model=yolov8n.pt \
  data=.cache/yolo/dataset/data.yaml \
  epochs=10 \
  imgsz=640 \
  batch=2 \
  project=.cache/yolo/runs \
  name=go_stones_smoke
```

Board-corner pose experiment:

```bash
python tool/yolo/convert_board_pose_samples.py \
  --samples test/assets/recognition_samples \
  --splits tool/yolo/splits \
  --out .cache/yolo/board_pose_dataset

yolo pose train \
  model=yolov8n-pose.pt \
  data=.cache/yolo/board_pose_dataset/data.yaml \
  epochs=10 \
  imgsz=640 \
  batch=2 \
  project=.cache/yolo/runs \
  name=go_board_pose_smoke
```

Evaluate board-corner predictions:

```bash
python tool/yolo/evaluate_board_pose.py \
  --model .cache/yolo/runs/go_board_pose_smoke/weights/best.pt \
  --split tool/yolo/splits/val.txt
```

Evaluate stone detections as board-state recognition using human-labeled JSON
geometry:

```bash
python tool/yolo/evaluate_stone_detector.py \
  --model .cache/yolo/runs/go_stones_smoke/weights/best.pt \
  --split tool/yolo/splits/val.txt
```

Resume an interrupted run:

```bash
yolo detect train \
  model=.cache/yolo/runs/go_stones_smoke/weights/last.pt \
  resume=True
```

The wrapper script exposes the same actions without remembering long commands:

```bash
python3 tool/yolo/run_experiment.py
python3 tool/yolo/run_experiment.py board-pose-main
python3 tool/yolo/run_experiment.py resume-board-pose-main
python3 tool/yolo/run_experiment.py board-pose-tuned
python3 tool/yolo/run_experiment.py resume-board-pose-tuned
python3 tool/yolo/run_experiment.py board-pose-rebalanced
python3 tool/yolo/run_experiment.py eval-full
python3 tool/yolo/run_experiment.py eval-full-val
```

`eval-full` prefers rebalanced board-pose weights, then tuned/main/smoke
weights. It prefers the main stone detector, then smoke weights. It prints the
selected model paths before running the evaluator. `eval-full` runs the whole
`test/assets/recognition_samples/` set; `eval-full-val` runs only the fixed
validation split.

Recognize one screenshot and print the current board text format:

```bash
.cache/yolo/venv/bin/python tool/yolo/recognize_screenshot.py \
  test/assets/recognition_samples/IMG_4778.PNG
```

Use `--json` when a caller also needs board-corner coordinates.
