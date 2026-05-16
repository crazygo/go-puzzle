import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../models/board_position.dart';
import '../services/app_log_store.dart';
import 'board_image_recognizer.dart';
import 'model_board_image_recognizer.dart' as public;

public.ModelBoardImageRecognizer createPlatformModelBoardImageRecognizer() =>
    _NativeModelBoardImageRecognizer();

class _NativeModelBoardImageRecognizer
    implements public.ModelBoardImageRecognizer {
  static const String boardPoseAsset = 'go_board_pose_yolov8n.onnx';
  static const String stonesAsset = 'go_stones_yolov8n.onnx';

  static const int _inputSize = 640;
  static const double _boardConfidence = 0.01;
  static const double _stoneConfidence = 0.25;
  static const double _stoneIou = 0.7;
  static const double _maxStoneDistanceRatio = 0.58;
  static const MethodChannel _assetChannel =
      MethodChannel('go_puzzle/model_assets');

  final OnnxRuntime _runtime = OnnxRuntime();
  Future<void>? _loading;
  OrtSession? _boardPoseSession;
  OrtSession? _stonesSession;

  @override
  Future<void> ensureLoaded() {
    final existing = _loading;
    if (existing != null) return existing;
    final loading = _load();
    _loading = loading;
    return loading;
  }

  @override
  Future<void> reload() async {
    await dispose();
    _loading = _load();
    return _loading;
  }

  @override
  Future<void> dispose() async {
    final boardSession = _boardPoseSession;
    final stonesSession = _stonesSession;
    _boardPoseSession = null;
    _stonesSession = null;
    _loading = null;
    await boardSession?.close();
    await stonesSession?.close();
  }

  Future<void> _load() async {
    try {
      final options = OrtSessionOptions();
      _boardPoseSession = await _runtime.createSession(
        await _nativeModelPath(boardPoseAsset),
        options: options,
      );
      _stonesSession = await _runtime.createSession(
        await _nativeModelPath(stonesAsset),
        options: options,
      );
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  Future<String> _nativeModelPath(String fileName) async {
    final path = await _assetChannel.invokeMethod<String>(
      'modelPath',
      {'fileName': fileName},
    );
    if (path == null || path.isEmpty) {
      throw StateError('找不到內置模型：$fileName');
    }
    return path;
  }

  @override
  Future<BoardRecognitionResult> recognize(Uint8List bytes) async {
    await ensureLoaded();
    final boardSession = _boardPoseSession;
    final stonesSession = _stonesSession;
    if (boardSession == null || stonesSession == null) {
      throw StateError('模型尚未載入');
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('無法解析圖片');
    final image = img.bakeOrientation(decoded);
    final input = _YoloInput.fromImage(image, size: _inputSize);

    final poseOutput = await _runYolo(
      boardSession,
      input.tensor,
      channels: 19,
      classStart: 4,
      classCount: 3,
      confidenceThreshold: _boardConfidence,
    );
    final poseDiagnostics = _PoseDiagnostics.fromOutput(
      poseOutput,
      input: input,
      threshold: _boardConfidence,
    );
    if (poseDiagnostics.outputLength < poseDiagnostics.expectedLength) {
      AppLogStore.instance.add(
        category: AppLogCategory.screenshotRecognition,
        level: AppLogLevel.error,
        message: '棋盤邊界模型輸出格式異常',
        details: poseDiagnostics.format(
          decodedWidth: decoded.width,
          decodedHeight: decoded.height,
          orientedWidth: image.width,
          orientedHeight: image.height,
          bytes: bytes.length,
        ),
      );
      throw const FormatException('模型輸出格式不符合預期');
    }
    final roughPose = _extractPose(poseOutput, input);
    if (roughPose == null) {
      AppLogStore.instance.add(
        category: AppLogCategory.screenshotRecognition,
        level: AppLogLevel.error,
        message: '棋盤邊界模型沒有候選',
        details: poseDiagnostics.format(
          decodedWidth: decoded.width,
          decodedHeight: decoded.height,
          orientedWidth: image.width,
          orientedHeight: image.height,
          bytes: bytes.length,
        ),
      );
      throw const FormatException('未能辨識棋盤邊界');
    }

    final refinedPose = _BoardPoseRefiner.refine(
      image,
      boardSize: roughPose.boardSize,
      corners: roughPose.corners,
      box: roughPose.box,
      confidence: roughPose.confidence,
    );

    final stonesOutput = await _runYolo(
      stonesSession,
      input.tensor,
      channels: 6,
      classStart: 4,
      classCount: 2,
      confidenceThreshold: _stoneConfidence,
    );
    final detections = _extractStoneDetections(stonesOutput, input);
    final board = _stonesToBoard(detections, refinedPose);

    return BoardRecognitionResult(
      boardSize: refinedPose.boardSize,
      board: board,
      confidence: roughPose.confidence,
    );
  }

  Future<_YoloOutput> _runYolo(
    OrtSession session,
    Float32List input, {
    required int channels,
    required int classStart,
    required int classCount,
    required double confidenceThreshold,
  }) async {
    OrtValue? inputTensor;
    Map<String, OrtValue> outputs = const {};
    try {
      final inputName =
          session.inputNames.isNotEmpty ? session.inputNames.first : 'images';
      inputTensor = await OrtValue.fromList(
        input,
        const [1, 3, _inputSize, _inputSize],
      );
      outputs = await session.run({inputName: inputTensor});
      final outputName =
          outputs.containsKey('output0') ? 'output0' : outputs.keys.first;
      final output = outputs[outputName]!;
      final values = await output.asFlattenedList();
      final data = values.map((value) => (value as num).toDouble()).toList();
      return _YoloOutput.fromFlatData(
        data,
        shape: output.shape,
        expectedChannels: channels,
        classStart: classStart,
        classCount: classCount,
        confidenceThreshold: confidenceThreshold,
      );
    } finally {
      await inputTensor?.dispose();
      for (final output in outputs.values) {
        await output.dispose();
      }
    }
  }

  _PosePrediction? _extractPose(_YoloOutput output, _YoloInput input) {
    final anchors = output.anchors;
    _PosePrediction? best;
    for (var anchor = 0; anchor < anchors; anchor++) {
      var bestClass = 0;
      var bestScore = output.value(4, anchor);
      for (var classId = 1; classId < 3; classId++) {
        final score = output.value(4 + classId, anchor);
        if (score > bestScore) {
          bestClass = classId;
          bestScore = score;
        }
      }
      if (bestScore < _boardConfidence) continue;

      final cx = output.value(0, anchor);
      final cy = output.value(1, anchor);
      final w = output.value(2, anchor);
      final h = output.value(3, anchor);
      final corners = <_Point>[];
      var keypointConfidence = 0.0;
      for (var i = 0; i < 4; i++) {
        final base = 7 + i * 3;
        final x = output.value(base, anchor);
        final y = output.value(base + 1, anchor);
        keypointConfidence += output.value(base + 2, anchor);
        corners.add(input.toOriginalPoint(x, y));
      }
      keypointConfidence /= 4;
      final score = bestScore * math.max(0.25, keypointConfidence);
      final candidate = _PosePrediction(
        boardSize: const [9, 13, 19][bestClass],
        corners: corners,
        confidence: bestScore,
        score: score,
        box: input.toOriginalBox(cx, cy, w, h),
      );
      if (best == null || candidate.score > best.score) best = candidate;
    }
    return best;
  }

  List<_StoneDetection> _extractStoneDetections(
    _YoloOutput output,
    _YoloInput input,
  ) {
    final anchors = output.anchors;
    final candidates = <_StoneDetection>[];
    for (var anchor = 0; anchor < anchors; anchor++) {
      final blackScore = output.value(4, anchor);
      final whiteScore = output.value(5, anchor);
      final isBlack = blackScore >= whiteScore;
      final confidence = isBlack ? blackScore : whiteScore;
      if (confidence < _stoneConfidence) continue;

      final cx = output.value(0, anchor);
      final cy = output.value(1, anchor);
      final w = output.value(2, anchor);
      final h = output.value(3, anchor);
      candidates.add(
        _StoneDetection(
          box: input.toOriginalBox(cx, cy, w, h),
          color: isBlack ? StoneColor.black : StoneColor.white,
          confidence: confidence,
        ),
      );
    }
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <_StoneDetection>[];
    for (final candidate in candidates) {
      final overlaps = kept.any(
        (existing) =>
            existing.color == candidate.color &&
            _boxIou(existing.box, candidate.box) > _stoneIou,
      );
      if (!overlaps) kept.add(candidate);
    }
    return kept;
  }

  List<List<StoneColor>> _stonesToBoard(
    List<_StoneDetection> detections,
    _RefinedBoardPose pose,
  ) {
    final board = List.generate(
      pose.boardSize,
      (_) => List<StoneColor>.filled(pose.boardSize, StoneColor.empty),
    );
    final confidence = List.generate(
      pose.boardSize,
      (_) => List<double>.filled(pose.boardSize, -1),
    );
    final step = pose.averageGridStep;
    for (final detection in detections) {
      final center = detection.box.center;
      final nearest = pose.nearestIntersection(center.x, center.y);
      if (nearest.distance / math.max(1, step) > _maxStoneDistanceRatio) {
        continue;
      }
      if (detection.confidence > confidence[nearest.row][nearest.col]) {
        board[nearest.row][nearest.col] = detection.color;
        confidence[nearest.row][nearest.col] = detection.confidence;
      }
    }
    return board;
  }
}

class _YoloInput {
  const _YoloInput({
    required this.tensor,
    required this.originalWidth,
    required this.originalHeight,
    required this.scale,
    required this.padX,
    required this.padY,
  });

  final Float32List tensor;
  final int originalWidth;
  final int originalHeight;
  final double scale;
  final double padX;
  final double padY;

  static _YoloInput fromImage(img.Image image, {required int size}) {
    final scale = math.min(size / image.width, size / image.height);
    final resizedWidth = (image.width * scale).round().clamp(1, size);
    final resizedHeight = (image.height * scale).round().clamp(1, size);
    final padX = ((size - resizedWidth) / 2).roundToDouble();
    final padY = ((size - resizedHeight) / 2).roundToDouble();
    final resized = img.copyResize(
      image,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );
    final tensor = Float32List(1 * 3 * size * size);
    final channelSize = size * size;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        var r = 114 / 255.0;
        var g = 114 / 255.0;
        var b = 114 / 255.0;
        final rx = x - padX.toInt();
        final ry = y - padY.toInt();
        if (rx >= 0 && rx < resizedWidth && ry >= 0 && ry < resizedHeight) {
          final pixel = resized.getPixel(rx, ry);
          r = pixel.rNormalized.toDouble();
          g = pixel.gNormalized.toDouble();
          b = pixel.bNormalized.toDouble();
        }
        final offset = y * size + x;
        tensor[offset] = r;
        tensor[channelSize + offset] = g;
        tensor[channelSize * 2 + offset] = b;
      }
    }
    return _YoloInput(
      tensor: tensor,
      originalWidth: image.width,
      originalHeight: image.height,
      scale: scale,
      padX: padX,
      padY: padY,
    );
  }

  _Point toOriginalPoint(double x, double y) {
    return _Point(
      ((x - padX) / scale).clamp(0.0, originalWidth.toDouble()),
      ((y - padY) / scale).clamp(0.0, originalHeight.toDouble()),
    );
  }

  _Box toOriginalBox(double cx, double cy, double w, double h) {
    final x1 = (cx - w / 2 - padX) / scale;
    final y1 = (cy - h / 2 - padY) / scale;
    final x2 = (cx + w / 2 - padX) / scale;
    final y2 = (cy + h / 2 - padY) / scale;
    return _Box(
      x1.clamp(0.0, originalWidth.toDouble()),
      y1.clamp(0.0, originalHeight.toDouble()),
      x2.clamp(0.0, originalWidth.toDouble()),
      y2.clamp(0.0, originalHeight.toDouble()),
    );
  }
}

enum _YoloOutputLayout { channelMajor, anchorMajor }

class _YoloOutput {
  const _YoloOutput({
    required this.data,
    required this.shape,
    required this.channels,
    required this.anchors,
    required this.layout,
    required this.channelMajorScore,
    required this.anchorMajorScore,
  });

  final List<double> data;
  final List<int> shape;
  final int channels;
  final int anchors;
  final _YoloOutputLayout layout;
  final _YoloLayoutScore channelMajorScore;
  final _YoloLayoutScore anchorMajorScore;

  int get length => data.length;

  double value(int channel, int anchor) {
    if (channel < 0 || channel >= channels || anchor < 0 || anchor >= anchors) {
      return 0;
    }
    final index = layout == _YoloOutputLayout.channelMajor
        ? channel * anchors + anchor
        : anchor * channels + channel;
    return index >= 0 && index < data.length ? data[index] : 0;
  }

  static _YoloOutput fromFlatData(
    List<double> data, {
    required List<int> shape,
    required int expectedChannels,
    required int classStart,
    required int classCount,
    required double confidenceThreshold,
  }) {
    final anchors = data.length ~/ expectedChannels;
    final channelMajorScore = _YoloLayoutScore.fromData(
      data,
      layout: _YoloOutputLayout.channelMajor,
      channels: expectedChannels,
      anchors: anchors,
      classStart: classStart,
      classCount: classCount,
      confidenceThreshold: confidenceThreshold,
    );
    final anchorMajorScore = _YoloLayoutScore.fromData(
      data,
      layout: _YoloOutputLayout.anchorMajor,
      channels: expectedChannels,
      anchors: anchors,
      classStart: classStart,
      classCount: classCount,
      confidenceThreshold: confidenceThreshold,
    );
    final shapeLayout = _layoutFromShape(shape, expectedChannels, anchors);
    final layout = _chooseLayout(
      channelMajorScore,
      anchorMajorScore,
      shapeLayout: shapeLayout,
    );
    return _YoloOutput(
      data: data,
      shape: shape,
      channels: expectedChannels,
      anchors: anchors,
      layout: layout,
      channelMajorScore: channelMajorScore,
      anchorMajorScore: anchorMajorScore,
    );
  }

  static _YoloOutputLayout? _layoutFromShape(
    List<int> shape,
    int channels,
    int anchors,
  ) {
    if (shape.length < 3) return null;
    if (shape[1] == channels && shape[2] == anchors) {
      return _YoloOutputLayout.channelMajor;
    }
    if (shape[1] == anchors && shape[2] == channels) {
      return _YoloOutputLayout.anchorMajor;
    }
    return null;
  }

  static _YoloOutputLayout _chooseLayout(
    _YoloLayoutScore channelMajor,
    _YoloLayoutScore anchorMajor, {
    required _YoloOutputLayout? shapeLayout,
  }) {
    if (channelMajor.plausible != anchorMajor.plausible) {
      return channelMajor.plausible
          ? _YoloOutputLayout.channelMajor
          : _YoloOutputLayout.anchorMajor;
    }
    if (channelMajor.plausible && anchorMajor.plausible) {
      if (channelMajor.candidatesAboveThreshold !=
          anchorMajor.candidatesAboveThreshold) {
        return channelMajor.candidatesAboveThreshold >
                anchorMajor.candidatesAboveThreshold
            ? _YoloOutputLayout.channelMajor
            : _YoloOutputLayout.anchorMajor;
      }
      if (shapeLayout != null) return shapeLayout;
      return channelMajor.maxClassScore >= anchorMajor.maxClassScore
          ? _YoloOutputLayout.channelMajor
          : _YoloOutputLayout.anchorMajor;
    }
    return shapeLayout ?? _YoloOutputLayout.channelMajor;
  }
}

class _YoloLayoutScore {
  const _YoloLayoutScore({
    required this.layout,
    required this.maxClassScore,
    required this.candidatesAboveThreshold,
    required this.bestClassId,
    required this.bestAnchor,
  });

  final _YoloOutputLayout layout;
  final double maxClassScore;
  final int candidatesAboveThreshold;
  final int bestClassId;
  final int bestAnchor;

  bool get plausible => maxClassScore >= 0 && maxClassScore <= 1.5;

  static _YoloLayoutScore fromData(
    List<double> data, {
    required _YoloOutputLayout layout,
    required int channels,
    required int anchors,
    required int classStart,
    required int classCount,
    required double confidenceThreshold,
  }) {
    var candidates = 0;
    var bestClassId = -1;
    var bestAnchor = -1;
    var maxClassScore = -double.infinity;
    for (var anchor = 0; anchor < anchors; anchor++) {
      var classId = 0;
      var classScore = _value(
        data,
        layout: layout,
        channels: channels,
        anchors: anchors,
        channel: classStart,
        anchor: anchor,
      );
      for (var offset = 1; offset < classCount; offset++) {
        final score = _value(
          data,
          layout: layout,
          channels: channels,
          anchors: anchors,
          channel: classStart + offset,
          anchor: anchor,
        );
        if (score > classScore) {
          classId = offset;
          classScore = score;
        }
      }
      if (classScore > maxClassScore) {
        maxClassScore = classScore;
        bestClassId = classId;
        bestAnchor = anchor;
      }
      if (classScore >= confidenceThreshold && classScore <= 1.5) candidates++;
    }
    return _YoloLayoutScore(
      layout: layout,
      maxClassScore: maxClassScore.isFinite ? maxClassScore : 0,
      candidatesAboveThreshold: candidates,
      bestClassId: bestClassId,
      bestAnchor: bestAnchor,
    );
  }

  static double _value(
    List<double> data, {
    required _YoloOutputLayout layout,
    required int channels,
    required int anchors,
    required int channel,
    required int anchor,
  }) {
    final index = layout == _YoloOutputLayout.channelMajor
        ? channel * anchors + anchor
        : anchor * channels + channel;
    return index >= 0 && index < data.length ? data[index] : 0;
  }
}

class _PoseDiagnostics {
  const _PoseDiagnostics({
    required this.outputLength,
    required this.expectedLength,
    required this.shape,
    required this.layout,
    required this.channelMajorScore,
    required this.anchorMajorScore,
    required this.anchors,
    required this.candidatesAboveThreshold,
    required this.maxRawValue,
    required this.minRawValue,
    required this.bestClassId,
    required this.bestClassScore,
    required this.bestKeypointConfidence,
    required this.bestCombinedScore,
    required this.bestBox,
    required this.input,
  });

  final int outputLength;
  final int expectedLength;
  final List<int> shape;
  final _YoloOutputLayout layout;
  final _YoloLayoutScore channelMajorScore;
  final _YoloLayoutScore anchorMajorScore;
  final int anchors;
  final int candidatesAboveThreshold;
  final double maxRawValue;
  final double minRawValue;
  final int bestClassId;
  final double bestClassScore;
  final double bestKeypointConfidence;
  final double bestCombinedScore;
  final _Box? bestBox;
  final _YoloInput input;

  static _PoseDiagnostics fromOutput(
    _YoloOutput output, {
    required _YoloInput input,
    required double threshold,
  }) {
    final anchors = output.anchors;
    final expectedLength = output.channels * anchors;
    var minRawValue = double.infinity;
    var maxRawValue = -double.infinity;
    for (final value in output.data) {
      if (value < minRawValue) minRawValue = value;
      if (value > maxRawValue) maxRawValue = value;
    }

    var candidates = 0;
    var bestClassId = -1;
    var bestClassScore = -double.infinity;
    var bestKeypointConfidence = 0.0;
    var bestCombinedScore = -double.infinity;
    _Box? bestBox;

    if (output.length >= expectedLength && anchors > 0) {
      for (var anchor = 0; anchor < anchors; anchor++) {
        var classId = 0;
        var classScore = output.value(4, anchor);
        for (var candidateClassId = 1;
            candidateClassId < 3;
            candidateClassId++) {
          final score = output.value(4 + candidateClassId, anchor);
          if (score > classScore) {
            classId = candidateClassId;
            classScore = score;
          }
        }
        if (classScore >= threshold) candidates++;

        var keypointConfidence = 0.0;
        for (var i = 0; i < 4; i++) {
          final base = 7 + i * 3;
          keypointConfidence += output.value(base + 2, anchor);
        }
        keypointConfidence /= 4;

        final combinedScore = classScore * math.max(0.25, keypointConfidence);
        if (combinedScore > bestCombinedScore) {
          bestClassId = classId;
          bestClassScore = classScore;
          bestKeypointConfidence = keypointConfidence;
          bestCombinedScore = combinedScore;
          bestBox = input.toOriginalBox(
            output.value(0, anchor),
            output.value(1, anchor),
            output.value(2, anchor),
            output.value(3, anchor),
          );
        }
      }
    }

    return _PoseDiagnostics(
      outputLength: output.length,
      expectedLength: expectedLength,
      shape: output.shape,
      layout: output.layout,
      channelMajorScore: output.channelMajorScore,
      anchorMajorScore: output.anchorMajorScore,
      anchors: anchors,
      candidatesAboveThreshold: candidates,
      maxRawValue: maxRawValue.isFinite ? maxRawValue : 0,
      minRawValue: minRawValue.isFinite ? minRawValue : 0,
      bestClassId: bestClassId,
      bestClassScore: bestClassScore.isFinite ? bestClassScore : 0,
      bestKeypointConfidence:
          bestKeypointConfidence.isFinite ? bestKeypointConfidence : 0,
      bestCombinedScore: bestCombinedScore.isFinite ? bestCombinedScore : 0,
      bestBox: bestBox,
      input: input,
    );
  }

  String format({
    required int decodedWidth,
    required int decodedHeight,
    required int orientedWidth,
    required int orientedHeight,
    required int bytes,
  }) {
    final boardSize = switch (bestClassId) {
      0 => 9,
      1 => 13,
      2 => 19,
      _ => null,
    };
    final box = bestBox;
    return [
      'bytes: $bytes',
      'decodedSize: ${decodedWidth}x$decodedHeight',
      'orientedSize: ${orientedWidth}x$orientedHeight',
      'inputSize: ${input.originalWidth}x${input.originalHeight}',
      'scale: ${input.scale.toStringAsFixed(6)}',
      'pad: ${input.padX.toStringAsFixed(1)}, ${input.padY.toStringAsFixed(1)}',
      'outputLength: $outputLength',
      'expectedLength: $expectedLength',
      'shape: ${shape.join('x')}',
      'layout: ${layout.name}',
      'anchors: $anchors',
      'rawRange: ${minRawValue.toStringAsFixed(6)}..${maxRawValue.toStringAsFixed(6)}',
      'threshold: ${_NativeModelBoardImageRecognizer._boardConfidence}',
      'candidatesAboveThreshold: $candidatesAboveThreshold',
      'channelMajor: max=${channelMajorScore.maxClassScore.toStringAsFixed(6)}, '
          'candidates=${channelMajorScore.candidatesAboveThreshold}, '
          'bestClass=${channelMajorScore.bestClassId}, '
          'bestAnchor=${channelMajorScore.bestAnchor}',
      'anchorMajor: max=${anchorMajorScore.maxClassScore.toStringAsFixed(6)}, '
          'candidates=${anchorMajorScore.candidatesAboveThreshold}, '
          'bestClass=${anchorMajorScore.bestClassId}, '
          'bestAnchor=${anchorMajorScore.bestAnchor}',
      'bestClassId: $bestClassId',
      'bestBoardSize: ${boardSize ?? '-'}',
      'bestClassScore: ${bestClassScore.toStringAsFixed(6)}',
      'bestKeypointConfidence: ${bestKeypointConfidence.toStringAsFixed(6)}',
      'bestCombinedScore: ${bestCombinedScore.toStringAsFixed(6)}',
      if (box != null)
        'bestBox: ${box.x1.toStringAsFixed(1)},${box.y1.toStringAsFixed(1)} '
            '${box.x2.toStringAsFixed(1)},${box.y2.toStringAsFixed(1)}',
    ].join('\n');
  }
}

class _BoardPoseRefiner {
  static const List<int> _boardSizes = [9, 13, 19];

  static _RefinedBoardPose refine(
    img.Image image, {
    required int boardSize,
    required List<_Point> corners,
    required _Box box,
    required double confidence,
  }) {
    final luma = _LumaImage.fromImage(image);
    final sizes = confidence < 0.5 ? _boardSizes : [boardSize];
    final candidates = sizes.map(
      (size) => _refineForSize(
        luma,
        boardSize: size,
        corners: corners,
        box: confidence < 0.5 ? box : null,
        driftBox: box,
        priorStrength: confidence < 0.5 ? 0.10 : 1.25,
      ),
    );
    return candidates.reduce(
      (best, candidate) => candidate.score > best.score ? candidate : best,
    );
  }

  static _RefinedBoardPose _refineForSize(
    _LumaImage luma, {
    required int boardSize,
    required List<_Point> corners,
    required _Box? box,
    required _Box driftBox,
    required double priorStrength,
  }) {
    var bounds = box ?? _axisAlignedBounds(corners);
    var x0 = bounds.x1;
    var y0 = bounds.y1;
    var x1 = bounds.x2;
    var y1 = bounds.y2;
    var score = 0.0;
    for (var i = 0; i < 2; i++) {
      final vertical = _verticalLineProfile(luma, y0, y1);
      final xResult = _searchPeriodicAxis(
        vertical,
        boardSize,
        x0,
        x1,
        priorStrength,
      );
      x0 = xResult.start;
      x1 = xResult.start + xResult.step * (boardSize - 1);

      final horizontal = _horizontalLineProfile(luma, x0, x1);
      final yResult = _searchPeriodicAxis(
        horizontal,
        boardSize,
        y0,
        y1,
        priorStrength,
      );
      y0 = yResult.start;
      y1 = yResult.start + yResult.step * (boardSize - 1);
      score = xResult.score + yResult.score;
    }

    final correctedX = _correctAxisDrift(
      x0,
      x1,
      boardSize,
      driftBox.x1,
      driftBox.x2,
      luma.width,
    );
    final correctedY = _correctAxisDrift(
      y0,
      y1,
      boardSize,
      driftBox.y1,
      driftBox.y2,
      luma.height,
    );
    x0 = correctedX.$1;
    x1 = correctedX.$2;
    y0 = correctedY.$1;
    y1 = correctedY.$2;

    return _RefinedBoardPose(
      boardSize: boardSize,
      corners: [
        _Point(x0, y0),
        _Point(x1, y0),
        _Point(x1, y1),
        _Point(x0, y1),
      ],
      score: score,
    );
  }

  static (double, double) _correctAxisDrift(
    double start,
    double end,
    int boardSize,
    double boxStart,
    double boxEnd,
    int imageLimit,
  ) {
    final step = (end - start) / math.max(1, boardSize - 1);
    if (end > boxEnd + step * 0.5 && start - step >= 0) {
      return (start - step, end - step);
    }
    if (start < boxStart - step * 0.5 && end + step <= imageLimit) {
      return (start + step, end + step);
    }
    return (start, end);
  }

  static _Box _axisAlignedBounds(List<_Point> corners) {
    final left = (corners[0].x + corners[3].x) / 2;
    final right = (corners[1].x + corners[2].x) / 2;
    final top = (corners[0].y + corners[1].y) / 2;
    final bottom = (corners[2].y + corners[3].y) / 2;
    return _Box(left, top, right, bottom);
  }

  static List<double> _verticalLineProfile(
    _LumaImage luma,
    double y0,
    double y1,
  ) {
    final top = y0.round().clamp(0, luma.height - 1);
    final bottom = math.max(top + 1, y1.round().clamp(0, luma.height));
    final profile = List<double>.filled(luma.width, 0);
    for (var x = 7; x < luma.width - 7; x++) {
      final center = luma.meanRect(x - 1, top, x + 2, bottom);
      final side = (luma.meanRect(x - 7, top, x - 4, bottom) +
              luma.meanRect(x + 4, top, x + 7, bottom)) /
          2;
      profile[x] = math.max(0, side - center);
    }
    return _smooth(profile);
  }

  static List<double> _horizontalLineProfile(
    _LumaImage luma,
    double x0,
    double x1,
  ) {
    final left = x0.round().clamp(0, luma.width - 1);
    final right = math.max(left + 1, x1.round().clamp(0, luma.width));
    final profile = List<double>.filled(luma.height, 0);
    for (var y = 7; y < luma.height - 7; y++) {
      final center = luma.meanRect(left, y - 1, right, y + 2);
      final side = (luma.meanRect(left, y - 7, right, y - 4) +
              luma.meanRect(left, y + 4, right, y + 7)) /
          2;
      profile[y] = math.max(0, side - center);
    }
    return _smooth(profile);
  }

  static List<double> _smooth(List<double> profile) {
    final result = List<double>.filled(profile.length, 0);
    for (var i = 0; i < profile.length; i++) {
      var sum = 0.0;
      var count = 0;
      for (var d = -2; d <= 2; d++) {
        final j = i + d;
        if (j < 0 || j >= profile.length) continue;
        sum += profile[j];
        count++;
      }
      result[i] = count == 0 ? profile[i] : sum / count;
    }
    return result;
  }

  static _AxisResult _searchPeriodicAxis(
    List<double> profile,
    int boardSize,
    double roughStart,
    double roughEnd,
    double priorStrength,
  ) {
    final roughStep = math.max(1.0, (roughEnd - roughStart) / (boardSize - 1));
    final stepDelta = math.max(1.0, roughStep * 0.01);
    final startDelta = math.max(1.0, roughStep * 0.01);
    var best = _AxisResult(
      score: double.negativeInfinity,
      start: roughStart,
      step: roughStep,
    );
    for (var step = math.max(8.0, roughStep * 0.55);
        step < roughStep * 1.30;
        step += stepDelta) {
      final maxStart = profile.length - step * (boardSize - 1);
      final startMin = math.max(0.0, roughStart - roughStep * 1.5);
      final startMax = math.min(maxStart, roughStart + roughStep * 1.5);
      for (var start = startMin; start < startMax; start += startDelta) {
        final end = start + step * (boardSize - 1);
        if (end >= profile.length) continue;
        var lineScore = 0.0;
        for (var i = 0; i < boardSize; i++) {
          lineScore += _localMax(profile, start + i * step);
        }
        lineScore /= boardSize;
        var midScore = 0.0;
        for (var i = 0; i < boardSize - 1; i++) {
          midScore += _localMax(profile, start + (i + 0.5) * step);
        }
        midScore /= math.max(1, boardSize - 1);
        var score = lineScore - 0.25 * midScore;
        final startDeltaRatio =
            (start - roughStart).abs() / math.max(1, roughStep);
        final stepDeltaRatio =
            (step - roughStep).abs() / math.max(1, roughStep);
        final prior = math.max(
          0.15,
          1.0 - priorStrength * (0.25 * startDeltaRatio + stepDeltaRatio),
        );
        score *= prior;
        if (score > best.score) {
          best = _AxisResult(score: score, start: start, step: step);
        }
      }
    }
    return best;
  }

  static double _localMax(List<double> profile, double index) {
    final center = index.round();
    final left = math.max(0, center - 2);
    final right = math.min(profile.length, center + 3);
    var result = 0.0;
    for (var i = left; i < right; i++) {
      result = math.max(result, profile[i]);
    }
    return result;
  }
}

class _LumaImage {
  _LumaImage(this.width, this.height, this._integral);

  final int width;
  final int height;
  final Float64List _integral;

  static _LumaImage fromImage(img.Image image) {
    final width = image.width;
    final height = image.height;
    final integral = Float64List((width + 1) * (height + 1));
    for (var y = 0; y < height; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        rowSum += 255 *
            (0.2126 * pixel.rNormalized +
                0.7152 * pixel.gNormalized +
                0.0722 * pixel.bNormalized);
        final index = (y + 1) * (width + 1) + x + 1;
        integral[index] = integral[y * (width + 1) + x + 1] + rowSum;
      }
    }
    return _LumaImage(width, height, integral);
  }

  double meanRect(int x0, int y0, int x1, int y1) {
    x0 = x0.clamp(0, width);
    x1 = x1.clamp(0, width);
    y0 = y0.clamp(0, height);
    y1 = y1.clamp(0, height);
    if (x0 >= x1 || y0 >= y1) return 0;
    final stride = width + 1;
    final sum = _integral[y1 * stride + x1] -
        _integral[y0 * stride + x1] -
        _integral[y1 * stride + x0] +
        _integral[y0 * stride + x0];
    return sum / ((x1 - x0) * (y1 - y0));
  }
}

class _PosePrediction {
  const _PosePrediction({
    required this.boardSize,
    required this.corners,
    required this.confidence,
    required this.score,
    required this.box,
  });

  final int boardSize;
  final List<_Point> corners;
  final double confidence;
  final double score;
  final _Box box;
}

class _RefinedBoardPose {
  const _RefinedBoardPose({
    required this.boardSize,
    required this.corners,
    required this.score,
  });

  final int boardSize;
  final List<_Point> corners;
  final double score;

  double get averageGridStep {
    if (boardSize <= 1) return 20;
    final top = corners[0].distanceTo(corners[1]) / (boardSize - 1);
    final right = corners[1].distanceTo(corners[2]) / (boardSize - 1);
    final bottom = corners[3].distanceTo(corners[2]) / (boardSize - 1);
    final left = corners[0].distanceTo(corners[3]) / (boardSize - 1);
    return (top + right + bottom + left) / 4;
  }

  _NearestIntersection nearestIntersection(double x, double y) {
    var best =
        const _NearestIntersection(row: 0, col: 0, distance: double.infinity);
    for (var row = 0; row < boardSize; row++) {
      for (var col = 0; col < boardSize; col++) {
        final point = gridPoint(row, col);
        final distance = point.distanceTo(_Point(x, y));
        if (distance < best.distance) {
          best = _NearestIntersection(row: row, col: col, distance: distance);
        }
      }
    }
    return best;
  }

  _Point gridPoint(int row, int col) {
    final u = boardSize <= 1 ? 0.0 : col / (boardSize - 1);
    final v = boardSize <= 1 ? 0.0 : row / (boardSize - 1);
    final top = _Point.lerp(corners[0], corners[1], u);
    final bottom = _Point.lerp(corners[3], corners[2], u);
    return _Point.lerp(top, bottom, v);
  }
}

class _StoneDetection {
  const _StoneDetection({
    required this.box,
    required this.color,
    required this.confidence,
  });

  final _Box box;
  final StoneColor color;
  final double confidence;
}

class _AxisResult {
  const _AxisResult({
    required this.score,
    required this.start,
    required this.step,
  });

  final double score;
  final double start;
  final double step;
}

class _NearestIntersection {
  const _NearestIntersection({
    required this.row,
    required this.col,
    required this.distance,
  });

  final int row;
  final int col;
  final double distance;
}

class _Box {
  const _Box(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  double get width => math.max(0, x2 - x1);
  double get height => math.max(0, y2 - y1);
  double get area => width * height;
  _Point get center => _Point((x1 + x2) / 2, (y1 + y2) / 2);
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(_Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static _Point lerp(_Point a, _Point b, double t) {
    return _Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }
}

double _boxIou(_Box a, _Box b) {
  final x1 = math.max(a.x1, b.x1);
  final y1 = math.max(a.y1, b.y1);
  final x2 = math.min(a.x2, b.x2);
  final y2 = math.min(a.y2, b.y2);
  final intersection = math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
  final union = a.area + b.area - intersection;
  return union <= 0 ? 0 : intersection / union;
}
