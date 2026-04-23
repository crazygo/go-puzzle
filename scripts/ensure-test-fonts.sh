#!/usr/bin/env bash
# Downloads NotoSansSC.ttf into .cache/fonts/ for headless screenshot tests.
# If the download fails, CJK characters will show as tofu boxes — that is OK.
#
# Usage:
#   bash scripts/ensure-test-fonts.sh

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${ROOT_DIR}/.cache/fonts"
FONT_TTF="${CACHE_DIR}/NotoSansSC.ttf"
# Variable-font TTF hosted on the noto-cjk GitHub release (subset for SC).
FONT_URL="https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/TTF/Subset/NotoSansSC-VF.ttf"

mkdir -p "${CACHE_DIR}"
log() { echo "[ensure-test-fonts] $*"; }

if [[ -f "${FONT_TTF}" ]]; then
  log "Font already present: ${FONT_TTF}"
  exit 0
fi

log "Downloading NotoSansSC from ${FONT_URL} ..."
if curl -fL --retry 3 --retry-delay 2 -o "${FONT_TTF}" "${FONT_URL}"; then
  log "Done: ${FONT_TTF} ($(du -h "${FONT_TTF}" | cut -f1))"
else
  log "WARNING: Download failed. CJK text will render as tofu boxes in screenshots."
  rm -f "${FONT_TTF}"
fi

