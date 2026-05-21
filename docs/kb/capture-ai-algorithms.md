# Capture AI Algorithms

This document is the entry point for capture-go AI algorithm details. Product
features stay in the main README; this page explains the algorithm families,
configuration surface, tactical safeguards, and evaluation links.

## Algorithm Families

### Heuristic

Heuristic configs score legal moves directly from capture-go features such as
captures, liberties, atari pressure, escape value, and local tactical shape.
They are fast and useful as baseline opponents, but they do not perform a deep
search over long forcing sequences.

### MCTS

MCTS configs use bounded Monte Carlo Tree Search over legal capture-go moves.
The standard config currently uses explicit parameters for playout count,
rollout depth, candidate limit, exploration, rollout temperature, and capture
search depth. MCTS is the main local-search baseline for tactical fighting.

### Hybrid Tactical

Hybrid tactical configs combine heuristic candidate scoring with deeper search
budgets. They are intended to sit between simple heuristic play and full MCTS,
keeping move selection tactical while staying practical for local gameplay and
arena evaluation.

### KataGo ONNX

KataGo ONNX configs use a real ONNX model path with no heuristic fallback. If
the model or runtime is unavailable, the arena must report a structured failure
instead of silently substituting another bot. The current integration is useful
as a model-backed policy/search path, but its capture-go strength still depends
on the encoder, candidate policy, and search layer around the model.

## Tactical Safeguards

Capture-go is optimized around the five-capture win condition. The AI therefore
uses capture-specific safeguards instead of territory-first evaluation:

- immediate win and immediate-loss checks
- liberty and atari pressure scoring
- bounded capture search
- doomed-chain rescue penalties for positions where extending a chain only
  worsens the capture race
- repeatable twist-ladder sample generation for regression testing

The doomed-chain rescue penalty is designed to reduce the repeated mistake of
saving stones that are already tactically lost, especially in twist-ladder style
positions.

## Evaluation Model

Strength runs use a fixed hierarchy:

```text
Evaluation Run
  Pair: unordered configA vs configB
    Cell: board size + opening + first-player direction
      Game repeat #1
      Game repeat #2
```

Standard evaluation dimensions include:

- board sizes: 9x9, 13x13, and targeted 19x19 runs
- openings: empty, cross, and twist-cross
- both first-player directions
- repeated games per cell
- validation gates for illegal moves, timeouts, fallback games, failure
  reasons, bad repeats, and bad dimensions

## Current Capability Snapshot

The current AI stack can run real headless pairwise matches between MCTS and
KataGo ONNX without fallback. Recent targeted results show that KataGo ONNX
Standard is strong on 9x9 against MCTS Standard, while MCTS Standard remains
competitive or stronger on 13x13 contact-heavy openings. Treat these as
evaluation evidence, not as a claim of professional-strength Go play.

## Code Map

- `lib/game/ai_algorithm_framework.dart`: framework/config registry and stable
  algorithm IDs.
- `lib/game/capture_ai.dart`: heuristic and hybrid capture-go move selection.
- `lib/game/mcts_engine.dart`: MCTS search and tactical scoring helpers.
- `lib/game/katago_flutter_onnx_model_adapter.dart`: Flutter ONNX model adapter.
- `lib/game/ai_arena_executor.dart`: repeatable pairwise arena execution.
- `tool/headless_full_matrix_arena_probe.dart`: headless strength-matrix runner.
- `tool/twist_ladder_template_generator.dart`: generated twist-ladder samples.

## Related Documents

- [AI Arena Runner](ai-arena-runner.md)
- [Capture AI Framework Tuning Notes](../ai_eval/capture-ai-framework-tuning-notes.md)
- [Capture AI Algorithm Optimization Plan](../plans/2026-05-08-16-20-+08-capture-ai-algorithm-optimization.md)
- [Capture AI Framework Arena Plan](../plans/2026-05-19-00-46-+08-capture-ai-framework-arena.md)
