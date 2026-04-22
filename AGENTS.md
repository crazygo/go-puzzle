# AGENTS

## Environment bootstrap
- `bash scripts/init-dev.sh` initializes the Flutter/Dart development environment for new contributors and Codex/container environments.
- After dependency or environment changes, run checks from the repo root: `flutter pub get`, `flutter analyze --no-fatal-infos --no-fatal-warnings`, and `flutter test`.

## Planning
- When an implementation plan is requested, write it in English and include these sections in order: Background, Goals, Implementation Plan (phased), and Acceptance Criteria.
- Keep acceptance criteria testable and user-observable where applicable, and include validation commands such as `flutter analyze` and `flutter test` when relevant.
- If a plan should be persisted, save it under `docs/plans/` with a `YYYY-MM-DD-HH-mm` prefix using 24-hour time.

## iOS and signing
- On macOS/iOS, CocoaPods 1.8.4 is too old for Xcode 16.1 project formats; use Homebrew CocoaPods 1.16.2+ before running `pod install`.
- For local iPhone testing from the home screen, install a Release or Profile build. A Debug iOS build requires Flutter tooling/Xcode attached and will exit when launched directly from the device.
- Keep Apple signing details machine-local. Store per-developer bundle IDs and team IDs in ignored local config, not committed project files.
