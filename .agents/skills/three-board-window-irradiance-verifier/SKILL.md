---
name: three-board-window-irradiance-verifier
description: Project verifier for the 3D Go board top-surface window-light task. Use when Codex needs to judge whether a candidate board screenshot matches the golden's screen-space upper-right milky warm window irradiance, left/right brightness relationship, and grid response; outputs itemized scores and a pass/fail decision.
---

# Three Board Window Irradiance Verifier

## Purpose

Verify the current board-top window-light goal only. This skill does not edit code. It scores whether the candidate board top has the expected board-space far-right / screen upper-right soft window-light increment and matching grid response.

Use this verifier before moving on to stones or UI composition.

## Inputs

Require:
- Golden screenshot path.
- Candidate screenshot path.
- Candidate params sidecar `.txt` path.

Read the sidecar first. Report `commit_id` and whether the working tree was dirty.

## Scope

Evaluate only the visible 3D board surface:
- Board top light field.
- Global board luminance and clean wood tone.
- Left/right brightness relationship on the top plane.
- Grid-line response to the same light field.

Ignore:
- Page layout, cards, headers, tab bar, and tuning button.
- Board side material unless it blocks judging the top plane.
- Stone lighting except to note that stone review is deferred.
- Camera/framing unless the board top is not visible enough to judge.

## Acceptance

Before scoring, record visible facts and observation confidence. The score must
follow the visible facts, not the implementation intent.

Score each dimension using score bands instead of arbitrary precise decimals:
- `0.90`: clearly matches the golden for this dimension.
- `0.75`: mostly matches, with only minor visible gaps.
- `0.60`: partial progress, but the golden relationship is not established.
- `0.45`: weak or ambiguous evidence.
- `0.30`: wrong direction or mostly absent.

Use intermediate values only when there is a concrete visible reason. Do not use
over-precise scores to imply measurement-level certainty. Overall score is the
weighted sum.

Pass only when:
- overall score is `>= 0.80`, and
- each required dimension score is `>= 0.70`.

If the candidate contains a visible ellipse, block-shaped glow, localized white patch, or obvious overlay artifact on the board top, cap the total score at `0.60`.

If debug guides or the human debug panel cover the board region, cap the total score at `0.60`.

## Dimensions

1. **Board Top Light Field** x 0.35
   - High score: board-space far-right / screen upper-right board top has a perceptible milky warm window-light wash with invisible boundaries and broad falloff into the middle.
   - Low score: right side only has a weak warm lift, not a perceptible milky window-light wash; light is uniform; bright area is a visible ellipse/block/patch; gradient is too narrow or too hard.

2. **Global Board Luminance / Clean Wood Tone** x 0.20
   - High score: the full board top reads bright, clean, and warm like the golden. The lit side is cream-white / milky warm, not golden yellow, and the shadow side remains warm and detailed rather than gray, dull, or dirty.
   - Low score: the board top is globally too dim, gray, dirty, or overly yellow/golden; increasing light appears to amplify yellow diffuse wood color instead of creating a cream-white window-light effect; the lit-side falloff reads as a white-to-gold color gradient rather than white light intensity fading over warm wood.

3. **Left/Right Brightness Relationship** x 0.20
   - High score: one side reads as washed by soft window light while the opposite lower/left side is clearly darker but still retains wood grain and grid detail.
   - Low score: right-side wash does not spread far enough toward the middle; transition is too narrow; shadow-side wood becomes dull, dirty, or heavy instead of warm and clean; one point is overexposed instead of a side-wide wash.

4. **Grid Response** x 0.25
   - High score: grid lines follow the same light field; lower-left / shadow-side grid has higher contrast and remains readable, while the bright upper-right grid is softly dissolved but still legible.
   - Low score: grid depth is uniform across the board; bright-region grid disappears completely or remains too hard for the light level; dark-region grid becomes too faint, too heavy, black, or coarse.

## Process

1. Open golden and candidate screenshots.
2. Read candidate sidecar.
3. First judge only the board top, mentally ignoring stones and UI.
4. Record visible facts before assigning scores:
   - Brightest board-top region appears at: `screen upper-right`, `upper-center`,
     `upper-left`, `right edge`, `center`, or `unclear`.
   - Wash spreads toward middle: `yes`, `partial`, or `no`.
   - Lower-left relative darkness: `clear`, `weak`, `too dark/dirty`, or
     `unclear`.
   - Overall board luminance: `bright/clean`, `acceptable`, `dim`, `dirty`,
     or `unclear`.
   - Lit-side color cast: `cream-white`, `warm-neutral`, `golden-yellow`,
     `gray`, or `unclear`.
   - Visible patch/ellipse: `yes`, `no`, or `unclear`.
5. Record observation confidence before assigning scores:
   - Light region location: `high`, `medium`, or `low`.
   - Global luminance / color cast: `high`, `medium`, or `low`.
   - Left/right separation: `high`, `medium`, or `low`.
   - Grid response: `high`, `medium`, or `low`.
6. Add grid-line judgment after the top light field is assessed.
7. Do not score stones or UI in this verifier; mark them as deferred.
8. Output visible facts, confidence, itemized scores, total score, pass/fail,
   and one next iteration target.

## Output Format

```text
Window irradiance verifier: <pass|fail>
Score: <total>/1.00
Threshold: 0.80 and each dimension >= 0.70

Observed visual facts:
- Brightest board-top region appears at: <screen upper-right|upper-center|upper-left|right edge|center|unclear>
- Wash spreads toward middle: <yes|partial|no>
- Lower-left relative darkness: <clear|weak|too dark/dirty|unclear>
- Overall board luminance: <bright/clean|acceptable|dim|dirty|unclear>
- Lit-side color cast: <cream-white|warm-neutral|golden-yellow|gray|unclear>
- Visible patch/ellipse: <yes|no|unclear>

Observation confidence:
- Light region location: <high|medium|low>
- Global luminance / color cast: <high|medium|low>
- Left/right separation: <high|medium|low>
- Grid response: <high|medium|low>

Dimension scores:
- Board top light field: <score> x 0.35 = <weighted>
- Global board luminance / clean wood tone: <score> x 0.20 = <weighted>
- Left/right brightness relationship: <score> x 0.20 = <weighted>
- Grid response: <score> x 0.25 = <weighted>

Caps / metadata:
- cap: <none|reason>
- commit_id: <value|missing>
- working_tree_dirty: <true|false|unknown>

Acceptance checks:
1. Board top light field: <pass|fail> - <specific reason>
2. Global board luminance / clean wood tone: <pass|fail> - <specific reason>
3. Left/right brightness relationship: <pass|fail> - <specific reason>
4. Grid response: <pass|fail> - <specific reason>
5. Stones/UI: deferred

Board-top deltas vs golden:
1. ...
2. ...
3. ...

Next iteration target: <none|board_top_window_irradiance|grid_window_response>
Reason: ...
```

Keep the language concrete. Use terms such as `board-space far-right`, `screen upper-right`, `lower-left`, and `middle falloff` because the board may be rotated and the final visual direction matters.

## Next Target Guidance

Choose the next iteration target from the observed facts and lowest-scoring
dimension. Do not assume a fixed failure mode.

- If the brightest region is not aligned with the golden's screen upper-right
  board-top region, choose `board_top_window_irradiance` and state that the
  window-light coordinate mapping or placement must be corrected.
- If the brightest region is aligned but does not spread broadly into the
  middle, choose `board_top_window_irradiance` and state that the wash coverage
  or falloff length must be adjusted.
- If the board is globally too dim, dirty, or yellow/golden compared with the
  golden, choose `board_top_window_irradiance` and state whether the issue is
  insufficient clean base luminance, yellow diffuse amplification, or lit-side
  color cast.
- If the opposite side lacks separation while still needing detail preservation,
  choose `board_top_window_irradiance` and state whether the issue is insufficient
  lit-side wash, insufficient shadow-side separation, or shadow-side dirtiness.
- If the top light field is acceptable but grid lines do not follow it, choose
  `grid_window_response`.
- If all required dimensions pass, choose `none`.

Recommendations must be based on the candidate screenshot's visible facts, not
on previous iteration history or expected implementation intent.
