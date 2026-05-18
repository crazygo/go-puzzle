# Copied Move Text Format

## Background

### Context

Capture-game records can be copied from the operation menu as readable text or SGF. The game can start from an empty board, a preset position such as 十字 or 扭十字, a custom setup board, or a forked review position.

### Problem

The previous copied text format could make a non-empty starting position look like a fresh empty-board game. A copied line such as `01 5五` does not say whether the board was empty, whether the stone was black or white, or whether earlier setup/fork context existed.

### Motivation

Copied text should be unambiguous for humans and parsers. Preset/custom starting stones and forked history should be represented consistently as inherited numbered moves, followed by a checkpoint line before newly played moves.

## Goals

- Keep only the non-duplicated copy menu items: `複製棋譜為文字` and `複製棋譜為 SGF`.
- Format copied text move lines as `<padded move number> <B|W>[<coordinate>]`.
- Treat preset and custom initial positions as inherited/setup moves that count toward numbering.
- Use `---` as a checkpoint after inherited/setup/forked moves.
- Continue numbering new moves after the inherited/setup move count.
- Match copied coordinates to the active board coordinate setting.
- End copied text with exactly one trailing newline.

## Implementation Plan

1. Remove duplicated operation-menu copy items and keep the clearer `複製棋譜為文字` and `複製棋譜為 SGF` actions.
2. Update text-copy enablement so games with preset/custom initial stones can copy text immediately, while empty-board games with no moves remain disabled.
3. Derive inherited/setup moves from the current context:
   - Prefer explicit fork `inheritedMoves` when present.
   - Otherwise convert known preset openings and custom initial boards into ordered inherited/setup moves.
   - Leave empty/setup boards without stones as no inherited/setup moves.
4. Format each copied text move with padded numbering, color tags, and the active coordinate-system output.
5. Insert `---` after inherited/setup/forked moves and before newly played moves.
6. Append exactly one trailing newline to copied text output.
7. Add widget tests for normal copy, preset opening copy, custom initial board copy, empty-board disabled copy, immediate fork copy, and fork copy after additional moves.
8. Document the local web-worker testing workflow in `AGENTS.md` so future browser testing uses `build/web` static hosting instead of Flutter's debug web server.

## Acceptance Criteria

- The operation menu has no duplicated text/SGF copy actions.
- A preset-start game can copy text immediately, and the copied text lists setup moves followed by `---`.
- A new move after a preset/custom starting position continues numbering after setup moves.
- A forked game copied immediately includes inherited moves followed by `---`.
- A forked game copied after new moves continues numbering after inherited moves.
- Move lines include `B[...]` or `W[...]`.
- Copied coordinates follow the selected board coordinate setting.
- Empty-board games with no moves do not write an empty copied record.
- Copied text ends with exactly one trailing newline.
- SGF copy remains available and preserves setup/fork context.

## Validation Commands

- `dart format lib/screens/capture_game_screen.dart test/capture_game_provider_test.dart`
- `flutter test test/capture_game_provider_test.dart`
- `bash scripts/compile-web-worker.sh`
- `flutter build web`
