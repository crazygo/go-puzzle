#!/usr/bin/env python3
"""Recognize a Go board screenshot and print the existing text format."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from board_grid_refiner import refine_board_pose
from evaluate_full_pipeline import (
    PosePrediction,
    extract_pose,
    format_coord,
    stones_to_board,
)
from ultralytics import YOLO


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BOARD_MODELS = [
    ROOT / ".cache/yolo/runs/go_board_pose_yolov8n_640_b2_rebalanced/weights/best.pt",
    ROOT / ".cache/yolo/runs/go_board_pose_yolov8n_640_b2_tuned/weights/best.pt",
    ROOT / ".cache/yolo/runs/go_board_pose_yolov8n_640_b2/weights/best.pt",
    ROOT / ".cache/yolo/runs/go_board_pose_smoke/weights/best.pt",
]
DEFAULT_STONE_MODELS = [
    ROOT / ".cache/yolo/runs/go_stones_yolov8n_640_b2/weights/best.pt",
    ROOT / ".cache/yolo/runs/go_stones_smoke/weights/best.pt",
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path, help="Screenshot image path")
    parser.add_argument("--board-model", type=Path, default=None)
    parser.add_argument("--stone-model", type=Path, default=None)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--board-conf", type=float, default=0.01)
    parser.add_argument("--stone-conf", type=float, default=0.25)
    parser.add_argument("--stone-iou", type=float, default=0.7)
    parser.add_argument("--max-stone-distance", type=float, default=0.58)
    parser.add_argument("--no-refine-board", action="store_true")
    parser.add_argument("--json", action="store_true", help="Include board corners and text lines as JSON")
    args = parser.parse_args()

    image_path = args.image
    if not image_path.exists():
        raise SystemExit(f"missing image: {image_path}")

    board_model_path = args.board_model or first_existing_model(DEFAULT_BOARD_MODELS)
    stone_model_path = args.stone_model or first_existing_model(DEFAULT_STONE_MODELS)
    if not board_model_path.exists():
        raise SystemExit(f"missing board model: {board_model_path}")
    if not stone_model_path.exists():
        raise SystemExit(f"missing stone model: {stone_model_path}")

    board_model = YOLO(str(board_model_path))
    stone_model = YOLO(str(stone_model_path))

    board_result = board_model.predict(
        source=str(image_path),
        conf=args.board_conf,
        imgsz=args.imgsz,
        verbose=False,
    )[0]
    pose = extract_pose(board_result)
    if pose is None:
        raise SystemExit("no board pose prediction")
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
    board = stones_to_board(
        stone_result,
        pose,
        image_path=image_path,
        max_distance_ratio=args.max_stone_distance,
        use_pixel_color=False,
    )
    lines = board_to_text_lines(board)

    if args.json:
        print(
            json.dumps(
                {
                    "boardSize": pose.board_size,
                    "corners": {
                        "topLeft": point_json(pose.corners[0]),
                        "topRight": point_json(pose.corners[1]),
                        "bottomRight": point_json(pose.corners[2]),
                        "bottomLeft": point_json(pose.corners[3]),
                    },
                    "text": "\n".join(lines),
                    "lines": lines,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return

    print("\n".join(lines))


def first_existing_model(candidates: list[Path]) -> Path:
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


def board_to_text_lines(board: list[list[str]]) -> list[str]:
    board_size = len(board)
    lines = [f"Size {board_size}"]
    for row, values in enumerate(board):
        for col, color in enumerate(values):
            if color == ".":
                continue
            lines.append(f"{color},{format_coord(row, col, board_size)}")
    return lines


def point_json(point: tuple[float, float]) -> dict[str, float]:
    return {"x": round(point[0], 3), "y": round(point[1], 3)}


if __name__ == "__main__":
    main()
