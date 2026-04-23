import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const shouldCapture = bool.fromEnvironment('CAPTURE_SCREENSHOTS');
  const screenshotPath = String.fromEnvironment('CAPTURE_SCREENSHOT_PATH');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'captures first screen screenshot',
    skip: !shouldCapture,
    timeout: const Timeout(Duration(seconds: 30)),
    (tester) async {
      if (screenshotPath.isEmpty) {
        throw StateError('CAPTURE_SCREENSHOT_PATH must be provided.');
      }

      // Use 1× pixel ratio so toImage() generates a modest-sized image
      // (390×844 px) that the headless software renderer can handle quickly.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844); // iPhone 12 logical pts
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final captureKey = GlobalKey();

      // pumpWidget renders the first frame; bounded pumps advance animations
      // without blocking on continuous tickers (avoids pumpAndSettle hang).
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: const GoPuzzleApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );

      // toImage() and toByteData() are GPU operations; runAsync lets them
      // complete on the real event loop instead of the fake test clock.
      final result = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData;
      });

      if (result == null) {
        throw StateError('Failed to encode screenshot as PNG.');
      }

      final screenshotFile = File(screenshotPath);
      await tester.runAsync(() async {
        await screenshotFile.parent.create(recursive: true);
        await screenshotFile.writeAsBytes(
          result.buffer.asUint8List(result.offsetInBytes, result.lengthInBytes),
        );
      });

      expect(screenshotFile.existsSync(), isTrue);
    },
  );
}
