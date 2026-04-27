# 3D Board Golden Comparison Rubric

Use professional rendering terms with concrete direction. Avoid vague user-facing phrasing such as "looks nice", "more real", "too flat", or "plastic" unless immediately translated into a rendering cause.

## Scope

Compare only the visible 3D board region:
- Board plane and edge lighting
- Stones
- Grid lines
- Shadows and contact shadows
- Camera/framing only when the current iteration is camera-related

Ignore app layout and surrounding UI unless it occludes the board capture.

## Factors

### Lighting / Exposure

Check:
- Overall exposure of board top surface
- Highlight clipping or washed-out bright regions
- Tonemapping/exposure balance
- Key light direction and falloff
- Fill/ambient strength
- Sheen/specular contribution
- Shadow-side separation

Useful wording:
- "Top surface exposure is higher/lower than golden."
- "Highlight transition is shorter/longer than golden."
- "Key/sheen contribution creates a localized band instead of broad falloff."
- "Ambient/fill lifts shadow values too much; shadow-side separation is weaker."

### Contact and Cast Shadows

Check:
- Stone contact shadow strength
- Ambient occlusion under stones
- Cast shadow direction and softness
- Whether stones visually sit on the board

Useful wording:
- "Contact shadow under stones is weaker than golden."
- "AO radius is too small/large."
- "Cast shadow edge is harder/softer than golden."

### Stone Shading

Check:
- Black stone specular size/intensity
- White stone value separation from board
- Roughness impression
- Rim/edge readability

Useful wording:
- "Black-stone specular lobe is smaller/brighter than golden, indicating lower apparent roughness."
- "White-stone midtone separation from board is weaker."

### Grid Readability

Check:
- Grid line contrast in highlight and shadow regions
- Whether lighting washes out grid lines
- Whether grid treatment has a contrast floor

Useful wording:
- "Grid contrast falls below golden in high-exposure regions."
- "Grid readability is inconsistent across lit and shadowed areas."

### Camera / Framing

Only use when the iteration is camera-related.

Check:
- FOV/wide-angle distortion
- Camera distance
- Board edge dominance
- Horizon/tilt relation

Useful wording:
- "Perspective is wider/closer than golden."
- "Near board edge occupies more visual weight than golden."

### Material / Texture

Only use when the iteration is material-related. If texture maps are out of scope, do not critique missing wood grain.

Check:
- Base color/value
- Roughness/specular response
- Texture map presence only if that is the current task

## Report Shape

Use this shape:

```text
Golden delta, board region only:
1. Exposure: ...
2. Key/sheen: ...
3. Ambient/fill: ...
4. Shadows/contact: ...
5. Stones/grid: ...

Next single capability: ...
Reason: ...
```

If the current iteration is lighting-only, do not recommend changing camera, board color, or texture as the immediate next edit unless lighting is already close.
