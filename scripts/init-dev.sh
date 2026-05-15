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
#   INIT_DEV_SKIP_RECOGNITION_MODELS=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${HOME}/.local/tools"
BIN_DIR="${HOME}/.local/bin"
CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/init-dev"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.7}"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
DEFAULT_DIST_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"
FLUTTER_DIST_URL="${FLUTTER_DIST_URL:-${DEFAULT_DIST_URL}}"
FLUTTER_ARCHIVE_LOCAL="${FLUTTER_ARCHIVE_LOCAL:-${CACHE_DIR}/${FLUTTER_ARCHIVE}}"
FLUTTER_DIR="${TOOLS_DIR}/flutter"
FLUTTER_VERSION_STAMP="${FLUTTER_DIR}/.installed-version"
RUN_ANALYZE=0

mkdir -p "${TOOLS_DIR}" "${BIN_DIR}" "${CACHE_DIR}"

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
        cat <<'EOF'
Usage:
  bash scripts/init-dev.sh [--analyze]

Options:
  --analyze       Run flutter/dart analyze checks after bootstrap.
  -h, --help      Show this help message and exit.
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
    log "Using local Flutter archive: ${FLUTTER_ARCHIVE_LOCAL}"
    return 0
  fi

  log "Downloading Flutter archive from: ${FLUTTER_DIST_URL}"
  if ! curl -fL --retry 3 --connect-timeout 20 "${FLUTTER_DIST_URL}" -o "${FLUTTER_ARCHIVE_LOCAL}"; then
    log "Download failed."
    log "If your environment blocks outbound network, pre-download archive and set:"
    log "  FLUTTER_ARCHIVE_LOCAL=/abs/path/to/${FLUTTER_ARCHIVE}"
    return 1
  fi
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
    tar --no-same-owner -xJf "${FLUTTER_ARCHIVE_LOCAL}" -C "${TOOLS_DIR}"
    ensure_flutter_git_safe
  fi

  echo "${FLUTTER_VERSION}" > "${FLUTTER_VERSION_STAMP}"

  ln -sf "${FLUTTER_DIR}/bin/flutter" "${BIN_DIR}/flutter"
  ln -sf "${FLUTTER_DIR}/bin/dart" "${BIN_DIR}/dart"
}

warmup() {
  flutter config --no-analytics >/dev/null 2>&1 || true
  dart --disable-analytics >/dev/null 2>&1 || true
  flutter precache --linux
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
