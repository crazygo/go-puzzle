# Game History Recording Plan

## Background

### Context
- The 「下棋」page (`CaptureGameScreen`) lets users start new capture games with configurable board size, difficulty, and initial mode (twist-cross, empty, or placement/setup).
- `CaptureGameProvider` manages game state, AI moves, and undo history entirely in memory; nothing is persisted beyond the active session.
- SharedPreferences is already in the dependency tree and used to persist the last-selected difficulty, board size, and initial mode across launches.

### Problem
- Every game session is ephemeral: once the user leaves the play screen all progress is discarded.
- There is no way to recall a satisfying game, review a finished position, or revisit a game where the AI won.
- Players who want to replay a challenging position must recreate it from scratch each time.

### Motivation
- A lightweight kifu (棋谱) record stored locally gives users a personal game archive without requiring a backend.
- Showing a reverse-chronological history list with outcome and move count provides immediate context and makes the app feel more polished.
- A "重下这一手" replay flow—with configurable difficulty and optional placement mode—turns the history feature into a practice tool, directly supporting the skill-training use case of the app.

## Goals
1. Record every capture game (moves, outcome, final board, metadata) to persistent local storage.
2. Display recorded games in a history card on the 「下棋」home screen, newest first.
3. Allow users to open a game detail sheet, preview the final board position, and start a new game from that record.
4. Surface "重下这一手" both from the history detail sheet and directly on the play screen when a game finishes.
5. Keep storage self-contained (SharedPreferences only, no new packages) and bounded (max 50 records).

## Implementation Plan

### Phase 1 — Data model and repository
- Add `GameRecord` (`lib/models/game_record.dart`): stores `id` (ISO-8601 timestamp), `playedAt`, `boardSize`, `captureTarget`, `difficulty` (name string), `humanColorIndex`, `initialMode` (name string), `moves` (`List<List<int>>`), `outcome` (`GameOutcome` enum: humanWins / aiWins / abandoned), `initialBoardCells` (optional, for setup-mode games), and `finalBoard` (optional snapshot for display).
- Add `GameHistoryRepository` (`lib/services/game_history_repository.dart`): CRUD over SharedPreferences key `game_history_v1` as a JSON-encoded string list; trims to 50 records; sorts newest-first.

### Phase 2 — Move tracking in provider
- Add `_moveLog: List<List<int>>` to `CaptureGameProvider`; append `[row, col]` in `placeStone` and `_doAiMove`.
- Trim log in `undoMove` by the number of undo-stack entries removed (`movesRemoved = stackSizeBefore - _undoStack.length`).
- Clear log in `newGame` / `_startNewGame` and `clearSetupBoard`.
- Expose `moveLog` as an unmodifiable getter.

### Phase 3 — Auto-save on play screen
- Wrap `CaptureGamePlayScreen` body in `PopScope`; call `_saveGame(provider)` in `onPopInvokedWithResult` to save on back-navigation.
- Inside the `Consumer` builder, call `Future.microtask(() => _saveGame(provider))` when `provider.result != CaptureGameResult.none` to save immediately when the game finishes.
- `_saveGame` is guarded by a `_gameSaved` flag so it writes exactly once per session; skips saving if `moveLog` is empty (no moves played).

### Phase 4 — History UI on home screen
- Load history asynchronously in `initState`; refresh with `_loadHistory()` on return from any game screen (`.then((_) => _loadHistory())`).
- Add `_HistorySectionCard` widget: shows up to 5 rows; hidden when empty; "全部 ›" button navigates to `_FullHistoryScreen` when there are more than 5 records.
- `_HistoryRow`: stone-color circle, board size · difficulty · move count, relative date, outcome badge.
- Tapping a row opens `_HistoryDetailSheet` (modal bottom sheet): outcome badge, date, `GoBoardWidget` preview of `finalBoard`, "重下这一手" primary button.

### Phase 5 — Replay setup dialog
- `_ReplaySetupDialog` (stateful): `CupertinoSlidingSegmentedControl` for difficulty, `CupertinoSwitch` for placement mode, note shown when original board will be restored.
- On confirm: resolve `boardOverride` (pass `initialBoardOverride` directly when placement mode selected), pop current screen or sheet chain, push a new `CaptureGamePlayScreen` via root navigator.
- "重下这一手" also replaces "提示一手" on the play screen once a game finishes, using the same dialog.

## Acceptance Criteria
- Playing a game and leaving the play screen causes a `GameRecord` to appear in the history list on the home screen (newest first).
- Abandoned games (navigated away with ≥1 move played) are recorded with `outcome = abandoned`; finished games record the correct winner.
- Tapping a history row opens a detail sheet showing the final board position and outcome.
- "重下这一手" from the detail sheet (or from the play screen after the game ends) opens `_ReplaySetupDialog`, where difficulty and placement mode can be configured.
- Selecting a difficulty and confirming starts a new game with the chosen settings; if placement mode is on and an original board exists, that board is restored.
- At most 50 records are kept; the oldest are automatically trimmed.
- No new package dependencies are introduced.
- Validation commands pass:
  - `flutter pub get`
  - `flutter analyze --no-fatal-infos --no-fatal-warnings`
  - `flutter test`
