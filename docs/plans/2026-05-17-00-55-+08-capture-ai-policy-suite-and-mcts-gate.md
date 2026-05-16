# Capture AI Policy Suite and MCTS Gate

## Background

### Context

The Capture AI already has tactical oracle probes, arena-style AI-versus-AI checks, and a first scripted-trial prototype. The prototype can run fixed openings against a scripted opponent and produce JSON reports, but the newly named tactics must not be treated as covered until each one has a real policy implementation and a fixture that proves the scripted opponent is actually playing that tactical pattern.

The target AI is `hunter/advanced`. The final gate must cover 9x9, 13x13, and 19x19 capture-go games under the five-capture rule.

### Problem

The current scripted trial prototype is not yet sufficient as a strength gate. Some tactics are represented only as enum names or broad local scoring weights. That can create false confidence: a report might say that ladder, net, snapback, or ko-fight behavior is covered even when no policy actually reads those tactical sequences.

The advanced AI also cannot be improved by simply increasing MCTS playouts. The user requires a hard runtime bound: every `hunter/advanced` move in the policy suite must complete within 5 seconds. The optimization therefore needs bounded tactical reading, deadline-aware search, and checkpointed measurement instead of unbounded compute.

### Motivation

The goal is to make AI strength measurable against practical player tactics. If a human can repeatedly beat the AI with a fixed trick, that trick should become a durable, reproducible policy test. Each AI improvement must be tied to a score and commit id so regressions and overfitting can be tracked.

## Goals

- Build a real policy-driven scripted trial suite, not a name-only enum list.
- Implement tactic policies that simulate concrete classes of player behavior: immediate capture, atari, rescue, counter-atari, self-atari bait, edge clamp, ladder chase, net containment, snapback, liberty shortage, connect-and-die, sacrifice race, ko fight, and throw-in.
- Add fixture tests that prove each policy chooses moves consistent with its tactical meaning.
- Run the suite across 9x9, 13x13, and 19x19 boards.
- Run each trial with AI as both black and white.
- Optimize `hunter/advanced` so it wins or draws every policy trial.
- Enforce a maximum `hunter/advanced` move time of 5 seconds in the policy suite.
- Record before, during, and after optimization checkpoints using commit id plus score.

## Implementation Plan

1. Replace the scripted-opponent scoring switch with explicit policy objects.
   - Introduce a `CaptureAiTrialPolicy` interface with `chooseMove`, `id`, and optional diagnostic metadata.
   - Keep the existing trial runner shape, but route scripted moves through the selected policy.
   - Remove or quarantine any tactic that does not yet have a real policy implementation.

2. Implement verified policy behavior.
   - `captureFirst`: enumerate legal immediate captures and choose the largest capture, with deterministic tie-breaking.
   - `atariFirst`: enumerate legal moves that put opponent groups in atari.
   - `rescueFirst`: identify own groups in atari and choose moves that save or increase their liberties.
   - `counterAtari`: prefer moves that atari an opponent while accepting or responding to local atari pressure.
   - `selfAtariBait`: choose self-atari moves only when short lookahead shows a follow-up capture or tactical gain.
   - `edgeClamp`: prefer edge/corner containment moves that reduce escape space near the side.
   - `ladderChase`: simulate chase-and-escape sequences and only classify a move as ladder pressure when the chase remains forcing.
   - `netContain`: choose containment moves that reduce outside liberties without immediately chasing into a ladder.
   - `snapback`: use short lookahead to validate sacrifice-then-recapture patterns.
   - `libertyShortage`: score moves by actual opponent group liberty reduction and multi-group shortage pressure.
   - `connectAndDie`: simulate connection moves and punish shapes where connected stones become easier to capture.
   - `sacrificeRace`: evaluate short capture-race sequences where losing stones may be correct if it wins the five-capture race.
   - `koFight`: explicitly detect single-stone capture and ko-forbidden recapture states before treating a move as ko-related.
   - `throwIn`: validate throw-in moves by checking self-sacrifice plus reduced opponent liberties or follow-up capture.

3. Add policy fixture tests.
   - Create focused board fixtures for every policy.
   - Assert that each policy selects the expected tactical move or one of a small accepted tactical set.
   - Assert that policy fixtures are deterministic.
   - Keep fixture tests lightweight and suitable for normal `flutter test`.

4. Add timing instrumentation to the trial runner.
   - Measure every AI move duration.
   - Store `maxMoveMs`, `p95MoveMs`, `p99MoveMs`, and `slowMovesOver5s` in JSON reports.
   - Mark a trial as failed if any `hunter/advanced` move exceeds 5 seconds.
   - Keep scripted policy move timing separate from AI timing.

5. Expand the policy suite gate.
   - Run board sizes `9,13,19`.
   - Run the fixed opening catalog for each board size.
   - Run every implemented policy.
   - Run both AI sides: black and white.
   - Final intended suite size is `3 board sizes * 5 openings * 14 policies * 2 AI sides = 420 trials`.

6. Capture the baseline checkpoint before AI optimization.
   - Commit the real policy suite and fixtures.
   - Run the full 420-trial suite against the current `hunter/advanced`.
   - Save a checkpoint record containing commit id, suite id, total trials, passed, failed, score, failed policies, failed board sizes, max/p95/p99 move times, slow move count, and report path.

7. Optimize `hunter/advanced` under the 5-second budget.
   - Add deadline-aware tactical search before MCTS for forced wins, forced defenses, captures, rescues, ladders, nets, snapbacks, and race emergencies.
   - Make MCTS consume only the remaining time budget after fast tactical checks.
   - Ensure every search layer can return the best known candidate before the 5-second deadline.
   - Prefer algorithmic tactical reading over simply raising playout counts.

8. Record intermediate checkpoints.
   - After each meaningful AI change, commit the change and run the policy suite or a named subset.
   - Append checkpoint rows with commit id plus score and timing.
   - Use the same report schema so before/mid/after results are comparable.

9. Finalize the gate.
   - Run the full 420-trial suite.
   - Run normal static and unit validation.
   - Record the final checkpoint with commit id and score.

## Acceptance Criteria

- Every named policy has a concrete implementation that simulates the corresponding tactic instead of relying on enum names or generic weights only.
- Every named policy has at least one fixture test proving that it selects a tactic-appropriate move.
- The policy suite supports 9x9, 13x13, and 19x19 boards.
- The policy suite supports AI as both black and white.
- The full gate contains 420 trials when all 14 policies are enabled.
- `hunter/advanced` wins or draws every full-gate trial.
- No trial ends with `invalidMove`.
- Every `hunter/advanced` move in the full gate completes in 5 seconds or less.
- JSON reports include per-trial outcome, per-policy outcome, per-board outcome, AI move timing summary, and slow-move details.
- Checkpoints are recorded before optimization, during optimization, and after final optimization.
- Each checkpoint includes commit id, suite id, total trials, passed, failed, score, failed policies, failed board sizes, max/p95/p99 move times, slow move count, and report path.

## Validation Commands

- `dart analyze lib/game/capture_ai_scripted_trials.dart tool/capture_ai_scripted_trials_probe.dart test/capture_ai_scripted_trials_test.dart`
- `flutter test test/capture_ai_scripted_trials_test.dart`
- `dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9,13,19 --ai-side both --max-ai-move-ms 5000 --output build/ai_eval/scripted_policy_gate.json`
- `flutter test`
