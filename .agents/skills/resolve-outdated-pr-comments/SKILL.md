---
name: resolve-outdated-pr-comments
description: Clean up stale GitHub pull request review comments by finding unresolved review threads, separating outdated threads from still-current comments, and resolving only safe outdated threads through GitHub GraphQL. Use when the user asks to resolve outdated PR comments, clean stale review comments, inspect unresolved review threads, or automate clicking GitHub's Resolve conversation button for comments that became obsolete after code changes.
---

# Resolve Outdated PR Comments

## Overview

Use this skill to clean GitHub PR review threads that are obsolete because the diff changed. The workflow is intentionally conservative: list first, resolve only threads that GitHub marks `isOutdated=true`, and leave current unresolved comments for normal code review.

## Workflow

1. Identify the repository and PR number from the user request or PR URL.
2. Query review threads with `scripts/resolve_outdated_threads.py --repo OWNER/REPO --pr NUMBER`.
3. Read the dry-run output:
   - `outdated unresolved` threads are candidates for automatic resolve.
   - `current unresolved` threads are still attached to the live diff and must not be resolved without explicit user approval.
   - `already resolved` threads need no action.
4. If the user asked to clean outdated comments, run the script again with `--resolve`.
5. Report how many threads were resolved and call out any current unresolved comments that remain.

## Commands

Dry run:

```bash
python3 .agents/skills/resolve-outdated-pr-comments/scripts/resolve_outdated_threads.py --repo crazygo/go-puzzle --pr 63
```

Resolve outdated unresolved threads:

```bash
python3 .agents/skills/resolve-outdated-pr-comments/scripts/resolve_outdated_threads.py --repo crazygo/go-puzzle --pr 63 --resolve
```

To inspect more threads on a large PR:

```bash
python3 .agents/skills/resolve-outdated-pr-comments/scripts/resolve_outdated_threads.py --repo OWNER/REPO --pr NUMBER --limit 100
```

## Safety Rules

- Do not resolve threads where `isOutdated=false` unless the user explicitly asks after seeing the dry-run list.
- Do not resolve ordinary PR issue comments; GitHub's resolve button applies to pull request review threads.
- Treat Copilot/Vercel bot comments the same as human comments: use thread state, not author identity, as the primary filter.
- If GitHub GraphQL fails or the token lacks permission, report that no cleanup was performed.
- If the script reports current unresolved comments, summarize them with file/path and URL so the user can decide whether they still need code changes.

## Resource

- `scripts/resolve_outdated_threads.py`: queries PR review threads with `gh api graphql`, prints a dry-run summary, and resolves outdated unresolved threads when passed `--resolve`.
