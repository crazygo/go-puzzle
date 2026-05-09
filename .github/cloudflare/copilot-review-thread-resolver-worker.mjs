import reviewCuePromptTemplate from './copilot-review-cue.prompt';

/**
 * Cloudflare Worker: automate GitHub PR review follow-up for crazygo/go-puzzle
 * Trigger sources:
 * - GitHub issue_comment webhook (created on pull requests)
 * - GitHub pull_request_review webhook (submitted)
 *
 * Required secrets:
 * - GITHUB_WEBHOOK_SECRET
 * - GITHUB_TOKEN (PAT with repo access for crazygo/go-puzzle)
 *
 * Optional env vars:
 * - GITHUB_API_URL (default: https://api.github.com)
 * - COPILOT_USER_ID (default: 175728472)
 * - COPILOT_SWE_AGENT_USER_ID (default: 198982749)
 * - ALLOWED_REPO (default: crazygo/go-puzzle)
 * - REVIEW_COMMENT_SETTLE_MS (default: 5000)
 */

const DEFAULT_GITHUB_API_URL = 'https://api.github.com';
const DEFAULT_COPILOT_REVIEWER_USER_ID = 175728472;
const DEFAULT_COPILOT_SWE_AGENT_USER_ID = 198982749;
const DEFAULT_ALLOWED_REPO = 'crazygo/go-puzzle';
const DEFAULT_REVIEW_COMMENT_SETTLE_MS = 5000;
const SECRET_DEBUG_NAMES = ['GITHUB_WEBHOOK_SECRET', 'GITHUB_TOKEN'];
const AI_REVIEW_WAITING_COMMENTS_LABEL = 'ai-review: waiting-comments';
const AI_REVIEW_FIX_REQUESTED_LABEL = 'ai-review: fix-requested';
const AI_REVIEW_NO_COMMENTS_LABEL = 'ai-review: no-comments';
const AI_REVIEW_FIX_COMPLETED_LABEL = 'ai-review: fix-completed';
const AI_REVIEW_STALE_RESOLVED_LABEL = 'ai-review: stale-resolved';
const AI_REVIEW_LABELS = [
  AI_REVIEW_WAITING_COMMENTS_LABEL,
  AI_REVIEW_FIX_REQUESTED_LABEL,
  AI_REVIEW_NO_COMMENTS_LABEL,
  AI_REVIEW_FIX_COMPLETED_LABEL,
  AI_REVIEW_STALE_RESOLVED_LABEL,
];
const AI_REVIEW_LABEL_DEFINITIONS = {
  [AI_REVIEW_WAITING_COMMENTS_LABEL]: {
    color: 'FBCA04',
    description: 'AI review webhook accepted; waiting for inline review comments.',
  },
  [AI_REVIEW_FIX_REQUESTED_LABEL]: {
    color: 'D93F0B',
    description: 'AI review comments exist and a Copilot fix request was posted.',
  },
  [AI_REVIEW_NO_COMMENTS_LABEL]: {
    color: 'C5DEF5',
    description: 'AI review was submitted but no inline review comments were found.',
  },
  [AI_REVIEW_FIX_COMPLETED_LABEL]: {
    color: '0E8A16',
    description: 'Copilot SWE agent reported that requested review fixes were completed.',
  },
  [AI_REVIEW_STALE_RESOLVED_LABEL]: {
    color: '5319E7',
    description: 'Outdated AI review threads were resolved after follow-up automation.',
  },
};

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
      return serverError({ ok: false, error: 'Missing GITHUB_WEBHOOK_SECRET' }, env);
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

    try {
      if (eventName === 'issue_comment') {
        const result = await handleIssueCommentCreated(payload, env);
        return json({ ok: true, deliveryId, event: eventName, ...result });
      }

      if (eventName === 'pull_request_review') {
        const result = await handlePullRequestReviewSubmitted(payload, env);
        return json({ ok: true, deliveryId, event: eventName, ...result });
      }
    } catch (error) {
      return serverError(
        { ok: false, deliveryId, event: eventName, error: String(error?.message ?? error) },
        env,
      );
    }

    return json({ ok: true, deliveryId, event: eventName, ignored: 'unsupported_event' });
  },
};

async function handleIssueCommentCreated(payload, env) {
  if (payload.action !== 'created') {
    return { ignored: 'issue_comment_action_not_created' };
  }

  if (!payload.issue?.pull_request) {
    return { ignored: 'comment_not_on_pull_request' };
  }

  const isReviewer = isCopilotReviewerUser(payload.comment?.user, env);
  const isSweAgent = isCopilotSweAgentUser(payload.comment?.user, env);
  if (!isReviewer && !isSweAgent) {
    return {
      ignored: 'comment_not_from_supported_copilot_bot',
      userMatchDebug: buildCopilotUserMatchDebug(payload.comment?.user, env),
    };
  }

  const repoCheck = validateAllowedRepo(payload, env);
  if (repoCheck.ignored) {
    return repoCheck;
  }

  if (!env.GITHUB_TOKEN) {
    throw new Error('Missing GITHUB_TOKEN');
  }

  if (isSweAgent) {
    if (!isCopilotSweAgentCompletionComment(payload.comment)) {
      return {
        ignored: 'copilot_swe_agent_comment_not_completion',
        commenter: payload.comment?.user?.login ?? null,
      };
    }

    const owner = payload.repository?.owner?.login;
    const repo = payload.repository?.name;
    const pullNumber = payload.issue?.number;
    if (!owner || !repo || !pullNumber) {
      throw new Error('Missing owner/repo/pull number in payload.');
    }

    const apiUrl = env.GITHUB_API_URL || DEFAULT_GITHUB_API_URL;
    const labelResult = await setAiReviewLabelState({
      owner,
      repo,
      pullNumber,
      stateLabel: AI_REVIEW_FIX_COMPLETED_LABEL,
      token: env.GITHUB_TOKEN,
      apiUrl,
    });

    return {
      repository: `${owner}/${repo}`,
      pullNumber,
      fixCompletedDetected: true,
      labelState: AI_REVIEW_FIX_COMPLETED_LABEL,
      labelResult,
      commentUrl: payload.comment?.html_url ?? null,
    };
  }

  const result = await resolveOutdatedThreads(payload, env);
  if (result.resolvedThreads <= 0) return result;

  const labelResult = await setAiReviewLabelState({
    owner: payload.repository?.owner?.login,
    repo: payload.repository?.name,
    pullNumber: payload.issue?.number,
    stateLabel: AI_REVIEW_STALE_RESOLVED_LABEL,
    token: env.GITHUB_TOKEN,
    apiUrl: env.GITHUB_API_URL || DEFAULT_GITHUB_API_URL,
  });

  return {
    ...result,
    labelState: AI_REVIEW_STALE_RESOLVED_LABEL,
    labelResult,
  };
}

async function handlePullRequestReviewSubmitted(payload, env) {
  if (payload.action !== 'submitted') {
    return { ignored: 'pull_request_review_action_not_submitted' };
  }

  if (!payload.pull_request) {
    return { ignored: 'review_not_on_pull_request' };
  }

  if (!isCopilotReviewerUser(payload.review?.user, env)) {
    return {
      ignored: 'review_not_from_copilot',
      userMatchDebug: buildCopilotUserMatchDebug(payload.review?.user, env),
    };
  }

  const repoCheck = validateAllowedRepo(payload, env);
  if (repoCheck.ignored) {
    return repoCheck;
  }

  if (!env.GITHUB_TOKEN) {
    throw new Error('Missing GITHUB_TOKEN');
  }

  const owner = payload.repository?.owner?.login;
  const repo = payload.repository?.name;
  const pullNumber = payload.pull_request?.number;
  const reviewId = payload.review?.id;
  const reviewUrl = payload.review?.html_url ?? payload.pull_request?.html_url;

  if (!owner || !repo || !pullNumber || !reviewId || !reviewUrl) {
    throw new Error('Missing owner/repo/pull number/review id/review url in payload.');
  }

  const apiUrl = env.GITHUB_API_URL || DEFAULT_GITHUB_API_URL;
  const token = env.GITHUB_TOKEN;
  const waitingLabelResult = await setAiReviewLabelState({
    owner,
    repo,
    pullNumber,
    stateLabel: AI_REVIEW_WAITING_COMMENTS_LABEL,
    token,
    apiUrl,
  });
  const settleMs = Number(env.REVIEW_COMMENT_SETTLE_MS || DEFAULT_REVIEW_COMMENT_SETTLE_MS);
  if (settleMs > 0) {
    await sleep(settleMs);
  }

  const reviewComments = await fetchReviewComments({
    owner,
    repo,
    pullNumber,
    reviewId,
    token,
    apiUrl,
  });

  if (reviewComments.length === 0) {
    const labelResult = await setAiReviewLabelState({
      owner,
      repo,
      pullNumber,
      stateLabel: AI_REVIEW_NO_COMMENTS_LABEL,
      token,
      apiUrl,
    });
    return {
      repository: `${owner}/${repo}`,
      pullNumber,
      reviewId,
      reviewUrl,
      reviewCommentCount: 0,
      labelState: AI_REVIEW_NO_COMMENTS_LABEL,
      waitingLabelResult,
      labelResult,
      ignored: 'review_has_no_comments',
    };
  }

  const existingCue = await findExistingCueComment({
    owner,
    repo,
    pullNumber,
    reviewUrl,
    token,
    apiUrl,
  });

  if (existingCue) {
    const labelResult = await setAiReviewLabelState({
      owner,
      repo,
      pullNumber,
      stateLabel: AI_REVIEW_FIX_REQUESTED_LABEL,
      token,
      apiUrl,
    });
    return {
      repository: `${owner}/${repo}`,
      pullNumber,
      reviewId,
      reviewUrl,
      reviewCommentCount: reviewComments.length,
      cueCommentPosted: false,
      existingCueCommentUrl: existingCue.html_url ?? null,
      labelState: AI_REVIEW_FIX_REQUESTED_LABEL,
      waitingLabelResult,
      labelResult,
      ignored: 'cue_comment_already_exists',
    };
  }

  const cueComment = await createIssueComment({
    owner,
    repo,
    pullNumber,
    body: renderTemplate(reviewCuePromptTemplate, { review_url: reviewUrl }),
    token,
    apiUrl,
  });
  const labelResult = await setAiReviewLabelState({
    owner,
    repo,
    pullNumber,
    stateLabel: AI_REVIEW_FIX_REQUESTED_LABEL,
    token,
    apiUrl,
  });

  return {
    repository: `${owner}/${repo}`,
    pullNumber,
    reviewId,
    reviewUrl,
    reviewCommentCount: reviewComments.length,
    cueCommentPosted: true,
    cueCommentUrl: cueComment.html_url ?? null,
    labelState: AI_REVIEW_FIX_REQUESTED_LABEL,
    waitingLabelResult,
    labelResult,
  };
}

function validateAllowedRepo(payload, env) {
  const repoFullName = `${payload.repository?.owner?.login ?? ''}/${payload.repository?.name ?? ''}`;
  const allowedRepo = env.ALLOWED_REPO || DEFAULT_ALLOWED_REPO;
  if (repoFullName !== allowedRepo) {
    return { ignored: 'repo_not_allowed', repoFullName, allowedRepo };
  }

  return { repoFullName, allowedRepo };
}

function isCopilotReviewerUser(user, env) {
  const userId = Number(user?.id ?? 0);
  const expectedUserId = Number(env.COPILOT_USER_ID || DEFAULT_COPILOT_REVIEWER_USER_ID);
  const userType = user?.type;
  const userLogin = user?.login;

  return userId === expectedUserId || (userLogin === 'Copilot' && userType === 'Bot');
}

function isCopilotSweAgentUser(user, env) {
  const userId = Number(user?.id ?? 0);
  const expectedUserId = Number(env.COPILOT_SWE_AGENT_USER_ID || DEFAULT_COPILOT_SWE_AGENT_USER_ID);
  const userType = user?.type;
  const userLogin = user?.login;
  const htmlUrl = user?.html_url;

  return userId === expectedUserId ||
      (userLogin === 'copilot-swe-agent[bot]' && userType === 'Bot') ||
      htmlUrl === 'https://github.com/apps/copilot-swe-agent';
}

function buildCopilotUserMatchDebug(user, env) {
  const expectedReviewerUserId = Number(env.COPILOT_USER_ID || DEFAULT_COPILOT_REVIEWER_USER_ID);
  const expectedSweAgentUserId =
      Number(env.COPILOT_SWE_AGENT_USER_ID || DEFAULT_COPILOT_SWE_AGENT_USER_ID);
  return {
    expectedReviewer: {
      id: expectedReviewerUserId,
      fallbackLogin: 'Copilot',
      fallbackType: 'Bot',
    },
    expectedSweAgent: {
      id: expectedSweAgentUserId,
      fallbackLogin: 'copilot-swe-agent[bot]',
      fallbackType: 'Bot',
      fallbackHtmlUrl: 'https://github.com/apps/copilot-swe-agent',
    },
    observed: {
      login: user?.login ?? null,
      id: user?.id ?? null,
      nodeId: user?.node_id ?? null,
      type: user?.type ?? null,
      userViewType: user?.user_view_type ?? null,
      htmlUrl: user?.html_url ?? null,
    },
  };
}

function isCopilotSweAgentCompletionComment(comment) {
  const body = comment?.body ?? '';
  if (!body) return false;
  return /\bDone in commits?\b/i.test(body) ||
      /\bReview comments addressed\b/i.test(body) ||
      (/\bDone\b/i.test(body) && /\bcommits?\b/i.test(body));
}

function renderTemplate(template, values) {
  let output = template;
  for (const [key, value] of Object.entries(values)) {
    output = output.replaceAll(`{{${key}}}`, String(value));
  }
  return output.trim();
}

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function fetchReviewComments({ owner, repo, pullNumber, reviewId, token, apiUrl }) {
  return fetchPaginatedRest({
    apiUrl,
    token,
    path: `/repos/${owner}/${repo}/pulls/${pullNumber}/reviews/${reviewId}/comments`,
  });
}

async function findExistingCueComment({ owner, repo, pullNumber, reviewUrl, token, apiUrl }) {
  const comments = await fetchPaginatedRest({
    apiUrl,
    token,
    path: `/repos/${owner}/${repo}/issues/${pullNumber}/comments`,
  });

  return comments.find((comment) => {
    const body = comment.body ?? '';
    return body.includes('@copilot') && body.includes(reviewUrl);
  });
}

async function createIssueComment({ owner, repo, pullNumber, body, token, apiUrl }) {
  return githubRest({
    apiUrl,
    token,
    method: 'POST',
    path: `/repos/${owner}/${repo}/issues/${pullNumber}/comments`,
    body: { body },
  });
}

async function setAiReviewLabelState({ owner, repo, pullNumber, stateLabel, token, apiUrl }) {
  if (!owner || !repo || !pullNumber) {
    throw new Error('Missing owner/repo/pull number for label state update.');
  }
  if (stateLabel != null && !AI_REVIEW_LABELS.includes(stateLabel)) {
    throw new Error(`Unsupported AI review label state: ${stateLabel}`);
  }

  if (stateLabel != null) {
    await ensureAiReviewLabel({ owner, repo, label: stateLabel, token, apiUrl });
  }

  const removed = [];
  const removeErrors = [];
  for (const label of AI_REVIEW_LABELS) {
    if (label === stateLabel) continue;
    const result = await removeIssueLabel({
      owner,
      repo,
      pullNumber,
      label,
      token,
      apiUrl,
    });
    if (result.removed) removed.push(label);
    if (result.error) removeErrors.push({ label, error: result.error });
  }

  if (removeErrors.length > 0) {
    throw new Error(`Failed to remove AI review labels: ${JSON.stringify(removeErrors)}`);
  }

  let added = null;
  if (stateLabel != null) {
    await addIssueLabel({ owner, repo, pullNumber, label: stateLabel, token, apiUrl });
    added = stateLabel;
  }

  return {
    state: stateLabel,
    added,
    removed,
  };
}

async function ensureAiReviewLabel({ owner, repo, label, token, apiUrl }) {
  const definition = AI_REVIEW_LABEL_DEFINITIONS[label] ?? {
    color: 'EDEDED',
    description: 'AI review automation state.',
  };
  const result = await githubRestRaw({
    apiUrl,
    token,
    method: 'POST',
    path: `/repos/${owner}/${repo}/labels`,
    body: {
      name: label,
      color: definition.color,
      description: definition.description,
    },
  });
  if (result.ok || result.status === 422) return result.body;
  throw new Error(`GitHub label create failed: status=${result.status}, body=${result.text}`);
}

async function addIssueLabel({ owner, repo, pullNumber, label, token, apiUrl }) {
  return githubRest({
    apiUrl,
    token,
    method: 'POST',
    path: `/repos/${owner}/${repo}/issues/${pullNumber}/labels`,
    body: { labels: [label] },
  });
}

async function removeIssueLabel({ owner, repo, pullNumber, label, token, apiUrl }) {
  const result = await githubRestRaw({
    apiUrl,
    token,
    method: 'DELETE',
    path: `/repos/${owner}/${repo}/issues/${pullNumber}/labels/${encodeURIComponent(label)}`,
  });
  if (result.ok) return { removed: true };
  if (result.status === 404) return { removed: false };
  return { removed: false, error: `status=${result.status}, body=${result.text}` };
}

async function fetchPaginatedRest({ apiUrl, token, path }) {
  const all = [];
  let page = 1;

  while (true) {
    const pageItems = await githubRest({
      apiUrl,
      token,
      path: `${path}?per_page=100&page=${page}`,
    });

    if (!Array.isArray(pageItems)) {
      return all;
    }

    all.push(...pageItems);
    if (pageItems.length < 100) {
      return all;
    }

    page += 1;
  }
}

async function githubRest({ apiUrl, token, path, method = 'GET', body }) {
  const result = await githubRestRaw({ apiUrl, token, path, method, body });
  if (!result.ok) {
    throw new Error(`GitHub REST failed: status=${result.status}, body=${result.text}`);
  }
  return result.body;
}

async function githubRestRaw({ apiUrl, token, path, method = 'GET', body }) {
  const response = await fetch(`${apiUrl}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'pr-review-comment-resolver',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const textBody = await response.text();
  const jsonBody = textBody ? JSON.parse(textBody) : null;
  return {
    ok: response.ok,
    status: response.status,
    body: jsonBody,
    text: textBody,
  };
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

function serverError(payload, env) {
  const body = {
    ...payload,
    secretDebug: buildSecretDebug(env),
  };
  console.error(JSON.stringify(body));
  return json(body, 500);
}

function buildSecretDebug(env) {
  return {
    note: 'Masked secret diagnostics for 500 responses only. Values show prefix/suffix only.',
    secrets: Object.fromEntries(
      SECRET_DEBUG_NAMES.map((name) => [name, maskSecret(env[name])]),
    ),
  };
}

function maskSecret(value) {
  if (!value) {
    return {
      present: false,
      length: 0,
      masked: null,
    };
  }

  const text = String(value);
  if (text.length <= 16) {
    return {
      present: true,
      length: text.length,
      masked: `${text.slice(0, 4)}...${text.slice(-4)}`,
      note: 'Secret is too short to expose 8+8 characters without revealing the full value.',
    };
  }

  return {
    present: true,
    length: text.length,
    masked: `${text.slice(0, 8)}...${text.slice(-8)}`,
  };
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
