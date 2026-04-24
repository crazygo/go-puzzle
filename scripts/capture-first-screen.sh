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

if [[ -f "${GENERATED_SCREENSHOT}" ]]; then
  max_version=0
  for archived in "${SCREENSHOT_DIR}"/first_screen\ v*.png "${SCREENSHOT_DIR}"/first_screen-v*.png; do
    [[ -e "${archived}" ]] || continue
    basename="$(basename "${archived}")"
    version="${basename#first_screen v}"
    version="${version#first_screen-v}"
    version="${version%.png}"
    if [[ "${version}" =~ ^[0-9]+$ ]] && (( version > max_version )); then
      max_version="${version}"
    fi
  done
  next_version=$((max_version + 1))
  mv "${GENERATED_SCREENSHOT}" "${SCREENSHOT_DIR}/first_screen v${next_version}.png"
fi

"${FLUTTER_BIN}" test --no-pub test/screenshots/first_screen_screenshot_test.dart \
  --dart-define=CAPTURE_SCREENSHOTS=true \
  --dart-define=CAPTURE_SCREENSHOT_PATH="${GENERATED_SCREENSHOT}"

test -f "${GENERATED_SCREENSHOT}"

echo "[capture-first-screen] Screenshot generated: ${GENERATED_SCREENSHOT}"
