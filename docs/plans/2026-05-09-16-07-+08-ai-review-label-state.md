# AI Review Label State

## Background

### Context

The Cloudflare GitHub webhook worker already listens for Copilot `pull_request_review.submitted` events. It waits briefly for GitHub to persist inline review comments, counts the submitted review's real comments, and posts an `@copilot` cue comment when there are comments to address.

### Problem

From the GitHub PR list, there is currently no visible state showing whether the worker has received a review and is waiting for inline comments, or whether it has already requested Copilot to address those comments. When the worker is delayed, skipped, or blocked by token permissions, the state is only visible by inspecting webhook delivery logs.

### Motivation

Two mutually exclusive PR labels will make the automation state visible without opening the PR or Cloudflare logs:

- `ai-review: waiting-comments`
- `ai-review: fix-requested`

This keeps the first version small while creating a clear path for later states such as no-comments, fix-completed, or stale-resolved.

## Goals

- Add `ai-review: waiting-comments` when a Copilot PR review submission is accepted by the worker and before the inline review comment wait begins.
- Replace `ai-review: waiting-comments` with `ai-review: fix-requested` only after the worker confirms review comments exist and successfully posts the `@copilot` fix request comment.
- Keep the two labels mutually exclusive so the PR list shows one clear automation state.
- Document the GitHub token permissions required for PR comments and PR labels.
- Avoid modifying unrelated repository labels.

## Implementation Plan

1. Define label constants in `.github/cloudflare/copilot-review-thread-resolver-worker.mjs`:
   - `AI_REVIEW_WAITING_COMMENTS_LABEL = 'ai-review: waiting-comments'`
   - `AI_REVIEW_FIX_REQUESTED_LABEL = 'ai-review: fix-requested'`

2. Add GitHub REST helpers for PR label operations:
   - Add labels to a PR using the issues labels API.
   - Remove only known `ai-review:` state labels before applying the next state.
   - Treat `404` on label removal as non-fatal so a missing previous state does not fail the webhook.

3. Update the `pull_request_review.submitted` flow:
   - After the repo and Copilot author checks pass, set state to `ai-review: waiting-comments`.
   - Wait `REVIEW_COMMENT_SETTLE_MS`.
   - Fetch review comments for the submitted review.
   - If review comment count is zero, remove `ai-review: waiting-comments` and leave no state label for now.
   - If review comment count is greater than zero, post the `@copilot` cue comment.
   - Only after the cue comment succeeds, replace `ai-review: waiting-comments` with `ai-review: fix-requested`.

4. Preserve idempotency:
   - If a cue comment for the same review URL already exists, replace `ai-review: waiting-comments` with `ai-review: fix-requested` instead of posting a duplicate comment.
   - Do not use GitHub's replace-all-labels endpoint.

5. Improve observability:
   - Include `labelState` and label operation results in successful JSON responses.
   - On label failures, return an explicit error that includes which operation failed and the GitHub status/body.

6. Update `.github/cloudflare/README.md`:
   - Document both labels and their lifecycle.
   - Document that `GITHUB_TOKEN` needs repository access to `crazygo/go-puzzle` and write permission for Issues and/or Pull Requests. Recommended permissions are `Issues: write`, `Pull requests: write`, and `Contents: read`.

## Acceptance Criteria

- When a valid Copilot `pull_request_review.submitted` webhook is received, the target PR gets `ai-review: waiting-comments` before the 5-second comment wait.
- When the submitted review has one or more inline comments and the cue comment is posted, the PR has `ai-review: fix-requested` and no longer has `ai-review: waiting-comments`.
- When the submitted review has zero inline comments, `ai-review: waiting-comments` is removed and `ai-review: fix-requested` is not added.
- Re-delivering the same webhook does not create duplicate cue comments and still leaves the PR in `ai-review: fix-requested`.
- Existing non-`ai-review:` labels on the PR are preserved.
- README documents the labels and token permissions needed to create PR comments and update PR labels.

## Validation Commands

- `node --check .github/cloudflare/copilot-review-thread-resolver-worker.mjs`
- `git diff --check`
