#!/usr/bin/env python3
"""Refine rough YOLO board poses onto visible grid lines."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image


BOARD_SIZES = (9, 13, 19)


@dataclass(frozen=True)
class RefinedBoardPose:
    board_size: int
    corners: list[tuple[float, float]]
    score: float


def refine_board_pose(
    image_path: Path,
    *,
    board_size: int,
    corners: list[tuple[float, float]],
    box: tuple[float, float, float, float] | None = None,
    confidence: float = 1.0,
    search_sizes_when_uncertain: bool = True,
) -> RefinedBoardPose:
    """Snap a rough axis-aligned board pose to periodic dark grid lines.

    The YOLO pose model gives a good region but not pixel-accurate corners on
    screenshots. This refinement searches for evenly-spaced vertical and
    horizontal line contrast near the model prediction.
    """

    luma = _load_luma(image_path)
    sizes = BOARD_SIZES if search_sizes_when_uncertain and confidence < 0.5 else (board_size,)
    uncertain = confidence < 0.5
    candidates = [
        _refine_for_size(
            luma,
            size,
            corners=corners,
            box=box if uncertain else None,
            drift_box=box,
            prior_strength=0.10 if uncertain else 1.25,
        )
        for size in sizes
    ]
    return max(candidates, key=lambda candidate: candidate.score)


def _load_luma(image_path: Path) -> np.ndarray:
    rgb = np.asarray(Image.open(image_path).convert("RGB"), dtype=np.float32)
    return 0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]


def _refine_for_size(
    luma: np.ndarray,
    board_size: int,
    *,
    corners: list[tuple[float, float]],
    box: tuple[float, float, float, float] | None,
    drift_box: tuple[float, float, float, float] | None,
    prior_strength: float,
) -> RefinedBoardPose:
    if box is not None:
        x0, y0, x1, y1 = box
    else:
        x0, y0, x1, y1 = _axis_aligned_bounds(corners)

    score = 0.0
    for _ in range(2):
        vertical = _vertical_line_profile(luma, y0, y1)
        x_result = _search_periodic_axis(vertical, board_size, x0, x1, prior_strength)
        x0 = x_result.start
        x1 = x_result.start + x_result.step * (board_size - 1)

        horizontal = _horizontal_line_profile(luma, x0, x1)
        y_result = _search_periodic_axis(horizontal, board_size, y0, y1, prior_strength)
        y0 = y_result.start
        y1 = y_result.start + y_result.step * (board_size - 1)
        score = x_result.score + y_result.score

    if drift_box is not None:
        x0, x1 = _correct_axis_drift(x0, x1, board_size, drift_box[0], drift_box[2], luma.shape[1])
        y0, y1 = _correct_axis_drift(y0, y1, board_size, drift_box[1], drift_box[3], luma.shape[0])

    return RefinedBoardPose(
        board_size=board_size,
        corners=[(x0, y0), (x1, y0), (x1, y1), (x0, y1)],
        score=score,
    )


def _correct_axis_drift(
    start: float,
    end: float,
    board_size: int,
    box_start: float,
    box_end: float,
    image_limit: int,
) -> tuple[float, float]:
    step = (end - start) / max(1, board_size - 1)
    if end > box_end + step * 0.5 and start - step >= 0:
        return start - step, end - step
    if start < box_start - step * 0.5 and end + step <= image_limit:
        return start + step, end + step
    return start, end


def _axis_aligned_bounds(corners: list[tuple[float, float]]) -> tuple[float, float, float, float]:
    left = (corners[0][0] + corners[3][0]) / 2
    right = (corners[1][0] + corners[2][0]) / 2
    top = (corners[0][1] + corners[1][1]) / 2
    bottom = (corners[2][1] + corners[3][1]) / 2
    return left, top, right, bottom


def _vertical_line_profile(luma: np.ndarray, y0: float, y1: float) -> np.ndarray:
    height, width = luma.shape
    top = max(0, min(height - 1, int(round(y0))))
    bottom = max(top + 1, min(height, int(round(y1))))
    profile = np.zeros(width, dtype=np.float32)
    for x in range(7, width - 7):
        center = luma[top:bottom, x - 1 : x + 2].mean()
        side = (
            luma[top:bottom, x - 7 : x - 4].mean()
            + luma[top:bottom, x + 4 : x + 7].mean()
        ) / 2
        profile[x] = max(0.0, side - center)
    return _smooth(profile)


def _horizontal_line_profile(luma: np.ndarray, x0: float, x1: float) -> np.ndarray:
    height, width = luma.shape
    left = max(0, min(width - 1, int(round(x0))))
    right = max(left + 1, min(width, int(round(x1))))
    profile = np.zeros(height, dtype=np.float32)
    for y in range(7, height - 7):
        center = luma[y - 1 : y + 2, left:right].mean()
        side = (
            luma[y - 7 : y - 4, left:right].mean()
            + luma[y + 4 : y + 7, left:right].mean()
        ) / 2
        profile[y] = max(0.0, side - center)
    return _smooth(profile)


def _smooth(profile: np.ndarray) -> np.ndarray:
    return np.convolve(profile, np.ones(5, dtype=np.float32) / 5, mode="same")


@dataclass(frozen=True)
class _AxisResult:
    score: float
    start: float
    step: float


def _search_periodic_axis(
    profile: np.ndarray,
    board_size: int,
    rough_start: float,
    rough_end: float,
    prior_strength: float,
) -> _AxisResult:
    rough_step = max(1.0, (rough_end - rough_start) / (board_size - 1))
    step_delta = max(1.0, rough_step * 0.01)
    start_delta = max(1.0, rough_step * 0.01)
    best = _AxisResult(score=float("-inf"), start=rough_start, step=rough_step)

    for step in np.arange(max(8.0, rough_step * 0.55), rough_step * 1.30, step_delta):
        max_start = len(profile) - step * (board_size - 1)
        start_min = max(0.0, rough_start - rough_step * 1.5)
        start_max = min(max_start, rough_start + rough_step * 1.5)
        for start in np.arange(start_min, start_max, start_delta):
            end = start + step * (board_size - 1)
            if end >= len(profile):
                continue
            line_score = sum(_local_max(profile, start + i * step) for i in range(board_size)) / board_size
            mid_score = sum(
                _local_max(profile, start + (i + 0.5) * step)
                for i in range(board_size - 1)
            ) / (board_size - 1)
            score = line_score - 0.25 * mid_score
            start_delta_ratio = abs(start - rough_start) / max(1.0, rough_step)
            step_delta_ratio = abs(step - rough_step) / max(1.0, rough_step)
            prior = max(
                0.15,
                1.0 - prior_strength * (0.25 * start_delta_ratio + step_delta_ratio),
            )
            score *= prior
            if score > best.score:
                best = _AxisResult(score=score, start=float(start), step=float(step))
    return best


def _local_max(profile: np.ndarray, index: float) -> float:
    center = int(round(index))
    left = max(0, center - 2)
    right = min(len(profile), center + 3)
    return float(profile[left:right].max())
