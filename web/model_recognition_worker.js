/* global ort */

const ORT_VERSION = '1.22.0';
const ORT_BASE = `https://cdn.jsdelivr.net/npm/onnxruntime-web@${ORT_VERSION}/dist/`;
const BOARD_MODEL_URL = './recognition_models/go_board_pose_yolov8n.onnx';
const STONES_MODEL_URL = './recognition_models/go_stones_yolov8n.onnx';

const INPUT_SIZE = 640;
const BOARD_CONFIDENCE = 0.01;
const STONE_CONFIDENCE = 0.25;
const STONE_IOU = 0.7;
const MAX_STONE_DISTANCE_RATIO = 0.58;
const BOARD_SIZE_BY_CLASS = [9, 13, 19];
const STONE_COLOR_BY_CLASS = [1, 2]; // StoneColor.black / StoneColor.white

let ortReady = false;
let boardSession = null;
let stonesSession = null;

self.onmessage = async (event) => {
  const data = event.data || {};
  const requestId = data.requestId;
  try {
    if (data.type === 'load') {
      await ensureLoaded();
      self.postMessage({ type: 'loaded', requestId });
      return;
    }

    if (data.type === 'recognize') {
      await ensureLoaded();
      const result = await recognize(data.bytes);
      self.postMessage({ type: 'recognized', requestId, ...result });
      return;
    }

    self.postMessage({ requestId, error: `Unknown request type: ${data.type}` });
  } catch (error) {
    self.postMessage({ requestId, error: String(error && error.message ? error.message : error) });
  }
};

async function ensureLoaded() {
  if (boardSession && stonesSession) return;
  if (!ortReady) {
    importScripts(`${ORT_BASE}ort.min.js`);
    ort.env.wasm.wasmPaths = ORT_BASE;
    ortReady = true;
  }
  const options = { executionProviders: ['wasm'] };
  boardSession = await ort.InferenceSession.create(BOARD_MODEL_URL, options);
  stonesSession = await ort.InferenceSession.create(STONES_MODEL_URL, options);
}

async function recognize(bytes) {
  const image = await decodeImage(bytes);
  const input = preprocess(image);
  const tensor = new ort.Tensor('float32', input.tensor, [1, 3, INPUT_SIZE, INPUT_SIZE]);

  const boardOutput = await runSession(boardSession, tensor);
  const roughPose = extractPose(boardOutput, input);
  if (!roughPose) throw new Error('未能辨識棋盤邊界');

  const refinedPose = refineBoardPose(image, roughPose);
  const stonesOutput = await runSession(stonesSession, tensor);
  const detections = extractStoneDetections(stonesOutput, input);
  const board = stonesToBoard(detections, refinedPose);

  return {
    boardSize: refinedPose.boardSize,
    board,
    confidence: roughPose.confidence,
  };
}

async function decodeImage(bytes) {
  const blob = new Blob([bytes]);
  const bitmap = await createImageBitmap(blob);
  return bitmap;
}

async function runSession(session, tensor) {
  const inputName = session.inputNames && session.inputNames.length ? session.inputNames[0] : 'images';
  const outputName = session.outputNames && session.outputNames.length ? session.outputNames[0] : 'output0';
  const outputs = await session.run({ [inputName]: tensor });
  return outputs[outputName].data;
}

function preprocess(image) {
  const scale = Math.min(INPUT_SIZE / image.width, INPUT_SIZE / image.height);
  const resizedWidth = Math.max(1, Math.min(INPUT_SIZE, Math.round(image.width * scale)));
  const resizedHeight = Math.max(1, Math.min(INPUT_SIZE, Math.round(image.height * scale)));
  const padX = Math.round((INPUT_SIZE - resizedWidth) / 2);
  const padY = Math.round((INPUT_SIZE - resizedHeight) / 2);

  const canvas = new OffscreenCanvas(INPUT_SIZE, INPUT_SIZE);
  const context = canvas.getContext('2d', { willReadFrequently: true });
  context.fillStyle = 'rgb(114,114,114)';
  context.fillRect(0, 0, INPUT_SIZE, INPUT_SIZE);
  context.drawImage(image, padX, padY, resizedWidth, resizedHeight);
  const pixels = context.getImageData(0, 0, INPUT_SIZE, INPUT_SIZE).data;

  const channelSize = INPUT_SIZE * INPUT_SIZE;
  const tensor = new Float32Array(channelSize * 3);
  for (let i = 0, p = 0; i < channelSize; i++, p += 4) {
    tensor[i] = pixels[p] / 255;
    tensor[channelSize + i] = pixels[p + 1] / 255;
    tensor[channelSize * 2 + i] = pixels[p + 2] / 255;
  }
  return {
    tensor,
    originalWidth: image.width,
    originalHeight: image.height,
    scale,
    padX,
    padY,
    luma: buildLumaIntegral(context.getImageData(0, 0, INPUT_SIZE, INPUT_SIZE), image, scale, padX, padY),
  };
}

function toOriginalPoint(input, x, y) {
  return {
    x: clamp((x - input.padX) / input.scale, 0, input.originalWidth),
    y: clamp((y - input.padY) / input.scale, 0, input.originalHeight),
  };
}

function toOriginalBox(input, cx, cy, w, h) {
  return {
    x1: clamp((cx - w / 2 - input.padX) / input.scale, 0, input.originalWidth),
    y1: clamp((cy - h / 2 - input.padY) / input.scale, 0, input.originalHeight),
    x2: clamp((cx + w / 2 - input.padX) / input.scale, 0, input.originalWidth),
    y2: clamp((cy + h / 2 - input.padY) / input.scale, 0, input.originalHeight),
  };
}

function extractPose(output, input) {
  const anchors = 8400;
  let best = null;
  for (let anchor = 0; anchor < anchors; anchor++) {
    let bestClass = 0;
    let bestScore = output[4 * anchors + anchor];
    for (let classId = 1; classId < 3; classId++) {
      const score = output[(4 + classId) * anchors + anchor];
      if (score > bestScore) {
        bestClass = classId;
        bestScore = score;
      }
    }
    if (bestScore < BOARD_CONFIDENCE) continue;

    const cx = output[anchor];
    const cy = output[anchors + anchor];
    const w = output[2 * anchors + anchor];
    const h = output[3 * anchors + anchor];
    const corners = [];
    let keypointConfidence = 0;
    for (let i = 0; i < 4; i++) {
      const base = 7 + i * 3;
      corners.push(toOriginalPoint(input, output[base * anchors + anchor], output[(base + 1) * anchors + anchor]));
      keypointConfidence += output[(base + 2) * anchors + anchor];
    }
    keypointConfidence /= 4;
    const score = bestScore * Math.max(0.25, keypointConfidence);
    const candidate = {
      boardSize: BOARD_SIZE_BY_CLASS[bestClass],
      corners,
      confidence: bestScore,
      score,
      box: toOriginalBox(input, cx, cy, w, h),
    };
    if (!best || candidate.score > best.score) best = candidate;
  }
  return best;
}

function extractStoneDetections(output, input) {
  const anchors = 8400;
  const candidates = [];
  for (let anchor = 0; anchor < anchors; anchor++) {
    const blackScore = output[4 * anchors + anchor];
    const whiteScore = output[5 * anchors + anchor];
    const isBlack = blackScore >= whiteScore;
    const confidence = isBlack ? blackScore : whiteScore;
    if (confidence < STONE_CONFIDENCE) continue;
    candidates.push({
      box: toOriginalBox(input, output[anchor], output[anchors + anchor], output[2 * anchors + anchor], output[3 * anchors + anchor]),
      color: isBlack ? STONE_COLOR_BY_CLASS[0] : STONE_COLOR_BY_CLASS[1],
      confidence,
    });
  }
  candidates.sort((a, b) => b.confidence - a.confidence);
  const kept = [];
  for (const candidate of candidates) {
    if (!kept.some((existing) => existing.color === candidate.color && boxIou(existing.box, candidate.box) > STONE_IOU)) {
      kept.push(candidate);
    }
  }
  return kept;
}

function stonesToBoard(detections, pose) {
  const board = Array.from({ length: pose.boardSize }, () => Array(pose.boardSize).fill(0));
  const confidence = Array.from({ length: pose.boardSize }, () => Array(pose.boardSize).fill(-1));
  const step = averageGridStep(pose);
  for (const detection of detections) {
    const center = boxCenter(detection.box);
    const nearest = nearestIntersection(center.x, center.y, pose);
    if (nearest.distance / Math.max(1, step) > MAX_STONE_DISTANCE_RATIO) continue;
    if (detection.confidence > confidence[nearest.row][nearest.col]) {
      board[nearest.row][nearest.col] = detection.color;
      confidence[nearest.row][nearest.col] = detection.confidence;
    }
  }
  return board;
}

function buildLumaIntegral(imageData, originalImage, scale, padX, padY) {
  const width = originalImage.width;
  const height = originalImage.height;
  const source = new OffscreenCanvas(width, height);
  const context = source.getContext('2d', { willReadFrequently: true });
  context.drawImage(originalImage, 0, 0);
  const data = context.getImageData(0, 0, width, height).data;
  const integral = new Float64Array((width + 1) * (height + 1));
  for (let y = 0; y < height; y++) {
    let rowSum = 0;
    for (let x = 0; x < width; x++) {
      const p = (y * width + x) * 4;
      rowSum += 0.2126 * data[p] + 0.7152 * data[p + 1] + 0.0722 * data[p + 2];
      integral[(y + 1) * (width + 1) + x + 1] = integral[y * (width + 1) + x + 1] + rowSum;
    }
  }
  return { width, height, integral };
}

function refineBoardPose(image, pose) {
  const luma = buildLumaIntegral(null, image);
  const sizes = pose.confidence < 0.5 ? [9, 13, 19] : [pose.boardSize];
  let best = null;
  for (const size of sizes) {
    const candidate = refineForSize(luma, size, pose.corners, pose.confidence < 0.5 ? pose.box : axisAlignedBounds(pose.corners), pose.box, pose.confidence < 0.5 ? 0.10 : 1.25);
    if (!best || candidate.score > best.score) best = candidate;
  }
  return best;
}

function refineForSize(luma, boardSize, corners, box, driftBox, priorStrength) {
  let { x1: x0, y1: y0, x2, y2 } = box;
  let x1 = x2;
  let y1 = y2;
  let score = 0;
  for (let i = 0; i < 2; i++) {
    const vertical = verticalLineProfile(luma, y0, y1);
    const xr = searchPeriodicAxis(vertical, boardSize, x0, x1, priorStrength);
    x0 = xr.start;
    x1 = xr.start + xr.step * (boardSize - 1);
    const horizontal = horizontalLineProfile(luma, x0, x1);
    const yr = searchPeriodicAxis(horizontal, boardSize, y0, y1, priorStrength);
    y0 = yr.start;
    y1 = yr.start + yr.step * (boardSize - 1);
    score = xr.score + yr.score;
  }
  [x0, x1] = correctAxisDrift(x0, x1, boardSize, driftBox.x1, driftBox.x2, luma.width);
  [y0, y1] = correctAxisDrift(y0, y1, boardSize, driftBox.y1, driftBox.y2, luma.height);
  return {
    boardSize,
    corners: [{ x: x0, y: y0 }, { x: x1, y: y0 }, { x: x1, y: y1 }, { x: x0, y: y1 }],
    score,
  };
}

function verticalLineProfile(luma, y0, y1) {
  const top = clamp(Math.round(y0), 0, luma.height - 1);
  const bottom = Math.max(top + 1, clamp(Math.round(y1), 0, luma.height));
  const profile = new Float64Array(luma.width);
  for (let x = 7; x < luma.width - 7; x++) {
    const center = meanRect(luma, x - 1, top, x + 2, bottom);
    const side = (meanRect(luma, x - 7, top, x - 4, bottom) + meanRect(luma, x + 4, top, x + 7, bottom)) / 2;
    profile[x] = Math.max(0, side - center);
  }
  return smooth(profile);
}

function horizontalLineProfile(luma, x0, x1) {
  const left = clamp(Math.round(x0), 0, luma.width - 1);
  const right = Math.max(left + 1, clamp(Math.round(x1), 0, luma.width));
  const profile = new Float64Array(luma.height);
  for (let y = 7; y < luma.height - 7; y++) {
    const center = meanRect(luma, left, y - 1, right, y + 2);
    const side = (meanRect(luma, left, y - 7, right, y - 4) + meanRect(luma, left, y + 4, right, y + 7)) / 2;
    profile[y] = Math.max(0, side - center);
  }
  return smooth(profile);
}

function searchPeriodicAxis(profile, boardSize, roughStart, roughEnd, priorStrength) {
  const roughStep = Math.max(1, (roughEnd - roughStart) / (boardSize - 1));
  const stepDelta = Math.max(1, roughStep * 0.01);
  const startDelta = Math.max(1, roughStep * 0.01);
  let best = { score: -Infinity, start: roughStart, step: roughStep };
  for (let step = Math.max(8, roughStep * 0.55); step < roughStep * 1.30; step += stepDelta) {
    const maxStart = profile.length - step * (boardSize - 1);
    const startMin = Math.max(0, roughStart - roughStep * 1.5);
    const startMax = Math.min(maxStart, roughStart + roughStep * 1.5);
    for (let start = startMin; start < startMax; start += startDelta) {
      const end = start + step * (boardSize - 1);
      if (end >= profile.length) continue;
      let lineScore = 0;
      for (let i = 0; i < boardSize; i++) lineScore += localMax(profile, start + i * step);
      lineScore /= boardSize;
      let midScore = 0;
      for (let i = 0; i < boardSize - 1; i++) midScore += localMax(profile, start + (i + 0.5) * step);
      midScore /= Math.max(1, boardSize - 1);
      let score = lineScore - 0.25 * midScore;
      const startDeltaRatio = Math.abs(start - roughStart) / Math.max(1, roughStep);
      const stepDeltaRatio = Math.abs(step - roughStep) / Math.max(1, roughStep);
      score *= Math.max(0.15, 1.0 - priorStrength * (0.25 * startDeltaRatio + stepDeltaRatio));
      if (score > best.score) best = { score, start, step };
    }
  }
  return best;
}

function meanRect(luma, x0, y0, x1, y1) {
  x0 = clamp(x0, 0, luma.width);
  x1 = clamp(x1, 0, luma.width);
  y0 = clamp(y0, 0, luma.height);
  y1 = clamp(y1, 0, luma.height);
  if (x0 >= x1 || y0 >= y1) return 0;
  const stride = luma.width + 1;
  const sum = luma.integral[y1 * stride + x1] - luma.integral[y0 * stride + x1] - luma.integral[y1 * stride + x0] + luma.integral[y0 * stride + x0];
  return sum / ((x1 - x0) * (y1 - y0));
}

function smooth(profile) {
  const result = new Float64Array(profile.length);
  for (let i = 0; i < profile.length; i++) {
    let sum = 0;
    let count = 0;
    for (let d = -2; d <= 2; d++) {
      const j = i + d;
      if (j < 0 || j >= profile.length) continue;
      sum += profile[j];
      count++;
    }
    result[i] = count ? sum / count : profile[i];
  }
  return result;
}

function localMax(profile, index) {
  const center = Math.round(index);
  const left = Math.max(0, center - 2);
  const right = Math.min(profile.length, center + 3);
  let result = 0;
  for (let i = left; i < right; i++) result = Math.max(result, profile[i]);
  return result;
}

function correctAxisDrift(start, end, boardSize, boxStart, boxEnd, imageLimit) {
  const step = (end - start) / Math.max(1, boardSize - 1);
  if (end > boxEnd + step * 0.5 && start - step >= 0) return [start - step, end - step];
  if (start < boxStart - step * 0.5 && end + step <= imageLimit) return [start + step, end + step];
  return [start, end];
}

function axisAlignedBounds(corners) {
  return {
    x1: (corners[0].x + corners[3].x) / 2,
    x2: (corners[1].x + corners[2].x) / 2,
    y1: (corners[0].y + corners[1].y) / 2,
    y2: (corners[2].y + corners[3].y) / 2,
  };
}

function nearestIntersection(x, y, pose) {
  let best = { row: 0, col: 0, distance: Infinity };
  for (let row = 0; row < pose.boardSize; row++) {
    for (let col = 0; col < pose.boardSize; col++) {
      const point = gridPoint(pose, row, col);
      const distance = Math.hypot(x - point.x, y - point.y);
      if (distance < best.distance) best = { row, col, distance };
    }
  }
  return best;
}

function gridPoint(pose, row, col) {
  const u = pose.boardSize <= 1 ? 0 : col / (pose.boardSize - 1);
  const v = pose.boardSize <= 1 ? 0 : row / (pose.boardSize - 1);
  const top = lerp(pose.corners[0], pose.corners[1], u);
  const bottom = lerp(pose.corners[3], pose.corners[2], u);
  return lerp(top, bottom, v);
}

function averageGridStep(pose) {
  if (pose.boardSize <= 1) return 20;
  const top = distance(pose.corners[0], pose.corners[1]) / (pose.boardSize - 1);
  const right = distance(pose.corners[1], pose.corners[2]) / (pose.boardSize - 1);
  const bottom = distance(pose.corners[3], pose.corners[2]) / (pose.boardSize - 1);
  const left = distance(pose.corners[0], pose.corners[3]) / (pose.boardSize - 1);
  return (top + right + bottom + left) / 4;
}

function lerp(a, b, t) {
  return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t };
}

function distance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function boxCenter(box) {
  return { x: (box.x1 + box.x2) / 2, y: (box.y1 + box.y2) / 2 };
}

function boxIou(a, b) {
  const x1 = Math.max(a.x1, b.x1);
  const y1 = Math.max(a.y1, b.y1);
  const x2 = Math.min(a.x2, b.x2);
  const y2 = Math.min(a.y2, b.y2);
  const intersection = Math.max(0, x2 - x1) * Math.max(0, y2 - y1);
  const union = boxArea(a) + boxArea(b) - intersection;
  return union <= 0 ? 0 : intersection / union;
}

function boxArea(box) {
  return Math.max(0, box.x2 - box.x1) * Math.max(0, box.y2 - box.y1);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
