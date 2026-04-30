# AI Arena Runner

This document defines the AI arena run terms and the expected local workflow.

## Terms

- **Move**: One stone placement or pass made by one side inside a game.
- **Game**: One complete capture-go game made of many moves. A game ends with a
  black win, white win, or draw.
- **Match**: One head-to-head comparison between two AI configs. The runner
  defaults to 10 games per match and alternates colors between the two configs.
- **Ladder**: The ordered ranking of AI configs, strongest first. The ladder can
  change only after a match finishes, because promotion rules use the match's
  final win counts.

## Artifact Policy

The repository tracks only the latest compact ladder snapshot:

```bash
docs/ai_arena/latest_ladder.json
```

Detailed per-match logs are local artifacts under `build/ai_arena/` and are not
committed to Git. The default log path is:

```bash
build/ai_arena/matches.jsonl
```

Each JSONL line is appended after a match completes. This is the fastest useful
checkpoint frequency in the current architecture: moves and games do not update
the ladder by themselves, while each completed match can update both the local
log and `latest_ladder.json`.

To watch progress during a run:

```bash
tail -f build/ai_arena/matches.jsonl
```

## Common Commands

Run the default 9x9 pass and update the tracked latest ladder:

```bash
dart run tool/capture_ai_arena_runner.dart --force
```

Run 13x13 and keep a separate local log:

```bash
dart run tool/capture_ai_arena_runner.dart --force --board-size 13 --output-log build/ai_arena/matches.b13.jsonl
```

Run a capped 19x19 smoke pass:

```bash
dart run tool/capture_ai_arena_runner.dart --smoke --force --board-size 19 --max-moves 128 --output-log build/ai_arena/matches.b19.smoke.jsonl
```

Skip detailed logs when only the latest ladder snapshot is needed:

```bash
dart run tool/capture_ai_arena_runner.dart --force --no-log
```

## Resume Behavior

When logging is enabled, resume uses:

- `build/ai_arena/manifest.json`
- `build/ai_arena/matches.jsonl`

The runner checks the manifest config hash before reusing prior local logs. The
hash includes board size, capture target, rounds, promotion threshold, base seed,
candidate IDs, and max moves.
