#!/usr/bin/env python3
"""Interactive runner for the offline YOLO recognition experiment."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VENV_BIN = ROOT / ".cache" / "yolo" / "venv" / "bin"
YOLO = VENV_BIN / "yolo"
PYTHON = VENV_BIN / "python"
DATASET = ROOT / ".cache" / "yolo" / "dataset"
BOARD_POSE_DATASET = ROOT / ".cache" / "yolo" / "board_pose_dataset"
RUNS = ROOT / ".cache" / "yolo" / "runs"
SAMPLES = ROOT / "test" / "assets" / "recognition_samples"
SPLITS = ROOT / "tool" / "yolo" / "splits"
CONVERTER = ROOT / "tool" / "yolo" / "convert_recognition_samples.py"
BOARD_POSE_CONVERTER = ROOT / "tool" / "yolo" / "convert_board_pose_samples.py"
REQUIREMENTS = ROOT / "tool" / "yolo" / "requirements.txt"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "action",
        nargs="?",
        choices=[
            "menu",
            "check",
            "install",
            "convert",
            "convert-board-pose",
            "smoke",
            "resume-smoke",
            "board-pose-smoke",
            "resume-board-pose-smoke",
            "main",
            "resume-main",
            "board-pose-main",
            "resume-board-pose-main",
            "board-pose-tuned",
            "resume-board-pose-tuned",
            "board-pose-rebalanced",
            "resume-board-pose-rebalanced",
            "eval-stones",
            "eval-board-pose",
            "eval-full",
            "eval-full-val",
            "results",
        ],
        default="menu",
    )
    args = parser.parse_args()
    return run_action(args.action)


def run_action(action: str) -> int:
    if action == "menu":
        return menu()
    if action == "check":
        return check()
    if action == "install":
        return install()
    if action == "convert":
        return convert()
    if action == "convert-board-pose":
        return convert_board_pose()
    if action == "smoke":
        return smoke()
    if action == "resume-smoke":
        return resume("detect", "go_stones_smoke")
    if action == "board-pose-smoke":
        return board_pose_smoke()
    if action == "resume-board-pose-smoke":
        return resume("pose", "go_board_pose_smoke")
    if action == "main":
        return main_train()
    if action == "resume-main":
        return resume("detect", "go_stones_yolov8n_640_b2")
    if action == "board-pose-main":
        return board_pose_main_train()
    if action == "resume-board-pose-main":
        return resume("pose", "go_board_pose_yolov8n_640_b2")
    if action == "board-pose-tuned":
        return board_pose_tuned_train()
    if action == "resume-board-pose-tuned":
        return resume("pose", "go_board_pose_yolov8n_640_b2_tuned")
    if action == "board-pose-rebalanced":
        return board_pose_rebalanced_train()
    if action == "resume-board-pose-rebalanced":
        return resume("pose", "go_board_pose_yolov8n_640_b2_rebalanced")
    if action == "eval-stones":
        return eval_stones()
    if action == "eval-board-pose":
        return eval_board_pose()
    if action == "eval-full":
        return eval_full(split=None)
    if action == "eval-full-val":
        return eval_full(split=SPLITS / "val.txt")
    if action == "results":
        return results()
    raise AssertionError(action)


def menu() -> int:
    options = [
        ("check", "检查环境和数据集"),
        ("install", "安装/更新 Python 依赖"),
        ("convert", "重新生成棋子 detect 数据集"),
        ("convert-board-pose", "重新生成棋盘四角 pose 数据集"),
        ("smoke", "启动棋子 detect 冒烟训练：epochs=10 imgsz=640 batch=2"),
        ("resume-smoke", "从 last.pt 恢复冒烟训练"),
        ("board-pose-smoke", "启动棋盘四角 pose 冒烟训练：epochs=10 imgsz=640 batch=2"),
        ("resume-board-pose-smoke", "从 last.pt 恢复棋盘四角训练"),
        ("main", "启动棋子 detect 主训练：epochs=100 imgsz=640 batch=2"),
        ("resume-main", "从 last.pt 恢复棋子 detect 主训练"),
        ("board-pose-main", "启动棋盘四角 pose 主训练：epochs=150 imgsz=640 batch=2"),
        ("resume-board-pose-main", "从 last.pt 恢复棋盘四角 pose 主训练"),
        ("board-pose-tuned", "启动棋盘四角 pose 调参训练：关闭 mosaic/flip/erasing"),
        ("resume-board-pose-tuned", "从 last.pt 恢复棋盘四角 pose 调参训练"),
        ("board-pose-rebalanced", "启动棋盘四角 pose 重排 split 训练"),
        ("resume-board-pose-rebalanced", "从 last.pt 恢复重排 split 训练"),
        ("eval-stones", "评估棋子 detect -> 棋盘状态"),
        ("eval-board-pose", "评估棋盘四角 pose"),
        ("eval-full", "评估完整模型流程 -> 全量棋盘文本指标"),
        ("eval-full-val", "评估完整模型流程 -> val split"),
        ("results", "列出已有训练结果"),
        ("quit", "退出"),
    ]
    print("YOLO recognition experiment")
    print("")
    for index, (_, label) in enumerate(options, start=1):
        print(f"{index}. {label}")
    print("")
    choice = input("选择一个选项编号: ").strip()
    if not choice.isdigit():
        print("请输入编号。")
        return 2
    index = int(choice) - 1
    if index < 0 or index >= len(options):
        print("编号超出范围。")
        return 2
    action = options[index][0]
    if action == "quit":
        return 0
    return run_action(action)


def check() -> int:
    print(f"repo: {ROOT}")
    print(f"venv python: {PYTHON} {'ok' if PYTHON.exists() else 'missing'}")
    print(f"yolo command: {YOLO} {'ok' if YOLO.exists() else 'missing'}")
    print(f"samples: {count_files(SAMPLES, '*.txt')} txt files")
    print(f"json: {count_files(SAMPLES, '*.json')} json files")
    print(f"train split: {count_lines(SPLITS / 'train.txt')} samples")
    print(f"val split: {count_lines(SPLITS / 'val.txt')} samples")
    print(f"dataset yaml: {DATASET / 'data.yaml'} {'ok' if (DATASET / 'data.yaml').exists() else 'missing'}")
    print(
        f"board pose yaml: {BOARD_POSE_DATASET / 'data.yaml'} "
        f"{'ok' if (BOARD_POSE_DATASET / 'data.yaml').exists() else 'missing'}"
    )
    return 0


def install() -> int:
    if not PYTHON.exists():
        print("Missing venv. Create it first:")
        print("  python3 -m venv .cache/yolo/venv")
        return 2
    return run([str(PYTHON), "-m", "pip", "install", "-r", str(REQUIREMENTS)])


def convert() -> int:
    return run([
        sys.executable,
        str(CONVERTER),
        "--samples",
        str(SAMPLES),
        "--splits",
        str(SPLITS),
        "--out",
        str(DATASET),
    ])


def convert_board_pose() -> int:
    return run([
        sys.executable,
        str(BOARD_POSE_CONVERTER),
        "--samples",
        str(SAMPLES),
        "--splits",
        str(SPLITS),
        "--out",
        str(BOARD_POSE_DATASET),
    ])


def smoke() -> int:
    if ensure_ready() != 0:
        return 2
    return run([
        str(YOLO),
        "detect",
        "train",
        "model=yolov8n.pt",
        f"data={DATASET / 'data.yaml'}",
        "epochs=10",
        "imgsz=640",
        "batch=2",
        f"project={RUNS}",
        "name=go_stones_smoke",
    ])


def board_pose_smoke() -> int:
    if ensure_ready(dataset=BOARD_POSE_DATASET, converter=convert_board_pose) != 0:
        return 2
    return run([
        str(YOLO),
        "pose",
        "train",
        "model=yolov8n-pose.pt",
        f"data={BOARD_POSE_DATASET / 'data.yaml'}",
        "epochs=10",
        "imgsz=640",
        "batch=2",
        f"project={RUNS}",
        "name=go_board_pose_smoke",
    ])


def main_train() -> int:
    if ensure_ready() != 0:
        return 2
    return run([
        str(YOLO),
        "detect",
        "train",
        "model=yolov8n.pt",
        f"data={DATASET / 'data.yaml'}",
        "epochs=100",
        "patience=30",
        "imgsz=640",
        "batch=2",
        f"project={RUNS}",
        "name=go_stones_yolov8n_640_b2",
    ])


def board_pose_main_train() -> int:
    if ensure_ready(dataset=BOARD_POSE_DATASET, converter=convert_board_pose) != 0:
        return 2
    return run([
        str(YOLO),
        "pose",
        "train",
        "model=yolov8n-pose.pt",
        f"data={BOARD_POSE_DATASET / 'data.yaml'}",
        "epochs=150",
        "patience=50",
        "imgsz=640",
        "batch=2",
        f"project={RUNS}",
        "name=go_board_pose_yolov8n_640_b2",
    ])


def board_pose_tuned_train() -> int:
    if ensure_ready(dataset=BOARD_POSE_DATASET, converter=convert_board_pose) != 0:
        return 2
    return run([
        str(YOLO),
        "pose",
        "train",
        "model=yolov8n-pose.pt",
        f"data={BOARD_POSE_DATASET / 'data.yaml'}",
        "epochs=140",
        "patience=40",
        "imgsz=640",
        "batch=2",
        "mosaic=0",
        "fliplr=0",
        "erasing=0",
        "translate=0.03",
        "scale=0.15",
        "hsv_s=0.25",
        "hsv_v=0.20",
        f"project={RUNS}",
        "name=go_board_pose_yolov8n_640_b2_tuned",
    ])


def board_pose_rebalanced_train() -> int:
    if ensure_ready(dataset=BOARD_POSE_DATASET, converter=convert_board_pose) != 0:
        return 2
    return run([
        str(YOLO),
        "pose",
        "train",
        "model=yolov8n-pose.pt",
        f"data={BOARD_POSE_DATASET / 'data.yaml'}",
        "epochs=140",
        "patience=40",
        "imgsz=640",
        "batch=2",
        "mosaic=0",
        "fliplr=0",
        "erasing=0",
        "translate=0.03",
        "scale=0.15",
        "hsv_s=0.25",
        "hsv_v=0.20",
        f"project={RUNS}",
        "name=go_board_pose_yolov8n_640_b2_rebalanced",
    ])


def resume(task: str, run_name: str) -> int:
    last = RUNS / run_name / "weights" / "last.pt"
    if not last.exists():
        print(f"Missing checkpoint: {last}")
        return 2
    if not YOLO.exists():
        print(f"Missing yolo command: {YOLO}")
        return 2
    return run([
        str(YOLO),
        task,
        "train",
        f"model={last}",
        "resume=True",
    ])


def eval_stones() -> int:
    model = first_existing_model([
        RUNS / "go_stones_yolov8n_640_b2" / "weights" / "best.pt",
        RUNS / "go_stones_smoke" / "weights" / "best.pt",
    ])
    if not model.exists():
        print(f"Missing model: {model}")
        return 2
    print(f"Using stone model: {model.relative_to(ROOT)}")
    return run([
        str(PYTHON),
        str(ROOT / "tool" / "yolo" / "evaluate_stone_detector.py"),
        "--model",
        str(model),
        "--split",
        str(SPLITS / "val.txt"),
    ])


def eval_board_pose() -> int:
    model = first_existing_model([
        RUNS / "go_board_pose_yolov8n_640_b2_rebalanced" / "weights" / "best.pt",
        RUNS / "go_board_pose_yolov8n_640_b2_tuned" / "weights" / "best.pt",
        RUNS / "go_board_pose_yolov8n_640_b2" / "weights" / "best.pt",
        RUNS / "go_board_pose_smoke" / "weights" / "best.pt",
    ])
    if not model.exists():
        print(f"Missing model: {model}")
        return 2
    print(f"Using board pose model: {model.relative_to(ROOT)}")
    return run([
        str(PYTHON),
        str(ROOT / "tool" / "yolo" / "evaluate_board_pose.py"),
        "--model",
        str(model),
        "--split",
        str(SPLITS / "val.txt"),
    ])


def eval_full(split: Path | None) -> int:
    board_model = first_existing_model([
        RUNS / "go_board_pose_yolov8n_640_b2_rebalanced" / "weights" / "best.pt",
        RUNS / "go_board_pose_yolov8n_640_b2_tuned" / "weights" / "best.pt",
        RUNS / "go_board_pose_yolov8n_640_b2" / "weights" / "best.pt",
        RUNS / "go_board_pose_smoke" / "weights" / "best.pt",
    ])
    stone_model = first_existing_model([
        RUNS / "go_stones_yolov8n_640_b2" / "weights" / "best.pt",
        RUNS / "go_stones_smoke" / "weights" / "best.pt",
    ])
    missing = [path for path in [board_model, stone_model] if not path.exists()]
    if missing:
        print("Missing model(s):")
        for path in missing:
            print(f"  {path}")
        return 2
    print(f"Using board pose model: {board_model.relative_to(ROOT)}")
    print(f"Using stone model: {stone_model.relative_to(ROOT)}")
    command = [
        str(PYTHON),
        str(ROOT / "tool" / "yolo" / "evaluate_full_pipeline.py"),
        "--board-model",
        str(board_model),
        "--stone-model",
        str(stone_model),
        "--include-rules-baseline",
    ]
    if split is not None:
        command.extend(["--split", str(split)])
    return run(command)


def first_existing_model(candidates: list[Path]) -> Path:
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


def results() -> int:
    if not RUNS.exists():
        print("No runs directory yet.")
        return 0
    for run_dir in sorted(path for path in RUNS.iterdir() if path.is_dir()):
        weights = run_dir / "weights"
        best = weights / "best.pt"
        last = weights / "last.pt"
        print(run_dir.relative_to(ROOT))
        print(f"  best.pt: {'yes' if best.exists() else 'no'}")
        print(f"  last.pt: {'yes' if last.exists() else 'no'}")
        results_csv = run_dir / "results.csv"
        if results_csv.exists():
            print(f"  results.csv: {results_csv.relative_to(ROOT)}")
    return 0


def ensure_ready(dataset: Path = DATASET, converter=convert) -> int:
    if not YOLO.exists():
        print(f"Missing yolo command: {YOLO}")
        print("Run option 2 first, or install manually:")
        print("  .cache/yolo/venv/bin/pip install -r tool/yolo/requirements.txt")
        return 2
    if not (dataset / "data.yaml").exists():
        print("Missing generated dataset. Running conversion first.")
        code = converter()
        if code != 0:
            return code
    return 0


def run(command: list[str]) -> int:
    print("")
    print("$ " + " ".join(command))
    print("")
    return subprocess.call(command, cwd=ROOT)


def count_files(directory: Path, pattern: str) -> int:
    return len(list(directory.glob(pattern))) if directory.exists() else 0


def count_lines(path: Path) -> int:
    if not path.exists():
        return 0
    return len([line for line in path.read_text().splitlines() if line.strip()])


if __name__ == "__main__":
    raise SystemExit(main())
