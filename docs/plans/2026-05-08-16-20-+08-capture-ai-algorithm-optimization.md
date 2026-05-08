# Capture AI Algorithm Optimization

## Background

### Context

The Capture AI now has an offline tactics evaluation harness with 134 problems on 9x9 and 13x13 boards. All problems use the product rule of winning by reaching at least five captured stones. The current hunter baseline shows that tactical strength does not improve much across difficulty levels: beginner reaches about 50.7% accepted moves, intermediate 54.5%, and advanced 54.5% on the current problem set.

The weakest named tactics are net/geta, shortage of liberties, snapback, connect-and-die, and self-atari punishment. Ladder performance is not yet reliable enough either, but the broader signal is that the AI is missing forcing-sequence judgment, sacrifice judgment, and target-count urgency.

### Problem

The current AI architecture mixes several decision paths that can disagree with each other. Urgent move selection can bypass MCTS, MCTS candidates are still shaped by local heuristic filtering, rollout scoring is shallow, and minimax safety checks have limited depth and candidate scope. This makes the AI good at obvious one-ply captures but weak at practical capture-game tactics where the best move may be a quiet block, sacrifice, net, throw-in, or target-count defense.

The current evaluation also shows that larger budgets in advanced difficulty do not create a clear tactical improvement over intermediate. This means the bottleneck is not only computation budget; it is the move-generation, evaluation, and decision-integration model.

### Motivation

The product goal is to win capture-go games under the five-capture rule. Algorithm work should therefore optimize for measurable win-relevant tactical strength, not for generic Go territory concepts or isolated pattern fixes. Every algorithm change should be accepted only if it improves the offline tactics baseline and does not regress legal-move stability or existing AI arena tests.

## Goals

- Make all tactical decision paths optimize the five-capture win condition consistently.
- Improve accepted-move rate and reduce severe blunders on the offline tactics set.
- Make advanced difficulty clearly stronger than intermediate on tactical positions.
- Cover practical capture-game tactics, including ladder, net/geta, snapback, throw-in, shortage of liberties, connect-and-die, edge/corner captures, self-atari punishment, sacrifice, and target-count defense.
- Preserve deterministic seeded behavior where the current tests require it.
- Keep runtime practical for 9x9 and 13x13 gameplay.

## Implementation Plan

1. Establish the baseline gate.
   - Treat `docs/ai_eval/latest.json` and `docs/ai_eval/hunter_all_difficulties_latest.json` as the current reference baseline.
   - Add a lightweight comparison mode to the probe so new reports can be compared against a saved baseline.
   - Track Top1, Top3, AcceptedAll, AcceptedAuth, severe blunder rate, and named tactic summaries.

2. Remove decision-path contradictions.
   - Replace hard early returns from urgent tactical selection with candidate injection into a unified tactical search path.
   - Keep urgent moves as high-priority candidates, but let search compare them against tenuki, sacrifice, counter-capture, and target-count defense moves.
   - Record the selected decision source in debug output so regressions can be traced.

3. Upgrade candidate generation for capture-go tactics.
   - Generate full-board legal candidates before tactical pruning.
   - Always include immediate wins, immediate opponent-win defenses, captures, ataris, liberty-reducing moves, rescues, counter-captures, snapback candidates, throw-ins, net candidates, and edge/corner liberties.
   - Preserve a bounded candidate horizon for runtime, but make the horizon tactical-priority based instead of only local-radius based.

4. Add a five-capture tactical evaluator.
   - Score distance to capture target, immediate over-target wins, opponent over-target threats, and value of captured stones under the five-capture rule.
   - Add sacrifice accounting: a move can be correct if it loses stones but prevents the opponent from reaching five or creates a larger forced capture.
   - Penalize repeated flight of doomed groups when the sequence worsens the capture race.
   - Add shape-independent features for liberties, shortage of liberties, snapback risk, net containment, and self-atari punishment.

5. Add bounded tactical sequence search.
   - Use a deterministic tactical minimax/negamax layer for forcing positions before or inside MCTS.
   - Search deeper only on forcing moves and target-count emergencies.
   - Stop early on terminal `captured >= 5` states, including moves that jump from four captures to six or more.
   - Return principal variation traces for failed problems so bad decisions are debuggable.

6. Rework MCTS rollout policy for capture-go.
   - Make rollouts prefer five-capture-relevant forcing moves over random local play.
   - Use terminal capture target outcome as the primary reward.
   - At rollout depth limit, evaluate by capture-target distance and tactical danger, not territory.
   - Tune beginner/intermediate/advanced budgets after the evaluator and candidate policy are fixed.

7. Calibrate difficulty levels.
   - Beginner may remain mostly heuristic, but must avoid immediate target-count blunders.
   - Intermediate should use unified tactical candidates plus shallow forcing search.
   - Advanced should add deeper forcing search, stronger rollout policy, and stricter sacrifice/doom detection.
   - Advanced must beat intermediate on the tactics harness by a meaningful margin before it is considered improved.

8. Iterate by tactic category.
   - Start with net/geta because it is currently near zero and is not solved by ladder-only fixes.
   - Then address shortage of liberties and snapback because they expose sacrifice and delayed-capture modeling gaps.
   - Then address ladder/flight and connect-and-die because they require multi-ply forced sequence judgment.
   - Re-run full reports after each tactic family improvement.

## Acceptance Criteria

- The default tactics probe rejects any problem set that is not configured for `captureTarget=5`.
- Hunter advanced improves AcceptedAll from the current 54.5% baseline to at least 70% on the 134-problem tactics set.
- Hunter advanced severe blunder rate drops from the current 35.1% baseline to at most 20%.
- Hunter advanced is at least 8 percentage points better than hunter intermediate on AcceptedAll.
- Named tactics improve from current weak baselines:
  - net/geta AcceptedAll reaches at least 50%.
  - shortage of liberties AcceptedAll reaches at least 60%.
  - snapback AcceptedAll reaches at least 60%.
  - ladder AcceptedAll reaches at least 80%.
- Existing Flutter tests still pass.
- Seeded MCTS behavior remains reproducible where tests assert reproducibility.
- Reports include enough trace detail to explain why a failed move lost under the five-capture rule.

## Validation Commands

- `dart analyze lib/game/capture_ai.dart lib/game/mcts_engine.dart lib/game/capture_ai_tactics.dart tool/capture_ai_tactics_probe.dart`
- `dart run tool/capture_ai_tactics_probe.dart --output=docs/ai_eval/latest.json --styles=hunter --difficulty=advanced --board-sizes=9,13 --capture-target=5 --oracle-depth=2 --oracle-horizon=6 --oracle-max-nodes=3000 --min-confidence-gap=80 --top-score-delta=80 --top-n-accepted=3 --max-accepted-move-ratio=0.25`
- `dart run tool/capture_ai_tactics_probe.dart --output=docs/ai_eval/hunter_all_difficulties_latest.json --styles=hunter --difficulty=all --board-sizes=9,13 --capture-target=5 --oracle-depth=2 --oracle-horizon=6 --oracle-max-nodes=3000 --min-confidence-gap=80 --top-score-delta=80 --top-n-accepted=3 --max-accepted-move-ratio=0.25`
- `flutter test`
