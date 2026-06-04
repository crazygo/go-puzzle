# Training Tab Daily and Focused Practice

## Background

### Context

The current puzzle surface is implemented as the `SkillsScreen` tactics list and `TacticsProblemScreen` detail flow. It loads `docs/ai_eval/tactics/problems.json`, groups problems by tactical category, opens a playable board, and shows AI and oracle suggestions. In the latest 1.3.0 worktree, the module logic matches `main`; the newer branch mainly expands the tactics data and related trap evaluation assets.

The next product direction is to evolve the puzzle surface into a training tab with a single-column, multi-card stream. For the first product pass, the tab should contain only two cards:

- Daily Challenge
- Focused Practice

The previously discussed third card is intentionally deferred.

### Problem

The current puzzle list exposes the internal tactic categories too directly. It behaves like a browseable collection instead of a daily learning surface. A visible skill-directory approach can feel dry, task-heavy, and intimidating, especially for beginners. It also does not create a strong daily completion loop.

### Motivation

The training tab should make Go learning feel lightweight and repeatable. Daily Challenge should create the "close the ring" motivation of a small daily set, while Focused Practice should give users a clear way to train high-level abilities without exposing a large knowledge tree on the first screen. The underlying knowledge taxonomy can still power selection, tagging, feedback, and future in-game coaching.

## Goals

- Replace the current top-level puzzle browsing experience with a training-oriented, single-column card layout.
- Make Daily Challenge the primary entry point, with clear daily content tags, progress, a start/continue action, and access to prior daily challenges.
- Make Focused Practice the secondary entry point, showing a small set of high-level practice areas on the card while keeping detailed concepts inside the next screen.
- Preserve the existing tactics problem loading and detail-play infrastructure where possible.
- Keep the first implementation scoped to two cards; do not add a third card, weakness radar, star archive, or real-game coach surface yet.

## Implementation Plan

1. Audit the current puzzle entry flow
   - Confirm how `SkillsScreen` is reached from the main tab shell and whether the user-facing tab label should remain "Puzzles" or become "Training".
   - Identify reusable widgets from the current list, filter chips, problem cards, and navigation patterns.
   - Confirm which existing tests cover the main puzzle tab wiring and tactics detail navigation.

2. Define the training tab data model
   - Introduce lightweight view models for Daily Challenge and Focused Practice rather than hardcoding display state into widgets.
   - For Daily Challenge, derive today's problem set from existing problem metadata, using a deterministic daily seed so the same date produces the same set.
   - Derive up to three display tags from today's selected problems, using high-level labels instead of raw internal categories where possible.
   - For Focused Practice, define a small stable set of high-level practice areas, such as capturing, life and death, capturing races, tesuji, and whole-board direction.
   - Map each high-level practice area to existing problem categories and metadata, but keep detailed concepts as second-level content.

3. Build the top-level Training screen
   - Convert or replace the current top-level `SkillsScreen` body with a single-column scroll view of two cards.
   - Implement the Daily Challenge card with title, short description, today's tags, progress display, primary action, and a history entry.
   - Implement the Focused Practice card with a compact set of high-level practice area rows or chips and a primary navigation path into the selected area.
   - Keep the visual tone consistent with the app's existing Cupertino styling and current theme palette.

4. Implement Daily Challenge navigation
   - Add a daily challenge flow that presents the selected daily problems one at a time or as a compact list, depending on the least disruptive fit with existing screens.
   - Reuse `TacticsProblemScreen` for individual problem play unless a dedicated challenge runner is needed for progress.
   - Track in-memory progress first if persistent progress is out of scope for the initial change; explicitly isolate persistence as a future step if not implemented.
   - Add a Daily Challenge history screen or placeholder list that can show previous dates once persistence exists. The first implementation may generate recent days deterministically from the same daily selection logic.

5. Implement Focused Practice navigation
   - Add a Focused Practice detail screen that lists second-level concepts or grouped problems for the chosen high-level area.
   - Keep the top-level card free of a full directory tree.
   - Reuse the existing grouped problem card behavior inside the detail screen where it still fits.

6. Update tests and documentation links
   - Update widget tests that assert the main puzzle tab text or current `SkillsScreen` layout.
   - Add tests for the Daily Challenge card, progress label, tags, and Focused Practice card visibility.
   - Add deterministic selection tests for the daily problem set.
   - If feature entry points or test maps are documented elsewhere, update those references.

## Acceptance Criteria

- The training tab displays a single-column flow with exactly two top-level cards: Daily Challenge and Focused Practice.
- Daily Challenge displays today's content tags, challenge progress, a start or continue action, and a history entry.
- Focused Practice displays high-level training areas on the top-level card, without exposing the full knowledge tree.
- Entering a daily challenge lets the user play the selected tactics problems using the existing board/problem interaction flow.
- Entering a focused practice area shows relevant second-level content or grouped problems for that area.
- The third card is not implemented in this change.
- Existing tactics problem parsing and detail-screen behavior remain intact.
- Updated tests reflect the current product requirements rather than only preserving the old puzzle-list assertions.

## Validation Commands

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test test/skills_screen_test.dart test/tactics_problem_repository_test.dart`
- `flutter test`
