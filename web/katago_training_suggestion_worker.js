/* global ort */

// Spec: docs/specs_map/technical_contracts.yaml#ai_background_execution
const ORT_VERSION = '1.22.0';
const ORT_BASE = `https://cdn.jsdelivr.net/npm/onnxruntime-web@${ORT_VERSION}/dist/`;

const EMPTY = 0;
const BLACK = 1;
const WHITE = 2;

let ortReady = false;
const sessions = new Map();

const POLICY_PLANE_LABELS = [
  '穩定推薦',
  '對手應手視角',
  '柔和推薦',
  '柔和對手應手',
  '長期樂觀',
  '短期樂觀',
];

self.onmessage = async (event) => {
  const data = event.data || {};
  const requestId = data.requestId;
  try {
    const params = data.params || {};
    const structuredSuggestions = await suggestWithKatago(params);
    self.postMessage({ requestId, structuredSuggestions });
  } catch (error) {
    self.postMessage({
      requestId,
      error: String(error && error.message ? error.message : error),
    });
  }
};

async function suggestWithKatago(params) {
  const boardSize = Number(params.boardSize);
  const cells = Array.from(params.cells || []).map(Number);
  const currentPlayer = Number(params.currentPlayer);
  const legalMoves = Array.from(params.legalMoves || []).map(Number);
  const count = Math.max(1, Number(params.count) || 3);
  const policyPlane = Math.max(0, Number(params.policyPlane) || 0);
  const candidateLimit = Math.max(1, Number(params.candidateLimit) || count);
  const modelAsset = String(params.modelAsset || '');

  if (!boardSize || cells.length !== boardSize * boardSize) {
    throw new Error('katago_worker_bad_board');
  }
  if (!modelAsset) throw new Error('katago_worker_missing_model');
  if (legalMoves.length === 0) return [];

  const session = await sessionFor(modelUrl(modelAsset));
  const before = await evaluate(session, {
    boardSize,
    cells,
    currentPlayer,
    policyPlane,
    legalMoves,
    candidateLimit: Math.max(candidateLimit, count),
  });
  if (!before.candidates.length) return [];

  const beforeWin = before.value ? before.value.win : null;
  const strategyLabel = POLICY_PLANE_LABELS[policyPlane] || POLICY_PLANE_LABELS[0];
  const suggestions = [];

  for (const candidate of before.candidates.slice(0, count)) {
    const afterBoard = applyMove({
      boardSize,
      cells,
      currentPlayer,
      move: candidate.move,
    });
    const after = await evaluate(session, {
      boardSize,
      cells: afterBoard.cells,
      currentPlayer: afterBoard.currentPlayer,
      policyPlane,
      legalMoves: legalMovesFor(afterBoard.cells),
      candidateLimit: Math.max(1, count),
    });
    const afterWin = after.value && Number.isFinite(after.value.loss)
      ? after.value.loss
      : beforeWin;
    const fallbackWin = 0.5;
    const winRate = clamp(
      Number.isFinite(afterWin) ? afterWin : (Number.isFinite(beforeWin) ? beforeWin : fallbackWin),
      0.05,
      0.95,
    );
    const valueDelta = Number.isFinite(beforeWin) && Number.isFinite(afterWin)
      ? afterWin - beforeWin
      : null;
    const scoreBelief = after.scoreBelief || before.scoreBelief;

    suggestions.push({
      row: Math.floor(candidate.move / boardSize),
      col: candidate.move % boardSize,
      winRate,
      policyScore: candidate.score,
      policyProbability: candidate.probability,
      valueDelta,
      scoreLead: scoreBelief ? scoreBelief.mean : null,
      scoreUncertainty: scoreBelief ? scoreBelief.stdev : null,
      strategyLabel,
      explanationSignals: explanationSignals({
        candidate,
        strategyLabel,
        scoreBelief,
      }),
      source: 'katago',
    });
  }
  return suggestions;
}

async function sessionFor(url) {
  if (!ortReady) {
    importScripts(`${ORT_BASE}ort.min.js`);
    ort.env.wasm.wasmPaths = ORT_BASE;
    ortReady = true;
  }
  if (!sessions.has(url)) {
    sessions.set(
      url,
      await ort.InferenceSession.create(url, { executionProviders: ['wasm'] }),
    );
  }
  return sessions.get(url);
}

function modelUrl(modelAsset) {
  return modelAsset.startsWith('assets/') ? `./assets/${modelAsset}` : modelAsset;
}

async function evaluate(session, request) {
  const features = encodeFeatures(
    request.cells,
    request.boardSize,
    request.currentPlayer,
  );
  const outputs = await session.run({
    bin_input: new ort.Tensor('float32', features.binInput, [
      1,
      22,
      request.boardSize,
      request.boardSize,
    ]),
    global_input: new ort.Tensor('float32', features.globalInput, [1, 19]),
  });
  const pointCount = request.boardSize * request.boardSize;
  const policy = outputData(outputs, 'policy', (request.policyPlane + 1) * (pointCount + 1));
  return {
    candidates: rankPolicyCandidates({
      policy,
      legalMoves: request.legalMoves,
      boardPointCount: pointCount,
      candidateLimit: request.candidateLimit,
      policyPlane: request.policyPlane,
    }),
    value: valueEstimate(outputByName(outputs, 'value')),
    scoreBelief: scoreBeliefSummary(outputByName(outputs, 'scorebelief')),
  };
}

function encodeFeatures(cells, size, currentPlayer) {
  const opponent = currentPlayer === BLACK ? WHITE : BLACK;
  const binInput = new Float32Array(1 * 22 * size * size);
  const globalInput = new Float32Array(19);
  for (let row = 0; row < size; row++) {
    for (let col = 0; col < size; col++) {
      setPlane(binInput, size, 0, row, col, 1);
    }
  }
  for (let index = 0; index < cells.length; index++) {
    const row = Math.floor(index / size);
    const col = index % size;
    const value = cells[index];
    if (value === currentPlayer) {
      setPlane(binInput, size, 1, row, col, 1);
    } else if (value === opponent) {
      setPlane(binInput, size, 2, row, col, 1);
    } else {
      setPlane(binInput, size, 3, row, col, 1);
    }
  }
  globalInput[0] = 1;
  globalInput[1] = currentPlayer === BLACK ? 1 : -1;
  globalInput[2] = size;
  return { binInput, globalInput };
}

function setPlane(input, size, plane, row, col, value) {
  input[plane * size * size + row * size + col] = value;
}

function outputByName(outputs, name) {
  const output = outputs[name];
  return output && output.data ? output.data : null;
}

function outputData(outputs, name, minLength) {
  const named = outputByName(outputs, name);
  if (named && named.length >= minLength) return named;
  for (const output of Object.values(outputs)) {
    if (output && output.data && output.data.length >= minLength) {
      return output.data;
    }
  }
  throw new Error(`katago_worker_missing_${name}_output`);
}

function rankPolicyCandidates({
  policy,
  legalMoves,
  boardPointCount,
  candidateLimit,
  policyPlane,
}) {
  const stride = boardPointCount + 1;
  const offset = policyPlane * stride;
  const scored = [];
  for (const move of legalMoves) {
    const score = Number(policy[offset + move]);
    if (Number.isFinite(score)) scored.push({ move, score });
  }
  scored.sort((a, b) => b.score - a.score);
  const shortlist = scored.slice(0, Math.max(1, Math.min(candidateLimit, scored.length)));
  const probabilities = softmax(shortlist.map((entry) => entry.score));
  return shortlist.map((entry, index) => ({
    move: entry.move,
    score: entry.score,
    probability: probabilities[index],
    rank: index + 1,
  }));
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
  for (let i = 0; i < probs.length; i++) {
    mean += probs[i] * (i - mid + 0.5);
  }
  let variance = 0;
  for (let i = 0; i < probs.length; i++) {
    const score = i - mid + 0.5;
    const delta = score - mean;
    variance += probs[i] * delta * delta;
  }
  return { mean, stdev: Math.sqrt(Math.max(0, variance)) };
}

function explanationSignals({ candidate, strategyLabel, scoreBelief }) {
  const signals = [
    `${strategyLabel}第 ${candidate.rank} 選`,
    `策略偏好 ${Math.round(candidate.probability * 100)}%`,
  ];
  if (scoreBelief) {
    const sign = scoreBelief.mean >= 0 ? '+' : '';
    signals.push(`模型目差 ${sign}${scoreBelief.mean.toFixed(1)}`);
  }
  return signals;
}

function softmax(values) {
  if (!values.length) return [];
  const max = values.reduce((a, b) => Math.max(a, b), values[0]);
  const weights = values.map((value) => Math.exp(value - max));
  const total = weights.reduce((a, b) => a + b, 0);
  return total > 0 ? weights.map((value) => value / total) : values.map(() => 0);
}

function applyMove({ boardSize, cells, currentPlayer, move }) {
  const next = cells.slice();
  const opponent = currentPlayer === BLACK ? WHITE : BLACK;
  next[move] = currentPlayer;
  for (const adjacent of adjacentIndices(move, boardSize)) {
    if (next[adjacent] !== opponent) continue;
    const group = collectGroup(next, boardSize, adjacent);
    if (countLiberties(next, boardSize, group) === 0) {
      for (const stone of group) next[stone] = EMPTY;
    }
  }
  const ownGroup = collectGroup(next, boardSize, move);
  if (countLiberties(next, boardSize, ownGroup) === 0) {
    next[move] = EMPTY;
  }
  return {
    cells: next,
    currentPlayer: opponent,
  };
}

function legalMovesFor(cells) {
  const moves = [];
  for (let i = 0; i < cells.length; i++) {
    if (cells[i] === EMPTY) moves.push(i);
  }
  return moves;
}

function collectGroup(cells, size, start) {
  const color = cells[start];
  const seen = new Set([start]);
  const stack = [start];
  while (stack.length) {
    const current = stack.pop();
    for (const adjacent of adjacentIndices(current, size)) {
      if (cells[adjacent] !== color || seen.has(adjacent)) continue;
      seen.add(adjacent);
      stack.push(adjacent);
    }
  }
  return seen;
}

function countLiberties(cells, size, group) {
  const liberties = new Set();
  for (const stone of group) {
    for (const adjacent of adjacentIndices(stone, size)) {
      if (cells[adjacent] === EMPTY) liberties.add(adjacent);
    }
  }
  return liberties.size;
}

function adjacentIndices(index, size) {
  const row = Math.floor(index / size);
  const col = index % size;
  const result = [];
  if (row > 0) result.push(index - size);
  if (row < size - 1) result.push(index + size);
  if (col > 0) result.push(index - 1);
  if (col < size - 1) result.push(index + 1);
  return result;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
