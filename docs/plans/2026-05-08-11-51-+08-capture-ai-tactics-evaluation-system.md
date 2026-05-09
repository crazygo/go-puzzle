# Capture AI Tactics Evaluation System

## Background

### Context

The Capture AI currently plays the capture-stones variant on 9x9, 13x13, and 19x19 boards. For this effort, the tactical evaluation scope is intentionally limited to 9x9 and 13x13 boards. The goal is not to add CI unit tests first, but to build an offline AI training and evaluation system that can prove the current AI's tactical weaknesses, measure improvement over time, and provide trustworthy training signals.

### Problem

The current AI has no dedicated tactical benchmark or trusted reference solver. Existing tests mostly verify legal move generation, reproducibility, and playable matches. They do not prove whether the AI understands group fate, capture races, sacrifice exchanges, multi-threat positions, or traps. Without a verified evaluation system, any algorithm change risks being judged by intuition or by hand-authored tactical answers that may themselves be wrong.

### Motivation

The tactical dataset is foundational. If the problems or labels are wrong, later AI improvements will optimize toward bad behavior. The evaluation system must therefore prioritize answer correctness through reproducible oracle computation, search traces, board symmetries, and holdout measurement before it is used to guide algorithm changes.

## Goals

- Build an offline tactical evaluation system for 9x9 and 13x13 Capture AI positions, explicitly excluding 19x19 from the first version.
- Use a high-cost oracle solver as the trusted reference for tactical scoring instead of relying only on manually labeled good and bad moves.
- Quantify current AI weakness by category before changing the AI algorithm.
- Support training, validation, and holdout problem splits so improvements can be measured without overfitting.
- Keep the system out of the normal CI flow; it should run through explicit developer commands.
- Produce human-readable reports and machine-readable artifacts that show baseline strength, category pass rates, oracle confidence, and regression risk.

## Implementation Plan

1. Define tactical problem and result formats.
   - Add a JSON fixture schema for board size, capture target, current player, ASCII diagram, category, objective, oracle configuration, and metadata.
   - Add result artifacts for per-problem AI move choice, oracle score, rank, confidence, search trace summary, and category aggregation.
   - Restrict accepted board sizes to 9 and 13 in the loader.

2. Implement a deterministic tactical oracle.
   - Start with a bounded tactical search that can run much deeper than the real-time AI because it is offline.
   - Expand forcing moves first: immediate captures, atari moves, rescues, counter-captures, captureTarget wins, and captureTarget defenses.
   - Score positions by capture race outcome, capture margin, expected group loss, and terminal win/loss when reachable.
   - Emit trace summaries explaining why top moves are preferred and why clearly losing moves are bad.

3. Add high-confidence validation mechanisms.
   - Run board transformations for every problem: horizontal mirror, vertical mirror, rotation where valid, and color swap where the objective remains equivalent.
   - Require oracle stability across deterministic seeds or search configurations before labeling a problem as high confidence.
   - Mark uncertain positions as exploratory rather than authoritative.

4. Build the AI tactics probe CLI.
   - Run selected Capture AI style and difficulty configurations against the fixture set.
   - Compare AI choices against oracle-ranked moves instead of only exact manually listed answers.
   - Report category pass rates, move-rank distributions, severe blunders, and captureTarget race failures.
   - Write timestamped reports under `docs/ai_eval/` or another explicit artifact directory.

5. Create the first curated problem set.
   - Start with 30-50 positions across group fate, capture race, sacrifice exchange, multi-threat, and tactical trap categories.
   - Include ladder positions only as examples of group fate, not as a separate hardcoded algorithm target.
   - Keep authored metadata human-readable, but allow oracle output to determine scoring.

6. Record the current AI baseline.
   - Run beginner, intermediate, and advanced configurations on 9x9 and 13x13.
   - Save baseline reports showing current weaknesses by category.
   - Use this baseline as the reference for later improvement rates.

7. Prepare for later training-system use.
   - Separate fixture splits into training, validation, and holdout groups.
   - Keep holdout problems excluded from tuning.
   - Add report comparisons that show improvement, regression, and category drift between two runs.

## Acceptance Criteria

- A new worktree branch exists for the effort: `feature/capture-ai-tactics-eval` at `.worktree/capture-ai-tactics-eval/`.
- The tactical evaluation design explicitly supports only 9x9 and 13x13 boards in the first version.
- The plan distinguishes benchmark/training evaluation from CI unit tests and keeps the new system out of mandatory CI.
- The proposed oracle design does not depend only on hand-authored good-move labels.
- The evaluation approach can prove current AI weakness before any AI algorithm changes are made.
- The system design includes validation against bad tactical data through oracle traces, symmetry checks, confidence levels, and holdout splits.

## Validation Commands

- `dart format tool test lib`
- `dart analyze`
- `flutter test`
- `dart run tool/capture_ai_tactics_probe.dart --board-sizes=9,13 --difficulty=advanced --output=docs/ai_eval/latest.json`
