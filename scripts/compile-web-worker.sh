#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/compile-web-worker.sh
#
# Compiles Web Worker Dart entrypoints to standalone JS bundles.
#
# The compiled worker JS files must be present inside the `web/` directory
# before `flutter build web` runs so that Flutter copies them into the output
# bundle.
#
# Usage:
#   bash scripts/compile-web-worker.sh
#
# Prerequisites:
#   - `dart` must be on $PATH (i.e. Flutter SDK already installed)
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI_SEARCH_WORKER_SRC="${ROOT_DIR}/web/ai_search_worker.dart"
AI_SEARCH_WORKER_OUT="${ROOT_DIR}/web/ai_search_worker.dart.js"
TRAINING_SUGGESTION_WORKER_SRC="${ROOT_DIR}/web/training_suggestion_worker.dart"
TRAINING_SUGGESTION_WORKER_OUT="${ROOT_DIR}/web/training_suggestion_worker.dart.js"

echo "[compile-web-worker] Compiling ${AI_SEARCH_WORKER_SRC} → ${AI_SEARCH_WORKER_OUT} …"
dart compile js "${AI_SEARCH_WORKER_SRC}" \
    -o "${AI_SEARCH_WORKER_OUT}" \
    --no-source-maps
echo "[compile-web-worker] Compiling ${TRAINING_SUGGESTION_WORKER_SRC} → ${TRAINING_SUGGESTION_WORKER_OUT} …"
dart compile js "${TRAINING_SUGGESTION_WORKER_SRC}" \
    -o "${TRAINING_SUGGESTION_WORKER_OUT}" \
    --no-source-maps
TACTICS_ADVICE_WORKER_SRC="${ROOT_DIR}/web/tactics_advice_worker.dart"
TACTICS_ADVICE_WORKER_OUT="${ROOT_DIR}/web/tactics_advice_worker.dart.js"
echo "[compile-web-worker] Compiling ${TACTICS_ADVICE_WORKER_SRC} → ${TACTICS_ADVICE_WORKER_OUT} …"
dart compile js "${TACTICS_ADVICE_WORKER_SRC}" \
    -o "${TACTICS_ADVICE_WORKER_OUT}" \
    --no-source-maps
echo "[compile-web-worker] Done."
