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
- low-liberty rescue penalties for newly formed two-liberty chains when the
  move saves stones but does not create an immediate capture payoff
- immediate opponent-capture penalties for moves that win a local capture but
  allow the opponent to reach the five-capture target on the next move
- repeatable tactical trap sample generation for regression testing

The doomed-chain rescue penalty is designed to reduce the repeated mistake of
saving stones that are already tactically lost, especially in twist-ladder style
positions. The low-liberty rescue penalty covers cases where the first saved
group is small, but the chase can transfer into a larger capture later in the
sequence. The immediate opponent-capture penalty covers snapback-like failures
where the AI captures a sacrifice stone and hands the opponent a legal
five-capture recapture.

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

Tactical trap evaluation uses a separate corpus-oriented hierarchy:

```text
Trap Corpus
  Family: doomed rescue, connect-and-die, edge escape, net containment, throw-in
    Sample: fixed board state, side to move, blunder move set, failure continuation, split
      Config result: selected move, legal status, blunder flag, proven failure flag, accepted flag
```

The current active trap families are:

- `doomed_rescue_twist_ladder`: extending a chased chain looks locally useful
  but keeps the chain tactically doomed.
- `edge_escape_dead_chain`: running along the side or corner looks like an
  escape, but the board edge leaves a finite last liberty that can be filled.
- `connect_and_die`: connecting two local chains looks positive, but the merged
  chain is short of liberties and can be captured immediately.
- `net_containment`: running through the apparent central escape route looks
  like it creates space, but surrounding stones above and below the route leave
  a final single liberty that can be filled.
- `throw_in_snapback`: capturing a thrown-in stone looks locally profitable,
  but the capture point becomes a legal recapture that takes the surrounding
  chain.

The corpus schema can add more continuation variants later without changing the
evaluator contract.

The evaluator reports `trapBlunderRate`, `provenFailures`, and
`acceptedMoveRate` overall, by family, by train/eval split, and by
family-and-split. Every active sample includes a `failureContinuation`: if a
config selects a labelled blunder, the evaluator replays the continuation from
the entry board and verifies that the forced line reaches the expected
five-capture loss. For moves outside the labelled blunder set,
`acceptedMoveRate` still means "legal and not a proven failure"; treat it as a
coarse baseline until each family has a broader outcome evaluator for
non-labelled moves.

## Current Capability Snapshot

The current AI stack can run real headless pairwise matches between MCTS and
KataGo ONNX without fallback. Recent targeted results show that KataGo ONNX
Standard is strong on 9x9 against MCTS Standard, while MCTS Standard remains
competitive or stronger on 13x13 contact-heavy openings. Treat these as
evaluation evidence, not as a claim of professional-strength Go play.

The current tactical trap corpus has 520 samples across five active families:
doomed-rescue twist ladders, edge escape dead chains, connect-and-die false
connections, net containment, and throw-in snapback. After adding the
low-liberty rescue and immediate opponent-capture penalties, all six native AI
configs have been evaluated on the full corpus. The standard native configs
have zero replay-proven failures, and the weak native MCTS/hybrid tiers each
remain at one replay-proven failure while still above 99% accepted moves. The
standard configs also have zero failures on the 156-sample eval holdout split.
The before/after comparison probe matches
baseline and after samples by `sampleId`; on the same 520-sample corpus, MCTS
standard replay-proven failures dropped from 83 to 0, and accepted move rate
rose from 84.0% to 100%. MCTS standard also passed a 9x9 non-regression arena
check against MCTS weak, winning 11 of 12 games with no illegal moves,
timeouts, fallback games, or failure reasons.

The same trap evaluator can run through the Node ONNX adapter for KataGo-backed
configs. Across the full 520-sample corpus, both `katago_onnx_weak_v1` and
`katago_onnx_standard_v1` recorded zero replay-proven failures and 100%
accepted moves. The weak ONNX tier reaches that result by using a shallow
capture-search safety pass after the model policy; it remains weaker by policy
temperature and candidate breadth, not by ignoring immediate tactical losses.

## Code Map

- `lib/game/ai_algorithm_framework.dart`: framework/config registry and stable
  algorithm IDs.
- `lib/game/capture_ai.dart`: heuristic and hybrid capture-go move selection.
- `lib/game/mcts_engine.dart`: MCTS search and tactical scoring helpers.
- `lib/game/katago_flutter_onnx_model_adapter.dart`: Flutter ONNX model adapter.
- `lib/game/ai_arena_executor.dart`: repeatable pairwise arena execution.
- `tool/headless_full_matrix_arena_probe.dart`: headless strength-matrix runner.
- `tool/twist_ladder_template_generator.dart`: generated twist-ladder samples.
- `tool/tactical_trap_corpus_generator.dart`: unified trap corpus generator.
- `tool/tactical_trap_eval_probe.dart`: selected-config trap blunder evaluator.
- `tool/tactical_trap_compare_probe.dart`: before/after sample-intersection
  metric comparison.
- `tool/node_katago_onnx_model_adapter.dart`: Node ONNX adapter shared by
  headless tactical and arena probes.
- `docs/ai_eval/tactics/tactical_trap_corpus.json`: generated trap corpus.

## Related Documents

- [AI Arena Runner](ai-arena-runner.md)
- [Capture AI Framework Tuning Notes](../ai_eval/capture-ai-framework-tuning-notes.md)
- [Capture AI Algorithm Optimization Plan](../plans/2026-05-08-16-20-+08-capture-ai-algorithm-optimization.md)
- [Capture AI Framework Arena Plan](../plans/2026-05-19-00-46-+08-capture-ai-framework-arena.md)
