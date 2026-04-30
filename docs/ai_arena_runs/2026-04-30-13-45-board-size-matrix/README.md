# AI Arena Board-size Matrix Run

Date (UTC): 2026-04-30

## Commands
- 9x9 full adjacent pass:
  - `dart run tool/capture_ai_arena_runner.dart --rounds 10 --promotion-threshold 7 --board-size 9 --output build/ai_arena/matches.b9.jsonl --snapshot build/ai_arena/ladder.b9.json`
- 13x13 full adjacent pass:
  - `dart run tool/capture_ai_arena_runner.dart --rounds 10 --promotion-threshold 7 --board-size 13 --output build/ai_arena/matches.b13.jsonl --snapshot build/ai_arena/ladder.b13.json`
- 19x19 smoke adjacent pass (3 candidates) with capped max moves:
  - `dart run tool/capture_ai_arena_runner.dart --smoke --rounds 10 --promotion-threshold 7 --board-size 19 --max-moves 128 --output build/ai_arena/matches.b19.smoke.jsonl --snapshot build/ai_arena/ladder.b19.smoke.json`

## Results
- 9x9: 15 candidates, 14 matches, replay passed.
- 13x13: 15 candidates, 14 matches, replay passed.
- 19x19 smoke: 3 candidates, 2 matches, replay passed.
