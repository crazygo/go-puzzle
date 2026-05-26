#!/usr/bin/env bash
set -euo pipefail

# Flutter/Dart bootstrap for container init.
# - Installs Flutter SDK to ~/.local/tools/flutter
# - Links flutter/dart into ~/.local/bin
# - Runs pub get (analyze checks are opt-in via --analyze)
#
# Usage:
#   bash scripts/init-dev.sh
#   bash scripts/init-dev.sh --analyze
#
# Optional env vars:
#   FLUTTER_VERSION=3.41.7
#   FLUTTER_DIST_URL=https://.../flutter_linux_3.41.7-stable.tar.xz
#   FLUTTER_ARCHIVE_LOCAL=/path/to/flutter_linux_*.tar.xz
#   INIT_DEV_SKIP_KATAGO_MODELS=1
#   KATAGO_ONNX_MODEL_URL=https://.../katago.onnx
#   INIT_DEV_SKIP_RECOGNITION_MODELS=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${HOME}/.local/tools"
BIN_DIR="${HOME}/.local/bin"
CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/init-dev"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.7}"
HOST_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"

case "${HOST_OS}:${HOST_ARCH}" in
  Darwin:arm64)
    FLUTTER_PLATFORM_DIR="macos"
    FLUTTER_ARCHIVE="flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"
    FLUTTER_EXTRACT_MODE="zip"
    FLUTTER_PRECACHE_PLATFORM="macos"
    ;;
  Darwin:x86_64)
    FLUTTER_PLATFORM_DIR="macos"
    FLUTTER_ARCHIVE="flutter_macos_${FLUTTER_VERSION}-stable.zip"
    FLUTTER_EXTRACT_MODE="zip"
    FLUTTER_PRECACHE_PLATFORM="macos"
    ;;
  Linux:x86_64)
    FLUTTER_PLATFORM_DIR="linux"
    FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    FLUTTER_EXTRACT_MODE="tar.xz"
    FLUTTER_PRECACHE_PLATFORM="linux"
    ;;
  Linux:aarch64|Linux:arm64)
    FLUTTER_PLATFORM_DIR="linux"
    FLUTTER_ARCHIVE="flutter_linux_arm64_${FLUTTER_VERSION}-stable.tar.xz"
    FLUTTER_EXTRACT_MODE="tar.xz"
    FLUTTER_PRECACHE_PLATFORM="linux"
    ;;
  *)
    echo "[init-dev] Unsupported Flutter bootstrap host: ${HOST_OS} ${HOST_ARCH}"
    exit 1
    ;;
esac

DEFAULT_DIST_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/${FLUTTER_PLATFORM_DIR}/${FLUTTER_ARCHIVE}"
FLUTTER_DIST_URL="${FLUTTER_DIST_URL:-${DEFAULT_DIST_URL}}"
FLUTTER_ARCHIVE_LOCAL="${FLUTTER_ARCHIVE_LOCAL:-${CACHE_DIR}/${FLUTTER_ARCHIVE}}"
FLUTTER_DIR="${TOOLS_DIR}/flutter"
FLUTTER_VERSION_STAMP="${FLUTTER_DIR}/.installed-version"
MODEL_DIR="${ROOT_DIR}/assets/models"
KATAGO_ONNX_MODEL_FILENAME="katago-kata1-b18c384nbt-batched-fp16.onnx"
DEFAULT_KATAGO_ONNX_MODEL_URL="${DEFAULT_KATAGO_ONNX_MODEL_URL:-https://huggingface.co/kaya-go/kaya/resolve/main/katago_small_b18c384nbt-onnx-batched-fp16.onnx}"
KATAGO_ONNX_MODEL_URL="${KATAGO_ONNX_MODEL_URL:-${DEFAULT_KATAGO_ONNX_MODEL_URL}}"
CAPTURE5_ONNX_MODEL_FILENAME="capture5_13x13_policy_only_v8.onnx"
CAPTURE5_ONNX_MODEL_SHA256="98441223424eef68eaeab35c715f56add24ff0207c0d59ab66a85fdaed4f48c6"
CAPTURE5_ONNX_MODEL_LOCAL="${CAPTURE5_ONNX_MODEL_LOCAL:-/Users/admin/Code/go-puzzle-ml/models/released/${CAPTURE5_ONNX_MODEL_FILENAME}}"
CAPTURE5_ONNX_MODEL_URL="${CAPTURE5_ONNX_MODEL_URL:-}"
RUN_ANALYZE=0

mkdir -p "${TOOLS_DIR}" "${BIN_DIR}" "${CACHE_DIR}" "${MODEL_DIR}"

log() {
  echo "[init-dev] $*"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --analyze)
        RUN_ANALYZE=1
        shift
        ;;
      -h|--help)
        cat <<EOF
Usage:
  bash scripts/init-dev.sh [--analyze]

Options:
  --analyze       Run flutter/dart analyze checks after bootstrap.
  -h, --help      Show this help message and exit.

Also downloads local territory ONNX models into:
  ${MODEL_DIR}/

Also ensures local recognition models are present unless
INIT_DEV_SKIP_RECOGNITION_MODELS=1 is set.

Set INIT_DEV_SKIP_KATAGO_MODELS=1 to skip territory model downloads.
EOF
        exit 0
        ;;
      *)
        log "Unknown argument: $1"
        exit 1
        ;;
    esac
  done
}

ensure_path() {
  case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *) export PATH="${BIN_DIR}:${PATH}" ;;
  esac
}

download_archive_if_needed() {
  if [[ -f "${FLUTTER_ARCHIVE_LOCAL}" ]]; then
    if archive_is_valid "${FLUTTER_ARCHIVE_LOCAL}"; then
      log "Using local Flutter archive: ${FLUTTER_ARCHIVE_LOCAL}"
      return 0
    fi

    if archive_is_cache_owned "${FLUTTER_ARCHIVE_LOCAL}"; then
      log "Removing incomplete or invalid cached Flutter archive: ${FLUTTER_ARCHIVE_LOCAL}"
      rm -f "${FLUTTER_ARCHIVE_LOCAL}"
    else
      log "Flutter archive is invalid: ${FLUTTER_ARCHIVE_LOCAL}"
      log "Replace the archive or unset FLUTTER_ARCHIVE_LOCAL to let init-dev download a fresh copy."
      return 1
    fi
  fi

  log "Downloading Flutter archive from: ${FLUTTER_DIST_URL}"
  local partial_archive="${FLUTTER_ARCHIVE_LOCAL}.partial"
  local curl_resume_args=()

  if [[ -f "${partial_archive}" ]]; then
    curl_resume_args=(-C -)
  fi

  if ! curl --http1.1 -fL ${curl_resume_args+"${curl_resume_args[@]}"} --retry 20 --retry-all-errors --retry-delay 1 --connect-timeout 20 --speed-limit 1024 --speed-time 60 "${FLUTTER_DIST_URL}" -o "${partial_archive}"; then
    log "Download failed."
    log "If your environment blocks outbound network, pre-download archive and set:"
    log "  FLUTTER_ARCHIVE_LOCAL=/abs/path/to/${FLUTTER_ARCHIVE}"
    return 1
  fi

  mv "${partial_archive}" "${FLUTTER_ARCHIVE_LOCAL}"
  if ! archive_is_valid "${FLUTTER_ARCHIVE_LOCAL}"; then
    log "Downloaded Flutter archive is invalid: ${FLUTTER_ARCHIVE_LOCAL}"
    if archive_is_cache_owned "${FLUTTER_ARCHIVE_LOCAL}"; then
      rm -f "${FLUTTER_ARCHIVE_LOCAL}"
    fi
    return 1
  fi
}

archive_is_valid() {
  local archive="$1"

  case "${FLUTTER_EXTRACT_MODE}" in
    zip)
      unzip -tq "${archive}" >/dev/null
      ;;
    tar.xz)
      tar -tJf "${archive}" >/dev/null
      ;;
  esac
}

archive_is_cache_owned() {
  local archive="$1"

  case "${archive}" in
    "${CACHE_DIR}"/*) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_flutter_git_safe() {
  if [[ -d "${FLUTTER_DIR}" ]]; then
    chown -R "$(id -u):$(id -g)" "${FLUTTER_DIR}" || true
    git config --global --add safe.directory "${FLUTTER_DIR}" || true
  fi
}

read_installed_flutter_version() {
  if [[ -f "${FLUTTER_VERSION_STAMP}" ]]; then
    tr -d '[:space:]' < "${FLUTTER_VERSION_STAMP}"
    return 0
  fi

  if [[ -x "${FLUTTER_DIR}/bin/flutter" ]]; then
    "${FLUTTER_DIR}/bin/flutter" --version 2>/dev/null | sed -n "s/^Flutter \([0-9][^ ]*\).*/\1/p" | head -n 1
    return 0
  fi

  return 1
}

install_flutter() {
  local installed_version=""

  if [[ -x "${FLUTTER_DIR}/bin/flutter" ]]; then
    ensure_flutter_git_safe
    installed_version="$(read_installed_flutter_version || true)"

    if [[ -n "${installed_version}" && "${installed_version}" == "${FLUTTER_VERSION}" ]]; then
      log "Flutter ${installed_version} already installed at ${FLUTTER_DIR}"
    else
      log "Reinstalling Flutter (found: ${installed_version:-unknown}, required: ${FLUTTER_VERSION})"
      rm -rf "${FLUTTER_DIR}"
    fi
  fi

  if [[ ! -x "${FLUTTER_DIR}/bin/flutter" ]]; then
    download_archive_if_needed
    log "Extracting Flutter SDK ..."
    rm -rf "${FLUTTER_DIR}"
    case "${FLUTTER_EXTRACT_MODE}" in
      zip)
        unzip -oq "${FLUTTER_ARCHIVE_LOCAL}" -d "${TOOLS_DIR}"
        ;;
      tar.xz)
        tar --no-same-owner -xJf "${FLUTTER_ARCHIVE_LOCAL}" -C "${TOOLS_DIR}"
        ;;
    esac
    ensure_flutter_git_safe
  fi

  echo "${FLUTTER_VERSION}" > "${FLUTTER_VERSION_STAMP}"

  ln -sf "${FLUTTER_DIR}/bin/flutter" "${BIN_DIR}/flutter"
  ln -sf "${FLUTTER_DIR}/bin/dart" "${BIN_DIR}/dart"
}

download_file_if_needed() {
  local url="$1"
  local target="$2"
  local cache_file="$3"

  if [[ -s "${target}" ]]; then
    log "Using existing model file: ${target}"
    if [[ ! -s "${cache_file}" && "${target}" != "${cache_file}" ]]; then
      cp -f "${target}" "${cache_file}"
      log "Seeded model cache from existing file: ${cache_file}"
    fi
    return 0
  fi

  if [[ -s "${cache_file}" ]]; then
    log "Using cached model archive: ${cache_file}"
    cp -f "${cache_file}" "${target}"
    return 0
  fi

  log "Downloading model from: ${url}"
  if ! curl -fL --retry 3 --connect-timeout 20 "${url}" -o "${cache_file}.part"; then
    rm -f "${cache_file}.part"
    log "Model download failed for ${target}"
    return 1
  fi

  mv "${cache_file}.part" "${cache_file}"
  cp -f "${cache_file}" "${target}"
}

download_katago_models() {
  if [[ "${INIT_DEV_SKIP_KATAGO_MODELS:-0}" == "1" ]]; then
    log "Skipping ONNX model downloads (INIT_DEV_SKIP_KATAGO_MODELS=1)."
    return 0
  fi

  local target="${MODEL_DIR}/${KATAGO_ONNX_MODEL_FILENAME}"
  local cache_file="${CACHE_DIR}/${KATAGO_ONNX_MODEL_FILENAME}"
  if ! download_file_if_needed "${KATAGO_ONNX_MODEL_URL}" "${target}" "${cache_file}"; then
    log "Missing KataGo ONNX model. Re-run init-dev after restoring network access or set KATAGO_ONNX_MODEL_URL."
    log "Continuing without the ONNX model; supported paths will surface model readiness or fallback according to product rules."
  fi

  local capture_target="${MODEL_DIR}/${CAPTURE5_ONNX_MODEL_FILENAME}"
  local capture_cache_file="${CACHE_DIR}/${CAPTURE5_ONNX_MODEL_FILENAME}"
  if [[ -s "${capture_target}" ]]; then
    log "Using existing Capture5 ONNX model file: ${capture_target}"
  elif [[ -s "${CAPTURE5_ONNX_MODEL_LOCAL}" ]]; then
    cp -f "${CAPTURE5_ONNX_MODEL_LOCAL}" "${capture_target}"
    log "Copied local Capture5 ONNX model file: ${capture_target}"
  elif [[ -n "${CAPTURE5_ONNX_MODEL_URL}" ]]; then
    if ! download_file_if_needed "${CAPTURE5_ONNX_MODEL_URL}" "${capture_target}" "${capture_cache_file}"; then
      log "Missing Capture5 ONNX model. Re-run init-dev after restoring network access or set CAPTURE5_ONNX_MODEL_URL."
    fi
  else
    log "Skipping Capture5 ONNX model download; set CAPTURE5_ONNX_MODEL_URL or CAPTURE5_ONNX_MODEL_LOCAL to enable it."
  fi

  if [[ -s "${capture_target}" ]]; then
    local actual_sha
    actual_sha="$(shasum -a 256 "${capture_target}" | awk '{print $1}')"
    if [[ "${actual_sha}" != "${CAPTURE5_ONNX_MODEL_SHA256}" ]]; then
      log "Capture5 ONNX checksum mismatch: expected ${CAPTURE5_ONNX_MODEL_SHA256}, got ${actual_sha}"
      return 1
    fi
  fi
}

warmup() {
  flutter config --no-analytics >/dev/null 2>&1 || true
  dart --disable-analytics >/dev/null 2>&1 || true
  flutter precache "--${FLUTTER_PRECACHE_PLATFORM}"
}

ensure_recognition_models() {
  if [[ "${INIT_DEV_SKIP_RECOGNITION_MODELS:-0}" == "1" ]]; then
    log "Skipping recognition model download (INIT_DEV_SKIP_RECOGNITION_MODELS=1)."
    return 0
  fi

  bash "${ROOT_DIR}/scripts/download-recognition-models.sh"
}

run_checks() {
  cd "${ROOT_DIR}"
  flutter --version
  dart --version

  flutter pub get
  download_katago_models
  ensure_recognition_models

  if [[ "${INIT_DEV_SKIP_NPM:-0}" == "1" ]]; then
    log "Skipping repo-local Node tooling install (INIT_DEV_SKIP_NPM=1)."
  elif [[ -n "${npm_lifecycle_event:-}" ]]; then
    log "Skipping repo-local Node tooling install during npm lifecycle (${npm_lifecycle_event})."
  elif [[ -f "${ROOT_DIR}/package.json" ]]; then
    if command -v npm >/dev/null 2>&1; then
      log "Installing repo-local Node tooling ..."
      if [[ -f "${ROOT_DIR}/package-lock.json" ]]; then
        npm ci --no-fund --no-audit
      else
        npm install --no-fund --no-audit
      fi
    else
      log "Skipping repo-local Node tooling install because npm is not available."
    fi
  fi

  # Ensure CJK subset font is available for screenshot tests.
  bash "${ROOT_DIR}/scripts/ensure-test-fonts.sh"

  if [[ "${RUN_ANALYZE}" == "1" ]]; then
    # 编译/静态检查（对新同学友好：保留输出，但不因 info/warning 中断）
    flutter analyze --no-fatal-infos --no-fatal-warnings
    dart analyze --no-fatal-warnings
  else
    log "Skipping analyze checks by default. Pass --analyze to enable."
  fi
}

main() {
  parse_args "$@"
  install_flutter
  ensure_path
  warmup
  run_checks
  if [[ "${RUN_ANALYZE}" == "1" ]]; then
    log "Environment is ready and checks passed."
  else
    log "Environment is ready (analyze skipped; pass --analyze to run checks)."
  fi
}

main "$@"
