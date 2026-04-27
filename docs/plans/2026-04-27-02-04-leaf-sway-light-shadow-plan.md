# Leaf-Sway Light & Shadow Upgrade Plan

## Background

### Context
- The home hero board uses `GoThreeBoardBackground` with a Three.js scene, warm multi-light setup, procedural board detail meshes, and animated camera drift.
- Stones already cast/receive shadows and the key directional light already enables `castShadow`.
- Current motion language emphasizes camera and particle movement, while board lighting remains mostly static.

### Problem
- The visual target calls for subtle animated light/shadow variation (like leaves moving in breeze), but current implementation lacks dynamic occlusion and light pulsing tied to a soft natural rhythm.
- Without animated caustic-like variation, the board can feel comparatively static versus the desired relaxed, premium look.

### Motivation
- Adding gentle “leaf sway” lighting motion improves realism and perceived material quality without requiring a full renderer rewrite.
- A lightweight procedural approach can deliver this look with predictable performance and easy tuning.

## Goals
- Add subtle animated shadow patches over the board that resemble leaf-filtered sunlight.
- Keep motion pace leisurely (not too slow), with small amplitude and no distracting flicker.
- Preserve existing scene composition while making the lighting feel alive.

## Implementation Plan
- **Phase 1 — Shadow-caustic layer**
  - Add a dedicated overlay group of translucent, soft-edged planar meshes positioned just above board top.
  - Seed per-sprite base position/scale/speed/phase for non-repetitive movement.
- **Phase 2 — Breeze animation loop**
  - Animate each shadow sprite with sinusoidal sway in X/Z, slight scale breathing, and tiny rotational drift.
  - Run this in the existing animation callback only when `animate` is enabled.
- **Phase 3 — Key-light micro modulation**
  - Store key directional light baseline position.
  - Add very small position/intensity oscillation to reinforce natural sun-through-leaves feel.
- **Phase 4 — Validation and tuning**
  - Run repository checks (`flutter pub get`, `flutter analyze --no-fatal-infos --no-fatal-warnings`, `flutter test`).
  - Tune opacity/speeds to avoid harsh flicker and keep the effect calm.

## Acceptance Criteria
- The home 3D board shows visible but soft moving light/shadow variation, resembling leaf sway.
- Motion is relaxed and continuous, with no abrupt jumps.
- Existing board/stones still render correctly and animation remains stable.
- Validation commands pass:
  - `flutter pub get`
  - `flutter analyze --no-fatal-infos --no-fatal-warnings`
  - `flutter test`
