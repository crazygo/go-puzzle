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
    if (decoded == null) throw const FormatException('無法解析圖片');
    final scaled = _scaleForAnalysis(decoded);
    final lumaMap = _LumaMap.fromImage(scaled);
    final candidate = _findBestGridCandidate(scaled, lumaMap);
    final board = _recognizeStones(scaled, candidate);
    return BoardRecognitionResult(
      boardSize: candidate.boardSize,
      board: board,
      confidence: candidate.confidence,
    );
  }

  static img.Image _scaleForAnalysis(img.Image image) {
    final maxEdge = math.max(image.width, image.height);
    if (maxEdge <= 900) return image;
    final scale = 900 / maxEdge;
    return img.copyResize(image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.average);
  }

  static _GridCandidate _findBestGridCandidate(
      img.Image image, _LumaMap lumaMap) {
    _GridCandidate? best;
    final xProj = _calculateBoardLineProjection(image, horizontal: true);
    final yProj = _calculateBoardLineProjection(image, horizontal: false);
    final searchDim = math.min(lumaMap.width, lumaMap.height);
    final xPeaks = _projectionPeaks(xProj);
    final yPeaks = _projectionPeaks(yProj);
    final boardSizes = xPeaks.length >= 18 && yPeaks.length >= 18
        ? const [19]
        : _boardSizeCandidates;

    for (final boardSize in boardSizes) {
      final xCandidates = _findTopPeriodicCandidates(
        xProj,
        boardSize,
        lumaMap.width,
        searchDim,
      );
      final yCandidates = _findTopPeriodicCandidates(
        yProj,
        boardSize,
        lumaMap.height,
        searchDim,
      );

      for (final x in xCandidates) {
        for (final y in yCandidates) {
          final ratio = x.step / y.step;
          if (ratio < 0.98 || ratio > 1.02) continue;
          final candidate = _scoreCandidate(
            image: image,
            lumaMap: lumaMap,
            left: x.start,
            top: y.start,
            side: (x.span + y.span) / 2,
            boardSize: boardSize,
            periodicScore: (x.score + y.score) / 2,
          );
          if (best == null || candidate.rawScore > best.rawScore) {
            best = candidate;
          }
        }
      }
    }
    final candidate = (best != null && best.confidence > 0.05)
        ? _refineCandidate(image, lumaMap, best)
        : _fallback(lumaMap);
    return _correctCandidateDrift(image, lumaMap, candidate);
  }

  static _GridCandidate _fallback(_LumaMap lumaMap) {
    final side = math.min(lumaMap.width, lumaMap.height) * 0.9;
    return _GridCandidate(
        left: (lumaMap.width - side) / 2,
        top: (lumaMap.height - side) / 2,
        side: side,
        boardSize: 9,
        rawScore: 0,
        confidence: 0.1);
  }

  static _GridCandidate _correctCandidateDrift(
    img.Image image,
    _LumaMap lumaMap,
    _GridCandidate candidate,
  ) {
    final step = candidate.side / (candidate.boardSize - 1);
    var corrected = candidate;
    final leftSurface = _edgeSurfaceScore(image, corrected, col: 0);
    final rightSurface =
        _edgeSurfaceScore(image, corrected, col: corrected.boardSize - 1);
    if (leftSurface < 0.45 && rightSurface > 0.70) {
      corrected = _scoreCandidate(
        image: image,
        lumaMap: lumaMap,
        left: corrected.left + step,
        top: corrected.top,
        side: corrected.side,
        boardSize: corrected.boardSize,
      );
    }
    final topSurface = _edgeSurfaceScore(image, corrected, row: 0);
    final bottomSurface =
        _edgeSurfaceScore(image, corrected, row: corrected.boardSize - 1);
    if (topSurface < 0.45 && bottomSurface > 0.70) {
      corrected = _scoreCandidate(
        image: image,
        lumaMap: lumaMap,
        left: corrected.left,
        top: corrected.top + step,
        side: corrected.side,
        boardSize: corrected.boardSize,
      );
    }
    return corrected;
  }

  static double _edgeSurfaceScore(
    img.Image image,
    _GridCandidate candidate, {
    int? row,
    int? col,
  }) {
    final step = candidate.side / (candidate.boardSize - 1);
    var score = 0.0;
    for (int i = 0; i < candidate.boardSize; i++) {
      final r = row ?? i;
      final c = col ?? i;
      score += _boardSurfaceScore(
        image,
        candidate.left + c * step,
        candidate.top + r * step,
        step,
      );
    }
    return score / candidate.boardSize;
  }

  static List<double> _calculateBoardLineProjection(
    img.Image image, {
    required bool horizontal,
  }) {
    final proj =
        List<double>.filled(horizontal ? image.width : image.height, 0);
    if (horizontal) {
      for (int x = 0; x < image.width; x++) {
        var sum = 0.0;
        for (int y = 0; y < image.height; y++) {
          sum += _boardLineWeight(image.getPixel(x, y));
        }
        proj[x] = sum;
      }
    } else {
      for (int y = 0; y < image.height; y++) {
        var sum = 0.0;
        for (int x = 0; x < image.width; x++) {
          sum += _boardLineWeight(image.getPixel(x, y));
        }
        proj[y] = sum;
      }
    }
    return _smoothProjection(proj, radius: 1);
  }

  static double _boardLineWeight(img.Pixel pixel) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();
    final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    if (luma < 35 || luma > 185) return 0;
    if (b > g * 0.92) return 0;
    if (g > r * 1.18) return 0;
    if ((r - b) < 18) return 0;
    return (185 - luma).clamp(0.0, 160.0);
  }

  static List<double> _smoothProjection(List<double> data,
      {required int radius}) {
    if (data.length < radius * 2 + 1) return data;
    final result = List<double>.filled(data.length, 0);
    for (int i = 0; i < data.length; i++) {
      var sum = 0.0;
      var count = 0;
      for (int d = -radius; d <= radius; d++) {
        final j = i + d;
        if (j < 0 || j >= data.length) continue;
        sum += data[j];
        count++;
      }
      result[i] = count == 0 ? data[i] : sum / count;
    }
    return result;
  }

  static List<int> _projectionPeaks(List<double> projection) {
    final maxProjection = projection.fold<double>(0, math.max);
    if (maxProjection <= 0) return const [];
    final threshold = maxProjection * 0.18;
    final peaks = <int>[];
    var start = -1;
    var sum = 0.0;
    var weighted = 0.0;
    for (int i = 0; i < projection.length; i++) {
      if (projection[i] >= threshold) {
        if (start < 0) start = i;
        sum += projection[i];
        weighted += projection[i] * i;
      } else if (start >= 0) {
        if (sum > 0) peaks.add((weighted / sum).round());
        start = -1;
        sum = 0;
        weighted = 0;
      }
    }
    if (start >= 0 && sum > 0) peaks.add((weighted / sum).round());
    return peaks;
  }

  static List<_PeriodicResult> _findTopPeriodicCandidates(
    List<double> proj,
    int boardSize,
    int totalDim,
    int searchDim,
  ) {
    final n = proj.length;
    final results = <_PeriodicResult>[];
    final maxProjection = proj.fold<double>(0, math.max);
    final strongLineThreshold = maxProjection * 0.10;
    final minStep = searchDim * 0.70 / (boardSize - 1),
        maxStep = searchDim * 0.98 / (boardSize - 1);

    for (double step = minStep; step <= maxStep; step += 0.5) {
      final maxOffset = n - step * (boardSize - 1);
      for (double offset = 4.0; offset < maxOffset - 4; offset += 0.5) {
        var score = 0.0, penalty = 0.0, strongLines = 0;
        for (int i = 0; i < boardSize; i++) {
          final idx = (offset + i * step).round();
          var localMax = proj[idx.clamp(0, n - 1)];
          if (idx > 0) localMax = math.max(localMax, proj[idx - 1]);
          if (idx < n - 1) localMax = math.max(localMax, proj[idx + 1]);
          score += localMax;
          if (localMax >= strongLineThreshold) strongLines++;
          if (i < boardSize - 1) {
            penalty +=
                proj[(offset + i * step + step / 2).round().clamp(0, n - 1)];
          }
        }
        final centerDist =
            (offset + (boardSize - 1) * step / 2 - totalDim / 2).abs() /
                totalDim;
        final sizeBonus = (boardSize == 9) ? 0.8 : 1.0;
        final consistency = strongLines / boardSize;
        final finalScore = (score - penalty * 1.1) /
            boardSize *
            (1.0 - centerDist) *
            sizeBonus *
            consistency *
            consistency;
        results.add(_PeriodicResult(
            start: offset,
            step: step,
            span: step * (boardSize - 1),
            score: finalScore));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(12).toList();
  }

  static _GridCandidate _scoreCandidate({
    required img.Image image,
    required _LumaMap lumaMap,
    required double left,
    required double top,
    required double side,
    required int boardSize,
    double periodicScore = 0,
  }) {
    final step = side / (boardSize - 1);
    var intersectionScore = 0.0;
    var boardColorScore = 0.0;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        final x = left + c * step;
        final y = top + r * step;
        intersectionScore +=
            lumaMap.getIntersectionStrength(x.round(), y.round());
        boardColorScore += _boardSurfaceScore(image, x, y, step);
      }
    }
    final intersectionAverage = intersectionScore / (boardSize * boardSize);
    final boardSurfaceAverage = boardColorScore / (boardSize * boardSize);
    final rawScore = intersectionAverage * 0.05 +
        boardSurfaceAverage * 22 +
        math.sqrt(math.max(0, periodicScore)) / 10;
    final confidence = (rawScore / 30).clamp(0.05, 0.99);
    return _GridCandidate(
        left: left,
        top: top,
        side: side,
        boardSize: boardSize,
        rawScore: rawScore,
        confidence: confidence);
  }

  static double _boardSurfaceScore(
    img.Image image,
    double cx,
    double cy,
    double step,
  ) {
    final sample = _sampleDisk(image, cx, cy, step * 0.18);
    final r = sample.meanR;
    final g = sample.meanG;
    final b = sample.meanB;
    final luma = sample.meanLuma;
    if (luma < 105 || luma > 230) return 0;
    if (r < 135 || g < 90 || b > 175) return 0;
    if (r < g * 0.92 || g < b + 16) return 0;
    if (r - b < 34) return 0;
    return 1;
  }

  static _GridCandidate _refineCandidate(
    img.Image image,
    _LumaMap lumaMap,
    _GridCandidate coarse,
  ) {
    var best = coarse;
    for (double dy = -1.0; dy <= 1.0; dy += 0.5) {
      for (double dx = -1.0; dx <= 1.0; dx += 0.5) {
        final candidate = _scoreCandidate(
          image: image,
          lumaMap: lumaMap,
          left: coarse.left + dx,
          top: coarse.top + dy,
          side: coarse.side,
          boardSize: coarse.boardSize,
        );
        if (candidate.rawScore > best.rawScore) best = candidate;
      }
    }
    return best;
  }

  static List<List<StoneColor>> _recognizeStones(
      img.Image image, _GridCandidate candidate) {
    final n = candidate.boardSize, step = candidate.side / (n - 1);
    final board =
        List.generate(n, (_) => List<StoneColor>.filled(n, StoneColor.empty));
    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n; col++) {
        final luma = _sampleDisk(
          image,
          candidate.left + col * step,
          candidate.top + row * step,
          step * 0.30,
        ).meanLuma;
        final outerLuma = _sampleAnnulus(
          image,
          candidate.left + col * step,
          candidate.top + row * step,
          innerRadius: step * 0.13,
          outerRadius: step * 0.32,
        ).meanLuma;
        final centerLuma = _sampleDisk(
          image,
          candidate.left + col * step,
          candidate.top + row * step,
          step * 0.10,
        ).meanLuma;
        if (luma < 115) {
          board[row][col] = StoneColor.black;
        } else if (luma > 205 || (outerLuma > 195 && centerLuma < 115)) {
          board[row][col] = StoneColor.white;
        }
      }
    }
    return board;
  }

  static _SampleStats _sampleDisk(
      img.Image image, double cx, double cy, double r) {
    return _sampleRadiusRange(image, cx, cy, minRadius: 0, maxRadius: r);
  }

  static _SampleStats _sampleAnnulus(
    img.Image image,
    double cx,
    double cy, {
    required double innerRadius,
    required double outerRadius,
  }) {
    return _sampleRadiusRange(
      image,
      cx,
      cy,
      minRadius: innerRadius,
      maxRadius: outerRadius,
    );
  }

  static _SampleStats _sampleRadiusRange(
    img.Image image,
    double cx,
    double cy, {
    required double minRadius,
    required double maxRadius,
  }) {
    var sum = 0.0, sumR = 0.0, sumG = 0.0, sumB = 0.0, cnt = 0;
    final rad = maxRadius.ceil();
    final minR2 = minRadius * minRadius;
    final maxR2 = maxRadius * maxRadius;
    for (int dy = -rad; dy <= rad; dy++) {
      for (int dx = -rad; dx <= rad; dx++) {
        final d2 = dx * dx + dy * dy;
        if (d2 < minR2 || d2 > maxR2) continue;
        final x = (cx + dx).round(), y = (cy + dy).round();
        if (x >= 0 && y >= 0 && x < image.width && y < image.height) {
          final p = image.getPixel(x, y);
          sumR += p.r;
          sumG += p.g;
          sumB += p.b;
          sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
          cnt++;
        }
      }
    }
    return _SampleStats(
      meanLuma: cnt == 0 ? 0 : sum / cnt,
      meanR: cnt == 0 ? 0 : sumR / cnt,
      meanG: cnt == 0 ? 0 : sumG / cnt,
      meanB: cnt == 0 ? 0 : sumB / cnt,
      count: cnt,
    );
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
        values[y * image.width + x] =
            (0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b).round().clamp(0, 255);
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
          final d =
              (luma[(y + 1) * width + x] - luma[(y - 1) * width + x]).abs();
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
    for (int i = 1; i < data.length - 1; i++) {
      res[i] = (data[i - 1] + data[i] + data[i + 1]) / 3;
    }
    return res;
  }
}

class _PeriodicResult {
  _PeriodicResult(
      {required this.start,
      required this.step,
      required this.span,
      required this.score});
  final double start, step, span, score;
}

class _GridCandidate {
  _GridCandidate(
      {required this.left,
      required this.top,
      required this.side,
      required this.boardSize,
      required this.rawScore,
      required this.confidence});
  final double left, top, side;
  final int boardSize;
  final double rawScore, confidence;
}

class _SampleStats {
  _SampleStats({
    required this.meanLuma,
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.count,
  });
  final double meanLuma, meanR, meanG, meanB;
  final int count;
}
