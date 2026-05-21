# Web Blank Screen Evidence Case

## User-visible bug

Flutter web opens to the app background color but renders no usable UI.

## Baseline behavior to prove

At `http://localhost:8080`, the page loads without obvious resource errors but
the first viewport remains visually blank or has no Flutter-rendered app text.

## Fixed behavior to prove

The same URL renders the app UI, with non-background pixels and at least one
Flutter semantics/visible text marker from the app shell.

## Environment

- Run from the repository root.
- Requires Flutter web to be served separately at `http://localhost:8080`.
- Requires Node dependencies from `package.json`.
- Uses the local Google Chrome app via Playwright Core.

## Run Command

```sh
tools/evidence/web_blank_screen/run.sh http://localhost:8080
```

## Evidence Output

Evidence is written to:

```text
.cache/evidence/web_blank_screen/<run-id>/
```

## Checkpoints

- `pageReachable`: HTTP navigation completed.
- `noSevereConsoleErrors`: no page error or console error entries.
- `flutterHostPresent`: Flutter host elements exist.
- `nonBackgroundPixels`: screenshot has enough pixels different from `#f9f4ec`.
- `renderedFlutterSurface`: Flutter host exists and screenshot has enough
  non-background pixels.

## Failure Reading Notes

Flutter CanvasKit paints text into a canvas, so `document.body.innerText` can be
empty even when the UI is correctly visible. Treat screenshot pixels and Flutter
host presence as the user-visible rendering proof.

If `pageReachable` and `noSevereConsoleErrors` pass but `renderedFlutterSurface`
fails, this is a rendered blank screen rather than a simple asset 404.
