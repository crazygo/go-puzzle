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
