#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="${ROOT_DIR}/assets/models/recognition"
TAG="${GO_RECOGNITION_MODEL_TAG:-go-recognition-models-v1}"
BASE_URL="${GO_RECOGNITION_MODEL_BASE_URL:-https://github.com/crazygo/go-puzzle/releases/download/${TAG}}"

BOARD_MODEL="go_board_pose_yolov8n.onnx"
BOARD_SHA256="8cb2b9a1634f4bef26f418d4a5b8c1140c355c8892ef7d985e4278aa01078f4f"
STONES_MODEL="go_stones_yolov8n.onnx"
STONES_SHA256="8bd3aaf72e9f0b0e8212d3f12c587ec720eeb4b8c62e3fc06ccae542ec0bccf1"

log() {
  echo "[recognition-models] $*"
}

sha256_of() {
  shasum -a 256 "$1" | awk '{print $1}'
}

ensure_model() {
  local file_name="$1"
  local expected_sha="$2"
  local target="${MODEL_DIR}/${file_name}"
  local url="${BASE_URL}/${file_name}"

  mkdir -p "${MODEL_DIR}"

  if [[ -f "${target}" ]]; then
    local actual_sha
    actual_sha="$(sha256_of "${target}")"
    if [[ "${actual_sha}" == "${expected_sha}" ]]; then
      log "${file_name} already present"
      return 0
    fi
    log "${file_name} checksum mismatch; re-downloading"
    rm -f "${target}"
  fi

  log "Downloading ${file_name}"
  if ! curl -fL --retry 3 --connect-timeout 20 "${url}" -o "${target}.tmp"; then
    rm -f "${target}.tmp"
    log "Download failed: ${url}"
    return 1
  fi

  local actual_sha
  actual_sha="$(sha256_of "${target}.tmp")"
  if [[ "${actual_sha}" != "${expected_sha}" ]]; then
    rm -f "${target}.tmp"
    log "Checksum mismatch for ${file_name}"
    log "  expected: ${expected_sha}"
    log "  actual:   ${actual_sha}"
    return 1
  fi

  mv "${target}.tmp" "${target}"
}

ensure_model "${BOARD_MODEL}" "${BOARD_SHA256}"
ensure_model "${STONES_MODEL}" "${STONES_SHA256}"
log "Recognition models are ready in ${MODEL_DIR}"
