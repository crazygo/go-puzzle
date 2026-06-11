# 遷移今日挑戰卡片至下棋頁面

## Background

### Context

The 「今日挑戰」 (Daily Challenge) card was originally located in the 「解棋」 (puzzle solving) screen (`SkillsScreen`). However, to align with user experience preferences and concentrate active game options in a single hub, the daily challenge card needs to be moved to the 「下棋」 (game play) screen (`CaptureGameScreen`), specifically placed below the capture game configuration card ("吃子卡片") and above the historical match card ("歷史對局").

### Problem

- The daily challenge card was tightly coupled with the local state of `SkillsScreen`.
- Solved/visited problem progress was only tracked locally in `SkillsScreen`'s in-session state, preventing other screens from reactively reflecting challenge completion.
- Moving the card to `CaptureGameScreen` requires a clean state management solution to ensure both the Daily Challenge card (now on the play tab) and the Heatmap/History sections (still on the puzzle solving tab) sync progress instantly.

### Motivation

By relocating the Daily Challenge card to the main play screen, users can easily discover and launch Weiqi tactics puzzle challenges right alongside standard matches. Synchronizing progress between tabs via a shared provider ensures a unified and reactive user experience.

---

## Goals

- Move the 「今日挑戰」 card from `SkillsScreen` to `CaptureGameScreen`.
- Place the card below the game config card and above the historical games card in `CaptureGameScreen`.
- Implement a global `TacticsChallengeProvider` to decouple daily challenge progress from local screen states, making it accessible and reactive across both tabs.
- Clean up unused layout widgets from `SkillsScreen`.
- Update the unit test suite (`skills_screen_test.dart`) to ensure it works correctly under the new provider architecture and tab structure.

---

## Implementation Plan

### 1. State Management (`TacticsChallengeProvider`)

Create a new file `lib/providers/tactics_challenge_provider.dart`:
- Expose properties for loaded problems, current daily challenges, selected difficulty level (`kLevel`), type filter (`typeFilter`), and daily completed status (`solvedByDay`).
- Handle asynchronous loading of Weiqi problems from the JSON repository.
- Provide callback methods (`setKLevel`, `setTypeFilter`, `recordSolved`) to trigger state changes and reactively notify listeners.
- Accept an optional `problemsFutureOverride` parameter in the constructor to support mock datasets in tests and prevent asset loading errors.

Register the provider in `lib/main.dart`'s `MultiProvider` configuration.

### 2. UI Component Extraction (`DailyChallengeCard`)

Create a shared, self-contained widget file `lib/widgets/daily_challenge_card.dart`:
- Migrate the Apple Watch–style completion ring (`_DailyRing`), pill buttons (`_PillButton`, `_KLevelPillRow`, `_PillSegmentRow`), and problem launch logic from `skills_screen.dart` into `DailyChallengeCard`.
- Bind the card directly to `TacticsChallengeProvider` so it updates seamlessly.

### 3. Layout updates

- In `lib/screens/capture_game_screen.dart`: Import and insert `DailyChallengeCard` in the vertical scroll list between `PageSectionCard` and `_HistorySectionCard`.
- In `lib/screens/skills_screen.dart`: Remove the old `_PuzzleSetupSection`, `_DailyRing`, `_RingPainter`, K-level pill rows, and related state fields. Consume daily challenge state from `TacticsChallengeProvider` with local in-session state fallbacks to guarantee test compatibility.

### 4. Tests

Update `test/skills_screen_test.dart` to:
- Inject `TacticsChallengeProvider` with a mock list of problems to avoid asynchronous file loading.
- Select the capture game tab (index 0) to verify daily challenge setup options.
- Select the puzzle solving tab (index 1) to verify history lists and heatmaps.

---

## Acceptance Criteria

- The 「今日挑戰」 card is visible on the 「下棋」 page, placed below the game config card and above the history list.
- The 「解棋」 page no longer displays the setup card, but correctly shows heatmap records and history matching the progress of solved daily challenges.
- Both tabs sync progress reactively in real time.
- All unit and widget tests in `test/skills_screen_test.dart` pass.

---

## Validation Commands

- `flutter test test/skills_screen_test.dart`
