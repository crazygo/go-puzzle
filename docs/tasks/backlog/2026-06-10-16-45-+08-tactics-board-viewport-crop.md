# Tactics Board Viewport Crop (19×19 Local Zoom)

## Background

### Context

- Competitor puzzle apps (e.g. 101weiqi) often show **19×19 problems** where stones occupy only a corner or side region.
- The UI **crops and magnifies** that region so stones remain readable, while **coordinate labels stay absolute** (e.g. columns `Q R S T`, not renumbered from `A`).
- Our current tactics flow renders the **full board** via `GoBoardWidget` and problem data supports **9×9 and 13×13** only. There is **no viewport/crop layer** yet.

### Problem

- Full-board rendering of sparse 19×19 problems makes local shapes too small on mobile.
- Re-labeling coordinates to a local 1–9 grid would break consistency with move logs, hints, and AI suggestions.

### Motivation

- Enables future 19×19 tactic problems without redesigning the solving screen.
- Matches familiar competitor UX and keeps one global coordinate system across board, kifu, and analysis.
- The feature is **largely independent** of the current daily-challenge / solving-screen layout work and can ship later.

## Goals

- Render a **rectangular viewport** into a full logical board, scaled up to fill available space.
- Preserve **absolute coordinates** on axis labels and in all text (kifu, hints, AI lines).
- Map tap/hit-testing from screen space back to global `(row, col)`.
- Compute viewport automatically from stone bounding box (+ margin), with sensible min/max window sizes.
- Optionally expose **show full board** from the operations menu (future).

## Implementation Plan

1. **Data model**
   - Keep `boardSize` as the full logical size (e.g. 19).
   - Store stones and moves in **global coordinates**.
   - Optionally allow an explicit `viewRect` in problem JSON later; default to **runtime auto-crop**.

2. **Viewport computation**
   - Bounding box over occupied intersections (and optionally adjacent empty points).
   - Expand by 1–2 lines; clamp to board edges.
   - Enforce minimum window (e.g. 7×7) and maximum (e.g. 13×13 or full board).

3. **Rendering**
   - Extend `GoBoardWidget` (or a thin wrapper) with `viewportRowMin/Max`, `viewportColMin/Max`.
   - Draw only visible grid lines and stones; scale `cellSize` from viewport dimensions, not full `boardSize`.
   - Axis labels use existing `board_coordinates.dart` with **global** `row`/`col` indices.

4. **Interaction**
   - Inverse map touch `(x, y)` → viewport cell → global `(row, col)`.
   - All legality / analysis continues on the full logical board.

5. **Product hooks (later)**
   - Operations menu: toggle **full board vs cropped view**.
   - Extend `TacticsProblemRepository` validation to allow 19×19 when this ships.

## Acceptance Criteria

- A 19×19 problem with stones in the bottom-right corner displays a **magnified local window**; stones are visually larger than full-board mode.
- Visible edge labels show **absolute coordinates** (e.g. `Q`, `R`, `S`, `T`), not renumbered local letters.
- Tapping an intersection places/analyses the correct **global** point; kifu and hint text match the board label.
- Auto viewport adds margin around the stone cluster and respects configured min/max window bounds.
- (Optional) User can switch to full-board view from operations without breaking move history.

## Validation Commands

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test` (add widget tests for viewport label mapping and tap inverse mapping when implemented)

## Notes

- **Deferred**: not part of the current solving-screen iteration; record as backlog idea only.
- Related discussion: competitor pattern = **viewport crop + absolute coordinates**, not a separate smaller board size.
