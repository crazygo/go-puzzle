#!/usr/bin/env python3
"""Evaluate a YOLO stone detector as board-state recognition.

This script intentionally uses the human-labeled JSON board geometry. It answers
one narrow question: if board size and board corners are known, how accurately
does the YOLO stone detector recover black/white stones on intersections?
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

from ultralytics import YOLO


COLOR_BY_CLASS = {0: "B", 1: "W"}
IMAGE_EXTENSIONS = (".png", ".PNG", ".jpg", ".JPG", ".jpeg", ".JPEG")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--samples", type=Path, default=Path("test/assets/recognition_samples"))
    parser.add_argument("--split", type=Path, default=None)
    parser.add_argument("--conf", type=float, default=0.25)
    parser.add_argument("--iou", type=float, default=0.7)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    sample_ids = load_sample_ids(args.samples, args.split)
    model = YOLO(str(args.model))

    totals = Totals()
    failed = []

    for sample_id in sample_ids:
        truth = load_txt_truth(args.samples / f"{sample_id}.txt")
        geometry = load_geometry(args.samples / f"{sample_id}.json")
        image_path = find_image(args.samples, sample_id)
        result = model.predict(
            source=str(image_path),
            conf=args.conf,
            iou=args.iou,
            imgsz=args.imgsz,
            verbose=False,
        )[0]
        predicted = predictions_to_board(result, geometry)
        stats = score_board(predicted, truth)
        totals.add(stats)
        if not stats.exact:
            failed.append(sample_id)

        if args.verbose or not stats.exact:
            print(f"sample: {sample_id}")
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

    print("")
    print("overall:")
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
    print(f"  exact samples {len(sample_ids) - len(failed)}/{len(sample_ids)}")
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


def load_geometry(path: Path) -> "Geometry":
    raw = json.loads(path.read_text())
    corners = raw["corners"]
    return Geometry(
        board_size=int(raw["boardSize"]),
        top_left=point(corners["topLeft"]),
        top_right=point(corners["topRight"]),
        bottom_right=point(corners["bottomRight"]),
        bottom_left=point(corners["bottomLeft"]),
    )


def point(raw: dict) -> tuple[float, float]:
    return float(raw["x"]), float(raw["y"])


def find_image(samples_dir: Path, sample_id: str) -> Path:
    for extension in IMAGE_EXTENSIONS:
        path = samples_dir / f"{sample_id}{extension}"
        if path.exists():
            return path
    raise FileNotFoundError(sample_id)


def predictions_to_board(result, geometry: "Geometry") -> list[list[str]]:
    board = [["." for _ in range(geometry.board_size)] for _ in range(geometry.board_size)]
    confidence = [[-1.0 for _ in range(geometry.board_size)] for _ in range(geometry.board_size)]

    if result.boxes is None:
        return board

    for box in result.boxes:
        class_id = int(box.cls[0].item())
        color = COLOR_BY_CLASS.get(class_id)
        if color is None:
            continue
        xyxy = box.xyxy[0].tolist()
        cx = (xyxy[0] + xyxy[2]) / 2
        cy = (xyxy[1] + xyxy[3]) / 2
        row, col, distance_ratio = nearest_intersection(cx, cy, geometry)
        if distance_ratio > 0.58:
            continue
        conf = float(box.conf[0].item())
        if conf > confidence[row][col]:
            board[row][col] = color
            confidence[row][col] = conf
    return board


def nearest_intersection(x: float, y: float, geometry: "Geometry") -> tuple[int, int, float]:
    best = (0, 0, float("inf"))
    step = average_grid_step(geometry)
    for row in range(geometry.board_size):
        for col in range(geometry.board_size):
            px, py = grid_point(geometry, row, col)
            dist = ((x - px) ** 2 + (y - py) ** 2) ** 0.5
            if dist < best[2]:
                best = (row, col, dist)
    return best[0], best[1], best[2] / max(1.0, step)


def average_grid_step(geometry: "Geometry") -> float:
    if geometry.board_size <= 1:
        return 20.0
    top = distance(geometry.top_left, geometry.top_right) / (geometry.board_size - 1)
    bottom = distance(geometry.bottom_left, geometry.bottom_right) / (geometry.board_size - 1)
    left = distance(geometry.top_left, geometry.bottom_left) / (geometry.board_size - 1)
    right = distance(geometry.top_right, geometry.bottom_right) / (geometry.board_size - 1)
    return (top + bottom + left + right) / 4


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


def grid_point(geometry: "Geometry", row: int, col: int) -> tuple[float, float]:
    u = 0.0 if geometry.board_size <= 1 else col / (geometry.board_size - 1)
    v = 0.0 if geometry.board_size <= 1 else row / (geometry.board_size - 1)
    top = lerp(geometry.top_left, geometry.top_right, u)
    bottom = lerp(geometry.bottom_left, geometry.bottom_right, u)
    return lerp(top, bottom, v)


def lerp(a: tuple[float, float], b: tuple[float, float], t: float) -> tuple[float, float]:
    return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t


def score_board(predicted: list[list[str]], truth: "BoardTruth") -> "Stats":
    total_points = truth.board_size * truth.board_size
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
        total_points=total_points,
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


def pct(numerator: int, denominator: int) -> str:
    if denominator == 0:
        return "n/a"
    return f"{numerator / denominator * 100:.1f}%"


@dataclass(frozen=True)
class BoardTruth:
    board_size: int
    board: list[list[str]]


@dataclass(frozen=True)
class Geometry:
    board_size: int
    top_left: tuple[float, float]
    top_right: tuple[float, float]
    bottom_right: tuple[float, float]
    bottom_left: tuple[float, float]


@dataclass(frozen=True)
class Stats:
    total_points: int
    correct_points: int
    expected_stones: int
    predicted_stones: int
    correct_stones: int
    mismatches: list[str]

    @property
    def exact(self) -> bool:
        return not self.mismatches


@dataclass
class Totals:
    total_points: int = 0
    correct_points: int = 0
    expected_stones: int = 0
    predicted_stones: int = 0
    correct_stones: int = 0

    def add(self, stats: Stats) -> None:
        self.total_points += stats.total_points
        self.correct_points += stats.correct_points
        self.expected_stones += stats.expected_stones
        self.predicted_stones += stats.predicted_stones
        self.correct_stones += stats.correct_stones


if __name__ == "__main__":
    main()
