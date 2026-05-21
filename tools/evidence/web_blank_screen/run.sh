#!/usr/bin/env bash
set -euo pipefail

url="${1:-http://localhost:8080}"
case_name="web_blank_screen"
run_id="$(date +%Y-%m-%d-%H-%M-%S)"
out_dir=".cache/evidence/${case_name}/${run_id}"

mkdir -p "$out_dir"

if [ ! -d node_modules/playwright-core ]; then
  npm install
fi

node tools/evidence/web_blank_screen/flow.mjs "$url" "$out_dir" "$run_id"

echo "Evidence directory: $out_dir"
echo "Summary: $out_dir/summary.json"
