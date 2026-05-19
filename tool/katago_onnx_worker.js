const readline = require('readline');
const ort = require('onnxruntime-node');

const sessions = new Map();

const rl = readline.createInterface({
  input: process.stdin,
  crlfDelay: Infinity,
});

rl.on('line', async (line) => {
  if (!line.trim()) return;
  let request;
  try {
    request = JSON.parse(line);
    const result = await handleRequest(request);
    write({ id: request.id, ok: true, ...result });
  } catch (error) {
    write({
      id: request && request.id,
      ok: false,
      error: `${error.name || 'Error'}:${error.message || error}`,
    });
  }
});

async function handleRequest(request) {
  if (request.type === 'load') {
    await sessionFor(request.model);
    return {};
  }
  if (request.type === 'eval') {
    const session = await sessionFor(request.model);
    const binInput = new ort.Tensor(
      'float32',
      Float32Array.from(request.binInput),
      request.binShape,
    );
    const globalInput = new ort.Tensor(
      'float32',
      Float32Array.from(request.globalInput),
      request.globalShape,
    );
    const outputs = await session.run({
      bin_input: binInput,
      global_input: globalInput,
    });
    const policy = policyOutputFor(
      outputs,
      (request.policyPlane + 1) * (request.boardPointCount + 1),
    );
    const move = selectMove({
      policy,
      policyPlane: request.policyPlane,
      boardPointCount: request.boardPointCount,
      legalMoves: request.legalMoves,
      temperature: request.policyTemperature,
      candidateLimit: request.candidateLimit,
    });
    return { move };
  }
  throw new Error(`unknown_request_type:${request.type}`);
}

async function sessionFor(model) {
  if (!model || typeof model !== 'string') {
    throw new Error('missing_model');
  }
  if (!sessions.has(model)) {
    sessions.set(model, await ort.InferenceSession.create(model));
  }
  return sessions.get(model);
}

function policyOutputFor(outputs, minPolicyLength) {
  const named = outputs.policy;
  if (named && named.data && named.data.length >= minPolicyLength) {
    return named.data;
  }
  for (const output of Object.values(outputs)) {
    if (output === named) continue;
    if (output && output.data && output.data.length >= minPolicyLength) {
      return output.data;
    }
  }
  throw new Error('katago_node_missing_policy_output');
}

function selectMove({
  policy,
  policyPlane,
  boardPointCount,
  legalMoves,
  temperature,
  candidateLimit,
}) {
  const stride = boardPointCount + 1;
  const offset = policyPlane * stride;
  if (offset + boardPointCount >= policy.length) {
    throw new RangeError(
      `policyPlaneOffset + boardPointCount ${offset + boardPointCount} >= ${policy.length}`,
    );
  }
  const scored = [];
  for (const move of legalMoves) {
    const score = Number(policy[offset + move]);
    if (!Number.isFinite(score)) continue;
    scored.push({ score, move });
  }
  if (scored.length === 0) {
    throw new Error('policy_has_no_finite_legal_scores');
  }
  scored.sort((a, b) => b.score - a.score);
  const limit = Math.max(1, Math.min(Number(candidateLimit) || 1, scored.length));
  const shortlist = scored.slice(0, limit);
  if (Number(temperature) <= 0) return shortlist[0].move;
  let best = shortlist[0];
  for (const entry of shortlist.slice(1)) {
    if (entry.score / temperature > best.score / temperature) best = entry;
  }
  return best.move;
}

function write(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}
