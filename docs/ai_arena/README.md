# AI Arena Results

`docs/ai_arena/latest_ladder.b<board-size>.json` files are the tracked AI arena
ranking snapshots. Each file stores the current ordered ladder, its hash, the
run config, and the number of completed matches in a compact form for one board
size.

The default run uses 12 games per match: 6 empty-board games and 6 twist-cross games, with colors alternated inside each opening pair.

Detailed match logs are local artifacts. They are appended to
`build/ai_arena/matches.b<board-size>.jsonl` after each completed match, so
runs can still be inspected, tailed, replayed, or resumed without committing
large JSONL files to Git.

```sh
tail -f build/ai_arena/matches.b9.jsonl
```

## Common Commands

Run the default 9x9 ladder pass and update `latest_ladder.b9.json`:

```sh
dart run tool/capture_ai_arena_runner.dart --force
```

Run a 13x13 pass and update `latest_ladder.b13.json`:

```sh
dart run tool/capture_ai_arena_runner.dart --force --board-size 13
```

Run a full 19x19 pass and update `latest_ladder.b19.json`:

```sh
dart run tool/capture_ai_arena_runner.dart --force --board-size 19
```

Run a capped 19x19 smoke pass for local validation:

```sh
dart run tool/capture_ai_arena_runner.dart --smoke --force --board-size 19 --max-moves 128
```

Use `--no-log` when only the latest ladder snapshot is needed and local replay
logs are not required.
