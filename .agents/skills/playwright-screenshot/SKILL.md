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
- uses an environment-provided Chrome or Chromium executable when configured
- otherwise lets Playwright use its installed browser registry
- launches the browser through Playwright
- or connects to an already-running Chromium browser when `PLAYWRIGHT_CDP_URL` is set
- waits for visual stability instead of capturing the first rendered frame
- uses a fixed viewport and device scale factor for repeatable comparison

For Flutter Web, the expected lifecycle is:

1. Start a new `flutter run -d web-server --web-hostname 127.0.0.1 --web-port <port>` process.
2. Wait until `lib/main.dart is being served at ...`.
3. Run `scripts/browser_screenshot.sh`.
4. Stop the Flutter process with `q` in the PTY, or kill the exact process if it does not exit.
5. Use a new process for the next shot, even when only params changed.

If repeated screenshot attempts stall before serving at `Resolving dependencies...`
or `Downloading packages...`, do not keep retrying the default launch. Once
dependencies are already present, start the screenshot server with
`flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port <port>`.
This keeps the fresh-process rule while avoiding nondeterministic package
resolution during visual iteration.

The skill expects a local Playwright dependency to already exist. It does not rely on a network install during execution.

Supported resolution order for the Playwright module:

- `PLAYWRIGHT_MODULE_PATH`, if set
- local `playwright`
- local `playwright-core`

Supported browser resolution order:

- `PLAYWRIGHT_CDP_URL`, if set, bypasses browser launch and connects to that remote-debugging endpoint
- `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`, if set
- `CHROME_BIN`, if set
- common binaries on `PATH` such as `google-chrome`, `google-chrome-stable`, `chromium`, `chromium-browser`, or `chrome`
- Playwright's installed browser registry, when available

Do not hard-code machine-specific browser paths in project workflows. CI and local machines should provide browser location through environment variables, PATH, or CDP.

## macOS Chrome Crash Handling

On macOS, `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` can crash before navigation with a report showing `HIServices _RegisterApplication` / `TransformProcessType` and `SIGABRT`. This is a browser process registration failure, not a page readiness problem.

Playwright's installed Chromium can also fail before navigation if the current execution sandbox blocks macOS Mach port registration. The error commonly includes `MachPortRendezvous`, `bootstrap_check_in`, or `Permission denied (1100)`.

When this happens:

- Do not treat it as a Flutter render failure.
- Do not keep retrying the same crashing browser executable.
- Prefer Playwright's installed Chromium, a non-app-bundle Chromium/Chrome-for-Testing executable via `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`, or a CI-provided `CHROME_BIN`.
- If the current execution context cannot launch the browser, move screenshot execution to a non-sandboxed runner or start Chrome/Chromium outside that context with remote debugging and connect to it with `PLAYWRIGHT_CDP_URL`.
- Record the failure in the final status and keep the current code iteration marked as `pending screenshot verification`.

External CDP fallback:

```bash
"$CHROME_BIN" \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/go-puzzle-cdp-chrome

PLAYWRIGHT_CDP_URL=http://127.0.0.1:9222 \
  bash skills/playwright-screenshot/scripts/browser_screenshot.sh \
  "http://127.0.0.1:<port>/?threeBoardDebug=1" \
  ".cache/screenshots/YYYY-MM-DD-HH-mm-threeBoardDebug-1.png" \
  402 874 3 12000
```

`CHROME_BIN` is an example environment-provided executable. It may point to Chrome, Chromium, or Chrome for Testing depending on the machine. Do not commit a local absolute browser path into the workflow.

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
