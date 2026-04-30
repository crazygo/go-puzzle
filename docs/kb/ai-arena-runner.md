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

The repository tracks compact ladder snapshots by board size:

```bash
docs/ai_arena/latest_ladder.b9.json
docs/ai_arena/latest_ladder.b13.json
docs/ai_arena/latest_ladder.b19.json
```

Detailed per-match logs are local artifacts under `build/ai_arena/` and are not
committed to Git. The default log path is:

```bash
build/ai_arena/matches.b<board-size>.jsonl
```

Each JSONL line is appended after a match completes. This is the fastest useful
checkpoint frequency in the current architecture: moves and games do not update
the ladder by themselves, while each completed match can update both the local
log and the board-size-specific latest ladder snapshot.

To watch progress during a run:

```bash
tail -f build/ai_arena/matches.b9.jsonl
```

## Common Commands

Run the default 9x9 pass and update `latest_ladder.b9.json`:

```bash
dart run tool/capture_ai_arena_runner.dart --force
```

Run 13x13 and update `latest_ladder.b13.json`:

```bash
dart run tool/capture_ai_arena_runner.dart --force --board-size 13
```

Run 19x19 and update `latest_ladder.b19.json`:

```bash
dart run tool/capture_ai_arena_runner.dart --force --board-size 19
```

Run a capped 19x19 smoke pass:

```bash
dart run tool/capture_ai_arena_runner.dart --smoke --force --board-size 19 --max-moves 128
```

Skip detailed logs when only the latest ladder snapshot is needed:

```bash
dart run tool/capture_ai_arena_runner.dart --force --no-log
```

## Resume Behavior

When logging is enabled, resume uses:

- `build/ai_arena/manifest.b<board-size>.json`
- `build/ai_arena/matches.b<board-size>.jsonl`

The runner checks the manifest config hash before reusing prior local logs. The
hash includes board size, capture target, rounds, promotion threshold, base seed,
candidate IDs, and max moves.
