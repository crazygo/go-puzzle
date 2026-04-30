---
name: three-board-lighting-verifier
description: Project verifier for scoring 3D Go board lighting against a golden screenshot. Use when Codex needs to review a candidate 3D board screenshot, compare only the board lighting region with the golden, assign a 0.0-1.0 lighting score, decide whether scores below 0.8 must enter another controlled iteration, and recommend the next single lighting capability to adjust.
---

# Three Board Lighting Verifier

## Purpose

Verify 3D board lighting quality against the project golden. This skill does not edit code. It produces an acceptance score and a single next iteration target when the score is below threshold.

## Inputs

Require:
- Golden screenshot path.
- Candidate screenshot path.
- Candidate params sidecar `.txt` path.

Read the candidate sidecar before scoring. If `commit_id` is missing, mark metadata incomplete but still score the image unless the user asks for strict gating.

## Scope

Score only lighting on the visible 3D board region:
- Board top exposure and tone mapping.
- Highlight shape, softness, falloff, and clipping.
- Key/fill/ambient balance and shadow-side separation.
- Contact/cast shadows under stones.
- Stone response to light.
- Grid readability under lighting.

Ignore:
- App layout.
- Text, tab bar, cards, and page composition.
- Wood texture realism unless the candidate claims a lighting change caused texture loss.
- Camera/framing unless it prevents fair lighting assessment.
- Board base color/material unless it directly changes perceived lighting.

## Acceptance Rule

Compute a total score from 0.0 to 1.0 using [lighting-score-rubric.md](references/lighting-score-rubric.md).

- `score >= 0.80`: accepted for lighting.
- `score < 0.80`: fail lighting verifier and enter another controlled iteration.

When failing, recommend exactly one next lighting capability:
- `sheen_specular_contribution`
- `key_light_intensity_or_direction`
- `ambient_fill_balance`
- `contact_shadow_ao`
- `grid_lighting_readability`
- `stone_light_response`
- `tone_mapping_exposure`

Do not recommend camera, layout, texture maps, or broad material redesign as the next step for this verifier.

## Process

1. Open the golden image and candidate screenshot.
2. Read the candidate params sidecar.
3. Confirm screenshot hygiene:
   - Debug panel hidden.
   - RGB axes/debug guides hidden.
   - Candidate is board-comparison capture, not human tuning capture.
4. Compare board lighting only.
5. Score each weighted dimension.
6. Apply any caps from the rubric.
7. Output pass/fail and one next lighting iteration target.

## Output Format

Use this format:

```text
Lighting verifier: <pass|fail>
Score: <total>/1.00
Threshold: 0.80

Dimension scores:
- Exposure / tonemapping: <score> x 0.25 = <weighted>
- Highlight falloff / sheen: <score> x 0.25 = <weighted>
- Ambient / fill separation: <score> x 0.15 = <weighted>
- Contact / cast shadows: <score> x 0.15 = <weighted>
- Stone light response: <score> x 0.10 = <weighted>
- Grid readability under lighting: <score> x 0.10 = <weighted>

Caps / metadata:
- <none|cap reason>
- commit_id: <value|missing>

Board-lighting deltas:
1. ...
2. ...
3. ...

Next lighting iteration target: <one target or none>
Reason: ...
```

Keep language professional and specific. Avoid vague phrases such as "looks better", "more real", or "too fake" unless translated into a lighting cause.
