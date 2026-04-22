# Go Puzzle

Go Puzzle is a Flutter app for practicing Go tactics through daily puzzles and focused skill training. It uses an iOS-style Cupertino interface and includes an interactive board for placing stones, undoing moves, viewing hints, and tracking captures.

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

## Technical Overview

- **Flutter** with Cupertino widgets for an iOS-oriented experience.
- **Provider** for app and game state.
- **CustomPainter** for board rendering, including wood texture, stone styling, and atari markers.
- Go rule handling for liberties, captures, ko, suicide checks, and undo.

## Development

Developer setup, validation, build, deployment, and puzzle-data notes live in [Development Flow](docs/kb/development-flow.md).

## References

- Puzzle design reference: [online-go.com/learn-to-play-go](https://online-go.com/learn-to-play-go)
- Go rules reference: [International Go Federation](https://www.igofederation.org)
