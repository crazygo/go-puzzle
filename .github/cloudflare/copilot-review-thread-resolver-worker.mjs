/**
 * Cloudflare Worker: auto-resolve outdated GitHub PR review threads for crazygo/go-puzzle
 * Trigger source: GitHub issue_comment webhook (created on pull requests)
 *
 * Required secrets:
 * - GITHUB_WEBHOOK_SECRET
 * - GITHUB_TOKEN (PAT with repo access for crazygo/go-puzzle)
 *
 * Optional env vars:
 * - GITHUB_API_URL (default: https://api.github.com)
 * - COPILOT_USER_ID (default: 198982749)
 * - ALLOWED_REPO (default: crazygo/go-puzzle)
 */

const DEFAULT_GITHUB_API_URL = 'https://api.github.com';
const DEFAULT_COPILOT_USER_ID = 198982749;
const DEFAULT_ALLOWED_REPO = 'crazygo/go-puzzle';

const QUERY_REVIEW_THREADS = `
  query($owner:String!, $repo:String!, $pr:Int!, $cursor:String) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100, after:$cursor) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
            isResolved
            isOutdated
            comments(first:1) {
              nodes {
                url
              }
            }
          }
        }
      }
    }
  }
`;

const MUTATION_RESOLVE_THREAD = `
  mutation($threadId:ID!) {
    resolveReviewThread(input:{threadId:$threadId}) {
      thread {
        id
        isResolved
        isOutdated
      }
    }
  }
`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'GET' && (url.pathname === '/' || url.pathname === '/healthz')) {
      return json({ ok: true, service: 'pr-review-comment-resolver' });
    }

    if (request.method !== 'POST') {
      return json({ ok: false, error: 'Method not allowed' }, 405);
    }

    const signature = request.headers.get('X-Hub-Signature-256');
    const eventName = request.headers.get('X-GitHub-Event') ?? 'unknown';
    const deliveryId = request.headers.get('X-GitHub-Delivery') ?? 'unknown';
    const rawBody = await request.text();

    if (!env.GITHUB_WEBHOOK_SECRET) {
      return json({ ok: false, error: 'Missing GITHUB_WEBHOOK_SECRET' }, 500);
    }

    if (!(await verifyWebhookSignature(rawBody, signature, env.GITHUB_WEBHOOK_SECRET))) {
      return json({ ok: false, error: 'Invalid webhook signature' }, 401);
    }

    let payload;
    try {
      payload = JSON.parse(rawBody);
    } catch (error) {
      return json({ ok: false, error: `Invalid JSON payload: ${String(error)}` }, 400);
    }

    if (eventName === 'ping') {
      return json({ ok: true, deliveryId, event: eventName, zen: payload.zen ?? null });
    }

    if (eventName !== 'issue_comment') {
      return json({ ok: true, deliveryId, event: eventName, ignored: 'unsupported_event' });
    }

    if (payload.action !== 'created') {
      return json({ ok: true, deliveryId, event: eventName, ignored: 'issue_comment_action_not_created' });
    }

    if (!payload.issue?.pull_request) {
      return json({ ok: true, deliveryId, event: eventName, ignored: 'comment_not_on_pull_request' });
    }

    if (!isCopilotComment(payload, env)) {
      return json({
        ok: true,
        deliveryId,
        event: eventName,
        ignored: 'comment_not_from_copilot',
        commenter: payload.comment?.user?.login ?? null,
      });
    }

    const repoFullName = `${payload.repository?.owner?.login ?? ''}/${payload.repository?.name ?? ''}`;
    const allowedRepo = env.ALLOWED_REPO || DEFAULT_ALLOWED_REPO;
    if (repoFullName !== allowedRepo) {
      return json({ ok: true, deliveryId, event: eventName, ignored: 'repo_not_allowed', repoFullName, allowedRepo });
    }

    if (!env.GITHUB_TOKEN) {
      return json({ ok: false, error: 'Missing GITHUB_TOKEN' }, 500);
    }

    const result = await resolveOutdatedThreads(payload, env);
    return json({ ok: true, deliveryId, event: eventName, ...result });
  },
};

function isCopilotComment(payload, env) {
  const commentUserId = Number(payload.comment?.user?.id ?? 0);
  const expectedUserId = Number(env.COPILOT_USER_ID || DEFAULT_COPILOT_USER_ID);
  const userType = payload.comment?.user?.type;
  const userLogin = payload.comment?.user?.login;

  return commentUserId === expectedUserId || (userLogin === 'Copilot' && userType === 'Bot');
}

async function resolveOutdatedThreads(payload, env) {
  const owner = payload.repository?.owner?.login;
  const repo = payload.repository?.name;
  const pullNumber = payload.issue?.number;

  if (!owner || !repo || !pullNumber) {
    throw new Error('Missing owner/repo/pull number in payload.');
  }

  const apiUrl = env.GITHUB_API_URL || DEFAULT_GITHUB_API_URL;
  const token = env.GITHUB_TOKEN;
  const allThreads = await fetchAllReviewThreads({ owner, repo, pullNumber, token, apiUrl });
  const targets = allThreads.filter((thread) => thread.isOutdated && !thread.isResolved);

  const resolvedUrls = [];
  for (const thread of targets) {
    await resolveReviewThread({ threadId: thread.id, token, apiUrl });
    const url = thread.comments?.nodes?.[0]?.url;
    if (url) {
      resolvedUrls.push(url);
    }
  }

  return {
    repository: `${owner}/${repo}`,
    pullNumber,
    totalThreads: allThreads.length,
    resolvedThreads: targets.length,
    resolvedUrls,
    note: 'Summary comment disabled by request (no PR comment posted).',
  };
}

async function fetchAllReviewThreads({ owner, repo, pullNumber, token, apiUrl }) {
  const all = [];
  let cursor = null;
  let hasNextPage = true;

  while (hasNextPage) {
    const data = await githubGraphql({
      apiUrl,
      token,
      query: QUERY_REVIEW_THREADS,
      variables: { owner, repo, pr: pullNumber, cursor },
    });

    const pr = data?.repository?.pullRequest;
    const conn = pr?.reviewThreads;
    if (!conn) {
      break;
    }

    all.push(...(conn.nodes ?? []));
    hasNextPage = Boolean(conn.pageInfo?.hasNextPage);
    cursor = conn.pageInfo?.endCursor ?? null;
  }

  return all;
}

async function resolveReviewThread({ threadId, token, apiUrl }) {
  const data = await githubGraphql({
    apiUrl,
    token,
    query: MUTATION_RESOLVE_THREAD,
    variables: { threadId },
  });

  const thread = data?.resolveReviewThread?.thread;
  if (!thread?.isResolved) {
    throw new Error(`Failed to resolve thread ${threadId}`);
  }
}

async function githubGraphql({ apiUrl, token, query, variables }) {
  const response = await fetch(`${apiUrl}/graphql`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'pr-review-comment-resolver',
    },
    body: JSON.stringify({ query, variables }),
  });

  const jsonBody = await response.json();
  if (!response.ok || jsonBody.errors) {
    throw new Error(`GitHub GraphQL failed: status=${response.status}, body=${JSON.stringify(jsonBody)}`);
  }
  return jsonBody.data;
}

async function verifyWebhookSignature(body, signatureHeader, secret) {
  if (!signatureHeader || !signatureHeader.startsWith('sha256=')) {
    return false;
  }

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const sigBuffer = await crypto.subtle.sign('HMAC', key, encoder.encode(body));
  const digest = `sha256=${toHex(sigBuffer)}`;
  return timingSafeEqual(digest, signatureHeader);
}

function toHex(buffer) {
  const bytes = new Uint8Array(buffer);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) {
    return false;
  }
  let out = 0;
  for (let i = 0; i < a.length; i += 1) {
    out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return out === 0;
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
