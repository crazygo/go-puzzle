# Specs Map Instructions

This directory records product behavior and UX contracts. These specs are the
source for tests and for short implementation comments at fragile business
boundaries.

## Scope

- Use one YAML file per product domain or user flow.
- Specs describe what the product should do, in terms a user or tester can
  understand.
- Specs must match the current code behavior unless the task explicitly asks to
  redefine the product behavior.
- Keep each `expected_behavior` item short, concrete, and testable.
- Link longer rationale to `docs/plans/`, `docs/kb/`, or other docs through
  `references`.

## Do Not Include

- Do not include code paths, test paths, owners, timestamps, or version fields.
  Git already tracks history, and code paths change during refactors.
- Do not use this directory for implementation plans, design essays, evaluation
  results, or debugging notes. Link those documents from `references` instead.
- Do not add speculative behavior. If code and intended behavior differ, call
  that out in the task discussion before changing the spec.

## File Shape

Use this shape:

```yaml
purpose: >
  Define expected product behavior and UX contracts for <domain or flow>.
  Specs are the source for tests and implementation comments. Specs may link to
  longer rationale docs, but do not track code paths.

specs:
  - spec_id: stable_snake_case_id
    expected_behavior:
      - A short, concrete behavior statement.
      - Another testable behavior statement.
    references:
      - docs/plans/example.md
```

## Referencing Specs

- Tests may reference a spec with a short comment:
  `// Spec: docs/specs_map/main_game_flow.yaml#move_log_visibility`
- Production code may reference a spec only at business boundaries that are easy
  to accidentally regress:
  `// Spec: docs/specs_map/main_game_flow.yaml#katago_onnx_final_move`
- Do not reference long-form plan or KB docs directly from code when a spec
  exists. Code and tests should point to the spec; the spec points to background
  docs.

## Maintenance

- When changing user-visible behavior, update or add the relevant spec first,
  then align implementation and tests.
- When refactoring code without changing behavior, do not edit specs.
- When a test expectation conflicts with a spec, treat the spec as the starting
  point for discussion: either update the spec because the product behavior
  changed, or fix the test.
- Before finalizing behavior changes, check that each changed requirement maps
  to a concrete test assertion.
