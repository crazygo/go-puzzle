# Cloudflare PR Review Automation

Cloudflare Worker that listens to GitHub PR review webhooks for `crazygo/go-puzzle`.

## Behavior

- Accepts GitHub webhook POST.
- Verifies signature via `GITHUB_WEBHOOK_SECRET`.
- On `issue_comment.created`:
  - Only handles comments created on pull requests.
  - Only acts when comment author matches Copilot bot identity.
  - Resolves review threads where `isOutdated=true` and `isResolved=false`.
  - Does **not** post summary comment to PR (per current requirement).
- On `pull_request_review.submitted`:
  - Only acts when review author matches Copilot bot identity.
  - Waits `REVIEW_COMMENT_SETTLE_MS` so GitHub can finish creating inline review comments.
  - Fetches the submitted review's real inline comments.
  - If at least one review comment exists, posts a PR comment cueing `@copilot` to address the review.
  - Skips posting if a cue comment for the same review URL already exists.

The `@copilot` cue text lives in `copilot-review-cue.prompt`. Edit that file to change the prompt body.

## Required Secrets

Set in Cloudflare:

- `GITHUB_WEBHOOK_SECRET`
- `GITHUB_TOKEN`

## Optional Vars

Configured in `wrangler.toml`:

- `ALLOWED_REPO` (default `crazygo/go-puzzle`)
- `COPILOT_USER_ID` (default `175728472`)
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
- Events: `Issue comments`, `Pull request reviews`
