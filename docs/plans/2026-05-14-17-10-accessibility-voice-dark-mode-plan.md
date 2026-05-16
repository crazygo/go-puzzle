# Accessibility, Voice Control, and Dark Mode Improvements

## Background

### Context

Baduk Puzzle is preparing for App Store distribution as a relaxing Go-rule puzzle app. The app already has visual board interactions, configurable themes, animated board backgrounds, local game history, AI suggestions, and screenshot import. App Store Connect also asks for accessibility feature declarations, which should only be enabled when the current build can honestly support them.

### Problem

The app should not overclaim accessibility support before it has been tested and implemented. The most important gaps are support for blind or low-vision users, non-touch operation through Voice Control or keyboard-style navigation, and a consistently comfortable dark interface.

Current board interactions are visually rich but likely not fully exposed as semantic controls. Some key game states may rely on visual board position, color, highlights, or animation. VoiceOver and Voice Control users need explicit labels, actions, and predictable navigation targets. Dark mode also needs verification across the primary app flows, including board readability and contrast.

### Motivation

Improving these areas makes the app more usable for people with visual impairments, users who rely on voice-based control, and users who prefer low-glare interfaces. It also allows future App Store accessibility declarations to be accurate and defensible.

## Goals

- Make the main puzzle and capture-game flows more usable for blind and low-vision users.
- Support hands-free or low-touch operation for core flows through Voice Control-friendly labels and actions.
- Strengthen dark mode so the board, controls, dialogs, history, and settings remain readable and comfortable.
- Ensure key game states are not communicated by color alone.
- Add tests and manual QA notes so App Store accessibility declarations can be made conservatively.

## Implementation Plan

1. Audit the current accessibility surface.
   - Review the setup screen, game screen, board widgets, operation menu, history screens, tactics screens, settings, and screenshot import flow.
   - Identify controls without useful semantic labels, board cells that are not reachable or understandable, and states shown only through color.
   - Document which App Store accessibility features are currently safe to claim and which require implementation first.

2. Improve semantic labels and state descriptions.
   - Add `Semantics` wrappers or equivalent labels for primary controls, board coordinates, stones, empty intersections, selected moves, AI suggestions, capture warnings, marked moves, and current turn state.
   - Use concise labels such as "D4, black stone", "E5, empty intersection", "AI suggested move", and "white stone in atari".
   - Ensure result dialogs, import failures, and history navigation have clear spoken labels.

3. Make board interaction more accessible.
   - Provide semantic tap actions for playable intersections where feasible.
   - Add non-color indicators for selected points, AI suggestions, warnings, and marked moves, such as icons, border patterns, text summaries, or accessible labels.
   - Consider a list-based alternative move picker for users who cannot accurately touch a board intersection.

4. Improve Voice Control and non-touch operation.
   - Give important buttons unique, stable, visible labels that are easy to say.
   - Avoid duplicate command labels within the same screen where possible.
   - Verify that users can start a game, open the operation menu, request hints, toggle move log visibility, navigate history, and leave a game using voice-targetable controls.
   - Consider adding keyboard/focus traversal support for simulator and external keyboard testing.

5. Strengthen dark interface support.
   - Audit every primary flow in dark mode: home/setup, gameplay, operation menu, dialogs, tactics, settings, history, and import preview.
   - Tune text, board lines, stones, highlights, and overlays for sufficient contrast.
   - Ensure dark mode does not make black stones, shadows, warnings, or disabled controls ambiguous.

6. Add accessibility tests and QA checks.
   - Add widget tests for critical semantic labels and actions where Flutter testing can cover them.
   - Add contrast and dynamic text manual QA notes if fully automated coverage is impractical.
   - Add a manual checklist for VoiceOver, Voice Control, larger text, reduce motion, and dark mode before enabling App Store accessibility declarations.

## Acceptance Criteria

- VoiceOver can identify the current turn, game result, board size, mode, important action buttons, and at least the active/playable board intersections in the main capture-game flow.
- Voice Control users can operate the primary game flow without relying on unlabeled icon-only controls.
- AI suggestions, capture warnings, selected points, and marked moves are distinguishable by more than color alone.
- Dark mode remains readable across setup, gameplay, settings, tactics, history, dialogs, and screenshot import.
- The app has a documented accessibility QA checklist that maps each App Store accessibility feature to the evidence needed before claiming support.
- Tests cover the most important semantic labels or actions added for the main game and settings flows.

## Validation Commands

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
- `flutter test test/capture_setup_screen_test.dart test/capture_game_provider_test.dart test/theme_switch_test.dart`
- Manual QA with iOS Simulator or device: VoiceOver, Voice Control, Larger Text, Dark Mode, and Reduce Motion enabled separately.
