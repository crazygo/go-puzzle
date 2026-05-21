# Go Puzzle

Go Puzzle is a Flutter app for practicing Go tactics through daily puzzles,
focused skill training, and capture-go games against configurable AI opponents.
It uses an iOS-style Cupertino interface and includes an interactive board for
placing stones, undoing moves, viewing hints, reviewing game records, and
tracking captures.

## Features

### Daily Puzzle
- One puzzle per day with a date timeline.
- Interactive board with move input, undo, and hints.
- Progress and capture tracking during play.

### Skill Training
The training library groups puzzles by tactical pattern:

| Category | Focus |
| --- | --- |
| Beginner | Basic captures and edge/corner play |
| Rules | Suicide, ko basics, and living with two eyes |
| Cut | Capturing after separating connected stones |
| Ko | Creating and resolving ko fights |
| Ladder | Repeated atari sequences |
| Net | Trapping stones with surrounding shapes |
| Double Atari | Threatening two captures at once |

### Settings
- Board modes for 9x9 capture, 13x13 capture, and 19x19 territory practice.
- Optional hints and move numbers.
- Sound and haptic feedback controls.

### AI Play
- Capture-go games against named AI opponents.
- Multiple AI families and strength tiers exposed through stable algorithm
  config IDs.
- Preset openings such as empty, cross, and twist-cross for repeatable practice
  and evaluation.
- Move-log copy and SGF/text export for reviewing positions and reproducing
  tactical failures.

### Evaluation Tools
- Headless AI arena for repeatable pairwise matches and full strength matrices.
- Board-size-specific runs for 9x9, 13x13, and 19x19 capture-go experiments.
- Validation gates for illegal moves, decision timeouts, fallback use, failed
  inference, and malformed repeated-game cells.
- Tracked AI evaluation artifacts under `docs/ai_eval/` and compact ladder
  snapshots under `docs/ai_arena/`.

## Technical Overview

- **Flutter** with Cupertino widgets for an iOS-oriented experience.
- **Provider** for app and game state.
- **CustomPainter** for board rendering, including wood texture, stone styling, and atari markers.
- Go rule handling for liberties, captures, ko, suicide checks, and undo.
- Capture-go AI configs for heuristic, MCTS, hybrid tactical, and KataGo ONNX
  opponents.
- Native/headless evaluation tooling for reproducible AI strength runs.

## Project Guide

- Product features and app behavior are summarized in this README.
- Capture-go AI algorithm details live in
  [Capture AI Algorithms](docs/kb/capture-ai-algorithms.md).
- Arena run terms and ladder workflow live in
  [AI Arena Runner](docs/kb/ai-arena-runner.md).
- Detailed tuning history and evaluation artifacts live in
  [Capture AI Framework Tuning Notes](docs/ai_eval/capture-ai-framework-tuning-notes.md).

## Development

Developer setup, validation, build, deployment, and puzzle-data notes live in [Development Flow](docs/kb/development-flow.md).

## References

- Puzzle design reference: [online-go.com/learn-to-play-go](https://online-go.com/learn-to-play-go)
- Go rules reference: [International Go Federation](https://www.igofederation.org)
- Thanks to [Kaya](https://github.com/kaya-go/kaya) — a free and open-source Go app for play, study, AI analysis, and board recognition from photos.
