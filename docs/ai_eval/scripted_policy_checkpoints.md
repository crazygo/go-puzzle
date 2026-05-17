# Scripted Policy Checkpoints

This file records reproducible checkpoints for the capture AI scripted policy
gate. Full-gate targets are defined in
`docs/plans/2026-05-17-00-55-+08-capture-ai-policy-suite-and-mcts-gate.md`.

## Checkpoints

| Checkpoint | Commit | Suite | Scope | Trials | Passed | Failed | Score | Max AI Move | Slow Moves | Report |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| baseline-partial-001 | `7ef7cd0` | `scripted_policy_v1` | 9x9, AI black, first 20 selected trials, max 80 moves | 20 | 17 | 3 | 0.8500 | 2522ms | 0 | `build/ai_eval/scripted_policy_partial_baseline_7ef7cd0.json` |
| optimization-empty-002 | `0b3abb2` | `scripted_policy_v1` | 9x9 empty opening, AI black, all 14 policies, max 80 moves | 14 | 14 | 0 | 1.0000 | 4046ms | 0 | `build/ai_eval/empty_all_policies_after_large_fallback.json` |
| optimization-large-sample-002 | `0b3abb2` | `scripted_policy_v1` | 13x13 and 19x19 empty opening, AI black, captureFirst/rescueFirst/netContain, max 80 moves | 6 | 6 | 0 | 1.0000 | 67ms | 0 | `build/ai_eval/advanced_large_key_after_heuristic_fallback.json` |
| optimization-black-003 | `b0ae660` | `scripted_policy_v1` | 9x9 empty opening, AI black, all 14 policies, max 80 moves | 14 | 14 | 0 | 1.0000 | 4054ms | 0 | `build/ai_eval/empty_all_policies_black_after_spacing.json` |
| optimization-white-003 | `b0ae660` | `scripted_policy_v1` | 9x9 empty opening, AI white, all 14 policies, max 80 moves | 14 | 13 | 1 | 0.9286 | 4826ms | 0 | `build/ai_eval/empty_all_policies_white_after_spacing.json` |
| optimization-white-004 | `8bd277a` | `scripted_policy_v1` | 9x9 empty opening, AI white, all 14 policies, max 80 moves | 14 | 14 | 0 | 1.0000 | 4318ms | 0 | `build/ai_eval/empty_all_policies_white_final_candidate.json` |
| large-progress-005 | `3c4bb61` | `scripted_policy_v1` | interrupted 13x13/19x19 full-gate run, first 48 completed trials | 48 | 48 | 0 | 1.0000 | 73ms | 0 | `build/ai_eval/large_boards_full_policy_gate_candidate.jsonl` |
| twist-cross-a-006 | `2fb6eb9` | `scripted_policy_v1` | 9x9 twistCrossA opening, AI both sides, all 14 policies, max 80 moves | 28 | 21 | 7 | 0.7500 | 5188ms | 1 | `build/ai_eval/b9_twistCrossA_both_sides_policy_gate.json` |
| twist-cross-a-007 | `89467c6` | `scripted_policy_v1` | 9x9 twistCrossA opening, AI both sides, all 14 policies, max 80 moves | 28 | 23 | 5 | 0.8214 | 3933ms | 0 | `build/ai_eval/b9_twistCrossA_after_twist_black_fallback.json` |
| twist-cross-a-008 | `cc79aa9` | `scripted_policy_v1` | 9x9 twistCrossA opening, AI both sides, all 14 policies, max 80 moves | 28 | 28 | 0 | 1.0000 | 3976ms | 0 | `build/ai_eval/b9_twistCrossA_after_twist_white_edge_guard.json` |
| nine-by-nine-full-009 | `41bd073` | `scripted_policy_v1` | 9x9, all 5 openings, AI both sides, all 14 policies, max 80 moves | 140 | 140 | 0 | 1.0000 | 4949ms | 0 | `build/ai_eval/b9_*_after_*_gate_fix.json` |

### baseline-partial-001

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side black --max-ai-move-ms 5000 --max-moves 80 --stop-after 20 --progress-every 5 --output build/ai_eval/scripted_policy_partial_baseline_7ef7cd0.json --output-log build/ai_eval/scripted_policy_partial_baseline_7ef7cd0.jsonl
```

Failures:

| Trial | Policy | Opening | AI Side | Result | Max AI Move |
| --- | --- | --- | --- | --- | ---: |
| `empty_rescueFirst_b9` | `rescueFirst` | `empty` | black | scripted won, captures 0-5, 34 moves | 2056ms |
| `twistCrossA_captureFirst_b9` | `captureFirst` | `twistCrossA` | black | scripted won, captures 0-6, 32 moves | 2142ms |
| `twistCrossA_rescueFirst_b9` | `rescueFirst` | `twistCrossA` | black | scripted won, captures 0-6, 32 moves | 2134ms |

Notes:

- This is a partial baseline, not the final 420-trial gate.
- No AI move exceeded the 5-second limit in this checkpoint.
- The first tactical weakness to target is five-capture race defense against
  `captureFirst` and `rescueFirst` pressure.

### optimization-empty-002

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side black --openings empty --max-ai-move-ms 5000 --max-moves 80 --progress-every 2 --output build/ai_eval/empty_all_policies_after_large_fallback.json --output-log build/ai_eval/empty_all_policies_after_large_fallback.jsonl
```

Result:

- Trials: 14
- Passed: 14
- Failed: 0
- Score: 1.0000
- Max AI move: 4046ms
- p95 / p99 AI move: 3390ms / 3707ms
- Slow moves over 5000ms: 0

Notes:

- Covers every currently implemented scripted policy on the empty 9x9 opening.
- This is still a partial gate: it does not cover all five openings, AI white,
  or every 13x13/19x19 policy combination.

### optimization-large-sample-002

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 13,19 --ai-side black --openings empty --tactics captureFirst,rescueFirst,netContain --max-ai-move-ms 5000 --max-moves 80 --progress-every 1 --output build/ai_eval/advanced_large_key_after_heuristic_fallback.json
```

Result:

- Trials: 6
- Passed: 6
- Failed: 0
- Score: 1.0000
- Max AI move: 67ms
- p95 / p99 AI move: 62ms / 65ms
- Slow moves over 5000ms: 0

Notes:

- Covers the large-board regression policies that exposed both strength and
  runtime failures during optimization.
- This is a large-board sample, not the final 13x13/19x19 full policy gate.

### optimization-black-003

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side black --openings empty --max-ai-move-ms 5000 --max-moves 80 --progress-every 2 --output build/ai_eval/empty_all_policies_black_after_spacing.json --output-log build/ai_eval/empty_all_policies_black_after_spacing.jsonl
```

Result:

- Trials: 14
- Passed: 14
- Failed: 0
- Score: 1.0000
- Max AI move: 4054ms
- p95 / p99 AI move: 3242ms / 3511ms
- Slow moves over 5000ms: 0

Notes:

- Confirms the AI-black empty-opening 9x9 gate remains green after reducing
  the 9x9 tactical node budget and adding the AI-white spacing fallback.

### optimization-white-003

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side white --openings empty --max-ai-move-ms 5000 --max-moves 80 --progress-every 2 --output build/ai_eval/empty_all_policies_white_after_spacing.json --output-log build/ai_eval/empty_all_policies_white_after_spacing.jsonl
```

Result:

- Trials: 14
- Passed: 13
- Failed: 1
- Score: 0.9286
- Max AI move: 4826ms
- p95 / p99 AI move: 3465ms / 3977ms
- Slow moves over 5000ms: 0

Failure:

| Trial | Policy | Opening | AI Side | Result | Max AI Move |
| --- | --- | --- | --- | --- | ---: |
| `empty_netContain_b9` | `netContain` | `empty` | white | scripted won, captures 7-3, 69 moves | 3480ms |

Notes:

- This checkpoint improves AI-white empty-opening coverage from 8/14 to 13/14
  while keeping every AI move under 5 seconds.
- The remaining immediate target is AI-white defense against `netContain`.

### optimization-white-004

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side white --openings empty --max-ai-move-ms 5000 --max-moves 80 --progress-every 2 --output build/ai_eval/empty_all_policies_white_final_candidate.json --output-log build/ai_eval/empty_all_policies_white_final_candidate.jsonl
```

Result:

- Trials: 14
- Passed: 14
- Failed: 0
- Score: 1.0000
- Max AI move: 4318ms
- p95 / p99 AI move: 3316ms / 4097ms
- Slow moves over 5000ms: 0

Notes:

- Confirms AI-white empty-opening 9x9 coverage is green for all 14 policies.
- This still does not cover all openings or full 13x13/19x19 policy matrices.

### large-progress-005

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 13,19 --ai-side both --max-ai-move-ms 5000 --max-moves 80 --progress-every 20 --output build/ai_eval/large_boards_full_policy_gate_candidate.json --output-log build/ai_eval/large_boards_full_policy_gate_candidate.jsonl
```

Result from completed JSONL rows before manual interruption:

- Trials: 48
- Passed: 48
- Failed: 0
- Score: 1.0000
- Max AI move: 73ms
- Slow moves over 5000ms: 0

Notes:

- The run was manually interrupted because the full 280-trial large-board gate
  was too slow as a single command.
- Completed rows covered the early 13x13 AI-black portion of the full ordering.
- This is progress evidence only, not a substitute for the final 13x13/19x19
  full gate.

### twist-cross-a-006

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side both --openings twistCrossA --max-ai-move-ms 5000 --max-moves 80 --progress-every 4 --output build/ai_eval/b9_twistCrossA_both_sides_policy_gate.json --output-log build/ai_eval/b9_twistCrossA_both_sides_policy_gate.jsonl
```

Result:

- Trials: 28
- Passed: 21
- Failed: 7
- Score: 0.7500
- Max AI move: 5188ms
- Slow moves over 5000ms: 1

Failures:

| Trial | Policy | Opening | AI Side | Result | Max AI Move |
| --- | --- | --- | --- | --- | ---: |
| `twistCrossA_rescueFirst_b9` | `rescueFirst` | `twistCrossA` | black | scripted won, captures 0-5, 34 moves | 2963ms |
| `twistCrossA_edgeClamp_b9` | `edgeClamp` | `twistCrossA` | black | scripted won, captures 0-5, 42 moves | 5188ms |
| `twistCrossA_captureFirst_b9` | `captureFirst` | `twistCrossA` | white | scripted won, captures 13-0, 63 moves | 2748ms |
| `twistCrossA_rescueFirst_b9` | `rescueFirst` | `twistCrossA` | white | scripted won, captures 16-1, 69 moves | 2680ms |
| `twistCrossA_netContain_b9` | `netContain` | `twistCrossA` | white | scripted won, captures 8-2, 67 moves | 3357ms |
| `twistCrossA_connectAndDie_b9` | `connectAndDie` | `twistCrossA` | white | scripted won, captures 5-1, 47 moves | 2586ms |
| `twistCrossA_koFight_b9` | `koFight` | `twistCrossA` | white | scripted won, captures 13-0, 63 moves | 2576ms |

Notes:

- This identifies non-empty opening handling as the next optimization target.
- It also reintroduces a 5-second budget violation on `edgeClamp` as AI black.

### twist-cross-a-007

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side both --openings twistCrossA --max-ai-move-ms 5000 --max-moves 80 --progress-every 4 --output build/ai_eval/b9_twistCrossA_after_twist_black_fallback.json --output-log build/ai_eval/b9_twistCrossA_after_twist_black_fallback.jsonl
```

Result:

- Trials: 28
- Passed: 23
- Failed: 5
- Score: 0.8214
- Max AI move: 3933ms
- Slow moves over 5000ms: 0

Failures:

| Trial | Policy | Opening | AI Side | Result | Max AI Move |
| --- | --- | --- | --- | --- | ---: |
| `twistCrossA_captureFirst_b9` | `captureFirst` | `twistCrossA` | white | scripted won, captures 13-0, 63 moves | 2621ms |
| `twistCrossA_rescueFirst_b9` | `rescueFirst` | `twistCrossA` | white | scripted won, captures 16-1, 69 moves | 2625ms |
| `twistCrossA_netContain_b9` | `netContain` | `twistCrossA` | white | scripted won, captures 8-2, 67 moves | 3330ms |
| `twistCrossA_connectAndDie_b9` | `connectAndDie` | `twistCrossA` | white | scripted won, captures 5-1, 47 moves | 2598ms |
| `twistCrossA_koFight_b9` | `koFight` | `twistCrossA` | white | scripted won, captures 13-0, 63 moves | 2668ms |

Notes:

- The twist-opening black fallback cleared both AI-black failures from
  `twist-cross-a-006` and removed the only 5-second violation in that suite.
- Remaining failures are all AI-white twistCrossA cases.

### twist-cross-a-008

Command:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side both --openings twistCrossA --max-ai-move-ms 5000 --max-moves 80 --progress-every 4 --output build/ai_eval/b9_twistCrossA_after_twist_white_edge_guard.json --output-log build/ai_eval/b9_twistCrossA_after_twist_white_edge_guard.jsonl
```

Result:

- Trials: 28
- Passed: 28
- Failed: 0
- Score: 1.0000
- Max AI move: 3976ms
- p95 / p99 AI move: 2932ms / 3420ms
- Slow moves over 5000ms: 0

Notes:

- Confirms the 9x9 `twistCrossA` opening is green for AI as both black and
  white across all 14 scripted policies.
- This is still an opening-level checkpoint. It is not a substitute for the
  final 420-trial gate across all openings, 9x9/13x13/19x19 boards, and both
  AI sides.

### nine-by-nine-full-009

Commands:

```sh
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side both --openings empty --max-ai-move-ms 5000 --max-moves 80 --progress-every 4 --output build/ai_eval/b9_empty_after_node800_diagonal_gate_fix.json --output-log build/ai_eval/b9_empty_after_node800_diagonal_gate_fix.jsonl
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side both --openings twistCrossA --max-ai-move-ms 5000 --max-moves 80 --progress-every 4 --output build/ai_eval/b9_twistCrossA_after_node800_horizontal_delegate.json --output-log build/ai_eval/b9_twistCrossA_after_node800_horizontal_delegate.jsonl
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side both --openings twistCrossB --max-ai-move-ms 5000 --max-moves 80 --progress-every 4 --output build/ai_eval/b9_twistCrossB_after_node800_horizontal_delegate.json --output-log build/ai_eval/b9_twistCrossB_after_node800_horizontal_delegate.jsonl
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side both --openings twistCrossC --max-ai-move-ms 5000 --max-moves 80 --progress-every 4 --output build/ai_eval/b9_twistCrossC_after_diagonal_gate_fix.json --output-log build/ai_eval/b9_twistCrossC_after_diagonal_gate_fix.jsonl
dart run tool/capture_ai_scripted_trials_probe.dart --style hunter --difficulty advanced --board-sizes 9 --ai-side both --openings twistCrossD --max-ai-move-ms 5000 --max-moves 80 --progress-every 4 --output build/ai_eval/b9_twistCrossD_after_diagonal_gate_fix.json --output-log build/ai_eval/b9_twistCrossD_after_diagonal_gate_fix.jsonl
```

Result:

- Trials: 140
- Passed: 140
- Failed: 0
- Score: 1.0000
- Max AI move: 4949ms
- Slow moves over 5000ms: 0

Per-opening reports:

| Opening | Trials | Passed | Failed | Max AI Move | p95 / p99 AI Move | Slow Moves |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `empty` | 28 | 28 | 0 | 4949ms | 3460ms / 4079ms | 0 |
| `twistCrossA` | 28 | 28 | 0 | 3930ms | 2877ms / 3246ms | 0 |
| `twistCrossB` | 28 | 28 | 0 | 4016ms | 2824ms / 3216ms | 0 |
| `twistCrossC` | 28 | 28 | 0 | 2693ms | 1324ms / 1588ms | 0 |
| `twistCrossD` | 28 | 28 | 0 | 2246ms | 1358ms / 1713ms | 0 |

Validation:

- `dart analyze lib/game/capture_ai.dart`
- `flutter test test/capture_ai_scripted_trials_test.dart`
- `flutter test test/capture_ai_evaluation_test.dart`

Notes:

- This checkpoint confirms the full 9x9 opening/policy/side matrix.
- It is still not the final goal because 13x13 and 19x19 full policy gates
  remain to be completed.
