---
name: playwright-screenshot
description: Use when you need browser-rendered screenshots of local or remote web pages for UI comparison, visual QA, or preserving screenshot history. Uses Playwright with a portable browser-resolution flow for macOS and Linux, and keeps screenshot history by renaming older files instead of deleting them.
---

# Playwright Screenshot

Use this skill when the user wants a real browser screenshot instead of a framework render or emulator export.

## Workflow

1. Decide the target URL, output path, and viewport.
2. Prefer repo-relative output paths such as `.cache/screenshots/page.png`.
3. Use the bundled script instead of rewriting Playwright launch code.
4. For Flutter Web verification, always start a fresh `flutter run -d web-server` process for the shot. Do not reuse a previous server and do not rely on hot restart; hot restart is not deterministic enough for screenshot comparison.
5. After the screenshot is captured, stop/kill the Flutter web-server process before taking the next screenshot. A fresh process per shot keeps the flow idempotent.
6. If the output file already exists, keep the history by renaming the old file to `name vN.ext` before writing the new file.
7. Report the exact viewport, DPR, URL, and server lifecycle used in the final response.

## Runtime Model

Run `scripts/browser_screenshot.sh`. It:

- archives the previous screenshot if present
- resolves a system Chrome or Chromium executable without hard-coded OS assumptions
- launches the browser through Playwright
- waits for visual stability instead of capturing the first rendered frame
- uses a fixed viewport and device scale factor for repeatable comparison

For Flutter Web, the expected lifecycle is:

1. Start a new `flutter run -d web-server --web-hostname 127.0.0.1 --web-port <port>` process.
2. Wait until `lib/main.dart is being served at ...`.
3. Run `scripts/browser_screenshot.sh`.
4. Stop the Flutter process with `q` in the PTY, or kill the exact process if it does not exit.
5. Use a new process for the next shot, even when only params changed.

The skill expects a local Playwright dependency to already exist. It does not rely on a network install during execution.

Supported resolution order for the Playwright module:

- `PLAYWRIGHT_MODULE_PATH`, if set
- local `playwright`
- local `playwright-core`

Supported browser resolution order:

- `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`, if set
- `CHROME_BIN`, if set
- common binaries on `PATH` such as `google-chrome`, `google-chrome-stable`, `chromium`, `chromium-browser`, or `chrome`
- common macOS app bundle executables as a fallback only

## iPhone 17 Preset

For iPhone 17 browser screenshots, use:

- CSS viewport: `402x874`
- Device scale factor: `3`

This is derived from Apple’s 1206x2622 display resolution. If the user asks for the latest device dimensions, verify the current official specs first.

Example:

```bash
bash skills/playwright-screenshot/scripts/browser_screenshot.sh \
  "http://localhost:8081" \
  ".cache/screenshots/particle.png" \
  402 874 3 12000
```

Arguments are:

1. URL
2. Output path
3. Width in CSS pixels
4. Height in CSS pixels
5. Device scale factor
6. Extra wait time in milliseconds after navigation

## Setup Notes

- If Playwright is missing, install it in the repo instead of in a home-directory tool cache.
- If Playwright browsers are not installed, prefer pointing Playwright at a system Chrome or Chromium executable with `CHROME_BIN` or `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`.
- For CJK screenshots, wire the font into Flutter assets and the app theme. Do not rely on the browser eventually swapping in a fallback font after first paint.
- `flutter test` screenshot rendering and browser rendering solve fonts differently. Do not assume a `FontLoader` test fix automatically applies to Playwright.
- In CI or Linux containers, the launcher may add `--no-sandbox` and `--disable-dev-shm-usage` automatically when needed.
- Keep the viewport fixed during visual comparison so only the UI changes between iterations.
