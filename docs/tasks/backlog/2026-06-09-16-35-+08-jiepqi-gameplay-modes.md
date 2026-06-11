# 解棋遊戲三模式

## Background

During a puzzle session, the user needs different levels of AI involvement. Currently the game only supports one fixed mode (AI auto-plays, no suggestions shown). Three distinct modes were identified.

## Goals

- Add three named gameplay modes to the 解棋 puzzle session screen.
- Allow the user to select a mode before starting a puzzle.

## Implementation Plan

1. Define a `PuzzlePlayMode` enum: `battle`, `research`, `freePlay`.
2. Map enum to two flags: `aiAutoPlay` and `showSuggestions`.
   - `battle`    → aiAutoPlay=true,  showSuggestions=false
   - `research`  → aiAutoPlay=false, showSuggestions=true
   - `freePlay`  → aiAutoPlay=false, showSuggestions=false
   - (Note: aiAutoPlay=true + showSuggestions=true = existing 訓練夥伴 mode, reusable)
3. Add a mode selector pill row to `_PuzzleSetupSection` in `skills_screen.dart`.
4. Pass the selected mode flags to `CaptureGameProvider` / `CaptureGamePlayScreen` when launching a puzzle.
5. Update tests.

## Acceptance Criteria

- User can choose 對戰 / 研究 / 試下 before starting a puzzle.
- 對戰: AI moves automatically; no suggestion overlay shown.
- 研究: AI does not move; suggestion hints shown after each human move.
- 試下: AI does not move; no suggestions; pure stone-placement.
- Mode selection persists for the session (resets on next app launch is acceptable).

## Validation Commands

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
