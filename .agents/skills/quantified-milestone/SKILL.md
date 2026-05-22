---
name: quantified-milestone
description: Use when drafting, reviewing, or revising milestone goals for engineering, ML, evaluation, product, documentation, or research work. Guides agents to replace vague success language with measurable completion criteria while keeping the milestone structure flexible.
---

# Quantified Milestone

Use this skill when the user asks for a milestone, next goal, handoff goal,
work package, experiment goal, or asks whether a goal is clear enough for an AI
or human to execute.

This skill is not a rigid template. The core rule is:

```text
Turn important adjectives into measurable completion criteria.
```

Agents often write milestones that sound useful but cannot be judged, such as
"improve quality", "generate a larger dataset", "make it stable", "run enough
tests", or "build a usable first version". A quantified milestone defines what
"done" means with numbers, thresholds, comparison targets, explicit coverage, or
pass/fail checks.

## When To Apply

Apply this skill whenever a milestone includes vague words such as:

- better, stronger, improved
- enough, sufficient, usable, complete
- larger, smaller, faster, slower
- stable, reliable, robust
- high quality, good, acceptable
- validate, test, evaluate, compare
- production ready, reviewable, releasable

Do not force every milestone into the same headings. Preserve the user's
natural structure when possible, but add measurable criteria where the goal
would otherwise be ambiguous.

## Quantification Checklist

For each important goal, ask whether at least one of these is specified:

- **Count**: records, cases, screens, files, games, samples, tests, commits.
- **Coverage**: categories, sources, platforms, board sizes, modes, user flows.
- **Ratio**: win rate, pass rate, completion rate, error rate, coverage rate.
- **Threshold**: minimum acceptable value or maximum allowed value.
- **Comparison**: baseline artifact, previous version, current production path,
  known-good behavior, or fixed opponent set.
- **Budget**: time, memory, file size, latency, CPU, cost, token usage.
- **Failure handling**: what to report and commit if the target is not reached.
- **Artifacts**: exact output files, reports, manifests, logs, screenshots, or
  model files that prove completion.

## Rewrite Examples

Prefer concrete criteria over vague direction:

```text
Generate a larger dataset.
```

Becomes:

```text
Generate at least 20,000 labeled records, with at least 1,000 records from each
source category, and write a manifest with source counts, seed, generator
version, rule version, and labeler version.
```

```text
Make v2 better than v1.
```

Becomes:

```text
Evaluate v1 and v2 under identical settings for at least 30 games per opponent.
v2 should improve total win rate by at least 10 percentage points with 0 illegal
moves. If it does not, commit the negative result and explain likely causes.
```

```text
Make the UI stable.
```

Becomes:

```text
The flow completes 20 consecutive runs on desktop and mobile viewports with no
severe console errors, no overlapping controls in screenshots, and no failed
interaction checkpoint.
```

```text
Keep the model small.
```

Becomes:

```text
The released ONNX file must be less than 2 MB and must not exceed the current
KataGo reference model size.
```

## Research And ML Milestones

For experiments, do not require success when the outcome is genuinely unknown.
Instead, quantify the experiment and require a useful conclusion:

```text
Run at least N trials under fixed settings. If the target is not met, commit the
report and state the leading hypothesis for why the experiment failed.
```

Good research milestones include:

- a fixed baseline
- fixed settings shared by baseline and candidate
- minimum sample size
- success threshold
- negative-result reporting requirement
- required artifact paths

## Engineering Milestones

For implementation work, quantify:

- supported platforms or modes
- required user flows
- exact tests or evidence runs
- failure states that must be handled
- performance or size limits when relevant
- migration or backwards-compatibility cases

Avoid claiming "done" because code exists. Completion requires evidence that
the behavior works under the stated conditions.

## Good Final Check

Before giving the milestone back to the user, scan for vague words. For every
important vague word, either:

1. replace it with a measurable criterion, or
2. explicitly mark it as a qualitative note, not an acceptance criterion.

The milestone is ready when another agent can answer these questions without
asking follow-up questions:

- How much work or data is enough?
- What must stay fixed?
- What comparison matters?
- What threshold counts as success?
- What artifact proves the result?
- What should happen if the threshold is not reached?
