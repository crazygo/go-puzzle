#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN=flutter
else
  FLUTTER_BIN="${HOME}/.local/bin/flutter"
fi

SCREENSHOT_DIR="${SCREENSHOT_DIR:-${HOME}/.cache/go-puzzle/screenshots}"
GENERATED_SCREENSHOT="${SCREENSHOT_DIR}/first_screen.png"
mkdir -p "${SCREENSHOT_DIR}"

rm -f "${GENERATED_SCREENSHOT}"

"${FLUTTER_BIN}" test --no-pub test/screenshots/first_screen_screenshot_test.dart \
  --dart-define=CAPTURE_SCREENSHOTS=true \
  --dart-define=CAPTURE_SCREENSHOT_PATH="${GENERATED_SCREENSHOT}"

test -f "${GENERATED_SCREENSHOT}"

echo "[capture-first-screen] Screenshot generated: ${GENERATED_SCREENSHOT}"
