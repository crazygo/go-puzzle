# Model Recognition Image Normalization Pitfall

This note records a runtime issue found while integrating ONNX screenshot recognition on iOS. It applies to the native Flutter path in `lib/game/model_board_image_recognizer_native.dart`.

## Symptom

The iOS app could load both bundled ONNX models successfully, but model screenshot recognition failed with no board candidate:

```text
模型載入完成
棋盤邊界模型沒有候選
shape: 1x19x8400
layout: channelMajor
channelMajor: max=0.004394, candidates=0
```

The same screenshot and the same ONNX model produced valid board candidates in local Python ONNX Runtime. Resizing the image to the same `945x2048` size used by `image_picker` did not reproduce the failure locally.

## Root Cause

The Dart `image` package does not guarantee that `pixel.r`, `pixel.g`, and `pixel.b` are always 8-bit `0..255` channel values. They reflect the image's decoded internal channel format. For higher precision PNGs or interpolated resized images, raw channel values can exceed 255 and can be fractional.

In the failing case, the Dart preprocessing path produced a tensor with a maximum value around `256.49` before the old `/ 255.0` normalization assumption was applied.

The old code assumed every decoded image was 8-bit RGB:

```dart
tensor[offset] = pixel.r / 255.0;
tensor[channelSize + offset] = pixel.g / 255.0;
tensor[channelSize * 2 + offset] = pixel.b / 255.0;
```

That assumption diverges from the YOLO training and Python ONNX preprocessing path, where model input must be normalized to `0..1`.

## Fix

Use the `image` package normalized channel accessors:

```dart
tensor[offset] = pixel.rNormalized.toDouble();
tensor[channelSize + offset] = pixel.gNormalized.toDouble();
tensor[channelSize * 2 + offset] = pixel.bNormalized.toDouble();
```

For luma/grid refinement code, also use normalized channels and scale back to a stable 8-bit luma range when needed:

```dart
rowSum += 255 *
    (0.2126 * pixel.rNormalized +
        0.7152 * pixel.gNormalized +
        0.0722 * pixel.bNormalized);
```

This keeps model input consistent across 8-bit PNGs, higher precision PNGs, and resized/interpolated images.

## Diagnostic Checklist

When ONNX output shape and length look correct but confidence scores are near zero:

- Check that the bundled model file hash matches the local asset.
- Log decoded image size, oriented image size, input scale, padding, output shape, raw output range, and max class score.
- Compare local Python ONNX Runtime against the same resized dimensions used by the app.
- Inspect the input tensor range before inference. For YOLO image input it should be approximately `0..1`, with letterbox padding around `114 / 255`.
- Avoid using raw `pixel.r/g/b` for model preprocessing unless the image format is explicitly converted to 8-bit first.

## Lesson

Model runtime bugs can look like poor model accuracy. Before blaming training data or overfitting, verify the full preprocessing contract:

- image orientation
- resize and letterbox parameters
- channel order
- channel normalization
- input tensor layout
- output tensor layout

For this project, the critical mistake was treating raw decoded pixel channels as fixed 8-bit values. Use normalized channel APIs for model input.
