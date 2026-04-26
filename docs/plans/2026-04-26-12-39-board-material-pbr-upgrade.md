# Board Material PBR Upgrade Plan

## 1. Background

### Context
- The in-game interactive board (`GoBoardPainter`) is currently rendered as a rounded rectangle filled by a single burlywood base color plus a soft diagonal gradient, then overlaid with uniform grid lines. This is a 2D painter pipeline and does not yet separate top vs side materials or support physically based shading controls such as roughness/metalness/bump. 
- The hero/background board (`GoParticleHeroBackgroundPainter`) already simulates a pseudo-3D board volume (top + side faces), wood-like particle bands, and softened grid lines with highlight offsets, but it still relies on procedural painter strokes rather than an explicit “top texture + side texture + engraved groove map” material model.

### Problem
- The interactive board lacks wood-fiber directionality, engraved grid-line depth cues, and side-face continuity; visually it reads as “flat color + lines”.
- The hero background has some depth and variation, but top/side color logic and groove readability are not yet tightly parameterized to the new target palette and constraints (light beech/maple, side not too dark, explicit shallow grooves).
- There is currently no shared board material token/config to keep gameplay board and hero board in sync.

### Motivation
- Aligning both board renderers to a consistent light-wood PBR-inspired art direction will improve perceived quality, realism, and brand coherence.
- Encoding the palette/roughness/bump/groove as reusable design tokens makes future tuning faster and safer.

## 2. Goals
- Build a “light wood” material system (base, grain, shadows/highlights) that matches the target palette and avoids flat yellow/gray tone drift.
- Separate top and side material logic while keeping them in one coherent wood family.
- Convert grid lines from UI-like strokes into shallow engraved grooves with readable but not harsh contrast.
- Add subtle edge bevel/highlight behavior so the board no longer appears as a hard-edged box.
- Keep rendering performant on Flutter canvas while preserving current gameplay legibility (stones, last move, hints, labels).

## 3. Implementation Plan

### Phase A — Material tokens and shared config
1. Create a shared board material spec (e.g., `lib/widgets/board_material_tokens.dart`) that defines:
   - Top palette: `#E8C98E`, `#F3DDB3`, `#C99655`, `#A9783D`.
   - Side palette: `#C98E4F`, `#9A6530`, `#E0B06B`.
   - Grid groove color target `#7A5C36` with alpha band `0.45~0.65`.
   - PBR-inspired scalar knobs mapped into Flutter equivalents (roughness proxy, bump intensity proxy).
2. Add helpers to derive near/far and lit/shaded variants so both painters consume identical color logic instead of hardcoded literals.

### Phase B — Upgrade interactive board painter (`go_board_widget.dart`)
1. Refactor `_drawBackground` into layered passes:
   - Base top surface fill.
   - Directional long-grain bands aligned with board axis (not random isotropic noise).
   - Fine grain streaks and subtle local dark veins.
2. Replace current simple grid stroke with groove-style rendering:
   - Draw groove core lines using `#7A5C36` target with controlled alpha.
   - Add one-pixel highlight/shadow offsets to fake shallow indentation.
   - Keep line width slim to avoid UI-overlay appearance.
3. Introduce visible board side/front thickness in the 2D board widget (where layout allows), including:
   - Side band with horizontal grain.
   - Slightly darker value than top but avoiding near-black.
4. Add bevel simulation on board perimeter:
   - Small inset path/ring with highlight on light-facing edge and gentle darkening on opposite edge.
   - Ensure corners look rounded and catch light.
5. Re-validate overlays (star points, coordinate labels, stones, hints) against updated contrast.

### Phase C — Align hero board painter (`go_particle_hero_background.dart`)
1. Remap existing top/side color generation to the same tokenized palette and brightness rules as Phase A.
2. Constrain wood particles/bands to emphasize long, fine grain flow along board direction; reduce blotchy/random appearance.
3. Tune grid rendering to groove behavior (core + micro highlight) with opacity/width inside target bands.
4. Enhance side face grain continuity and bevel-edge highlight so top-to-side transition matches design intent.

### Phase D — Validation and regression checks
1. Visual snapshot validation for both renderers in representative screens:
   - gameplay board (`GoBoardWidget`)
   - hero banner background (`GoParticleHeroBackground`)
2. Ensure no loss of gameplay readability (grid intersections, stones, last move mark).
3. Run static checks and tests from repo root.

## 4. Acceptance Criteria
- Interactive board is no longer a flat single-tone panel; visible fine, elongated light-wood grain appears across top surface.
- Top and side are clearly related materials: side is darker than top but remains wood-toned (not near-black).
- Grid appears engraved (subtle groove) rather than heavy overlay lines; lines remain readable.
- Board edge shows soft bevel/highlight behavior, reducing hard-box appearance.
- Hero and gameplay boards share consistent wood palette logic from central tokens.
- Validation commands pass:
  - `flutter pub get`
  - `flutter analyze --no-fatal-infos --no-fatal-warnings`
  - `flutter test`
