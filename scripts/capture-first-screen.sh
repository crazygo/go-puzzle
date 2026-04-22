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
mkdir -p "${SCREENSHOT_DIR}"

"${FLUTTER_BIN}" test test/golden/first_screen_golden_test.dart \
  --dart-define=SCREENSHOT_OUTPUT_DIR="${SCREENSHOT_DIR}" \
  --update-goldens

echo "[capture-first-screen] Screenshot generated: ${SCREENSHOT_DIR}/first_screen.png"
