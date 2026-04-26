import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/widgets/go_particle_hero_background.dart';

/// Minimal host app that renders only the particle background at a fixed
/// 390×844 viewport (iPhone 12 logical points).
class _BackgroundTestApp extends StatelessWidget {
  const _BackgroundTestApp({required this.preset});

  final GoScenePreset preset;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(
        child: Stack(
          children: [
            Positioned.fill(
              child: GoParticleHeroBackground(
                preset: preset,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  // ── Smoke / render tests ──────────────────────────────────────────────────

  testWidgets('GoParticleHeroBackground renders without errors',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const _BackgroundTestApp(preset: GoScenePreset.defaultPreset),
    );
    await tester.pump();

    expect(find.byType(GoParticleHeroBackground), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GoParticleHeroBackground renders for 13×13 board',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const preset = GoScenePreset(
      boardSize: 13,
      stones: [
        GoSceneStone(col: 3, row: 3, isBlack: true),
        GoSceneStone(col: 9, row: 3, isBlack: false),
        GoSceneStone(col: 6, row: 6, isBlack: true),
      ],
    );

    await tester.pumpWidget(const _BackgroundTestApp(preset: preset));
    await tester.pump();

    expect(find.byType(GoParticleHeroBackground), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GoParticleHeroBackground renders for 19×19 board',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const preset = GoScenePreset(boardSize: 19, stones: []);

    await tester.pumpWidget(const _BackgroundTestApp(preset: preset));
    await tester.pump();

    expect(find.byType(GoParticleHeroBackground), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GoParticleHeroBackground accepts custom intensity and blurStrength',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: CupertinoPageScaffold(
          child: Stack(
            children: [
              Positioned.fill(
                child: GoParticleHeroBackground(
                  preset: GoScenePreset.defaultPreset,
                  intensity: 0.5,
                  blurStrength: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(GoParticleHeroBackground), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── Screenshot capture test ───────────────────────────────────────────────

  const shouldCapture =
      bool.fromEnvironment('CAPTURE_PARTICLE_SCREENSHOT');
  const screenshotPath =
      String.fromEnvironment('CAPTURE_PARTICLE_SCREENSHOT_PATH');

  testWidgets(
    'captures GoParticleHeroBackground screenshot',
    skip: !shouldCapture,
    timeout: const Timeout(Duration(seconds: 30)),
    (tester) async {
      if (screenshotPath.isEmpty) {
        throw StateError('CAPTURE_PARTICLE_SCREENSHOT_PATH must be set.');
      }

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final captureKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: const _BackgroundTestApp(preset: GoScenePreset.defaultPreset),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );

      final result = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });

      if (result == null) throw StateError('PNG encoding failed.');

      final file = File(screenshotPath);
      await tester.runAsync(() async {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          result.buffer.asUint8List(result.offsetInBytes, result.lengthInBytes),
        );
      });

      expect(file.existsSync(), isTrue);
    },
  );
}
