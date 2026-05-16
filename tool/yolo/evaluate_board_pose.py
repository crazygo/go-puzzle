#!/usr/bin/env python3
"""Evaluate YOLO pose board-corner predictions against JSON geometry."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

from board_grid_refiner import refine_board_pose
from ultralytics import YOLO


IMAGE_EXTENSIONS = (".png", ".PNG", ".jpg", ".JPG", ".jpeg", ".JPEG")
KEYPOINT_NAMES = ("topLeft", "topRight", "bottomRight", "bottomLeft")
BOARD_SIZE_BY_CLASS = {0: 9, 1: 13, 2: 19}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--samples", type=Path, default=Path("test/assets/recognition_samples"))
    parser.add_argument("--split", type=Path, default=None)
    parser.add_argument("--conf", type=float, default=0.01)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--no-refine", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    sample_ids = load_sample_ids(args.samples, args.split)
    model = YOLO(str(args.model))

    totals = Totals()
    failed = []

    for sample_id in sample_ids:
        geometry = load_geometry(args.samples / f"{sample_id}.json")
        image_path = find_image(args.samples, sample_id)
        result = model.predict(
            source=str(image_path),
            conf=args.conf,
            imgsz=args.imgsz,
            verbose=False,
        )[0]
        predicted = extract_pose(result)
        if predicted is not None and not args.no_refine:
            refined = refine_board_pose(
                image_path,
                board_size=predicted.board_size,
                corners=predicted.corners,
                box=predicted.box,
                confidence=predicted.confidence,
            )
            predicted = PosePrediction(
                board_size=refined.board_size,
                corners=refined.corners,
                confidence=predicted.confidence,
                box=predicted.box,
            )
        stats = score_corners(predicted, geometry)
        totals.add(stats)
        if not stats.pass_sample:
            failed.append(sample_id)

        if args.verbose or not stats.pass_sample:
            print(f"sample: {sample_id}")
            if predicted is None:
                print("  no board pose prediction")
                continue
            print(f"  board size expected={geometry.board_size} predicted={predicted.board_size}")
            print(f"  mean corner error: {stats.mean_error_px:.1f}px ({stats.mean_error_step:.2f} step)")
            print(f"  max corner error: {stats.max_error_px:.1f}px ({stats.max_error_step:.2f} step)")
            for name, error in zip(KEYPOINT_NAMES, stats.corner_errors_px):
                print(f"    {name}: {error:.1f}px")

    print("")
    print("overall:")
    print(f"  samples with prediction {totals.predicted_samples}/{totals.samples}")
    print(f"  mean corner error {totals.mean_error_px:.1f}px ({totals.mean_error_step:.2f} step)")
    print(f"  max corner error {totals.max_error_px:.1f}px ({totals.max_error_step:.2f} step)")
    print(f"  pass samples {totals.pass_samples}/{totals.samples}")
    print(f"  board size accuracy {totals.correct_board_size}/{totals.samples} ({pct(totals.correct_board_size, totals.samples)})")
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


def load_geometry(path: Path) -> "Geometry":
    raw = json.loads(path.read_text())
    corners = raw["corners"]
    return Geometry(
        board_size=int(raw["boardSize"]),
        corners=[point(corners[name]) for name in KEYPOINT_NAMES],
    )


def point(raw: dict) -> tuple[float, float]:
    return float(raw["x"]), float(raw["y"])


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


def score_corners(predicted: "PosePrediction | None", geometry: "Geometry") -> "Stats":
    if predicted is None:
        return Stats(
            predicted=False,
            correct_board_size=False,
            corner_errors_px=[float("inf")] * 4,
            grid_step=average_grid_step(geometry),
        )
    errors = [
        distance(actual, expected)
        for actual, expected in zip(predicted.corners, geometry.corners)
    ]
    return Stats(
        predicted=True,
        correct_board_size=predicted.board_size == geometry.board_size,
        corner_errors_px=errors,
        grid_step=average_grid_step(geometry),
    )


def average_grid_step(geometry: "Geometry") -> float:
    if geometry.board_size <= 1:
        return 20.0
    top = distance(geometry.corners[0], geometry.corners[1]) / (geometry.board_size - 1)
    right = distance(geometry.corners[1], geometry.corners[2]) / (geometry.board_size - 1)
    bottom = distance(geometry.corners[3], geometry.corners[2]) / (geometry.board_size - 1)
    left = distance(geometry.corners[0], geometry.corners[3]) / (geometry.board_size - 1)
    return (top + right + bottom + left) / 4


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


@dataclass(frozen=True)
class Geometry:
    board_size: int
    corners: list[tuple[float, float]]


@dataclass(frozen=True)
class PosePrediction:
    board_size: int
    corners: list[tuple[float, float]]
    confidence: float
    box: tuple[float, float, float, float]


@dataclass(frozen=True)
class Stats:
    predicted: bool
    correct_board_size: bool
    corner_errors_px: list[float]
    grid_step: float

    @property
    def mean_error_px(self) -> float:
        return sum(self.corner_errors_px) / len(self.corner_errors_px)

    @property
    def max_error_px(self) -> float:
        return max(self.corner_errors_px)

    @property
    def mean_error_step(self) -> float:
        return self.mean_error_px / max(1.0, self.grid_step)

    @property
    def max_error_step(self) -> float:
        return self.max_error_px / max(1.0, self.grid_step)

    @property
    def pass_sample(self) -> bool:
        return self.predicted and self.correct_board_size and self.max_error_step <= 0.50


@dataclass
class Totals:
    samples: int = 0
    predicted_samples: int = 0
    pass_samples: int = 0
    correct_board_size: int = 0
    sum_mean_error_px: float = 0.0
    sum_mean_error_step: float = 0.0
    max_error_px: float = 0.0
    max_error_step: float = 0.0

    def add(self, stats: Stats) -> None:
        self.samples += 1
        if stats.predicted:
            self.predicted_samples += 1
            if stats.correct_board_size:
                self.correct_board_size += 1
            self.sum_mean_error_px += stats.mean_error_px
            self.sum_mean_error_step += stats.mean_error_step
            self.max_error_px = max(self.max_error_px, stats.max_error_px)
            self.max_error_step = max(self.max_error_step, stats.max_error_step)
        if stats.pass_sample:
            self.pass_samples += 1

    @property
    def mean_error_px(self) -> float:
        if self.predicted_samples == 0:
            return float("inf")
        return self.sum_mean_error_px / self.predicted_samples

    @property
    def mean_error_step(self) -> float:
        if self.predicted_samples == 0:
            return float("inf")
        return self.sum_mean_error_step / self.predicted_samples


def pct(numerator: int, denominator: int) -> str:
    if denominator == 0:
        return "n/a"
    return f"{numerator / denominator * 100:.1f}%"


if __name__ == "__main__":
    main()
