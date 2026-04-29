#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <url> <output_path> [width] [height] [device_scale_factor] [wait_ms]" >&2
  exit 1
fi

url="$1"
output_path="$2"
width="${3:-402}"
height="${4:-874}"
device_scale_factor="${5:-3}"
wait_ms="${6:-12000}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_step() {
  printf '[screenshot] %s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

archive_existing() {
  local current="$1"
  if [ ! -e "${current}" ]; then
    return 0
  fi

  local base ext archived version
  base="${current%.*}"
  ext=".${current##*.}"
  if [ "${base}" = "${current}" ]; then
    ext=""
  fi

  version=2
  archived="${base} v${version}${ext}"
  while [ -e "${archived}" ]; do
    version=$((version + 1))
    archived="${base} v${version}${ext}"
  done

  mv "${current}" "${archived}"
}

resolve_browser() {
  local candidate

  for candidate in \
    "${PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH:-}" \
    "${CHROME_BIN:-}"
  do
    if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  for candidate in \
    google-chrome \
    google-chrome-stable \
    chromium \
    chromium-browser \
    chrome \
    microsoft-edge \
    microsoft-edge-stable
  do
    if command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return 0
    fi
  done

  return 1
}

mkdir -p "$(dirname "${output_path}")"
archive_existing "${output_path}"

if [ -z "${PLAYWRIGHT_CDP_URL:-}" ]; then
  if browser_bin="$(resolve_browser 2>/dev/null)"; then
    log_step "browser=${browser_bin}"
    export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH="${browser_bin}"
  else
    log_step "browser=playwright-registry"
  fi
else
  log_step "browser=cdp ${PLAYWRIGHT_CDP_URL}"
fi

log_step "url=${url}"
log_step "output=${output_path}"
log_step "viewport=${width}x${height} dpr=${device_scale_factor} wait_ms=${wait_ms}"

node "${script_dir}/playwright_screenshot.mjs" \
  "${url}" \
  "${output_path}" \
  "${width}" \
  "${height}" \
  "${device_scale_factor}" \
  "${wait_ms}"
