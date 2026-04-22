# Development Flow

This document covers local setup, validation, builds, deployment, and puzzle data authoring for Go Puzzle.

## Environment

Required tools:

- Flutter SDK 3.22.0 or newer. CI and bootstrap scripts currently pin Flutter 3.41.7.
- Dart 3.0.0 or newer.
- Xcode 14 or newer for iOS builds.
- CocoaPods 1.16.2 or newer when using Xcode 16.1 project formats.

For a new local or Codex/container environment, run:

```bash
bash scripts/init-dev.sh
```

The script installs or reuses Flutter, links `flutter` and `dart`, runs dependency installation, and performs analysis checks.

## Local Development

Install dependencies:

```bash
flutter pub get
```

Run the app on a simulator or connected device:

```bash
flutter run
```

Run tests:

```bash
flutter test
```

Run analysis:

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
dart analyze --no-fatal-warnings
```

## Web Build

Enable web support and build a release artifact:

```bash
flutter config --enable-web
flutter build web --release --no-wasm-dry-run
```

For GitHub Pages, the workflow builds with:

```bash
flutter build web --release --no-wasm-dry-run --base-href /go-puzzle/
```

The output is written to `build/web/`.

## iOS Build

Install CocoaPods dependencies:

```bash
cd ios
pod install --repo-update
cd ..
```

Build a release app without signing:

```bash
flutter build ios --release --no-codesign
```

For local iPhone testing from the home screen, install a Release or Profile build. A Debug iOS build requires Flutter tooling or Xcode attached and exits when launched directly from the device.

Keep Apple signing details machine-local. Store per-developer bundle IDs and team IDs in ignored local config, not committed project files.

## GitHub Pages Deployment

`.github/workflows/build-and-deploy.yml` deploys the web build to GitHub Pages on pushes to `main`, `master`, and `copilot/**`. Pull requests to `main` and `master` run the same validation and build path.

The workflow:

1. Installs Flutter 3.41.7.
2. Runs `flutter pub get`.
3. Runs `flutter test`.
4. Builds web with the `/go-puzzle/` base href.
5. Uploads and deploys the Pages artifact.
6. Builds an unsigned iOS release artifact on macOS.

## Vercel Deployment

`vercel.json` configures Vercel to run:

```bash
bash vercel-build.sh
```

The build script installs Flutter 3.41.7, enables web support, runs `flutter pub get`, and builds `build/web/`.

To deploy manually with the Vercel CLI:

```bash
npm i -g vercel
bash vercel-build.sh
vercel build/web --prod
```

When importing the repository in Vercel, choose "Other" as the framework. The build command and output directory are configured by `vercel.json`.

## Puzzle Data

Each puzzle is represented by a `Puzzle` object:

```dart
Puzzle(
  id: 'unique_id',
  title: 'Puzzle title',
  description: 'Puzzle description',
  boardSize: 9,
  initialStones: [...],
  targetCaptures: [...],
  solutions: [[BoardPosition, ...]],
  category: PuzzleCategory.beginner,
  difficulty: PuzzleDifficulty.easy,
  hint: 'Hint text',
)
```

Important fields:

- `boardSize`: one of the supported board sizes, usually 9, 13, or 19.
- `initialStones`: stones placed before the player starts.
- `targetCaptures`: stones the player is expected to capture.
- `solutions`: one or more accepted move sequences.
- `category` and `difficulty`: metadata used by the training UI.

## Validation Checklist

Before merging behavior or dependency changes, run:

```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```
