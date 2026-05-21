const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright-core');

const baseUrl = process.env.FULL_MATRIX_PROBE_URL || 'http://127.0.0.1:8092/';
const outPath =
  process.env.FULL_MATRIX_PROBE_OUT ||
  'docs/ai_eval/runs/2026-05-19-flutter-full-matrix-arena-probe.json';
const shardDir =
  process.env.FULL_MATRIX_PROBE_SHARD_DIR ||
  'docs/ai_eval/runs/2026-05-19-flutter-full-matrix-shards';
const chromePath =
  process.env.CHROME_PATH ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const totalCells = Number(process.env.FULL_MATRIX_TOTAL_CELLS || 168);
const shardSize = Number(process.env.FULL_MATRIX_SHARD_SIZE || 21);
const startCell = Number(process.env.FULL_MATRIX_START_CELL || 0);
const endCell = Number(process.env.FULL_MATRIX_END_CELL || totalCells);
const mergeExisting = process.env.FULL_MATRIX_MERGE_EXISTING === '1';

(async () => {
  fs.mkdirSync(shardDir, { recursive: true });
  fs.mkdirSync(path.dirname(outPath), { recursive: true });

  const shardsByPath = mergeExisting ? loadExistingShards(shardDir) : new Map();
  for (let start = startCell; start < endCell; start += shardSize) {
    const end = Math.min(endCell, start + shardSize);
    const shard = await runShard(start, end);
    const shardPath = path.join(
      shardDir,
      `${String(start).padStart(3, '0')}-${String(end).padStart(3, '0')}.json`,
    );
    fs.writeFileSync(shardPath, JSON.stringify(shard, null, 2));
    console.log(`WROTE ${shardPath}`);
    shardsByPath.set(shardPath, shard);
  }

  const shards = [...shardsByPath.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([, shard]) => shard);
  const merged = mergeShards(shards);
  validateMerged(merged);
  fs.writeFileSync(outPath, JSON.stringify(merged, null, 2));
  console.log(`WROTE ${outPath}`);
})();

function loadExistingShards(directory) {
  const shards = new Map();
  if (!fs.existsSync(directory)) return shards;
  for (const name of fs.readdirSync(directory)) {
    if (!/^\d{3}-\d{3}\.json$/.test(name)) continue;
    const shardPath = path.join(directory, name);
    shards.set(shardPath, JSON.parse(fs.readFileSync(shardPath, 'utf8')));
  }
  return shards;
}

async function runShard(startCell, endCell) {
  const browser = await chromium.launch({
    executablePath: chromePath,
    headless: true,
  });
  try {
    const page = await browser.newPage();
    let collecting = false;
    const lines = [];
    let resolveOutput;
    let rejectOutput;
    const output = new Promise((resolve, reject) => {
      resolveOutput = resolve;
      rejectOutput = reject;
    });
    const timeout = setTimeout(() => {
      rejectOutput(new Error(`Timed out waiting for shard ${startCell}-${endCell}`));
    }, 900000);

    page.on('console', (msg) => {
      const text = msg.text();
      if (text === 'FULL_MATRIX_ARENA_PROBE_JSON_BEGIN') {
        collecting = true;
        return;
      }
      if (text === 'FULL_MATRIX_ARENA_PROBE_JSON_END') {
        collecting = false;
        clearTimeout(timeout);
        resolveOutput();
        return;
      }
      if (collecting) lines.push(text);
    });

    page.on('pageerror', (error) => {
      console.error(`[pageerror] ${error.message}`);
    });

    const url = new URL(baseUrl);
    url.searchParams.set('startCell', String(startCell));
    url.searchParams.set('endCell', String(endCell));
    await page.goto(url.toString(), { waitUntil: 'load', timeout: 30000 });
    await output;
    if (lines.length === 0) {
      throw new Error(`No JSON output for shard ${startCell}-${endCell}`);
    }
    const json = JSON.parse(lines.join('\n'));
    if (json.status === 'failed') {
      throw new Error(`Shard ${startCell}-${endCell} failed: ${json.failureReason}`);
    }
    return json;
  } finally {
    await browser.close();
  }
}

function mergeShards(shards) {
  const metadata = { ...shards[0].metadata };
  const cells = shards.flatMap((shard) => shard.matrixCells);
  cells.sort((a, b) => a.index - b.index);
  metadata.startCell = 0;
  metadata.endCell = metadata.totalCells;
  metadata.selectedCells = cells.length;
  metadata.expectedGames = metadata.totalExpectedGames;
  metadata.actualGames = cells.reduce((sum, cell) => sum + cell.games.length, 0);

  return {
    metadata,
    matrixCells: cells,
    pairwiseOverall: pairwiseOverall(cells),
    perOpeningPerformance: perOpeningPerformance(cells),
    perFirstPlayerPerformance: perFirstPlayerPerformance(cells),
    rankings: rankings(cells),
    validation: validation(cells, metadata),
  };
}

function pairwiseOverall(cells) {
  const scores = new Map();
  for (const cell of cells) {
    const score = getScore(scores, cell.pairId);
    addPair(score, cell);
  }
  return [...scores.values()].map(pairJson).sort((a, b) => a.pairId.localeCompare(b.pairId));
}

function perOpeningPerformance(cells) {
  const scores = new Map();
  for (const cell of cells) {
    for (const id of [cell.firstConfigId, cell.secondConfigId]) {
      const key = `${cell.opening}::${id}`;
      const score = getScore(scores, key, { opening: cell.opening, configId: id });
      addPerspective(score, cell, id);
    }
  }
  return [...scores.values()].map(genericJson).sort((a, b) => {
    const opening = a.opening.localeCompare(b.opening);
    return opening || a.configId.localeCompare(b.configId);
  });
}

function perFirstPlayerPerformance(cells) {
  const scores = new Map();
  for (const cell of cells) {
    const score = getScore(scores, cell.firstConfigId, { firstConfigId: cell.firstConfigId });
    score.wins += cell.firstWins;
    score.losses += cell.secondWins;
    score.draws += cell.draws;
    addStatus(score, cell);
  }
  return [...scores.values()].map(genericJson).sort((a, b) => a.firstConfigId.localeCompare(b.firstConfigId));
}

function rankings(cells) {
  const scores = new Map();
  for (const cell of cells) {
    for (const id of [cell.firstConfigId, cell.secondConfigId]) {
      const score = getScore(scores, id, { configId: id });
      addPerspective(score, cell, id);
      const ownWins = id === cell.firstConfigId ? cell.firstWins : cell.secondWins;
      const otherWins = id === cell.firstConfigId ? cell.secondWins : cell.firstWins;
      if (ownWins > otherWins) score.matchWins += 1;
      else if (ownWins < otherWins) score.matchLosses += 1;
      else score.matchDraws += 1;
    }
  }
  return [...scores.values()]
    .sort((a, b) =>
      b.matchWins - a.matchWins ||
      rate(b.wins, b.losses, b.draws) - rate(a.wins, a.losses, a.draws) ||
      b.wins - a.wins ||
      a.configId.localeCompare(b.configId),
    )
    .map((score, index) => ({
      rank: index + 1,
      configId: score.configId,
      matchWins: score.matchWins,
      matchLosses: score.matchLosses,
      matchDraws: score.matchDraws,
      matchWinRate: rate(score.matchWins, score.matchLosses, score.matchDraws),
      gameWins: score.wins,
      gameLosses: score.losses,
      draws: score.draws,
      games: score.wins + score.losses + score.draws,
      gameWinRate: rate(score.wins, score.losses, score.draws),
      illegalMoves: score.illegalMoves,
      timeouts: score.timeouts,
      fallbackGames: score.fallbackGames,
    }));
}

function validation(cells, metadata) {
  const games = cells.reduce((sum, cell) => sum + cell.games.length, 0);
  const dimensions = new Map();
  for (const cell of cells) {
    const key = `${cell.pairId}::${cell.opening}::${cell.firstConfigId}`;
    dimensions.set(key, (dimensions.get(key) || 0) + cell.games.length);
  }
  const pairwise = pairwiseOverall(cells);
  return {
    cells: cells.length,
    expectedCells: metadata.totalCells,
    games,
    expectedGames: metadata.totalExpectedGames,
    randomGames: cells.flatMap((cell) => cell.games).filter((game) => game.opening === 'random').length,
    illegalMoves: pairwise.reduce((sum, item) => sum + item.illegalMoves, 0),
    timeouts: pairwise.reduce((sum, item) => sum + item.timeouts, 0),
    fallbackGames: pairwise.reduce((sum, item) => sum + item.fallbackGames, 0),
    failureReasons: pairwise.reduce((sum, item) => sum + item.failureReasons.length, 0),
    badRepeatCells: cells.filter((cell) => cell.repeats !== 2 || cell.games.length !== 2).length,
    dimensionCells: dimensions.size,
    badDimensionCells: [...dimensions.values()].filter((count) => count !== 2).length,
  };
}

function validateMerged(merged) {
  const v = merged.validation;
  const failures = [];
  if (v.cells !== v.expectedCells) failures.push(`cells ${v.cells} != ${v.expectedCells}`);
  if (v.games !== v.expectedGames) failures.push(`games ${v.games} != ${v.expectedGames}`);
  if (v.randomGames !== 0) failures.push(`randomGames ${v.randomGames}`);
  if (v.illegalMoves !== 0) failures.push(`illegalMoves ${v.illegalMoves}`);
  if (v.fallbackGames !== 0) failures.push(`fallbackGames ${v.fallbackGames}`);
  if (v.failureReasons !== 0) failures.push(`failureReasons ${v.failureReasons}`);
  if (v.badRepeatCells !== 0) failures.push(`badRepeatCells ${v.badRepeatCells}`);
  if (v.badDimensionCells !== 0) failures.push(`badDimensionCells ${v.badDimensionCells}`);
  if (failures.length) throw new Error(`Merged artifact failed validation: ${failures.join(', ')}`);
}

function getScore(map, key, extra = {}) {
  if (!map.has(key)) {
    map.set(key, {
      key,
      ...extra,
      configWins: new Map(),
      configLosses: new Map(),
      wins: 0,
      losses: 0,
      draws: 0,
      matchWins: 0,
      matchLosses: 0,
      matchDraws: 0,
      illegalMoves: 0,
      timeouts: 0,
      fallbackGames: 0,
      failureReasons: new Set(),
    });
  }
  return map.get(key);
}

function addPair(score, cell) {
  inc(score.configWins, cell.firstConfigId, cell.firstWins);
  inc(score.configLosses, cell.firstConfigId, cell.secondWins);
  inc(score.configWins, cell.secondConfigId, cell.secondWins);
  inc(score.configLosses, cell.secondConfigId, cell.firstWins);
  score.draws += cell.draws;
  addStatus(score, cell);
}

function addPerspective(score, cell, configId) {
  const isFirst = configId === cell.firstConfigId;
  score.wins += isFirst ? cell.firstWins : cell.secondWins;
  score.losses += isFirst ? cell.secondWins : cell.firstWins;
  score.draws += cell.draws;
  addStatus(score, cell);
}

function addStatus(score, cell) {
  score.illegalMoves += cell.illegalMoves;
  score.timeouts += cell.timeouts;
  score.fallbackGames += cell.fallbackGames;
  for (const reason of cell.failureReasons) score.failureReasons.add(reason);
}

function pairJson(score) {
  const ids = score.key.split('::');
  const aWins = score.configWins.get(ids[0]) || 0;
  const aLosses = score.configLosses.get(ids[0]) || 0;
  const bWins = score.configWins.get(ids[1]) || 0;
  const bLosses = score.configLosses.get(ids[1]) || 0;
  return {
    pairId: score.key,
    configAId: ids[0],
    configBId: ids[1],
    configAWins: aWins,
    configALosses: aLosses,
    configAWinRate: rate(aWins, aLosses, score.draws),
    configBWins: bWins,
    configBLosses: bLosses,
    configBWinRate: rate(bWins, bLosses, score.draws),
    draws: score.draws,
    games: aWins + aLosses + score.draws,
    illegalMoves: score.illegalMoves,
    timeouts: score.timeouts,
    fallbackGames: score.fallbackGames,
    failureReasons: [...score.failureReasons].sort(),
  };
}

function genericJson(score) {
  return {
    ...(score.configId ? { configId: score.configId } : {}),
    ...(score.opening ? { opening: score.opening } : {}),
    ...(score.firstConfigId ? { firstConfigId: score.firstConfigId } : {}),
    wins: score.wins,
    losses: score.losses,
    draws: score.draws,
    games: score.wins + score.losses + score.draws,
    winRate: rate(score.wins, score.losses, score.draws),
    illegalMoves: score.illegalMoves,
    timeouts: score.timeouts,
    fallbackGames: score.fallbackGames,
    failureReasons: [...score.failureReasons].sort(),
  };
}

function inc(map, key, value) {
  map.set(key, (map.get(key) || 0) + value);
}

function rate(wins, losses, draws) {
  const games = wins + losses + draws;
  return games === 0 ? 0 : wins / games;
}
