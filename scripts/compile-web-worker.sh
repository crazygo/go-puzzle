#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/compile-web-worker.sh
#
# Compiles the AI search Web Worker Dart entrypoint to a standalone JS bundle.
#
# The compiled ai_search_worker.dart.js must be present inside the `web/`
# directory before `flutter build web` runs so that Flutter copies it into
# the output bundle.
#
# Usage:
#   bash scripts/compile-web-worker.sh
#
# Prerequisites:
#   - `dart` must be on $PATH (i.e. Flutter SDK already installed)
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKER_SRC="${ROOT_DIR}/web/ai_search_worker.dart"
WORKER_OUT="${ROOT_DIR}/web/ai_search_worker.dart.js"

echo "[compile-web-worker] Compiling ${WORKER_SRC} → ${WORKER_OUT} …"
dart compile js "${WORKER_SRC}" \
    -o "${WORKER_OUT}" \
    --no-source-maps
echo "[compile-web-worker] Done."
