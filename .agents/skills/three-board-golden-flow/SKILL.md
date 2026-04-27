---
name: three-board-golden-flow
description: Controlled 3D Go board golden-iteration workflow for Flutter/Web work. Use when Codex is asked to adjust the 3D board render, lighting, camera, shadows, grid readability, or screenshot/golden comparison flow; make one rendering change at a time, commit it, capture timestamped screenshots with parameter sidecars, and compare only the board region against a golden image.
---

# Three Board Golden Flow

## Core Rule

Use controlled variables by optimization objective. Change exactly one rendering goal per iteration unless the user explicitly asks otherwise.

One objective may require multiple implementation changes when they serve the same visual cause. For example, a `highlight_overlay_structure` iteration may tune reflection, shaft, and front-glow overlays together. Do not interpret controlled variables as "only one numeric parameter".

Examples of one capability:
- Key light intensity/direction
- Sheen/specular contribution
- Ambient/fill balance
- Contact shadow/AO
- Camera/FOV/framing
- Grid contrast/readability
- Board color/material
- Stone roughness/specular

Do not combine themes such as lighting plus camera plus board color in the same iteration.

Prefer simple, correct lighting structure over accumulating compensating lights or overlays. One correct light/overlay relationship is better than many incorrect ones. When repeated numeric tuning has little visual effect, inspect structural causes such as additive fake highlights, transparent overlays, material emissive terms, or debug artifacts before adding new light sources.

## Workflow

1. Identify the single capability being changed and state it before editing.
2. Inspect the current implementation and existing debug flow. Reuse the existing 3D board element and debug panel; do not duplicate the panel.
3. Modify code narrowly for that capability.
4. Run only component-local validation:
   - Formatting for edited files.
   - Analyzer when useful.
   - Relevant widget/screenshot/component tests only.
   - Do not run project-wide `flutter test` for 3D board-only changes unless the user asks or the change touches shared app behavior.
5. Commit the code and record the commit id:
   - Use a concise commit message that names the capability.
   - Use `git rev-parse --short HEAD` for `commit_id`.
6. Capture the screenshot after the commit.
7. Stop/kill the screenshot server after capture. Each screenshot must use a fresh Flutter web-server process; do not use hot restart for iterative captures.
8. Name screenshots with timestamp and params id:
   - Pattern: `.cache/screenshots/YYYY-MM-DD-HH-mm-<params-id>.png`
   - Use 24-hour local time.
   - Derive `<params-id>` from route/query params, e.g. `threeBoardDebug-1`, `threeBoardDebug-1-keyIntensity-0p74`.
9. Write a sidecar text file next to every screenshot:
   - Same basename, `.txt`.
   - Include `commit_id`.
   - Include URL, route/query params, viewport, DPR, wait time.
   - Include server lifecycle, e.g. `server_lifecycle=fresh_process_stopped_after_capture`.
   - Include every current 3D/debug parameter value relevant to the shot, including hidden/default values.
10. Compare latest screenshot to the golden image using only the board region.
11. Output a concise designer/3D-rendering delta report and one next suggested capability to adjust.

## Screenshot Requirements

Use the existing browser screenshot skill/script when available.

Every capture must be process-isolated:
- Start a new Flutter web-server process for the screenshot.
- Do not hot restart an existing server to get a new capture.
- Stop/kill the web-server process immediately after screenshot capture.
- Use a new server process for the next iteration to keep screenshots idempotent.

Default mobile capture:

```bash
bash skills/playwright-screenshot/scripts/browser_screenshot.sh \
  'http://127.0.0.1:<port>/?threeBoardDebug=1' \
  '.cache/screenshots/YYYY-MM-DD-HH-mm-threeBoardDebug-1.png' \
  402 874 3 12000
```

Screenshot mode must hide human-only debug panels. The debug panel may be available from a manual launcher, but it must not cover the board in captured golden-comparison shots.

Disable debug visual artifacts for golden comparison screenshots unless the user specifically asks for them:
- RGB axes
- Debug guides
- Control overlays
- Panel sheets

## Sidecar Template

Use plain `key=value` lines:

```text
commit_id=<short-sha>
url=http://127.0.0.1:<port>/?threeBoardDebug=1
params_id=threeBoardDebug-1
query.threeBoardDebug=1
viewport_css=402x874
device_scale_factor=3
extra_wait_ms=12000
server_lifecycle=fresh_process_stopped_after_capture

changed_capability=<one capability>
debug_page.panel_visible=false
debug_page.show_debug_guides=false
debug_page.scene_scale=<value>
debug_page.camera_lift=<value>
debug_page.camera_depth=<value>
debug_page.target_z_offset=<value>
debug_page.leaf_shadow_opacity=<value>
debug_page.stone_extra_overlay_enabled=<value>
debug_page.board_top_brightness=<value>
debug_page.key_light_position=<x,y,z>
debug_page.fill_light_position=<x,y,z>
debug_page.key_light_intensity=<value>
debug_page.fill_light_intensity=<value>
debug_page.ambient_light_intensity=<value>
debug_page.sheen_light_intensity=<value>
debug_page.key_light_color=<hex>
debug_page.fill_light_color=<hex>
debug_page.ambient_light_color=<hex>
debug_page.sheen_light_color=<hex>
```

## Golden Comparison

Compare only the board region, not full-page layout. Do not comment on:
- Page card layout
- Header text placement
- Tab bar
- Wood texture realism if the current component lacks texture maps and the task is lighting

For comparison vocabulary and factors, read [comparison-rubric.md](references/comparison-rubric.md).

## Output Format

Keep final output short:
- Changed capability
- Commit id
- Screenshot path
- Params sidecar path
- Validation run
- Golden delta report
- Recommended next single capability
