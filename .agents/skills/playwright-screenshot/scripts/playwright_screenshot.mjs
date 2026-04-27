#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { PNG } = require('pngjs');

function resolvePlaywright() {
  const explicitModule = process.env.PLAYWRIGHT_MODULE_PATH;
  if (explicitModule) {
    return require(explicitModule);
  }

  for (const moduleName of ['playwright', 'playwright-core']) {
    try {
      return require(moduleName);
    } catch {}
  }

  throw new Error(
    'Playwright is not installed in this repo. Install `playwright` or `playwright-core` locally before using this skill.',
  );
}

function parseNumber(name, value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`Invalid ${name}: ${value}`);
  }
  return parsed;
}

function browserStartupHint(error) {
  const message = String(error?.message ?? error);
  if (
    process.platform === 'darwin' &&
    (
      message.includes('MachPortRendezvous') ||
      message.includes('bootstrap_check_in') ||
      message.includes('TransformProcessType') ||
      message.includes('_RegisterApplication')
    )
  ) {
    return (
      '\n\nDetected a macOS browser startup failure before page navigation. ' +
      'This is usually caused by the execution sandbox blocking Chromium app registration or Mach port bootstrap. ' +
      'Run the screenshot in a non-sandboxed runner, provide a CI/browser executable through CHROME_BIN or PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH, ' +
      'or connect to an already-running browser with PLAYWRIGHT_CDP_URL.'
    );
  }

  return '';
}

function analyzeScreenshot(buffer) {
  const png = PNG.sync.read(buffer);
  const bucketCounts = new Map();
  let sampleCount = 0;
  let luminanceSum = 0;
  let luminanceSquareSum = 0;
  let edgeHits = 0;
  let edgeChecks = 0;

  const bucketStep = 32;
  const stride = Math.max(1, Math.floor(Math.min(png.width, png.height) / 80));

  const luminanceAt = (x, y) => {
    const index = (png.width * y + x) << 2;
    const r = png.data[index];
    const g = png.data[index + 1];
    const b = png.data[index + 2];
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };

  for (let y = 0; y < png.height; y += stride) {
    for (let x = 0; x < png.width; x += stride) {
      const index = (png.width * y + x) << 2;
      const r = png.data[index];
      const g = png.data[index + 1];
      const b = png.data[index + 2];
      const bucketKey = [
        Math.floor(r / bucketStep),
        Math.floor(g / bucketStep),
        Math.floor(b / bucketStep),
      ].join(':');
      bucketCounts.set(bucketKey, (bucketCounts.get(bucketKey) ?? 0) + 1);

      const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      luminanceSum += luminance;
      luminanceSquareSum += luminance * luminance;
      sampleCount += 1;

      if (x + stride < png.width) {
        edgeChecks += 1;
        if (Math.abs(luminance - luminanceAt(x + stride, y)) > 12) {
          edgeHits += 1;
        }
      }
      if (y + stride < png.height) {
        edgeChecks += 1;
        if (Math.abs(luminance - luminanceAt(x, y + stride)) > 12) {
          edgeHits += 1;
        }
      }
    }
  }

  const dominantRatio = Math.max(...bucketCounts.values()) / sampleCount;
  const luminanceMean = luminanceSum / sampleCount;
  const luminanceVariance =
    luminanceSquareSum / sampleCount - luminanceMean * luminanceMean;
  const luminanceStdDev = Math.sqrt(Math.max(0, luminanceVariance));
  const edgeDensity = edgeChecks > 0 ? edgeHits / edgeChecks : 0;

  return {
    dominantRatio,
    luminanceStdDev,
    edgeDensity,
    isVisuallyReady:
      (dominantRatio < 0.9 && luminanceStdDev > 8 && edgeDensity > 0.012) ||
      (luminanceStdDev > 18 && edgeDensity > 0.03) ||
      (dominantRatio < 0.96 && luminanceStdDev > 15 && edgeDensity > 0.012),
  };
}

const [url, outputPath, widthArg, heightArg, dprArg, waitArg] = process.argv.slice(2);

if (!url || !outputPath) {
  process.stderr.write(
    'usage: playwright_screenshot.mjs <url> <outputPath> [width] [height] [deviceScaleFactor] [waitMs]\n' +
    '  Defaults: width=402 height=874 deviceScaleFactor=3 waitMs=12000\n'
  );
  process.exit(1);
}

const width = widthArg ? parseNumber('width', widthArg) : 402;
const height = heightArg ? parseNumber('height', heightArg) : 874;
const deviceScaleFactor = dprArg ? parseNumber('device scale factor', dprArg) : 3;
const waitMs = waitArg ? parseNumber('wait time', waitArg) : 12000;

const playwright = resolvePlaywright();
const cdpUrl = process.env.PLAYWRIGHT_CDP_URL;

function logStep(message) {
  const timestamp = new Date().toISOString();
  process.stderr.write(`[screenshot] ${timestamp} ${message}\n`);
}

const launchOptions = {
  headless: true,
};

const explicitBrowser = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH;
if (explicitBrowser) {
  launchOptions.executablePath = explicitBrowser;
}

if (process.platform === 'linux') {
  const args = [];
  if (process.env.CI === 'true') {
    args.push('--no-sandbox', '--disable-dev-shm-usage');
  }
  if (args.length > 0) {
    launchOptions.args = args;
  }
}

let browser;
let context;

try {
  try {
    logStep(cdpUrl ? `connect_over_cdp ${cdpUrl}` : 'launch_browser');
    browser = cdpUrl
      ? await playwright.chromium.connectOverCDP(cdpUrl)
      : await playwright.chromium.launch(launchOptions);
  } catch (error) {
    throw new Error(`${error.message}${browserStartupHint(error)}`);
  }

  logStep('new_context');
  context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor,
  });
  const page = await context.newPage();

  try {
    logStep('goto networkidle');
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  } catch {
    logStep('goto networkidle failed; retry domcontentloaded');
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  }
  logStep('goto complete');

  const startedAt = Date.now();
  const deadline = startedAt + waitMs;
  let acceptedBuffer = null;
  let lastBuffer = null;
  let lastMetrics = null;
  const diagnostics = [];

  page.on('console', (message) => {
    diagnostics.push(`[console:${message.type()}] ${message.text()}`);
  });
  page.on('pageerror', (error) => {
    diagnostics.push(`[pageerror] ${error.stack || error.message}`);
  });
  page.on('requestfailed', (request) => {
    diagnostics.push(
      `[requestfailed] ${request.url()} ${request.failure()?.errorText ?? ''}`,
    );
  });

  while (Date.now() <= deadline) {
    await page.waitForTimeout(700);
    const buffer = await page.screenshot({
      fullPage: false,
      animations: 'disabled',
    });
    const metrics = analyzeScreenshot(buffer);
    lastBuffer = buffer;
    lastMetrics = metrics;
    logStep(
      `sample dominantRatio=${metrics.dominantRatio.toFixed(3)} luminanceStdDev=${metrics.luminanceStdDev.toFixed(3)} edgeDensity=${metrics.edgeDensity.toFixed(3)}`,
    );
    if (metrics.isVisuallyReady) {
      acceptedBuffer = buffer;
      break;
    }
  }

  if (!acceptedBuffer) {
    const domSnapshot = await page.evaluate(() => {
      const selectors = [
        'flt-glass-pane',
        'flutter-view',
        'canvas',
        'flt-scene-host',
        'flt-semantics-host',
        'script',
      ];
      const counts = Object.fromEntries(
        selectors.map((selector) => [
          selector,
          document.querySelectorAll(selector).length,
        ]),
      );
      return {
        href: window.location.href,
        readyState: document.readyState,
        title: document.title,
        bodyText: document.body?.innerText?.slice(0, 1200) ?? '',
        bodyChildren: document.body?.children.length ?? 0,
        counts,
        bodyHtml: document.body?.outerHTML?.slice(0, 2000) ?? '',
      };
    }).catch((error) => ({ error: String(error?.message ?? error) }));
    const timeoutImagePath = `${outputPath}.notready.png`;
    const timeoutLogPath = `${outputPath}.notready.txt`;
    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    if (lastBuffer) {
      await fs.writeFile(timeoutImagePath, lastBuffer);
    }
    await fs.writeFile(
      timeoutLogPath,
      [
        `url=${url}`,
        `output_path=${outputPath}`,
        `timeout_image_path=${lastBuffer ? timeoutImagePath : ''}`,
        `dominantRatio=${lastMetrics?.dominantRatio?.toFixed(3) ?? 'n/a'}`,
        `luminanceStdDev=${lastMetrics?.luminanceStdDev?.toFixed(3) ?? 'n/a'}`,
        `edgeDensity=${lastMetrics?.edgeDensity?.toFixed(3) ?? 'n/a'}`,
        '',
        '[dom]',
        JSON.stringify(domSnapshot, null, 2),
        '',
        '[events]',
        ...diagnostics,
      ].join('\n'),
    );
    throw new Error(
      `Screenshot did not reach a visually ready state before timeout. dominantRatio=${lastMetrics?.dominantRatio?.toFixed(3) ?? 'n/a'}, luminanceStdDev=${lastMetrics?.luminanceStdDev?.toFixed(3) ?? 'n/a'}, edgeDensity=${lastMetrics?.edgeDensity?.toFixed(3) ?? 'n/a'}. Saved diagnostics to ${timeoutLogPath}`,
    );
  }

  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, acceptedBuffer);
  logStep(`saved ${outputPath}`);
} finally {
  logStep('close_browser');
  await context?.close().catch(() => {});
  await browser?.close().catch(() => {});
}
