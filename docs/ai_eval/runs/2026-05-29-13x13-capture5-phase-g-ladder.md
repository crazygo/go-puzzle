# Capture5 Phase G Ladder Arena Results

- Source JSON: `docs/ai_eval/runs/2026-05-29-13x13-capture5-phase-g-ladder.json`
- Board: [13] capture-five
- Openings: empty, cross, twistCross
- Repeat per direction: 3
- Cells: 36 / 36
- Games: 108 / 108
- Scheduling: fixed with 4 workers

Each matrix cell is the row config perspective as `W-L-D` over six games for that opening: both first-player directions, three repeats each.

## Config IDs

- Capture5 Phase G: `capture5_13x13_11p_resnet_phase_g_tactical005_expected`
- MCTS Standard: `mcts_counter_standard_v1`
- Hybrid Tactical Standard: `hybrid_tactical_counter_standard_v1`
- Heuristic Standard: `heuristic_counter_standard_v1`

## Empty Opening

| Row config | Capture5 Phase G | MCTS Standard | Hybrid Tactical Standard | Heuristic Standard |
| --- | ---: | ---: | ---: | ---: |
| Capture5 Phase G | - | 0-6-0 | 0-6-0 | 0-3-3 |
| MCTS Standard | 6-0-0 | - | 3-0-3 | 0-0-6 |
| Hybrid Tactical Standard | 6-0-0 | 0-3-3 | - | 0-0-6 |
| Heuristic Standard | 3-0-3 | 0-0-6 | 0-0-6 | - |

## Cross Opening

| Row config | Capture5 Phase G | MCTS Standard | Hybrid Tactical Standard | Heuristic Standard |
| --- | ---: | ---: | ---: | ---: |
| Capture5 Phase G | - | 0-6-0 | 0-6-0 | 0-6-0 |
| MCTS Standard | 6-0-0 | - | 3-3-0 | 0-0-6 |
| Hybrid Tactical Standard | 6-0-0 | 3-3-0 | - | 0-0-6 |
| Heuristic Standard | 6-0-0 | 0-0-6 | 0-0-6 | - |

## Twist Cross Opening

| Row config | Capture5 Phase G | MCTS Standard | Hybrid Tactical Standard | Heuristic Standard |
| --- | ---: | ---: | ---: | ---: |
| Capture5 Phase G | - | 0-6-0 | 0-6-0 | 0-6-0 |
| MCTS Standard | 6-0-0 | - | 0-0-6 | 2-0-4 |
| Hybrid Tactical Standard | 6-0-0 | 0-0-6 | - | 0-0-6 |
| Heuristic Standard | 6-0-0 | 0-2-4 | 0-0-6 | - |

## Validation

- Random games: 0
- Illegal moves: 0
- Timeouts: 0
- Fallback games: 0
- Failure reasons: 0
- Bad repeat cells: 0
- Bad dimension cells: 0
