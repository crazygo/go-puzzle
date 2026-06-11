# 解棋今日挑戰卡片

## Background

### Context

The 解棋 (puzzle) page has a setup card titled 「解棋題目」. It shows a difficulty (K-level) and type filter, and a 「開始解棋」 button that currently navigates to a full problem list screen. There is no concept of a daily problem set, no progress ring, and no problem-composition summary.

### Problem

- Tapping 「開始解棋」 opens a list screen instead of starting a game directly.
- The card gives no information about what the user will actually solve today.
- There is no daily selection or locking mechanism — every tap shows all problems regardless of date or config.
- The UI has no visual feedback on daily progress.

### Motivation

A daily challenge card with a progress ring, a locked problem set, and a direct-to-game flow gives the user a clear goal, visible progress, and a frictionless start. This aligns with the "record but don't force" philosophy: the ring is informational, not a gate.

## Goals

- Change card title to 「今日挑戰」 with an Apple Watch–style completion ring.
- Show a one-line summary of today's problem composition inside the card.
- Select and lock today's problems on first entry; re-select only when 調整 config actually changes.
- Provide a placeholder problem-selection function with a clean interface for future strategy replacement.
- Tapping 「開始解棋」 launches the first unsolved problem directly (or any problem if all are done).
- The ring being full (5/5 done) does not disable the button; data is still recorded.

## Implementation Plan

### 1. Problem-selection interface

Add a top-level function in `skills_screen.dart`:

```dart
// Placeholder: picks [count] problems in order from the filtered pool.
// Future strategy: replace body; keep signature stable.
// Inputs: full problem pool, kLevel, typeFilter, count.
// Output: selected problem list.
List<CaptureAiTacticsProblem> selectDailyProblems({
  required List<CaptureAiTacticsProblem> pool,
  required int kLevel,
  required _TypeFilter typeFilter,
  int count = 5,
})
```

### 2. Daily state model

Add to `_SkillsScreenState`:
- `List<CaptureAiTacticsProblem>? _todayProblems` — locked daily set (null = not selected yet)
- `_DailyConfig? _lastConfig` — the kLevel + typeFilter snapshot at selection time
- `_DailyConfig` value object: `{ int kLevel, _TypeFilter typeFilter }`

Selection logic (called in `_ensureTodayProblems`):
1. If `_todayProblems == null` → select and lock.
2. If config changed (`kLevel` or `typeFilter` differs from `_lastConfig`) → re-select and lock.
3. Otherwise → keep existing set.

### 3. Progress ring

Add `_DailyRing` widget:
- Takes `completed` (int) and `total` (int, default 5).
- Draws a circular arc using `CustomPaint` (similar to Apple Watch rings).
- Shows fraction text in the centre (e.g. `3/5`) or a checkmark when full.

### 4. Card UI changes

Update `_PuzzleSetupSection`:
- Title row: `「今日挑戰」` + `_DailyRing` on the right.
- Below title: one-line problem-composition summary built from `_todayProblems`
  (e.g. `「死活 ×3　手筋 ×1　吃子 ×1」`).
- 調整 panel: unchanged (K-level + type filter pills).
- 「開始解棋」 button: always enabled; tapping calls `_startTodayChallenge`.

### 5. Game launch flow

`_startTodayChallenge`:
1. Call `_ensureTodayProblems` to guarantee `_todayProblems` is set.
2. Find first problem in `_todayProblems` not yet in `_solvedByDay[today]`.
3. If all done, pick `_todayProblems.first` (allow replaying).
4. Call `_openProblem(context, problem)` — which already records the visit.

Remove the `_ProblemListScreen` navigation from the 「開始解棋」 button path (keep the screen for history drill-down).

### 6. Problem-composition summary helper

```dart
String _describeProblemSet(List<CaptureAiTacticsProblem> problems)
// Groups by display label, returns e.g. "死活 ×3　手筋 ×1　吃子 ×1"
```

### 7. Tests

Update `skills_screen_test.dart`:
- Card title shows 「今日挑戰」.
- Progress ring widget present.
- Problem summary text present after problems load.
- Tapping 「開始解棋」 navigates directly to `TacticsProblemScreen` (not a list screen).
- Changing kLevel after selection re-selects problems.
- Ring full (5/5) does not disable the button.

## Acceptance Criteria

- Card title reads 「今日挑戰」 with a ring widget beside it.
- Ring shows `n/5` where `n` = number of today's problems already visited.
- Problem-composition summary is visible below the title (e.g. 「死活 ×2　吃子 ×3」).
- On first open each day, 5 problems are selected and locked.
- Changing kLevel or typeFilter in 調整 replaces today's set; unchanged config does not.
- Tapping 「開始解棋」 launches the game screen directly.
- When all 5 are done, button still works and records an extra visit.
- `flutter analyze --no-fatal-infos --no-fatal-warnings` passes.
- `flutter test` passes.

## Validation Commands

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test test/skills_screen_test.dart`
