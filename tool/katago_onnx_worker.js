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
    const candidates = rankPolicyCandidates({
      policy,
      policyPlane: request.policyPlane,
      boardPointCount: request.boardPointCount,
      legalMoves: request.legalMoves,
      candidateLimit: request.candidateLimit,
    });
    const selected = selectMove({
      candidates,
      temperature: request.policyTemperature,
    });
    return {
      move: selected.move,
      policyCandidates: candidates,
      value: valueEstimate(outputData(outputs, 'value')),
      scoreBelief: scoreBeliefSummary(outputData(outputs, 'scorebelief')),
    };
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

function outputData(outputs, name) {
  const output = outputs[name];
  return output && output.data ? output.data : null;
}

function rankPolicyCandidates({
  policy,
  policyPlane,
  boardPointCount,
  legalMoves,
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
  const probabilities = softmax(shortlist.map((entry) => entry.score));
  return shortlist.map((entry, index) => ({
    move: entry.move,
    score: entry.score,
    probability: probabilities[index],
    rank: index + 1,
    policyPlane,
  }));
}

function selectMove({ candidates, temperature }) {
  if (!candidates.length) {
    throw new Error('policy_has_no_finite_legal_scores');
  }
  if (Number(temperature) <= 0) return candidates[0];
  const maxScore = candidates.reduce(
    (max, entry) => Math.max(max, entry.score),
    candidates[0].score,
  );
  const weights = candidates.map((entry) =>
    Math.exp((entry.score - maxScore) / Number(temperature)),
  );
  const total = weights.reduce((sum, value) => sum + value, 0);
  let threshold = Math.random() * total;
  for (let i = 0; i < candidates.length; i += 1) {
    threshold -= weights[i];
    if (threshold <= 0) return candidates[i];
  }
  return candidates[candidates.length - 1];
}

function valueEstimate(raw) {
  if (!raw || raw.length < 3) return null;
  const probs = softmax(Array.from(raw.slice(0, 3)).map(Number));
  return { win: probs[0], loss: probs[1], noResult: probs[2] };
}

function scoreBeliefSummary(raw) {
  if (!raw || raw.length === 0) return null;
  const probs = softmax(Array.from(raw).map(Number));
  const mid = probs.length / 2;
  let mean = 0;
  for (let i = 0; i < probs.length; i += 1) {
    mean += probs[i] * (i - mid + 0.5);
  }
  let variance = 0;
  for (let i = 0; i < probs.length; i += 1) {
    const score = i - mid + 0.5;
    const delta = score - mean;
    variance += probs[i] * delta * delta;
  }
  return { mean, stdev: Math.sqrt(Math.max(0, variance)), distribution: probs };
}

function softmax(values) {
  if (!values.length) return [];
  const max = values.reduce((a, b) => Math.max(a, b), values[0]);
  const weights = values.map((value) => Math.exp(value - max));
  const total = weights.reduce((a, b) => a + b, 0);
  return total > 0 ? weights.map((value) => value / total) : values.map(() => 0);
}

function write(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}
