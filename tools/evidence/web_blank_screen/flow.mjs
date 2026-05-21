import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright-core';
import { PNG } from 'pngjs';

const [url, outDir, runId, requestedBrowserPath] = process.argv.slice(2);
const screenshotPath = path.join(outDir, `${runId}-page.png`);
const eventsPath = path.join(outDir, 'browser-events.json');
const summaryPath = path.join(outDir, 'summary.json');

const events = [];
const checkpoints = {};

function record(type, payload) {
  events.push({ ts: new Date().toISOString(), type, payload });
}

function setCheckpoint(name, pass, details = {}) {
  checkpoints[name] = { pass, ...details };
}

function browserPathCandidates() {
  switch (process.platform) {
    case 'darwin':
      return [
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
      ];
    case 'linux':
      return [
        '/usr/bin/google-chrome',
        '/usr/bin/google-chrome-stable',
        '/usr/bin/chromium',
        '/usr/bin/chromium-browser',
      ];
    case 'win32':
      return [
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files\\Chromium\\Application\\chrome.exe',
      ];
    default:
      return [];
  }
}

function resolveExecutablePath() {
  const overrides = [
    requestedBrowserPath,
    process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
    process.env.CHROME_PATH,
    process.env.CHROMIUM_PATH,
  ].filter(Boolean);
  for (const candidate of [...overrides, ...browserPathCandidates()]) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

function countNonBackgroundPixels(png, bg = [249, 244, 236]) {
  let different = 0;
  const total = png.width * png.height;
  for (let i = 0; i < png.data.length; i += 4) {
    const dr = Math.abs(png.data[i] - bg[0]);
    const dg = Math.abs(png.data[i + 1] - bg[1]);
    const db = Math.abs(png.data[i + 2] - bg[2]);
    const alpha = png.data[i + 3];
    if (alpha > 0 && dr + dg + db > 18) different++;
  }
  return { different, total, ratio: different / total };
}

fs.mkdirSync(outDir, { recursive: true });

const executablePath = resolveExecutablePath();
if (!executablePath && requestedBrowserPath) {
  record('browserExecutableMissing', { requestedBrowserPath });
}

const browser = await chromium.launch({
  ...(executablePath ? { executablePath } : {}),
  headless: true,
  args: ['--disable-gpu'],
});

const page = await browser.newPage({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
});

page.on('console', (msg) => {
  record('console', {
    type: msg.type(),
    text: msg.text(),
    location: msg.location(),
  });
});
page.on('pageerror', (error) => {
  record('pageerror', { message: error.message, stack: error.stack });
});
page.on('requestfailed', (request) => {
  record('requestfailed', {
    url: request.url(),
    method: request.method(),
    failure: request.failure(),
  });
});
page.on('response', (response) => {
  if (response.status() >= 400) {
    record('badresponse', { url: response.url(), status: response.status() });
  }
});

let pageReachable = false;
try {
  const response = await page.goto(url, {
    waitUntil: 'domcontentloaded',
    timeout: 30000,
  });
  pageReachable = Boolean(response && response.ok());
  setCheckpoint('pageReachable', pageReachable, {
    status: response?.status() ?? null,
  });
  await page.waitForTimeout(12000);
} catch (error) {
  setCheckpoint('pageReachable', false, { error: String(error) });
}

const domState = await page.evaluate(() => {
  const text = document.body?.innerText?.trim() ?? '';
  const hostCount = document.querySelectorAll(
    'flutter-view, flt-glass-pane, flt-scene-host, canvas',
  ).length;
  const scripts = [...document.scripts].map((script) => ({
    src: script.src,
    textPrefix: script.src ? '' : script.textContent?.slice(0, 80) ?? '',
  }));
  return {
    title: document.title,
    bodyText: text.slice(0, 500),
    bodyTextLength: text.length,
    bodyHtmlLength: document.body?.innerHTML?.length ?? 0,
    hostCount,
    scripts,
    flutterLoader: Boolean(window._flutter?.loader),
  };
});

await page.screenshot({ path: screenshotPath, fullPage: false });
await browser.close();

const png = PNG.sync.read(fs.readFileSync(screenshotPath));
const pixelStats = countNonBackgroundPixels(png);

const severeEvents = events.filter((event) => {
  if (event.type === 'pageerror' || event.type === 'requestfailed') return true;
  if (event.type === 'console' && event.payload.type === 'error') return true;
  return false;
});

setCheckpoint('noSevereConsoleErrors', severeEvents.length === 0, {
  count: severeEvents.length,
});
setCheckpoint('flutterHostPresent', domState.hostCount > 0, {
  hostCount: domState.hostCount,
});
setCheckpoint('nonBackgroundPixels', pixelStats.ratio > 0.02, pixelStats);
setCheckpoint(
  'renderedFlutterSurface',
  domState.hostCount > 0 && pixelStats.ratio > 0.02,
  {
    hostCount: domState.hostCount,
    nonBackgroundRatio: pixelStats.ratio,
    note: 'CanvasKit text is painted into canvas, not DOM text.',
  },
);

fs.writeFileSync(eventsPath, JSON.stringify(events, null, 2));
fs.writeFileSync(summaryPath, JSON.stringify({
  runId,
  caseName: 'web_blank_screen',
  url,
  browserExecutablePath: executablePath,
  browserLaunchMode: executablePath ? 'explicit' : 'playwright-default',
  evidenceDir: outDir,
  screenshotPath,
  eventsPath,
  checkpoints,
  domState,
  pixelStats,
}, null, 2));
