# Scripted Policy Checkpoints

This file records reproducible checkpoints for the capture AI scripted policy
gate. Full-gate targets are defined in
`docs/plans/2026-05-17-00-55-+08-capture-ai-policy-suite-and-mcts-gate.md`.

## Checkpoints

| Checkpoint | Commit | Suite | Scope | Trials | Passed | Failed | Score | Max AI Move | Slow Moves | Report |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| baseline-partial-001 | `7ef7cd0` | `scripted_policy_v1` | 9x9, AI black, first 20 selected trials, max 80 moves | 20 | 17 | 3 | 0.8500 | 2522ms | 0 | `build/ai_eval/scripted_policy_partial_baseline_7ef7cd0.json` |

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
