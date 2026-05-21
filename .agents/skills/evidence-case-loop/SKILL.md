---
name: evidence-case-loop
description: Use when a stubborn or complex bug must be fixed with repeatable before/after evidence in this repo. Guides agents to create a case-specific evidence harness under tools/evidence, capture baseline proof, make a scoped fix, rerun the same path, and report concrete screenshots/logs/checkpoints. Especially useful for Flutter Web blank screens, rendering bugs, browser-only behavior, AI gameplay regressions, and issues where console output alone is not enough.
---

# Evidence Case Loop

Use this skill when the user asks for evidence-driven debugging, screenshot
verification, repeatable browser proof, or when a bug is stubborn enough that a
single manual check is likely to mislead.

The goal is to turn one bug into a small, rerunnable case with named
checkpoints. Do not claim the bug is fixed until the same harness that
reproduced the baseline failure passes after the fix.

## Case Directory

Create or update a case-specific directory:

```text
tools/evidence/<case_name>/
```

Recommended files:

```text
tools/evidence/<case_name>/
├── AGENTS.md
├── run.sh
├── flow.mjs
└── checkpoint.mjs     # optional when checks are large enough to split
```

Use `.cache/evidence/<case_name>/<run-id>/` for outputs. Keep generated
screenshots, logs, event dumps, and `summary.json` out of tracked source unless
the user explicitly asks to preserve a fixture.

## AGENTS.md

Write `AGENTS.md` before implementation changes. It is the case contract for
future agents.

Include:

- user-visible bug or requirement
- baseline behavior that must be proven before fixing
- fixed behavior that must be proven after fixing
- required fixture/data shape
- required environment variables
- single run command
- evidence output location
- named checkpoint list
- notes for reading failures

Keep it concrete enough that another agent can rerun the exact case without
rediscovering the path from chat history.

## run.sh

`run.sh` is the only entrypoint.

It should:

- create a sortable run id
- create the output directory
- validate required dependencies and environment variables
- start or verify required local services when appropriate
- run the flow/checkpoint scripts
- print the final evidence directory
- print or point to `summary.json`

If dependencies are missing, install only the minimal repo-declared dependency
set, such as `npm install` when the case uses `playwright-core` from
`package.json`.

## Flow And Checkpoints

The flow script drives the exact user path. Checkpoints answer named questions,
not just "test passed".

Useful checkpoint names:

```text
pageReachable
noSevereConsoleErrors
flutterHostPresent
nonBackgroundPixels
renderedFlutterSurface
interactionReceived
gameStateMatches
aiMoveMatchesExpected
apiStateMatches
dbStateMatches
```

Each checkpoint should include enough detail for failure triage: status code,
console count, screenshot path, pixel ratio, selected move, board state, or
other concrete evidence.

## Browser And Flutter Web Notes

For Flutter Web evidence in this repo, prefer release static output:

```sh
flutter build web --release
python3 -m http.server 8080 --bind 0.0.0.0 --directory build/web
```

Avoid using `flutter run -d web-server` as the default browser proof path. It
can serve a debug/DWDS page that ordinary Chrome or a phone opens as a blank
background because Dart main is not triggered without the debug workflow.

When testing on a phone, bind the static server to `0.0.0.0` and report both:

```text
http://localhost:<port>
http://<local-lan-ip>:<port>
```

CanvasKit paints text into canvas, so DOM text can be empty even when the UI is
visible. For rendering proof, prefer a combination of:

- Flutter host/canvas presence
- screenshot non-background pixel ratio
- screenshot image inspection
- absence of severe console/page/request failures

Do not treat `document.body.innerText == ""` as a blank-screen failure by
itself on CanvasKit pages.

## Loop

1. Create or update the case directory.
2. Write `AGENTS.md` before implementation changes.
3. Write `run.sh` as the only entrypoint.
4. Write flow/checkpoint scripts for the exact path.
5. Run baseline and capture evidence.
6. If baseline does not reproduce the bug, stop and report the evidence gap.
7. Fix implementation or environment setup.
8. Rerun the same harness.
9. Compare before/after evidence.
10. Report evidence paths, changed files, validation, and remaining risks.

## summary.json

Each run should write:

```text
.cache/evidence/<case_name>/<run-id>/summary.json
```

Include:

- run id
- case name
- local URLs
- evidence directory
- screenshot paths
- browser events path
- named checkpoint results
- diagnosis
- important file paths
- failure details when a checkpoint fails

## Final Report

When complete, report:

- baseline evidence path
- fixed evidence path
- changed files
- validation commands run
- local services still running, including port and URL
- environment limitations

Keep the final answer short, but include the exact paths needed to inspect the
proof.
