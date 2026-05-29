# Capture5 Phase G Ladder Arena Results

- Source JSON: `docs/ai_eval/runs/2026-05-30-13x13-capture5-mcts-five-option-ladder.json`
- Board: [13] capture-five
- Openings: empty, cross, twistCross
- Repeat per direction: 3
- Cells: 60 / 60
- Games: 180 / 180
- Scheduling: fixed with 4 workers

Each matrix cell is the row config perspective as `W-L-D` over six games for that opening: both first-player directions, three repeats each.

## Config IDs

- MCTS Weak: `mcts_counter_weak_v1`
- MCTS Standard: `mcts_counter_standard_v1`
- Capture5 Phase G: `capture5_13x13_11p_resnet_phase_g_tactical005_expected`
- MCTS+Capture5 Weak: `mcts_capture5_weak_v1`
- MCTS+Capture5 Standard: `mcts_capture5_standard_v1`

## Empty Opening

| Row config | MCTS Weak | MCTS Standard | Capture5 Phase G | MCTS+Capture5 Weak | MCTS+Capture5 Standard |
| --- | ---: | ---: | ---: | ---: | ---: |
| MCTS Weak | - | 0-5-1 | 6-0-0 | 3-3-0 | 5-1-0 |
| MCTS Standard | 5-0-1 | - | 6-0-0 | 6-0-0 | 6-0-0 |
| Capture5 Phase G | 0-6-0 | 0-6-0 | - | 0-6-0 | 0-6-0 |
| MCTS+Capture5 Weak | 3-3-0 | 0-6-0 | 6-0-0 | - | 6-0-0 |
| MCTS+Capture5 Standard | 1-5-0 | 0-6-0 | 6-0-0 | 0-6-0 | - |

## Cross Opening

| Row config | MCTS Weak | MCTS Standard | Capture5 Phase G | MCTS+Capture5 Weak | MCTS+Capture5 Standard |
| --- | ---: | ---: | ---: | ---: | ---: |
| MCTS Weak | - | 1-5-0 | 5-1-0 | 5-1-0 | 6-0-0 |
| MCTS Standard | 5-1-0 | - | 6-0-0 | 6-0-0 | 6-0-0 |
| Capture5 Phase G | 1-5-0 | 0-6-0 | - | 0-6-0 | 0-6-0 |
| MCTS+Capture5 Weak | 1-5-0 | 0-6-0 | 6-0-0 | - | 6-0-0 |
| MCTS+Capture5 Standard | 0-6-0 | 0-6-0 | 6-0-0 | 0-6-0 | - |

## Twist Cross Opening

| Row config | MCTS Weak | MCTS Standard | Capture5 Phase G | MCTS+Capture5 Weak | MCTS+Capture5 Standard |
| --- | ---: | ---: | ---: | ---: | ---: |
| MCTS Weak | - | 0-6-0 | 6-0-0 | 4-1-1 | 4-2-0 |
| MCTS Standard | 6-0-0 | - | 6-0-0 | 6-0-0 | 6-0-0 |
| Capture5 Phase G | 0-6-0 | 0-6-0 | - | 1-5-0 | 0-6-0 |
| MCTS+Capture5 Weak | 1-4-1 | 0-6-0 | 5-1-0 | - | 2-4-0 |
| MCTS+Capture5 Standard | 2-4-0 | 0-6-0 | 6-0-0 | 4-2-0 | - |

## Validation

- Random games: 0
- Illegal moves: 0
- Timeouts: 0
- Fallback games: 0
- Failure reasons: 0
- Bad repeat cells: 0
- Bad dimension cells: 0
