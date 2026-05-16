# Go Puzzle

Go Puzzle is a Flutter app for practicing Go tactics through focused skill training. It uses an iOS-style Cupertino interface and includes an interactive board for placing stones, undoing moves, viewing hints, and tracking captures.

## Features

- Interactive board with move input, undo, and hints.
- Progress and capture tracking during play.
- Import a Go board screenshot.
- Recognize board size, stone positions, and stone colors.
- Convert the screenshot into an editable board position.
- Includes a self-trained YOLO/ONNX recognition model pipeline for improving screenshot recognition over time.
- Board modes for 9x9 capture, 13x13 capture, and 19x19 territory practice.
- Optional hints and move numbers.
- Sound and haptic feedback controls.

## Technical Overview

- **Flutter** with Cupertino widgets for an iOS-oriented experience.
- **Provider** for app and game state.
- **CustomPainter** for board rendering, including wood texture, stone styling, and atari markers.
- Go rule handling for liberties, captures, ko, suicide checks, and undo.
- Screenshot recognition with a rule-based path and a self-trained YOLO/ONNX model pipeline.

## Development

Developer setup, validation, build, deployment, and puzzle-data notes live in [Development Flow](docs/kb/development-flow.md).

## References

- Puzzle design reference: [online-go.com/learn-to-play-go](https://online-go.com/learn-to-play-go)
- Go rules reference: [International Go Federation](https://www.igofederation.org)
