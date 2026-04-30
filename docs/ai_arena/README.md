# AI Arena Results

`docs/ai_arena/latest_ladder.json` is the only tracked AI arena ranking
snapshot. It stores the current ordered ladder, its hash, the run config, and
the number of completed matches in a compact form.

Detailed match logs are local artifacts. They are appended to
`build/ai_arena/matches.jsonl` after each completed match, so runs can still be
inspected, tailed, replayed, or resumed without committing large JSONL files to
Git.

```sh
tail -f build/ai_arena/matches.jsonl
```

## Common Commands

Run the default 9x9 ladder pass and update the tracked latest ladder:

```sh
dart run tool/capture_ai_arena_runner.dart --force
```

Run a 13x13 pass while keeping detailed logs under `build/ai_arena/`:

```sh
dart run tool/capture_ai_arena_runner.dart --force --board-size 13 --output-log build/ai_arena/matches.b13.jsonl
```

Run a capped 19x19 smoke pass for local validation:

```sh
dart run tool/capture_ai_arena_runner.dart --smoke --force --board-size 19 --max-moves 128 --output-log build/ai_arena/matches.b19.smoke.jsonl
```

Use `--no-log` when only the latest ladder snapshot is needed and local replay
logs are not required.
