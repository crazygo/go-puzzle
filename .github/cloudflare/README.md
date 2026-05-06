# Cloudflare PR Review Comment Resolver

Cloudflare Worker that listens to GitHub `issue_comment` webhooks and resolves outdated PR review threads for `crazygo/go-puzzle`.

## Behavior

- Accepts GitHub webhook POST.
- Verifies signature via `GITHUB_WEBHOOK_SECRET`.
- Only handles PR comment creation events.
- Only acts when comment author matches Copilot bot identity.
- Resolves review threads where `isOutdated=true` and `isResolved=false`.
- Does **not** post summary comment to PR (per current requirement).

## Required Secrets

Set in Cloudflare:

- `GITHUB_WEBHOOK_SECRET`
- `GITHUB_TOKEN`

## Optional Vars

Configured in `wrangler.toml`:

- `ALLOWED_REPO` (default `crazygo/go-puzzle`)
- `COPILOT_USER_ID` (default `198982749`)
- `GITHUB_API_URL` (default `https://api.github.com`)

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
- Events: `Issue comments`
