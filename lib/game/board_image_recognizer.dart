import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/board_position.dart';

class BoardRecognitionResult {
  const BoardRecognitionResult({
    required this.boardSize,
    required this.board,
    required this.confidence,
  });

  final int boardSize;
  final List<List<StoneColor>> board;
  final double confidence;
}

class BoardImageRecognizer {
  static const _boardSizeCandidates = [9, 13, 19];

  static BoardRecognitionResult recognize(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('无法解析图片');
    final scaled = _scaleForAnalysis(decoded);
    final lumaMap = _LumaMap.fromImage(scaled);
    final candidate = _findBestGridCandidate(lumaMap);
    final board = _recognizeStones(scaled, candidate);
    return BoardRecognitionResult(boardSize: candidate.boardSize, board: board, confidence: candidate.confidence);
  }

  static img.Image _scaleForAnalysis(img.Image image) {
    final maxEdge = math.max(image.width, image.height);
    if (maxEdge <= 900) return image;
    final scale = 900 / maxEdge;
    return img.copyResize(image, width: (image.width * scale).round(), height: (image.height * scale).round(), interpolation: img.Interpolation.average);
  }

  static _GridCandidate _findBestGridCandidate(_LumaMap lumaMap) {
    _GridCandidate? best;
    final xProj = lumaMap.calculateEdgeProjection(horizontal: true);
    final yProj = lumaMap.calculateEdgeProjection(horizontal: false);

    for (final boardSize in _boardSizeCandidates) {
      final xCandidates = _findTopPeriodicCandidates(xProj, boardSize, lumaMap.width);
      final yCandidates = _findTopPeriodicCandidates(yProj, boardSize, lumaMap.height);

      for (final x in xCandidates) {
        for (final y in yCandidates) {
          final ratio = x.step / y.step;
          if (ratio < 0.98 || ratio > 1.02) continue;
          final candidate = _scoreCandidate(lumaMap: lumaMap, left: x.start, top: y.start, side: (x.span + y.span) / 2, boardSize: boardSize);
          if (best == null || candidate.rawScore > best.rawScore) best = candidate;
        }
      }
    }
    return (best != null && best.confidence > 0.05) ? _refineCandidate(lumaMap, best) : _fallback(lumaMap);
  }

  static _GridCandidate _fallback(_LumaMap lumaMap) {
    final side = math.min(lumaMap.width, lumaMap.height) * 0.9;
    return _GridCandidate(left: (lumaMap.width - side) / 2, top: (lumaMap.height - side) / 2, side: side, boardSize: 9, rawScore: 0, confidence: 0.1);
  }

  static List<_PeriodicResult> _findTopPeriodicCandidates(List<double> proj, int boardSize, int totalDim) {
    final n = proj.length;
    final results = <_PeriodicResult>[];
    final minStep = totalDim * 0.70 / (boardSize - 1), maxStep = totalDim * 0.98 / (boardSize - 1);

    for (double step = minStep; step <= maxStep; step += 0.5) {
      final maxOffset = n - step * (boardSize - 1);
      for (double offset = 4.0; offset < maxOffset - 4; offset += 0.5) {
        var score = 0.0, penalty = 0.0;
        for (int i = 0; i < boardSize; i++) {
          final idx = (offset + i * step).round();
          var localMax = proj[idx.clamp(0, n-1)];
          if (idx > 0) localMax = math.max(localMax, proj[idx-1]);
          if (idx < n - 1) localMax = math.max(localMax, proj[idx+1]);
          score += localMax;
          if (i < boardSize - 1) penalty += proj[(offset + i * step + step / 2).round().clamp(0, n-1)];
        }
        final centerDist = (offset + (boardSize - 1) * step / 2 - totalDim / 2).abs() / totalDim;
        final sizeBonus = (boardSize == 9) ? 0.8 : 1.0;
        final finalScore = (score - penalty * 0.6) / boardSize * (1.0 - centerDist) * sizeBonus;
        results.add(_PeriodicResult(start: offset, step: step, span: step * (boardSize - 1), score: finalScore));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(12).toList();
  }

  static _GridCandidate _scoreCandidate({required _LumaMap lumaMap, required double left, required double top, required double side, required int boardSize}) {
    final step = side / (boardSize - 1);
    var intersectionScore = 0.0;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        intersectionScore += lumaMap.getIntersectionStrength((left + c * step).round(), (top + r * step).round());
      }
    }
    final rawScore = intersectionScore / (boardSize * boardSize);
    final confidence = (rawScore / 30).clamp(0.05, 0.99);
    return _GridCandidate(left: left, top: top, side: side, boardSize: boardSize, rawScore: rawScore, confidence: confidence);
  }

  static _GridCandidate _refineCandidate(_LumaMap lumaMap, _GridCandidate coarse) {
    var best = coarse;
    for (double dy = -1.0; dy <= 1.0; dy += 0.5) {
      for (double dx = -1.0; dx <= 1.0; dx += 0.5) {
        final candidate = _scoreCandidate(lumaMap: lumaMap, left: coarse.left + dx, top: coarse.top + dy, side: coarse.side, boardSize: coarse.boardSize);
        if (candidate.rawScore > best.rawScore) best = candidate;
      }
    }
    return best;
  }

  static List<List<StoneColor>> _recognizeStones(img.Image image, _GridCandidate candidate) {
    final n = candidate.boardSize, step = candidate.side / (n - 1);
    final features = List<double>.filled(n * n, 0);
    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n; col++) {
        features[row * n + col] = _sampleDisk(image, candidate.left + col * step, candidate.top + row * step, step * 0.16).meanLuma;
      }
    }
    final clusters = _kMeans1D(features, k: 3);
    final sortedIdx = List.generate(3, (i) => i)..sort((a, b) => clusters.centers[a].compareTo(clusters.centers[b]));
    final bIdx = sortedIdx[0], eIdx = sortedIdx[1], wIdx = sortedIdx[2];
    final bGap = clusters.centers[eIdx] - clusters.centers[bIdx], wGap = clusters.centers[wIdx] - clusters.centers[eIdx];
    final board = List.generate(n, (_) => List<StoneColor>.filled(n, StoneColor.empty));
    for (int i = 0; i < features.length; i++) {
      final c = clusters.assignments[i];
      if (c == bIdx && bGap > 12) board[i ~/ n][i % n] = StoneColor.black;
      else if (c == wIdx && wGap > 12) board[i ~/ n][i % n] = StoneColor.white;
    }
    return board;
  }

  static _KMeansResult _kMeans1D(List<double> data, {required int k}) {
    if (data.isEmpty) return _KMeansResult([], []);
    double minV = data.reduce(math.min), maxV = data.reduce(math.max);
    var centers = [minV, (minV + maxV) / 2, maxV];
    final assigns = List<int>.filled(data.length, 0);
    for (int iter = 0; iter < 12; iter++) {
      for (int i = 0; i < data.length; i++) {
        var bestD = (data[i] - centers[0]).abs(), bestK = 0;
        for (int j = 1; j < k; j++) { final d = (data[i] - centers[j]).abs(); if (d < bestD) { bestD = d; bestK = j; } }
        assigns[i] = bestK;
      }
      final nextC = List<double>.filled(k, 0), cnts = List<int>.filled(k, 0);
      for (int i = 0; i < data.length; i++) { nextC[assigns[i]] += data[i]; cnts[assigns[i]]++; }
      var changed = false;
      for (int j = 0; j < k; j++) {
        if (cnts[j] > 0) {
          final next = nextC[j] / cnts[j];
          if ((next - centers[j]).abs() > 0.1) { centers[j] = next; changed = true; }
        }
      }
      if (!changed) break;
    }
    return _KMeansResult(assigns, centers);
  }

  static _SampleStats _sampleDisk(img.Image image, double cx, double cy, double r) {
    var sum = 0.0, cnt = 0;
    final rad = r.ceil(), r2 = r * r;
    for (int dy = -rad; dy <= rad; dy++) {
      for (int dx = -rad; dx <= rad; dx++) {
        if (dx * dx + dy * dy > r2) continue;
        final x = (cx + dx).round(), y = (cy + dy).round();
        if (x >= 0 && y >= 0 && x < image.width && y < image.height) {
          final p = image.getPixel(x, y);
          sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
          cnt++;
        }
      }
    }
    return _SampleStats(meanLuma: cnt == 0 ? 0 : sum / cnt, count: cnt);
  }
}

class _LumaMap {
  _LumaMap({required this.width, required this.height, required this.luma});
  final int width, height;
  final Uint8List luma;

  factory _LumaMap.fromImage(img.Image image) {
    final values = Uint8List(image.width * image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        values[y * image.width + x] = (0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b).round().clamp(0, 255);
      }
    }
    return _LumaMap(width: image.width, height: image.height, luma: values);
  }

  double getIntersectionStrength(int x, int y) {
    if (x < 3 || y < 3 || x >= width - 3 || y >= height - 3) return 0;
    final dx = (luma[y * width + x + 2] - luma[y * width + x - 2]).abs();
    final dy = (luma[(y + 2) * width + x] - luma[(y - 2) * width + x]).abs();
    return math.min(dx, dy).toDouble();
  }

  List<double> calculateEdgeProjection({required bool horizontal}) {
    final proj = List<double>.filled(horizontal ? width : height, 0);
    if (horizontal) {
      for (int x = 0; x < width; x++) {
        var sum = 0.0;
        for (int y = 10; y < height - 10; y++) {
          final d = (luma[(y + 1) * width + x] - luma[(y - 1) * width + x]).abs();
          if (d > 16) sum += d;
        }
        proj[x] = math.min(sum * sum, 4000000.0);
      }
    } else {
      for (int y = 0; y < height; y++) {
        var sum = 0.0;
        for (int x = 10; x < width - 10; x++) {
          final d = (luma[y * width + x + 1] - luma[y * width + x - 1]).abs();
          if (d > 16) sum += d;
        }
        proj[y] = math.min(sum * sum, 4000000.0);
      }
    }
    return _smooth(proj);
  }

  List<double> _smooth(List<double> data) {
    if (data.length < 3) return data;
    final res = List<double>.from(data);
    for (int i = 1; i < data.length - 1; i++) res[i] = (data[i - 1] + data[i] + data[i + 1]) / 3;
    return res;
  }
}

class _PeriodicResult {
  _PeriodicResult({required this.start, required this.step, required this.span, required this.score});
  final double start, step, span, score;
}

class _GridCandidate {
  _GridCandidate({required this.left, required this.top, required this.side, required this.boardSize, required this.rawScore, required this.confidence});
  final double left, top, side;
  final int boardSize;
  final double rawScore, confidence;
}

class _KMeansResult {
  _KMeansResult(this.assignments, this.centers);
  final List<int> assignments;
  final List<double> centers;
}

class _SampleStats {
  _SampleStats({required this.meanLuma, required this.count});
  final double meanLuma;
  final int count;
}
