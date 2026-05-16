#!/usr/bin/env python3
"""Convert recognition samples into an Ultralytics YOLO pose dataset.

Pose task:
  class 0: board_9
  class 1: board_13
  class 2: board_19
  keypoints: topLeft, topRight, bottomRight, bottomLeft
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


IMAGE_EXTENSIONS = (".png", ".PNG", ".jpg", ".JPG", ".jpeg", ".JPEG")
KEYPOINT_NAMES = ("topLeft", "topRight", "bottomRight", "bottomLeft")
BOARD_CLASS_IDS = {9: 0, 13: 1, 19: 2}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=Path, required=True)
    parser.add_argument("--splits", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--bbox-padding",
        type=float,
        default=0.04,
        help="Board bbox padding as a fraction of the larger bbox side.",
    )
    args = parser.parse_args()

    train_ids = read_split(args.splits / "train.txt")
    val_ids = read_split(args.splits / "val.txt")
    validate_splits(args.samples, train_ids, val_ids)

    reset_output(args.out)
    write_split(args.samples, args.out, "train", train_ids, args.bbox_padding)
    write_split(args.samples, args.out, "val", val_ids, args.bbox_padding)
    write_data_yaml(args.out)

    print(f"wrote board pose dataset: {args.out}")
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
    bbox_padding: float,
) -> None:
    for sample_id in sample_ids:
        image_path = find_image(samples_dir, sample_id)
        json_path = samples_dir / f"{sample_id}.json"
        if not json_path.exists():
            raise SystemExit(f"missing json: {json_path}")

        data = json.loads(json_path.read_text())
        width = int(data["image"]["width"])
        height = int(data["image"]["height"])
        board_size = int(data["boardSize"])
        if board_size not in BOARD_CLASS_IDS:
            raise SystemExit(f"unsupported board size {board_size}: {sample_id}")
        corners = [point(data["corners"][name]) for name in KEYPOINT_NAMES]

        out_image = out_dir / "images" / split / f"{sample_id}{image_path.suffix}"
        shutil.copy2(image_path, out_image)

        label_path = out_dir / "labels" / split / f"{sample_id}.txt"
        label_path.write_text(
            pose_label_line(
                class_id=BOARD_CLASS_IDS[board_size],
                corners=corners,
                image_width=width,
                image_height=height,
                bbox_padding=bbox_padding,
            )
        )


def find_image(samples_dir: Path, sample_id: str) -> Path:
    for extension in IMAGE_EXTENSIONS:
        image = samples_dir / f"{sample_id}{extension}"
        if image.exists():
            return image
    raise SystemExit(f"missing image for sample: {sample_id}")


def point(raw: dict) -> tuple[float, float]:
    return float(raw["x"]), float(raw["y"])


def pose_label_line(
    class_id: int,
    corners: list[tuple[float, float]],
    image_width: int,
    image_height: int,
    bbox_padding: float,
) -> str:
    xs = [p[0] for p in corners]
    ys = [p[1] for p in corners]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    pad = max(max_x - min_x, max_y - min_y) * bbox_padding
    min_x = clamp_px(min_x - pad, image_width)
    max_x = clamp_px(max_x + pad, image_width)
    min_y = clamp_px(min_y - pad, image_height)
    max_y = clamp_px(max_y + pad, image_height)

    cx = (min_x + max_x) / 2 / image_width
    cy = (min_y + max_y) / 2 / image_height
    bw = (max_x - min_x) / image_width
    bh = (max_y - min_y) / image_height

    values: list[str] = [str(class_id), f"{cx:.8f}", f"{cy:.8f}", f"{bw:.8f}", f"{bh:.8f}"]
    for x, y in corners:
        values.extend([
            f"{clamp01(x / image_width):.8f}",
            f"{clamp01(y / image_height):.8f}",
            "2",
        ])
    return " ".join(values) + "\n"


def clamp_px(value: float, maximum: int) -> float:
    return max(0.0, min(float(maximum), value))


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def write_data_yaml(out_dir: Path) -> None:
    data_yaml = f"""path: {out_dir.resolve()}
train: images/train
val: images/val
kpt_shape: [4, 3]
flip_idx: [1, 0, 3, 2]
names:
  0: board_9
  1: board_13
  2: board_19
"""
    (out_dir / "data.yaml").write_text(data_yaml)


if __name__ == "__main__":
    main()
