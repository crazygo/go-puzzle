#!/usr/bin/env bash
set -euo pipefail

# Flutter/Dart bootstrap for container init.
# - Installs Flutter SDK to ~/.local/tools/flutter
# - Links flutter/dart into ~/.local/bin
# - Runs pub get + compile checks
#
# Usage:
#   bash scripts/init-dev.sh
#
# Optional env vars:
#   FLUTTER_VERSION=3.24.3
#   FLUTTER_DIST_URL=https://.../flutter_linux_3.24.3-stable.tar.xz
#   FLUTTER_ARCHIVE_LOCAL=/path/to/flutter_linux_*.tar.xz

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${HOME}/.local/tools"
BIN_DIR="${HOME}/.local/bin"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.24.3}"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
DEFAULT_DIST_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"
FLUTTER_DIST_URL="${FLUTTER_DIST_URL:-${DEFAULT_DIST_URL}}"
FLUTTER_ARCHIVE_LOCAL="${FLUTTER_ARCHIVE_LOCAL:-${ROOT_DIR}/.cache/${FLUTTER_ARCHIVE}}"

mkdir -p "${TOOLS_DIR}" "${BIN_DIR}" "${ROOT_DIR}/.cache"

log() {
  echo "[init-dev] $*"
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

install_flutter() {
  if [[ -x "${TOOLS_DIR}/flutter/bin/flutter" ]]; then
    log "Flutter already installed at ${TOOLS_DIR}/flutter"
  else
    download_archive_if_needed
    log "Extracting Flutter SDK ..."
    tar -xJf "${FLUTTER_ARCHIVE_LOCAL}" -C "${TOOLS_DIR}"
  fi

  ln -sf "${TOOLS_DIR}/flutter/bin/flutter" "${BIN_DIR}/flutter"
  ln -sf "${TOOLS_DIR}/flutter/bin/dart" "${BIN_DIR}/dart"
}

warmup() {
  flutter config --no-analytics >/dev/null 2>&1 || true
  dart --disable-analytics >/dev/null 2>&1 || true
  flutter precache --linux
}

run_checks() {
  cd "${ROOT_DIR}"
  flutter --version
  dart --version

  flutter pub get

  # 编译/静态检查（用户要求）
  flutter analyze
  dart analyze
}

main() {
  install_flutter
  ensure_path
  warmup
  run_checks
  log "Environment is ready and checks passed."
}

main "$@"
