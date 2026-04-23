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
GENERATED_SCREENSHOT="test/screenshots/first_screen.png"
mkdir -p "${SCREENSHOT_DIR}"

"${FLUTTER_BIN}" test test/screenshots/first_screen_screenshot_test.dart \
  --dart-define=CAPTURE_SCREENSHOTS=true \
  --update-goldens

cp "${GENERATED_SCREENSHOT}" "${SCREENSHOT_DIR}/first_screen.png"

echo "[capture-first-screen] Screenshot generated: ${SCREENSHOT_DIR}/first_screen.png"
