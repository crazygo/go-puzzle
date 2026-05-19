#!/usr/bin/env python3
"""Pick a capture-go move from a KataGo-family ONNX policy model.

The helper is intentionally small and process-oriented so Dart arena runs can
use a real model without linking ONNX Runtime into every Flutter target.
Input is JSON on argv[1] or stdin:

  {
    "model": "assets/models/katago_capture_standard.onnx",
    "size": 9,
    "currentPlayer": 1,
    "cells": [0, 0, ...],
    "legalMoves": [0, 1, ...],
    "policyTemperature": 0.8,
    "candidateLimit": 8
  }

Output is JSON on stdout with either {"move":[row,col]} or {"error":"..."}.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort


def main() -> int:
    try:
        request = json.loads(sys.argv[1]) if len(sys.argv) > 1 else json.load(sys.stdin)
        model_path = Path(request["model"])
        if not model_path.is_file():
            return _fail(f"model_not_found:{model_path}")

        size = int(request["size"])
        cells = [int(v) for v in request["cells"]]
        current_player = int(request["currentPlayer"])
        legal_moves = [int(v) for v in request["legalMoves"]]
        if len(cells) != size * size:
            return _fail("bad_cells_length")
        if not legal_moves:
            return _fail("no_legal_moves")

        bin_input = _encode_bin_input(
            size=size,
            cells=cells,
            current_player=current_player,
        )
        global_input = _encode_global_input(
            size=size,
            current_player=current_player,
        )
        session = ort.InferenceSession(
            str(model_path),
            providers=["CPUExecutionProvider"],
        )
        policy = session.run(
            ["policy"],
            {
                "bin_input": bin_input,
                "global_input": global_input,
            },
        )[0][0, 0, : size * size]

        move_index = _select_move(
            policy=policy,
            legal_moves=legal_moves,
            temperature=float(request.get("policyTemperature", 1.0)),
            candidate_limit=int(request.get("candidateLimit", len(legal_moves))),
        )
        print(
            json.dumps(
                {
                    "move": [move_index // size, move_index % size],
                    "backend": "python_onnxruntime",
                    "model": str(model_path),
                },
                separators=(",", ":"),
            )
        )
        return 0
    except Exception as error:  # noqa: BLE001 - tool boundary must be explicit.
        return _fail(f"{type(error).__name__}:{error}")


def _encode_bin_input(
    *,
    size: int,
    cells: list[int],
    current_player: int,
) -> np.ndarray:
    opponent = 2 if current_player == 1 else 1
    tensor = np.zeros((1, 22, size, size), dtype=np.float32)

    # Minimal KataGo-style board encoding. Plane 0 marks valid board points and
    # avoids the NaN behavior seen when all binary inputs are zero. Planes 1-3
    # encode current-player stones, opponent stones, and empty points.
    tensor[0, 0, :, :] = 1.0
    for index, value in enumerate(cells):
        row = index // size
        col = index % size
        if value == current_player:
            tensor[0, 1, row, col] = 1.0
        elif value == opponent:
            tensor[0, 2, row, col] = 1.0
        else:
            tensor[0, 3, row, col] = 1.0
    return tensor


def _encode_global_input(*, size: int, current_player: int) -> np.ndarray:
    tensor = np.zeros((1, 19), dtype=np.float32)
    tensor[0, 0] = 1.0
    tensor[0, 1] = 1.0 if current_player == 1 else -1.0
    tensor[0, 2] = float(size)
    return tensor


def _select_move(
    *,
    policy: np.ndarray,
    legal_moves: list[int],
    temperature: float,
    candidate_limit: int,
) -> int:
    scored = []
    for move_index in legal_moves:
        raw = float(policy[move_index])
        if math.isnan(raw) or math.isinf(raw):
            continue
        scored.append((raw, move_index))
    if not scored:
        raise ValueError("policy_has_no_finite_legal_scores")
    scored.sort(reverse=True)
    shortlist = scored[: max(1, min(candidate_limit, len(scored)))]
    if temperature <= 0:
        return shortlist[0][1]
    adjusted = [(score / temperature, move) for score, move in shortlist]
    return max(adjusted)[1]


def _fail(message: str) -> int:
    print(json.dumps({"error": message}, separators=(",", ":")))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
