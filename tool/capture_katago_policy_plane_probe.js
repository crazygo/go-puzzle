const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright-core');

const baseUrl =
  process.env.KATAGO_POLICY_PLANE_PROBE_URL || 'http://127.0.0.1:8093/';
const outPath =
  process.env.KATAGO_POLICY_PLANE_PROBE_OUT ||
  'docs/ai_eval/runs/2026-05-19-katago-policy-plane-probe.json';
const chromePath =
  process.env.CHROME_PATH ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

(async () => {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });

  const browser = await chromium.launch({
    executablePath: chromePath,
    headless: true,
  });
  try {
    const page = await browser.newPage();
    const json = await captureJson(page);
    validate(json);
    fs.writeFileSync(outPath, JSON.stringify(json, null, 2));
    console.log(`WROTE ${outPath}`);
    for (const plane of json.planes) {
      console.log(
        [
          `plane=${plane.policyPlane}`,
          `katago=${plane.katagoWins}`,
          `mctsWeak=${plane.mctsWeakWins}`,
          `draws=${plane.draws}`,
          `illegal=${plane.illegalMoves}`,
          `timeouts=${plane.timeouts}`,
          `fallback=${plane.fallbackGames}`,
          `failures=${plane.failureReasons.length}`,
        ].join(' '),
      );
    }
  } finally {
    await browser.close();
  }
})();

async function captureJson(page) {
  let collecting = false;
  const lines = [];
  let resolveOutput;
  let rejectOutput;
  const output = new Promise((resolve, reject) => {
    resolveOutput = resolve;
    rejectOutput = reject;
  });
  const timeout = setTimeout(() => {
    rejectOutput(new Error('Timed out waiting for policy-plane probe output'));
  }, 900000);

  page.on('console', (msg) => {
    const text = msg.text();
    if (text === 'KATAGO_POLICY_PLANE_PROBE_JSON_BEGIN') {
      collecting = true;
      return;
    }
    if (text === 'KATAGO_POLICY_PLANE_PROBE_JSON_END') {
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

  await page.goto(baseUrl, { waitUntil: 'load', timeout: 30000 });
  await output;
  if (lines.length === 0) throw new Error('No policy-plane JSON output');
  const json = JSON.parse(lines.join('\n'));
  if (json.status === 'failed') {
    throw new Error(`Policy-plane probe failed: ${json.failureReason}`);
  }
  return json;
}

function validate(json) {
  const failures = [];
  if (!Array.isArray(json.planes) || json.planes.length !== 6) {
    failures.push(`planes=${json.planes && json.planes.length}`);
  }
  for (const plane of json.planes || []) {
    const games = plane.katagoWins + plane.mctsWeakWins + plane.draws;
    if (games !== 12) failures.push(`plane ${plane.policyPlane} games=${games}`);
    if (plane.illegalMoves !== 0) {
      failures.push(`plane ${plane.policyPlane} illegal=${plane.illegalMoves}`);
    }
    if (plane.timeouts !== 0) {
      failures.push(`plane ${plane.policyPlane} timeouts=${plane.timeouts}`);
    }
    if (plane.fallbackGames !== 0) {
      failures.push(`plane ${plane.policyPlane} fallback=${plane.fallbackGames}`);
    }
  }
  if (failures.length) {
    throw new Error(`Policy-plane artifact failed validation: ${failures.join(', ')}`);
  }
}
