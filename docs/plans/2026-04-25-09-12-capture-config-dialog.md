# Background
The capture game currently exposes AI style switching directly in the top-right of the in-game navigation bar, while capture warning (atari marks) is always on and cannot be configured. Product feedback requires a single configuration entry in-game and a configurable global capture-warning switch.

# Goals
1. Replace the in-game top-right AI style entry with a configuration button.
2. Show a dialog that includes current-round configuration (AI style) and global configuration.
3. Add a global `capture warning` toggle, default enabled, and connect it to existing atari warning rendering.
4. Keep the settings discoverable in the Settings tab as well.

# Implementation Plan (phased)
## Phase 1: Global settings model
- Add `showCaptureWarning` to `SettingsProvider`.
- Default value is `true`.
- Add setter and notifier updates.

## Phase 2: Settings UI exposure
- Add a switch item in `SettingsScreen > 游戏选项` for `吃子预警`.
- Ensure language clearly communicates this controls atari warning marks.

## Phase 3: Capture-game configuration dialog
- Replace the in-game top-right `AI 风格` text control with a `配置` icon/button.
- Add a popup dialog showing:
  - Current round config: AI style selector.
  - Global config: `吃子预警` switch.
- Reuse existing AI style picker for consistency.

## Phase 4: Board warning toggle wiring
- Add a `showCaptureWarning` flag to `GoBoardPainter`.
- Conditionally render atari marks only when enabled.
- Pass the global setting down from `CaptureGamePlayScreen` to board rendering.

# Acceptance Criteria
1. In capture gameplay, the top-right entry is a config button that opens a dialog.
2. The dialog contains both `本轮配置` and `全局配置` sections.
3. `吃子预警` is ON by default and can be toggled in both Settings and in-game config dialog.
4. Turning `吃子预警` OFF immediately hides atari warning marks on the board.
5. Validation passes with:
   - `flutter analyze --no-fatal-infos --no-fatal-warnings`
   - `flutter test`
