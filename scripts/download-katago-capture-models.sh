#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="${ROOT_DIR}/assets/models"
CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/go-puzzle-katago"
MODEL_FILENAME="katago-kata1-b18c384nbt-batched-fp16.onnx"
MODEL_URL="${KATAGO_ONNX_MODEL_URL:-https://huggingface.co/kaya-go/kaya/resolve/main/katago_small_b18c384nbt-onnx-batched-fp16.onnx}"
MODEL_CACHE="${CACHE_DIR}/${MODEL_FILENAME}"

mkdir -p "${MODEL_DIR}" "${CACHE_DIR}"

log() {
  echo "[katago-capture-models] $*"
}

if [[ ! -s "${MODEL_CACHE}" ]]; then
  log "Downloading ${MODEL_URL}"
  curl --http1.1 -fL \
    --retry 5 \
    --retry-all-errors \
    --connect-timeout 20 \
    --speed-time 30 \
    --speed-limit 1024 \
    "${MODEL_URL}" \
    -o "${MODEL_CACHE}.part"
  mv "${MODEL_CACHE}.part" "${MODEL_CACHE}"
else
  log "Using cached model: ${MODEL_CACHE}"
fi

cp -f "${MODEL_CACHE}" "${MODEL_DIR}/${MODEL_FILENAME}"

log "Installed:"
ls -lh "${MODEL_DIR}/${MODEL_FILENAME}"
