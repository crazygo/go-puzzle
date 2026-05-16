#!/usr/bin/env python3
"""Convert recognition samples into an Ultralytics YOLO detection dataset.

The converter uses the existing sample triplet:

  <sample>.png/.PNG  original image
  <sample>.txt       board-state truth
  <sample>.json      board geometry sidecar from recognition_labeler.html

YOLO classes:
  0 black_stone
  1 white_stone
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


CLASS_IDS = {"B": 0, "W": 1}
IMAGE_EXTENSIONS = (".png", ".PNG", ".jpg", ".JPG", ".jpeg", ".JPEG")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=Path, required=True)
    parser.add_argument("--splits", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--stone-scale",
        type=float,
        default=0.72,
        help="Bounding-box side length as a fraction of average grid step.",
    )
    args = parser.parse_args()

    train_ids = read_split(args.splits / "train.txt")
    val_ids = read_split(args.splits / "val.txt")
    validate_splits(args.samples, train_ids, val_ids)

    reset_output(args.out)
    write_split(args.samples, args.out, "train", train_ids, args.stone_scale)
    write_split(args.samples, args.out, "val", val_ids, args.stone_scale)
    write_data_yaml(args.out)

    print(f"wrote dataset: {args.out}")
    print(f"train samples: {len(train_ids)}")
    print(f"val samples: {len(val_ids)}")


def read_split(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]


def validate_splits(samples_dir: Path, train_ids: list[str], val_ids: list[str]) -> None:
    all_ids = sorted(path.stem for path in samples_dir.glob("*.txt"))
    split_ids = train_ids + val_ids
    overlap = sorted(set(train_ids).intersection(val_ids))
    missing = sorted(set(all_ids).difference(split_ids))
    extra = sorted(set(split_ids).difference(all_ids))
    duplicates = sorted(sample_id for sample_id in set(split_ids) if split_ids.count(sample_id) > 1)
    problems = []
    if overlap:
        problems.append(f"overlap: {', '.join(overlap)}")
    if missing:
        problems.append(f"missing: {', '.join(missing)}")
    if extra:
        problems.append(f"extra: {', '.join(extra)}")
    if duplicates:
        problems.append(f"duplicates: {', '.join(duplicates)}")
    if problems:
        raise SystemExit("\n".join(problems))


def reset_output(out_dir: Path) -> None:
    for subdir in [
        "images/train",
        "images/val",
        "labels/train",
        "labels/val",
    ]:
        path = out_dir / subdir
        if path.exists():
            shutil.rmtree(path)
        path.mkdir(parents=True, exist_ok=True)


def write_split(
    samples_dir: Path,
    out_dir: Path,
    split: str,
    sample_ids: list[str],
    stone_scale: float,
) -> None:
    for sample_id in sample_ids:
        image_path = find_image(samples_dir, sample_id)
        json_path = samples_dir / f"{sample_id}.json"
        if not json_path.exists():
            raise SystemExit(f"missing json: {json_path}")

        data = json.loads(json_path.read_text())
        image = data["image"]
        width = int(image["width"])
        height = int(image["height"])
        board_size = int(data["boardSize"])
        corners = parse_corners(data["corners"])
        step = average_grid_step(corners, board_size)
        box_side = max(4.0, step * stone_scale)

        out_image = out_dir / "images" / split / f"{sample_id}{image_path.suffix}"
        shutil.copy2(image_path, out_image)

        label_lines = []
        for stone in data["stones"]:
            color = stone["color"]
            row = int(stone["row"])
            col = int(stone["col"])
            cx, cy = grid_point(corners, board_size, row, col)
            label_lines.append(
                yolo_line(CLASS_IDS[color], cx, cy, box_side, box_side, width, height)
            )

        label_path = out_dir / "labels" / split / f"{sample_id}.txt"
        label_path.write_text("".join(label_lines))


def find_image(samples_dir: Path, sample_id: str) -> Path:
    for extension in IMAGE_EXTENSIONS:
        image = samples_dir / f"{sample_id}{extension}"
        if image.exists():
            return image
    raise SystemExit(f"missing image for sample: {sample_id}")


def parse_corners(raw: dict) -> dict[str, tuple[float, float]]:
    return {
        "top_left": point(raw["topLeft"]),
        "top_right": point(raw["topRight"]),
        "bottom_right": point(raw["bottomRight"]),
        "bottom_left": point(raw["bottomLeft"]),
    }


def point(raw: dict) -> tuple[float, float]:
    return float(raw["x"]), float(raw["y"])


def average_grid_step(corners: dict[str, tuple[float, float]], board_size: int) -> float:
    if board_size <= 1:
        return 20.0
    top = distance(corners["top_left"], corners["top_right"]) / (board_size - 1)
    bottom = distance(corners["bottom_left"], corners["bottom_right"]) / (board_size - 1)
    left = distance(corners["top_left"], corners["bottom_left"]) / (board_size - 1)
    right = distance(corners["top_right"], corners["bottom_right"]) / (board_size - 1)
    return (top + bottom + left + right) / 4


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


def grid_point(
    corners: dict[str, tuple[float, float]],
    board_size: int,
    row: int,
    col: int,
) -> tuple[float, float]:
    u = 0.0 if board_size <= 1 else col / (board_size - 1)
    v = 0.0 if board_size <= 1 else row / (board_size - 1)
    top = lerp(corners["top_left"], corners["top_right"], u)
    bottom = lerp(corners["bottom_left"], corners["bottom_right"], u)
    return lerp(top, bottom, v)


def lerp(a: tuple[float, float], b: tuple[float, float], t: float) -> tuple[float, float]:
    return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t


def yolo_line(
    class_id: int,
    cx: float,
    cy: float,
    box_width: float,
    box_height: float,
    image_width: int,
    image_height: int,
) -> str:
    x = clamp(cx / image_width)
    y = clamp(cy / image_height)
    w = clamp(box_width / image_width)
    h = clamp(box_height / image_height)
    return f"{class_id} {x:.8f} {y:.8f} {w:.8f} {h:.8f}\n"


def clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def write_data_yaml(out_dir: Path) -> None:
    data_yaml = f"""path: {out_dir.resolve()}
train: images/train
val: images/val
names:
  0: black_stone
  1: white_stone
"""
    (out_dir / "data.yaml").write_text(data_yaml)


if __name__ == "__main__":
    main()
