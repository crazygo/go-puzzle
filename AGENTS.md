# AGENTS

## Environment bootstrap
- `bash scripts/init-dev.sh` initializes the Flutter/Dart development environment for new contributors and Codex/container environments.
- If Flutter is required in this repo, run `bash scripts/init-dev.sh` (or `npm run init-dev`) explicitly; do not rely on npm `postinstall` to provision Flutter.
- After dependency or environment changes, run checks from the repo root: `flutter pub get`, `flutter analyze --no-fatal-infos --no-fatal-warnings`, and `flutter test`.

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
