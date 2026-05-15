#!/usr/bin/env python3
"""Evaluate model-based screenshot-to-board recognition end to end.

Inputs:
  - board pose model: predicts board size and four board corners
  - stone detector model: predicts black/white stone centers

Output:
  Business metrics in the same spirit as tool/recognition_accuracy_report.dart:
  points accuracy, stone precision, stone recall, exact samples, board size
  accuracy, and failed sample list.
"""

from __future__ import annotations

import argparse
import subprocess
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from board_grid_refiner import refine_board_pose
from PIL import Image
from ultralytics import YOLO


IMAGE_EXTENSIONS = (".png", ".PNG", ".jpg", ".JPG", ".jpeg", ".JPEG")
BOARD_SIZE_BY_CLASS = {0: 9, 1: 13, 2: 19}
STONE_COLOR_BY_CLASS = {0: "B", 1: "W"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--board-model", type=Path, required=True)
    parser.add_argument("--stone-model", type=Path, required=True)
    parser.add_argument("--samples", type=Path, default=Path("test/assets/recognition_samples"))
    parser.add_argument("--split", type=Path, default=None)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--board-conf", type=float, default=0.01)
    parser.add_argument("--stone-conf", type=float, default=0.25)
    parser.add_argument("--stone-iou", type=float, default=0.7)
    parser.add_argument("--max-stone-distance", type=float, default=0.58)
    parser.add_argument("--no-refine-board", action="store_true")
    parser.add_argument("--pixel-stone-color", action="store_true")
    parser.add_argument("--include-rules-baseline", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    sample_ids = load_sample_ids(args.samples, args.split)
    board_model = YOLO(str(args.board_model))
    stone_model = YOLO(str(args.stone_model))

    totals = Totals()
    failed = []

    for sample_id in sample_ids:
        truth = load_txt_truth(args.samples / f"{sample_id}.txt")
        image_path = find_image(args.samples, sample_id)
        board_result = board_model.predict(
            source=str(image_path),
            conf=args.board_conf,
            imgsz=args.imgsz,
            verbose=False,
        )[0]
        pose = extract_pose(board_result)
        if pose is None:
            stats = Stats.for_missing_pose(truth.board_size)
        else:
            if not args.no_refine_board:
                refined = refine_board_pose(
                    image_path,
                    board_size=pose.board_size,
                    corners=pose.corners,
                    box=pose.box,
                    confidence=pose.confidence,
                )
                pose = PosePrediction(
                    board_size=refined.board_size,
                    corners=refined.corners,
                    confidence=pose.confidence,
                    box=pose.box,
                )
            stone_result = stone_model.predict(
                source=str(image_path),
                conf=args.stone_conf,
                iou=args.stone_iou,
                imgsz=args.imgsz,
                verbose=False,
            )[0]
            predicted = stones_to_board(
                stone_result,
                pose,
                image_path=image_path,
                max_distance_ratio=args.max_stone_distance,
                use_pixel_color=args.pixel_stone_color,
            )
            stats = score_board(predicted, truth, pose.board_size)

        totals.add(stats)
        if not stats.exact:
            failed.append(sample_id)

        if args.verbose or not stats.exact:
            print(f"sample: {sample_id}")
            print(
                f"  size expected={truth.board_size} predicted={stats.predicted_board_size}"
            )
            print(
                f"  points {stats.correct_points}/{stats.total_points} "
                f"({pct(stats.correct_points, stats.total_points)})"
            )
            print(
                f"  stones correct={stats.correct_stones} "
                f"expected={stats.expected_stones} predicted={stats.predicted_stones} "
                f"precision={pct(stats.correct_stones, stats.predicted_stones)} "
                f"recall={pct(stats.correct_stones, stats.expected_stones)}"
            )
            if stats.mismatches:
                print("  mismatches:")
                for mismatch in stats.mismatches[:40]:
                    print(f"    {mismatch}")
                if len(stats.mismatches) > 40:
                    print(f"    ... {len(stats.mismatches) - 40} more")
            else:
                print("  mismatches: none")

    if args.include_rules_baseline:
        print("")
        print("rules baseline:")
        run_rules_baseline()

    print("")
    print("model full pipeline:")
    print(
        f"  points {totals.correct_points}/{totals.total_points} "
        f"({pct(totals.correct_points, totals.total_points)})"
    )
    print(
        f"  stones correct={totals.correct_stones} expected={totals.expected_stones} "
        f"predicted={totals.predicted_stones} "
        f"precision={pct(totals.correct_stones, totals.predicted_stones)} "
        f"recall={pct(totals.correct_stones, totals.expected_stones)}"
    )
    print(
        f"  board size accuracy {totals.correct_board_size}/{totals.samples} "
        f"({pct(totals.correct_board_size, totals.samples)})"
    )
    print(f"  exact samples {totals.exact_samples}/{totals.samples}")
    if failed:
        print(f"  failed samples: {', '.join(failed)}")


def load_sample_ids(samples_dir: Path, split: Path | None) -> list[str]:
    if split is not None:
        return [
            line.strip()
            for line in split.read_text().splitlines()
            if line.strip() and not line.strip().startswith("#")
        ]
    return sorted(path.stem for path in samples_dir.glob("*.txt"))


def load_txt_truth(path: Path) -> "BoardTruth":
    lines = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    board_size = int(lines[0].split()[-1])
    board = [["." for _ in range(board_size)] for _ in range(board_size)]
    for line in lines[1:]:
        color, coord = line.split(",", 1)
        row, col = parse_coord(coord, board_size)
        board[row][col] = color
    return BoardTruth(board_size=board_size, board=board)


def find_image(samples_dir: Path, sample_id: str) -> Path:
    for extension in IMAGE_EXTENSIONS:
        path = samples_dir / f"{sample_id}{extension}"
        if path.exists():
            return path
    raise FileNotFoundError(sample_id)


def extract_pose(result) -> "PosePrediction | None":
    if result.keypoints is None or result.boxes is None or len(result.boxes) == 0:
        return None
    best_index = int(result.boxes.conf.argmax().item())
    class_id = int(result.boxes.cls[best_index].item())
    board_size = BOARD_SIZE_BY_CLASS.get(class_id)
    if board_size is None:
        return None
    keypoints = result.keypoints.xy[best_index].tolist()
    if len(keypoints) < 4:
        return None
    corners = [(float(x), float(y)) for x, y in keypoints[:4]]
    box = tuple(float(value) for value in result.boxes.xyxy[best_index].tolist())
    confidence = float(result.boxes.conf[best_index].item())
    return PosePrediction(
        board_size=board_size,
        corners=corners,
        confidence=confidence,
        box=box,
    )


def stones_to_board(
    result,
    pose: "PosePrediction",
    *,
    image_path: Path,
    max_distance_ratio: float,
    use_pixel_color: bool,
) -> list[list[str]]:
    board = [["." for _ in range(pose.board_size)] for _ in range(pose.board_size)]
    confidence = [[-1.0 for _ in range(pose.board_size)] for _ in range(pose.board_size)]
    luma = load_luma(image_path) if use_pixel_color else None

    if result.boxes is None:
        return board

    for box in result.boxes:
        class_id = int(box.cls[0].item())
        color = STONE_COLOR_BY_CLASS.get(class_id)
        if color is None:
            continue
        xyxy = box.xyxy[0].tolist()
        cx = (xyxy[0] + xyxy[2]) / 2
        cy = (xyxy[1] + xyxy[3]) / 2
        if luma is not None:
            color = classify_stone_color_from_pixels(luma, xyxy)
        row, col, distance_ratio = nearest_intersection(cx, cy, pose)
        if distance_ratio > max_distance_ratio:
            continue
        conf = float(box.conf[0].item())
        if conf > confidence[row][col]:
            board[row][col] = color
            confidence[row][col] = conf
    return board


def load_luma(image_path: Path) -> np.ndarray:
    rgb = np.asarray(Image.open(image_path).convert("RGB"), dtype=np.float32)
    return 0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]


def classify_stone_color_from_pixels(luma: np.ndarray, xyxy: list[float]) -> str:
    x1, y1, x2, y2 = xyxy
    cx = (x1 + x2) / 2
    cy = (y1 + y2) / 2
    radius = max(2.0, min(x2 - x1, y2 - y1) * 0.28)
    x_min = max(0, int(cx - radius))
    x_max = min(luma.shape[1], int(cx + radius) + 1)
    y_min = max(0, int(cy - radius))
    y_max = min(luma.shape[0], int(cy + radius) + 1)
    if x_min >= x_max or y_min >= y_max:
        return "B"
    yy, xx = np.ogrid[y_min:y_max, x_min:x_max]
    mask = (xx - cx) ** 2 + (yy - cy) ** 2 <= radius**2
    values = luma[y_min:y_max, x_min:x_max][mask]
    if values.size == 0:
        return "B"
    return "W" if float(values.mean()) >= 90.0 else "B"


def nearest_intersection(x: float, y: float, pose: "PosePrediction") -> tuple[int, int, float]:
    best = (0, 0, float("inf"))
    step = average_grid_step(pose)
    for row in range(pose.board_size):
        for col in range(pose.board_size):
            px, py = grid_point(pose, row, col)
            dist = ((x - px) ** 2 + (y - py) ** 2) ** 0.5
            if dist < best[2]:
                best = (row, col, dist)
    return best[0], best[1], best[2] / max(1.0, step)


def average_grid_step(pose: "PosePrediction") -> float:
    if pose.board_size <= 1:
        return 20.0
    tl, tr, br, bl = pose.corners
    top = distance(tl, tr) / (pose.board_size - 1)
    right = distance(tr, br) / (pose.board_size - 1)
    bottom = distance(bl, br) / (pose.board_size - 1)
    left = distance(tl, bl) / (pose.board_size - 1)
    return (top + right + bottom + left) / 4


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


def grid_point(pose: "PosePrediction", row: int, col: int) -> tuple[float, float]:
    u = 0.0 if pose.board_size <= 1 else col / (pose.board_size - 1)
    v = 0.0 if pose.board_size <= 1 else row / (pose.board_size - 1)
    top = lerp(pose.corners[0], pose.corners[1], u)
    bottom = lerp(pose.corners[3], pose.corners[2], u)
    return lerp(top, bottom, v)


def lerp(a: tuple[float, float], b: tuple[float, float], t: float) -> tuple[float, float]:
    return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t


def score_board(
    predicted: list[list[str]],
    truth: "BoardTruth",
    predicted_board_size: int,
) -> "Stats":
    if predicted_board_size != truth.board_size:
        return Stats.for_size_mismatch(truth, predicted_board_size)

    correct_points = 0
    expected_stones = 0
    predicted_stones = 0
    correct_stones = 0
    mismatches = []

    for row in range(truth.board_size):
        for col in range(truth.board_size):
            expected = truth.board[row][col]
            actual = predicted[row][col]
            if expected != ".":
                expected_stones += 1
            if actual != ".":
                predicted_stones += 1
            if expected == actual:
                correct_points += 1
                if expected != ".":
                    correct_stones += 1
            else:
                mismatches.append(
                    f"{format_coord(row, col, truth.board_size)} "
                    f"expected={expected} predicted={actual}"
                )

    return Stats(
        expected_board_size=truth.board_size,
        predicted_board_size=predicted_board_size,
        total_points=truth.board_size * truth.board_size,
        correct_points=correct_points,
        expected_stones=expected_stones,
        predicted_stones=predicted_stones,
        correct_stones=correct_stones,
        mismatches=mismatches,
    )


def parse_coord(coord: str, board_size: int) -> tuple[int, int]:
    col = ord(coord[0]) - ord("A")
    if col > 8:
        col -= 1
    row = board_size - int(coord[1:])
    return row, col


def format_coord(row: int, col: int, board_size: int) -> str:
    code = col if col < 8 else col + 1
    return f"{chr(ord('A') + code)}{board_size - row}"


def run_rules_baseline() -> None:
    try:
        output = subprocess.check_output(
            ["dart", "run", "tool/recognition_accuracy_report.dart"],
            text=True,
        )
    except Exception as error:
        print(f"  unavailable: {error}")
        return
    lines = output.splitlines()
    try:
        start = lines.index("overall:")
    except ValueError:
        print("  unavailable: no overall section")
        return
    for line in lines[start + 1 :]:
        if line.strip():
            print(line)


def pct(numerator: int, denominator: int) -> str:
    if denominator == 0:
        return "n/a"
    return f"{numerator / denominator * 100:.1f}%"


@dataclass(frozen=True)
class BoardTruth:
    board_size: int
    board: list[list[str]]


@dataclass(frozen=True)
class PosePrediction:
    board_size: int
    corners: list[tuple[float, float]]
    confidence: float
    box: tuple[float, float, float, float]


@dataclass(frozen=True)
class Stats:
    expected_board_size: int
    predicted_board_size: int | None
    total_points: int
    correct_points: int
    expected_stones: int
    predicted_stones: int
    correct_stones: int
    mismatches: list[str]

    @classmethod
    def for_missing_pose(cls, expected_board_size: int) -> "Stats":
        return cls(
            expected_board_size=expected_board_size,
            predicted_board_size=None,
            total_points=expected_board_size * expected_board_size,
            correct_points=0,
            expected_stones=0,
            predicted_stones=0,
            correct_stones=0,
            mismatches=["missing board pose prediction"],
        )

    @classmethod
    def for_size_mismatch(
        cls,
        truth: BoardTruth,
        predicted_board_size: int,
    ) -> "Stats":
        expected_stones = sum(1 for row in truth.board for value in row if value != ".")
        return cls(
            expected_board_size=truth.board_size,
            predicted_board_size=predicted_board_size,
            total_points=truth.board_size * truth.board_size,
            correct_points=0,
            expected_stones=expected_stones,
            predicted_stones=0,
            correct_stones=0,
            mismatches=["board size mismatch"],
        )

    @property
    def exact(self) -> bool:
        return not self.mismatches

    @property
    def correct_board_size(self) -> bool:
        return self.predicted_board_size == self.expected_board_size


@dataclass
class Totals:
    samples: int = 0
    total_points: int = 0
    correct_points: int = 0
    expected_stones: int = 0
    predicted_stones: int = 0
    correct_stones: int = 0
    correct_board_size: int = 0
    exact_samples: int = 0

    def add(self, stats: Stats) -> None:
        self.samples += 1
        self.total_points += stats.total_points
        self.correct_points += stats.correct_points
        self.expected_stones += stats.expected_stones
        self.predicted_stones += stats.predicted_stones
        self.correct_stones += stats.correct_stones
        if stats.correct_board_size:
            self.correct_board_size += 1
        if stats.exact:
            self.exact_samples += 1


if __name__ == "__main__":
    main()
