# 遷移截圖擺棋與歷史對局模組，重新命名解棋頁面為「歷史」

## Background

### Context

Following the relocation of the 「今日挑戰」 (Daily Challenge) card, the user requested additional layout adjustments to optimize feature grouping:
1. **Move 「匯入截圖擺棋」 Card**: Shift the Import Screenshot setup card from the puzzle solving page (`SkillsScreen`) to the main playing page (`CaptureGameScreen`), placed directly below the Daily Challenge card.
2. **Move 「歷史對局」 Card and Screen**: Shift the Play History list card and its detailed review/browse screens from the playing page (`CaptureGameScreen`) to the renamed solver page (`SkillsScreen`), rendering it at the bottom.
3. **Rename the Tab / Screen**: Rename the solver tab/page from 「解棋」 to 「歷史」 (History) to accurately reflect the unified display of puzzle solving records and play history.
4. **Fix Compilation/Loading Bugs**: Resolve compilation errors in the widgets (`daily_challenge_card.dart` nullability type checks and `_StoneRipplePainter` syntax error from partial deletions) that were blocking app hot reloads and causing a stuck loading state.

---

## Goals

- Move `ImportScreenshotCard` from `SkillsScreen` to `CaptureGameScreen` under `DailyChallengeCard`.
- Copy all Play History classes (`_HistorySectionCard`, `_HistoryRow`, `_StoneCircle`, `_HistoryDetailSheet`, `_FullHistoryScreen`, `_GameBrowseScreen`, `_GameBrowseScreenState`, `_NavIconButton`, and `_DecoratedActionButton`) to `SkillsScreen`.
- Load game play history inside `_SkillsScreenState` using `GameHistoryRepository` and render `_HistorySectionCard` at the bottom of the page.
- Clean up the play history viewer and screenshot imports from their old screens.
- Rename all tab labels and navigation titles from 「解棋」 to 「歷史」 in `main_screen.dart`, `screenshot_import_screen.dart`, and `skills_screen.dart`.
- Update `test/skills_screen_test.dart` to expect tab label `'歷史'` instead of `'解棋'`.
- Verify compilation is error-free and all tests pass.

---

## Implementation Details

### 1. Resolving Compilation & Loading Bugs
- **`DailyChallengeCard` Nullability Shadow**: Bound a local final `provider` after checking for null on `localProvider` in `DailyChallengeCard.build()` to ensure proper type promotion of `TacticsChallengeProvider`.
- **`_StoneRipplePainter` Restoration**: Restored the damaged implementation of `_StoneRipplePainter.paint()` in `capture_game_screen.dart` to fix syntax errors introduced during partial history class deletions.

### 2. screenshot import card relocation
- Added `ImportScreenshotCard` to the play tab layout directly under `DailyChallengeCard` in `capture_game_screen.dart`.
- Cleaned up `ImportScreenshotCard` and `_launchGameFromBoard` from the solver screen (`skills_screen.dart`).

### 3. play history relocation
- Integrated `GameHistoryRepository` into `_SkillsScreenState` and loaded play records on initialization (`initState`).
- Appended all Play History layout widgets, screens, and coordinate helpers to `lib/screens/skills_screen.dart`.
- Cleaned up the leftover review controls and classes from `capture_game_screen.dart`.

### 4. Renaming to "歷史"
- Changed navigation header text in `skills_screen.dart` to `'歷史'`.
- Renamed the bottom navigation tab item label in `main_screen.dart` to `'歷史'`.
- Updated page references and back buttons in `screenshot_import_screen.dart` to `'歷史'`.
- Updated test assertions in `skills_screen_test.dart` to tap and assert on `'歷史'`.

### 5. Restyling the '開始解棋' (Start Daily Challenge) Button
- Replaced the primary `CupertinoButton.filled` style of `'開始解棋'` in `daily_challenge_card.dart` with the `_SecondaryActionButton` styling (using custom `DecoratedBox` for fill and border, plus a non-filled `CupertinoButton` wrapper with 14 border radius) to match the secondary styling used by the `'執白後行'` button, reflecting its status as a secondary action on the play screen.

### 6. Daily Challenge Category Mapping and Display Format
- Replaced the raw database categories (like "转换", "棋型生死") with the user-facing option labels ("吃子", "死活", "手筋", "對殺") by checking the problem categories and tactic metadata.
- If the type filter is set to "全部", it displays "全部".
- Changed the display format under the "今日挑戰" title to strictly follow the requested structure:
  ```
  級別 15K
  類型 全部/吃子/死活...
  ```

---

## Validation & Verification

### Unit & Widget Tests
- Tapped and asserted navigation flow and state updates in `test/skills_screen_test.dart`.
- Ran the full test suite via `flutter test` and verified all 235 tests pass without compilation issues or layout breakages.
