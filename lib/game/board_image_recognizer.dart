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
    if (decoded == null) {
      throw const FormatException('无法解析图片');
    }

    final scaled = _scaleForAnalysis(decoded);
    final lumaMap = _LumaMap.fromImage(scaled);
    final candidate = _findBestGridCandidate(lumaMap);
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
    return img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  static _GridCandidate _findBestGridCandidate(_LumaMap lumaMap) {
    final minDim = math.min(lumaMap.width, lumaMap.height).toDouble();
    final minSide = (minDim * 0.42).round().toDouble();
    final maxSide = (minDim * 0.96).round().toDouble();

    _GridCandidate? best;

    for (final boardSize in _boardSizeCandidates) {
      final stepSpan = (minDim * 0.05).clamp(12.0, 44.0);
      for (double side = minSide; side <= maxSide; side += stepSpan) {
        final step = side / (boardSize - 1);
        if (step < 10) continue;

        final xyStep = math.max(6.0, side / 9);
        final maxX = lumaMap.width - side - 1;
        final maxY = lumaMap.height - side - 1;

        for (double top = 0; top <= maxY; top += xyStep) {
          for (double left = 0; left <= maxX; left += xyStep) {
            final candidate = _scoreCandidate(
              lumaMap: lumaMap,
              left: left,
              top: top,
              side: side,
              boardSize: boardSize,
            );
            if (best == null || candidate.rawScore > best.rawScore) {
              best = candidate;
            }
          }
        }
      }
    }

    if (best == null) {
      final fallbackSide = (minDim * 0.86).roundToDouble();
      return _GridCandidate(
        left: (lumaMap.width - fallbackSide) / 2,
        top: (lumaMap.height - fallbackSide) / 2,
        side: fallbackSide,
        boardSize: 9,
        rawScore: 0,
        confidence: 0.25,
      );
    }

    return _refineCandidate(lumaMap, best);
  }

  static _GridCandidate _refineCandidate(
    _LumaMap lumaMap,
    _GridCandidate coarse,
  ) {
    var best = coarse;
    final sideStep = math.max(4.0, coarse.side * 0.02);
    final posStep = math.max(2.0, coarse.side * 0.015);

    for (double side = coarse.side - sideStep;
        side <= coarse.side + sideStep;
        side += 2) {
      final maxX = lumaMap.width - side - 1;
      final maxY = lumaMap.height - side - 1;
      for (double top = coarse.top - posStep;
          top <= coarse.top + posStep;
          top += 2) {
        if (top < 0 || top > maxY) continue;
        for (double left = coarse.left - posStep;
            left <= coarse.left + posStep;
            left += 2) {
          if (left < 0 || left > maxX) continue;
          final candidate = _scoreCandidate(
            lumaMap: lumaMap,
            left: left,
            top: top,
            side: side,
            boardSize: coarse.boardSize,
          );
          if (candidate.rawScore > best.rawScore) {
            best = candidate;
          }
        }
      }
    }

    return best;
  }

  static _GridCandidate _scoreCandidate({
    required _LumaMap lumaMap,
    required double left,
    required double top,
    required double side,
    required int boardSize,
  }) {
    final step = side / (boardSize - 1);
    final lineThickness = (step * 0.08).clamp(1.0, 2.6);

    var lineDarkness = 0.0;
    var sampledLines = 0;

    for (int i = 0; i < boardSize; i++) {
      final offset = i * step;
      final x = left + offset;
      final y = top + offset;

      lineDarkness += lumaMap.darknessAlongLine(
        x1: x,
        y1: top,
        x2: x,
        y2: top + side,
        thickness: lineThickness,
      );
      lineDarkness += lumaMap.darknessAlongLine(
        x1: left,
        y1: y,
        x2: left + side,
        y2: y,
        thickness: lineThickness,
      );
      sampledLines += 2;
    }

    final avgLineDarkness = sampledLines == 0 ? 0 : lineDarkness / sampledLines;
    final interiorDarkness = lumaMap.darkRatioInRect(
      left: left + side * 0.06,
      top: top + side * 0.06,
      width: side * 0.88,
      height: side * 0.88,
    );
    final lineAdvantage = avgLineDarkness - interiorDarkness;
    final interiorLuma = lumaMap.meanLuma(
      left: left + side * 0.08,
      top: top + side * 0.08,
      width: side * 0.84,
      height: side * 0.84,
    );
    final borderLuma = lumaMap.meanLumaOnBorder(
      left: left,
      top: top,
      side: side,
      thickness: lineThickness * 2,
    );

    final contrastBonus = ((interiorLuma - borderLuma) / 255).clamp(-0.2, 0.3);
    final rawScore = lineAdvantage * 1.7 + contrastBonus;
    final confidence = (0.25 + rawScore * 1.1).clamp(0.2, 0.99).toDouble();

    return _GridCandidate(
      left: left,
      top: top,
      side: side,
      boardSize: boardSize,
      rawScore: rawScore,
      confidence: confidence,
    );
  }

  static List<List<StoneColor>> _recognizeStones(
    img.Image image,
    _GridCandidate candidate,
  ) {
    final n = candidate.boardSize;
    final board = List.generate(
      n,
      (_) => List<StoneColor>.filled(n, StoneColor.empty),
    );
    final step = candidate.side / (n - 1);

    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n; col++) {
        final cx = candidate.left + col * step;
        final cy = candidate.top + row * step;

        final center = _sampleDisk(image, cx, cy, step * 0.29);
        final ring = _sampleRing(image, cx, cy, step * 0.35, step * 0.56);

        if (center.count == 0 || ring.count == 0) continue;

        final lumaDelta = center.meanLuma - ring.meanLuma;
        final sat = center.meanSaturation;

        if (lumaDelta <= -20) {
          board[row][col] = StoneColor.black;
        } else if (lumaDelta >= 17 && sat <= 0.35) {
          board[row][col] = StoneColor.white;
        }
      }
    }

    return board;
  }

  static _SampleStats _sampleDisk(
      img.Image image, double cx, double cy, double r) {
    var lumaSum = 0.0;
    var satSum = 0.0;
    var count = 0;

    final radius = r.ceil();
    final r2 = r * r;
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final d2 = dx * dx + dy * dy;
        if (d2 > r2) continue;
        final x = (cx + dx).round();
        final y = (cy + dy).round();
        if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
        final pixel = image.getPixel(x, y);
        lumaSum +=
            _luma(pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble());
        satSum += _saturation(
            pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble());
        count++;
      }
    }

    return _SampleStats(
      meanLuma: count == 0 ? 0 : lumaSum / count,
      meanSaturation: count == 0 ? 0 : satSum / count,
      count: count,
    );
  }

  static _SampleStats _sampleRing(
    img.Image image,
    double cx,
    double cy,
    double inner,
    double outer,
  ) {
    var lumaSum = 0.0;
    var satSum = 0.0;
    var count = 0;

    final radius = outer.ceil();
    final inner2 = inner * inner;
    final outer2 = outer * outer;
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final d2 = dx * dx + dy * dy;
        if (d2 <= inner2 || d2 > outer2) continue;
        final x = (cx + dx).round();
        final y = (cy + dy).round();
        if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
        final pixel = image.getPixel(x, y);
        lumaSum +=
            _luma(pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble());
        satSum += _saturation(
            pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble());
        count++;
      }
    }

    return _SampleStats(
      meanLuma: count == 0 ? 0 : lumaSum / count,
      meanSaturation: count == 0 ? 0 : satSum / count,
      count: count,
    );
  }

  static double _luma(double r, double g, double b) {
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _saturation(double r, double g, double b) {
    final maxV = math.max(r, math.max(g, b));
    final minV = math.min(r, math.min(g, b));
    if (maxV <= 0) return 0;
    return (maxV - minV) / maxV;
  }
}

class _LumaMap {
  _LumaMap({
    required this.width,
    required this.height,
    required this.luma,
    required this.darkThreshold,
  });

  final int width;
  final int height;
  final Uint8List luma;
  final int darkThreshold;

  factory _LumaMap.fromImage(img.Image image) {
    final values = Uint8List(image.width * image.height);
    final histogram = List<int>.filled(256, 0);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final lum = BoardImageRecognizer._luma(
          pixel.r.toDouble(),
          pixel.g.toDouble(),
          pixel.b.toDouble(),
        ).round().clamp(0, 255).toInt();
        values[y * image.width + x] = lum;
        histogram[lum]++;
      }
    }

    final darkThreshold = _histPercentile(histogram, 0.24).clamp(50, 140);

    return _LumaMap(
      width: image.width,
      height: image.height,
      luma: values,
      darkThreshold: darkThreshold,
    );
  }

  static int _histPercentile(List<int> hist, double p) {
    final total = hist.fold<int>(0, (a, b) => a + b);
    final target = (total * p).round();
    var run = 0;
    for (int i = 0; i < hist.length; i++) {
      run += hist[i];
      if (run >= target) return i;
    }
    return 128;
  }

  double darknessAlongLine({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required double thickness,
  }) {
    final length = math.max((x2 - x1).abs(), (y2 - y1).abs()).round();
    if (length <= 0) return 0;

    var darkCount = 0;
    var total = 0;

    final t = thickness.ceil();
    for (int i = 0; i <= length; i++) {
      final f = i / length;
      final x = x1 + (x2 - x1) * f;
      final y = y1 + (y2 - y1) * f;

      for (int dx = -t; dx <= t; dx++) {
        for (int dy = -t; dy <= t; dy++) {
          final sx = (x + dx).round();
          final sy = (y + dy).round();
          if (sx < 0 || sy < 0 || sx >= width || sy >= height) continue;
          final lum = luma[sy * width + sx];
          if (lum <= darkThreshold) darkCount++;
          total++;
        }
      }
    }

    if (total == 0) return 0;
    return darkCount / total;
  }

  double meanLuma({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    var sum = 0.0;
    var count = 0;
    final l = left.round().clamp(0, this.width - 1);
    final t = top.round().clamp(0, this.height - 1);
    final r = (left + width).round().clamp(0, this.width - 1);
    final b = (top + height).round().clamp(0, this.height - 1);
    for (int y = t; y <= b; y++) {
      for (int x = l; x <= r; x++) {
        sum += luma[y * this.width + x];
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  double darkRatioInRect({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    var dark = 0;
    var total = 0;
    final l = left.round().clamp(0, this.width - 1);
    final t = top.round().clamp(0, this.height - 1);
    final r = (left + width).round().clamp(0, this.width - 1);
    final b = (top + height).round().clamp(0, this.height - 1);
    for (int y = t; y <= b; y++) {
      for (int x = l; x <= r; x++) {
        if (luma[y * this.width + x] <= darkThreshold) dark++;
        total++;
      }
    }
    return total == 0 ? 0 : dark / total;
  }

  double meanLumaOnBorder({
    required double left,
    required double top,
    required double side,
    required double thickness,
  }) {
    final t = thickness.round().clamp(1, 8);
    final l = left.round();
    final up = top.round();
    final r = (left + side).round();
    final b = (top + side).round();

    var sum = 0.0;
    var count = 0;

    for (int y = up; y <= b; y++) {
      for (int x = l; x <= r; x++) {
        if (x < 0 || y < 0 || x >= width || y >= height) continue;
        final isBorder = x <= l + t || x >= r - t || y <= up + t || y >= b - t;
        if (!isBorder) continue;
        sum += luma[y * width + x];
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }
}

class _GridCandidate {
  const _GridCandidate({
    required this.left,
    required this.top,
    required this.side,
    required this.boardSize,
    required this.rawScore,
    required this.confidence,
  });

  final double left;
  final double top;
  final double side;
  final int boardSize;
  final double rawScore;
  final double confidence;
}

class _SampleStats {
  const _SampleStats({
    required this.meanLuma,
    required this.meanSaturation,
    required this.count,
  });

  final double meanLuma;
  final double meanSaturation;
  final int count;
}
