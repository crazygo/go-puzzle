# Cloudflare PR Review Automation

Cloudflare Worker that listens to GitHub PR review webhooks for `crazygo/go-puzzle`.

## Behavior

- Accepts GitHub webhook POST.
- Verifies signature via `GITHUB_WEBHOOK_SECRET`.
- On `issue_comment.created`:
  - Only handles comments created on pull requests.
  - When comment author matches Copilot reviewer identity, resolves review threads where `isOutdated=true` and `isResolved=false`.
  - When comment author matches Copilot SWE Agent identity, checks whether a Copilot SWE Agent commit landed after `ai-review: fix-requested`; if so, marks the PR as fixed.
  - Does **not** post summary comment to PR (per current requirement).
- On `pull_request.synchronize`:
  - Checks whether a Copilot SWE Agent commit landed after `ai-review: fix-requested`.
  - If yes, applies `ai-review: fix-completed`.
- On `pull_request.review_requested`:
  - Only acts when the requested reviewer matches Copilot bot identity.
  - Applies `ai-review: review-requested` so the PR list shows that Copilot review has been requested and is pending submission.
- On `pull_request_review.submitted`:
  - Only acts when review author matches Copilot bot identity.
  - Applies `ai-review: waiting-comments` before waiting for inline comments.
  - Waits `REVIEW_COMMENT_SETTLE_MS` so GitHub can finish creating inline review comments.
  - Fetches the submitted review's real inline comments.
  - If no review comments exist, applies `ai-review: no-comments`.
  - If at least one review comment exists, posts a PR comment cueing `@copilot` to address the review and applies `ai-review: fix-requested`.
  - Skips posting if a cue comment for the same review URL already exists.
- On `pull_request_review.edited`:
  - Uses the same comment-count and label logic as `submitted`, without the waiting label or settle delay.
  - This is a fallback for Copilot reviews that later edit their summary body after submitting, so a clean review with no inline comments still receives `ai-review: no-comments` if the `submitted` delivery was missed or not processed.

The `@copilot` cue text lives in `copilot-review-cue.prompt`. Edit that file to change the prompt body.

## AI Review Labels

The worker treats these labels as mutually exclusive automation states and does not replace unrelated labels:

- `ai-review: review-requested` — Copilot review was requested and the worker is waiting for the review submission.
- `ai-review: waiting-comments` — review submission accepted; waiting for inline review comments to settle.
- `ai-review: fix-requested` — inline review comments exist and a Copilot fix request was posted or already exists.
- `ai-review: no-comments` — review submission had no inline review comments after the wait.
- `ai-review: fix-completed` — a Copilot SWE Agent commit was pushed after the latest `ai-review: fix-requested` label event.
- `ai-review: stale-resolved` — outdated review threads were resolved after a Copilot follow-up comment.

## Required Secrets

Set in Cloudflare:

- `GITHUB_WEBHOOK_SECRET`
- `GITHUB_TOKEN`

For creating PR comments and updating PR labels, `GITHUB_TOKEN` should have
write permission for Issues and Pull requests on `crazygo/go-puzzle`.

## 500 Error Diagnostics

When the worker returns a `500` response, it includes masked diagnostics for the
secrets used by the webhook flow:

- `GITHUB_WEBHOOK_SECRET`
- `GITHUB_TOKEN`

Each value reports whether it is present, its length, and a masked value in the
form `first8...last8`. Short secrets are not fully exposed.

## Optional Vars

Configured in `wrangler.toml`:

- `ALLOWED_REPO` (default `crazygo/go-puzzle`)
- `COPILOT_USER_ID` (default `175728472`)
- `COPILOT_SWE_AGENT_USER_ID` (default `198982749`)
- `GITHUB_API_URL` (default `https://api.github.com`)
- `REVIEW_COMMENT_SETTLE_MS` (default `5000`)

## Deploy

```bash
cd .github/cloudflare
npm i -g wrangler
wrangler secret put GITHUB_WEBHOOK_SECRET
wrangler secret put GITHUB_TOKEN
wrangler deploy
```

## GitHub Webhook

Repository settings → Webhooks:

- Payload URL: your deployed Worker URL
- Content type: `application/json`
- Secret: same value as `GITHUB_WEBHOOK_SECRET`
- Events: `Issue comments`, `Pull request reviews`, `Pull requests`
