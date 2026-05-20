# AGENTS

## Environment bootstrap
- `bash scripts/init-dev.sh` initializes the Flutter/Dart development environment for new contributors and Codex/container environments.
- If Flutter is required in this repo, run `bash scripts/init-dev.sh` (or `npm run init-dev`) explicitly; do not rely on npm `postinstall` to provision Flutter.
- After dependency or environment changes, run checks from the repo root: `flutter pub get`, `flutter analyze --no-fatal-infos --no-fatal-warnings`, and `flutter test`.
- If `dart`/`flutter` is missing in shell PATH (`command not found`), run `bash scripts/init-dev.sh` first, then use the repo-local SDK path for the current session: `export PATH="$PWD/.local/flutter/bin:$PATH"`.

## Local web testing
- The capture-game AI search worker is authored at `web/ai_search_worker.dart` and must be compiled to `web/ai_search_worker.dart.js` before browser testing or web release builds: `bash scripts/compile-web-worker.sh`.
- Do not use `flutter run -d web-server` to validate the AI search worker. In this project it may serve missing `web/` assets as HTML or 404, causing browser errors such as `Refused to execute script ... ai_search_worker.dart.js ... MIME type ('text/html')`.
- To test web behavior locally in a way that matches static/cloud hosting, run:
  1. `bash scripts/compile-web-worker.sh`
  2. `flutter build web`
  3. `python3 -m http.server 8081 --bind 127.0.0.1 --directory build/web`
- Verify the worker is served as JavaScript before debugging AI move behavior: `curl -I http://127.0.0.1:8081/ai_search_worker.dart.js` should return `200 OK` with a JavaScript content type such as `text/javascript`.

## AI arena evaluation naming
- The evaluation hierarchy is: **Evaluation Run -> Pair -> Cell -> Game repeats**.
- **Evaluation Run**: One complete arena execution over the configured set of AI config comparisons.
- **Pair**: One unordered comparison between two AI configs within an Evaluation Run.
- **Cell**: One fixed condition combination for a Pair: the two configs, the opening, and the `firstConfig` / first-player direction. Repeats inside a Cell vary by game seed only, not by these fixed conditions.
- **Game**: One played repeat inside a Cell, using one game seed under the Cell's fixed conditions.
- **Opening**: The predefined initial board state or move sequence used as part of a Cell's fixed conditions.
- **First-player direction**: Which config in the Pair is assigned to move first for the Cell, represented by `firstConfig`.

## Planning
- When an implementation plan is requested, write it in English and include these sections in order:
    1. **Background**: Substructured into **Context** (current state), **Problem** (limitations/pain points), and **Motivation** (why this change is valuable).
    2. **Goals**: Clear, high-level objectives.
    3. **Implementation Plan**: Phased approach to delivery.
    4. **Acceptance Criteria**: Testable and user-observable criteria, including validation commands (e.g., `flutter analyze`, `flutter test`).
- If a plan should be persisted, save it under `docs/plans/` with a `YYYY-MM-DD-HH-mm` prefix using 24-hour time.

## iOS and signing
- On macOS/iOS, CocoaPods 1.8.4 is too old for Xcode 16.1 project formats; use Homebrew CocoaPods 1.16.2+ before running `pod install`.
- For local iPhone testing from the home screen, install a Release or Profile build. A Debug iOS build requires Flutter tooling/Xcode attached and will exit when launched directly from the device.
- Keep Apple signing details machine-local. Store per-developer bundle IDs and team IDs in ignored local config, not committed project files.

## Git worktrees
- Feature branch worktrees live inside the repo at `.worktree/<short-name>/`.
- Create with: `git worktree add .worktree/<short-name> -b <branch-name>`
- The `.worktree/` directory is git-ignored; never commit files from within a worktree to the main tree.

## Unit test requirement alignment
- Unit tests must be validated against the **current product/feature requirements** (acceptance criteria, PR description, issue context), not merely adjusted to pass the latest implementation.
- When requirements change, update both production code and tests together; explicitly verify each changed requirement still has a corresponding test assertion.
- Before finalizing, perform a “requirements-to-tests” check: list the key requirements and map each to concrete test cases. If a requirement has no test, add or revise tests.
- Do not treat “tests pass” as sufficient proof. Prioritize tests that reflect real expected behavior, even if that means failing fast until implementation catches up.
