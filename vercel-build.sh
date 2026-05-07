#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# vercel-build.sh — Installs Flutter and builds the web release artifact.
# Vercel runs this as the buildCommand (see vercel.json).
# ---------------------------------------------------------------------------
set -euo pipefail

FLUTTER_VERSION="3.41.7"   # pin to the repo's current Flutter version
FLUTTER_DIR="$HOME/flutter"
FLUTTER_VERSION_STAMP="$FLUTTER_DIR/.installed-version"

echo "──────────────────────────────────────────────"
echo " Flutter web build for Vercel"
echo " Flutter version : $FLUTTER_VERSION"
echo "──────────────────────────────────────────────"

# ── 1. Install Flutter (cached between builds via ~/.cache/flutter) ─────────
if [ ! -x "$FLUTTER_DIR/bin/flutter" ] || \
   [ ! -f "$FLUTTER_VERSION_STAMP" ] || \
   [ "$(cat "$FLUTTER_VERSION_STAMP")" != "$FLUTTER_VERSION" ]; then
  rm -rf "$FLUTTER_DIR"
  echo "▸ Cloning Flutter $FLUTTER_VERSION …"
  git clone https://github.com/flutter/flutter.git \
      --depth 1 \
      --branch "$FLUTTER_VERSION" \
      "$FLUTTER_DIR"
  echo "$FLUTTER_VERSION" > "$FLUTTER_VERSION_STAMP"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "▸ Flutter doctor (minimal)…"
flutter doctor --android-licenses 2>/dev/null || true
flutter doctor -v

# ── 2. Enable web support ────────────────────────────────────────────────────
flutter config --enable-web

# ── 3. Install dependencies ──────────────────────────────────────────────────
echo "▸ flutter pub get…"
flutter pub get

# ── 4. Compile the AI search Web Worker ──────────────────────────────────────
# The worker is a standalone Dart program that runs inside a browser
# DedicatedWorker.  It must be compiled before `flutter build web` so that
# Flutter copies the resulting JS to build/web/.
echo "▸ Compiling AI search web worker (web/ai_search_worker.dart)…"
dart compile js web/ai_search_worker.dart \
    -o web/ai_search_worker.dart.js \
    --no-source-maps

# ── 5. Optionally download screenshot-test fonts ─────────────────────────────
if [ "${ENABLE_SCREENSHOT_TEST_FONTS:-}" = "1" ] || \
   [ "${ENABLE_SCREENSHOT_TEST_FONTS:-}" = "true" ]; then
  echo "▸ Ensuring screenshot-test fonts…"
  bash scripts/ensure-test-fonts.sh
else
  echo "▸ Skipping screenshot-test fonts (set ENABLE_SCREENSHOT_TEST_FONTS=1 to enable)…"
fi

# ── 6. Build ─────────────────────────────────────────────────────────────────
echo "▸ Building Flutter web (release)…"
flutter build web \
    --release \
    --no-wasm-dry-run

echo "✓ Build complete → build/web/"
ls -lh build/web/
