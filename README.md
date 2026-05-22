# Go Puzzle

Go Puzzle is a Flutter app for practicing Go tactics through daily puzzles,
focused skill training, and capture-go games against configurable AI opponents.
It uses an iOS-style Cupertino interface and includes an interactive board for
placing stones, undoing moves, viewing hints, reviewing game records, and
tracking captures.

## Core Features

### Daily Puzzle
- One puzzle per day with a date timeline.
- Interactive board with move input, undo, and hints.
- Progress and capture tracking during play.

### Skill Training
- Tactical puzzle library grouped by pattern and difficulty.
- Practice categories include rules, cuts, ko, ladders, nets, and double atari.
- Focused screens for repeated tactical training instead of only daily play.

### Capture-Go Play
- 9x9 and 13x13 capture-go practice.
- Preset openings such as empty, cross, and twist-cross.
- Move history, undo, hints, capture tracking, and SGF/text copy.

### AI Play
- Capture-go games against named AI opponents.
- Multiple AI families and strength tiers.
- Repeatable AI evaluation through arena tools and recorded artifacts.
- Generated tactical-trap corpora for regression-testing AI decisions around
  ladders, false connections, edge escapes, nets, and snapbacks.

### App Settings
- Board mode and coordinate display options.
- Optional hints and move numbers.
- Sound and haptic feedback controls.

## Technical Overview

- **Flutter** with Cupertino widgets for an iOS-oriented experience.
- **Provider** for app and game state.
- **CustomPainter** for board rendering, stone styling, and atari markers.
- Go rule handling for liberties, captures, ko, suicide checks, and undo.
- Capture-go AI opponents and headless arena evaluation tooling.

## Documentation

- [Capture AI Algorithms](docs/kb/capture-ai-algorithms.md): algorithm
  families, tactical safeguards, evaluation model, and code map.
- [AI Arena Runner](docs/kb/ai-arena-runner.md): arena terms, ladder workflow,
  local artifacts, and common run commands.
- [Capture AI Framework Tuning Notes](docs/ai_eval/capture-ai-framework-tuning-notes.md):
  detailed experiment history and evaluation results.
- [Development Flow](docs/kb/development-flow.md): setup, validation, build,
  deployment, and puzzle-data workflow.

## Development

Run the project checks from the repository root after environment setup:

```sh
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```
