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
  throw new Error('Expected url and output path arguments.');
}

const width = parseNumber('width', widthArg);
const height = parseNumber('height', heightArg);
const deviceScaleFactor = parseNumber('device scale factor', dprArg);
const waitMs = parseNumber('wait time', waitArg);

const playwright = resolvePlaywright();

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

const browser = await playwright.chromium.launch(launchOptions);

try {
  const page = await browser.newPage({
    viewport: { width, height },
    deviceScaleFactor,
  });

  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  } catch {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  }

  const startedAt = Date.now();
  const deadline = startedAt + waitMs;
  let acceptedBuffer = null;
  let lastMetrics = null;

  while (Date.now() <= deadline) {
    await page.waitForTimeout(700);
    const buffer = await page.screenshot({
      fullPage: false,
      animations: 'disabled',
    });
    const metrics = analyzeScreenshot(buffer);
    lastMetrics = metrics;
    if (metrics.isVisuallyReady) {
      acceptedBuffer = buffer;
      break;
    }
  }

  if (!acceptedBuffer) {
    throw new Error(
      `Screenshot did not reach a visually ready state before timeout. dominantRatio=${lastMetrics?.dominantRatio?.toFixed(3) ?? 'n/a'}, luminanceStdDev=${lastMetrics?.luminanceStdDev?.toFixed(3) ?? 'n/a'}, edgeDensity=${lastMetrics?.edgeDensity?.toFixed(3) ?? 'n/a'}`,
    );
  }

  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, acceptedBuffer);
} finally {
  await browser.close();
}
