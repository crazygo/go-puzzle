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
#   FLUTTER_VERSION=3.41.7
#   FLUTTER_DIST_URL=https://.../flutter_linux_3.41.7-stable.tar.xz
#   FLUTTER_ARCHIVE_LOCAL=/path/to/flutter_linux_*.tar.xz

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

mkdir -p "${TOOLS_DIR}" "${BIN_DIR}" "${CACHE_DIR}"

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

run_checks() {
  cd "${ROOT_DIR}"
  flutter --version
  dart --version

  flutter pub get

  if [[ -f "${ROOT_DIR}/package.json" ]]; then
    log "Installing repo-local Node tooling ..."
    npm install --no-fund --no-audit
  fi

  # Ensure CJK subset font is available for screenshot tests.
  bash "${ROOT_DIR}/scripts/ensure-test-fonts.sh"

  # 编译/静态检查（对新同学友好：保留输出，但不因 info/warning 中断）
  flutter analyze --no-fatal-infos --no-fatal-warnings
  dart analyze --no-fatal-warnings
}

main() {
  install_flutter
  ensure_path
  warmup
  run_checks
  log "Environment is ready and checks passed."
}

main "$@"
