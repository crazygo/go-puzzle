# Window Air Glow Animation

## Background

### Context

The 3D Go board hero now uses a shared board instance across the main tab surfaces and includes a `BoardAtmosphereBackdrop`-style warm background behind the transparent WebGL canvas. The board top uses a window irradiance field for the upper-right light wash, while the older `particles` implementation is disabled by default because it is too small at the current camera distance and reads as generic random dust rather than window-light atmosphere.

### Problem

The current board is static enough that users may not immediately perceive the hero as a live 3D scene. The existing particle system is not a good direct fit: it is distributed around the board in 3D root space, rotates with the board, and only becomes visible when the camera is pushed in. Simply increasing particle size would make it noisy without tying it to the window-light story.

The animation also needs to respect the new atmosphere backdrop. If the board light breathes but the backdrop remains completely static, the scene can feel disconnected. If the backdrop moves too much, the whole page background will look like it is flickering or drifting.

### Motivation

A subtle window-air animation can communicate depth and create a calmer, more immersive scene without changing the board composition. The goal is not a visible special effect; it is a low-amplitude optical cue that makes the board feel present in a warm room.

## Goals

- Replace the old generic particle behavior with a purpose-built `windowAirGlow` atmosphere tied to the board's window-light direction.
- Add very slow, low-amplitude optical motion that suggests 3D depth without rotating the board or disturbing layout.
- Use one shared window-light animation controller so board light, air dust, and backdrop glow feel connected.
- Keep `BoardAtmosphereBackdrop` synchronized only in opacity/softness, with much weaker response than particles and no obvious geometric drift.
- Preserve existing debug workflow by adding explicit controls for enabling and tuning the animation.

## Implementation Plan

1. Rename the conceptual feature from generic `particles` to `windowAirGlow` in the 3D board API and debug panel, while keeping compatibility if a short migration path is useful.
2. Introduce a small window-light phase function driven by `_elapsed`, for example a slow sine/noise blend that outputs a stable `windowPulse`.
3. Apply the pulse with different response strengths:
   - Board top light/window intensity: very subtle, around `+/- 2%` to `+/- 3%`.
   - Window air dust opacity: stronger but still quiet, around `+/- 12%` to `+/- 18%`.
   - `BoardAtmosphereBackdrop` window glow opacity: barely visible, around `+/- 1%`.
4. Rebuild the old particle distribution into a low-count window-air field:
   - Use about 8-16 particles, not 120.
   - Place them only in the board-space far-right / screen upper-right window-light path.
   - Use larger but softer points or small stretched sprites so they remain visible at current camera framing.
   - Animate with slow drift through the light volume, not rotation around the board.
5. Keep the board itself stable:
   - Do not animate `boardRotationY`.
   - Do not orbit the camera broadly.
   - If camera micro-drift is added later, keep it as a separate optional capability and gate it behind a debug control.
6. Update the debug panel:
   - Add `windowAirGlow enabled`.
   - Add controls for dust count or density, opacity, point size, drift speed, and pulse strength.
   - Add a backdrop pulse strength control only if it is needed during tuning; default should be very low.
7. Validate the animation against the current golden direction:
   - The board must still read as the same composition in static screenshots.
   - The motion should be perceptible only over time, not as a single-frame effect.
   - Debug screenshots should still be capturable with animation disabled or with deterministic phase when needed.

## Acceptance Criteria

- The default home hero shows a subtle live window-air effect without making the board look like it is spinning, shaking, or sparkling.
- The visible dust/air effect is concentrated in the upper-right window-light region and does not cover the whole board.
- The `BoardAtmosphereBackdrop` remains visually stable; any pulse is too subtle to read as page background flicker.
- The board top, air dust, and backdrop glow respond to the same window-light phase with separate response strengths.
- The old generic particle effect is no longer the default production behavior.
- Debug controls allow the animation to be turned off for stable screenshot comparison.

## Validation Commands

- `dart format lib/widgets/go_three_board_background.dart lib/screens/capture_game_screen.dart lib/screens/main_screen.dart`
- `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings lib/widgets/go_three_board_background.dart lib/screens/capture_game_screen.dart lib/screens/main_screen.dart`
- `flutter build web --no-pub --release`
- `python3 -m http.server <port> --bind 127.0.0.1 --directory build/web`
- `bash .agents/skills/playwright-screenshot/scripts/browser_screenshot.sh "http://127.0.0.1:<port>/?shot=<timestamp>" ".cache/screenshots/<timestamp>-window-air-glow-release-web-wide.png" 900 874 2 45000`
