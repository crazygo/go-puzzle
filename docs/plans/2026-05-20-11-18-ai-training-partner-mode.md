# AI Training Partner Mode (陪練模式)

## Background

### Context

`CaptureGamePlayScreen` hosts the main Go game UI. An `操作` menu (operation context menu, `_OperationContextMenu`) is shown from the navigation bar trailing button. The current hint system (`_showHintsOnBoard`) fetches one suggestion via `suggestMovesAsync(count: 1)` and overlays it as a dashed circle (`_HintOverlayPainter`). The `CaptureGameProvider` enforces that only `humanColor` can call `placeStone`; the AI plays all moves for the opposite color via `_scheduleAiMove`.

### Problem

There is no mode that lets a user practice freely as both colors with continuous AI guidance. The existing single-shot hint returns one position, does not display a per-position advantage rate, and does not refresh automatically.

### Motivation

An AI training partner mode (陪練模式) allows users to self-play both colors while receiving live, board-rendered AI move suggestions with advantage percentages. This helps learners study positions interactively without needing an AI opponent.

## Goals

- Add an **AI Training Partner mode** (陪練模式) accessible from the operation menu.
- While in training mode, both colors are played by the user; the AI does not auto-play.
- The AI automatically computes and refreshes up to 3 board suggestions every 3 seconds for up to 15 seconds after each user move, then stops.
- Each suggestion is rendered on the board as a dashed circle with a win-rate percentage label inside.
- A persistent status bar above the move-log strip shows training mode state and a **Leave** button.
- Leaving training mode restores normal play: AI takes over if it is the AI's turn.

## Implementation Plan

### Phase 1 – Provider: training mode flag and both-color placement

1. Add a `bool trainingMode` property (default `false`) and `enterTrainingMode()` / `exitTrainingMode()` methods to `CaptureGameProvider`.
2. In `enterTrainingMode()`: set the flag, cancel any in-flight AI request, cancel any pending AI move timer, call `notifyListeners()`.
3. In `exitTrainingMode()`: clear the flag, call `notifyListeners()`, then if the game is not over and it is the AI's turn (`currentPlayer != humanColor`), call `_scheduleAiMove()` to resume normal play.
4. In `placeStone()`: skip the `currentPlayer != humanColor` guard when `trainingMode` is true, so both colors can be placed by the user.
5. In `_scheduleAiMove()`: return immediately (no-op) when `trainingMode` is true.
6. Expose `trainingMode` as a public getter.

### Phase 2 – Background compute: suggestions with per-position win rates

1. Add a new top-level function `_runTrainingSuggestions(Map<String, dynamic> params)` in `capture_game_provider.dart` that:
   - Accepts the same board params as `_runSuggestMoves` plus `'maxCandidates': 3`.
   - Runs the primary AI agent for the current player on a SimBoard, collecting up to 3 candidate positions using the agent's scored output (`CaptureAiMove.score`).
   - For each candidate, applies the move to a scratch SimBoard and computes a win-rate estimate for the current player using the same normalized capture/territory formula already used in `winRateEstimate`.
   - Returns `List<List<num>>` where each entry is `[row, col, winRateMillis]` (win-rate × 1000 as int to stay serialisable through `compute()`).
2. Add `suggestMovesWithWinRateAsync({int count = 3})` to `CaptureGameProvider` that calls `compute(_runTrainingSuggestions, params)` and returns `List<_TrainingSuggestion>` (a simple value type carrying `BoardPosition position` and `double winRate`).

### Phase 3 – Extended hint mark and painter

1. Extend `_HintMark` with an optional `double? winRate` field (null = no label, used by the existing single-hint path).
2. Update `_HintOverlayPainter.paint()` so that when `hint.winRate != null`, it draws a centred percentage label (e.g. `"64%"`) inside each dashed circle using `canvas.drawParagraph`. Font size should be proportional to `cell * 0.28`, white/black colour matching `hintColor` with a contrasting stroke for legibility.
3. Update `_CaptureBoardArea` (and `_TapBoard`) to propagate `List<_HintMark>` unchanged – the existing interface already threads `hintMarks` through without typing assumptions.

### Phase 4 – Training hint session controller

1. Add a `_TrainingHintSession` class (private, inside the screen file) with:
   - Constructor takes the provider reference, a `void Function(List<_HintMark>)` onUpdate callback, and a `void Function()` onDone callback.
   - `start()` launches a periodic loop: every 3 seconds invoke `provider.suggestMovesWithWinRateAsync(count: 3)`, convert results to `_HintMark` objects (with `winRate` set), call `onUpdate`, increment a round counter.
   - After 5 rounds (15 seconds total), call `onDone` and stop.
   - `cancel()` stops any in-flight computation and the timer.
2. In `_CaptureGamePlayScreenState`:
   - Add `_TrainingHintSession? _trainingSession` and `bool _trainingMode = false`.
   - `_enterTrainingMode(provider)`: calls `provider.enterTrainingMode()`, creates and starts a new `_TrainingHintSession`, sets `_trainingMode = true`.
   - `_leaveTrainingMode(provider)`: calls `_trainingSession?.cancel()`, clears `_hintMarks`, calls `provider.exitTrainingMode()`, sets `_trainingMode = false`.
   - In `_handleBoardTap`: when `_trainingMode` is true and the tap placed a stone, cancel and restart the training session for the new board position.
   - In `dispose()`: cancel and nullify the training session.

### Phase 5 – UI wiring

1. **Operation menu entry**: Add a new `_OperationMenuItem` entry ("進入陪練模式") to `_OperationContextMenu`. Update the `menuItemCount` constant from `9` to `10` in `_showOperationMenu`. Add the required callback prop `onEnterTrainingMode` to the widget.  Pass the callback from `_showOperationMenu` to dismiss the menu and call `_enterTrainingMode(provider)`.
2. **Training mode status bar**: Add a `_TrainingModeStatusBar` stateless widget that shows the training status text (e.g., "AI 陪練模式 — 正在計算第N輪...") and a "離開" button. Expose the round number as a parameter (updated via `setState` from the session's `onUpdate` callback). Insert it just above the `_MoveLogStrip` / `SizedBox` in the `Column` inside `SafeArea`, guarded by `if (_trainingMode)`.
3. **Board enabled logic**: In `_CaptureBoardArea`, the `enabled` flag should be `!aiThinking && !isFinished && !inReviewMode` – unchanged, since `provider.isAiThinking` is always false during training mode (no AI moves are scheduled).
4. **Title bar**: Update `_buildGameTitle()` to return `'AI 陪練模式'` when `provider.trainingMode` is true, regardless of whose turn it is.

## Acceptance Criteria

- Tapping 操作 → "進入陪練模式" enters training mode; the nav-bar title changes to "AI 陪練模式".
- A status bar appears above the move log strip with a "離開" button.
- Both black and white stones can be placed by the user in training mode; the AI does not auto-play.
- After each stone placement, dashed circles with percentage labels (up to 3) appear on the board within 3 seconds and refresh every 3 seconds for up to 15 seconds, then stop.
- Tapping "離開" exits training mode; the game resumes normally (AI plays if it is the AI's turn).
- All hint marks clear immediately when training mode exits.
- Existing 提示一手 (single-hint) and all other operation menu items continue to function unchanged outside of training mode.
- `flutter analyze --no-fatal-infos --no-fatal-warnings` produces no new errors.
- `flutter test` continues to pass.

## Validation Commands

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
