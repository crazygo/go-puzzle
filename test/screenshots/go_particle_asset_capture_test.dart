import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/widgets/go_particle_hero_background.dart';

Future<void> _captureBoundary(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String outputPath,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  if (bytes == null) {
    throw StateError('PNG encoding failed for $outputPath');
  }

  final file = File(outputPath);
  await tester.runAsync(() async {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  });
}

void main() {
  const shouldCapture = bool.fromEnvironment('CAPTURE_GO_ASSET');
  const assetPath =
      String.fromEnvironment('CAPTURE_GO_ASSET_PATH', defaultValue: '');
  const previewPath =
      String.fromEnvironment('CAPTURE_GO_PREVIEW_PATH', defaultValue: '');

  testWidgets(
    'capture polished Go board asset only',
    skip: !shouldCapture,
    (tester) async {
      if (assetPath.isEmpty) {
        throw StateError('CAPTURE_GO_ASSET_PATH must be set.');
      }

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      await tester.pumpWidget(
        CupertinoApp(
          home: RepaintBoundary(
            key: key,
            child: const CupertinoPageScaffold(
              child: SizedBox.expand(
                child: GoParticleHeroBackground(
                  preset: GoScenePreset.defaultPreset,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await _captureBoundary(tester, key, assetPath);
    },
  );

  testWidgets(
    'capture preview screen with debug panel',
    skip: !shouldCapture,
    (tester) async {
      if (previewPath.isEmpty) {
        throw StateError('CAPTURE_GO_PREVIEW_PATH must be set.');
      }

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();

      await tester.pumpWidget(
        CupertinoApp(
          home: RepaintBoundary(
            key: key,
            child: CupertinoPageScaffold(
              navigationBar: const CupertinoNavigationBar(
                middle: Text('粒子背景预览'),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: GoParticleHeroBackground(
                      preset: GoScenePreset.defaultPreset,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground
                              .withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PanelSlider(label: '强度', value: '1.00'),
                            _PanelSlider(label: '模糊', value: '1.00'),
                            _PanelSlider(label: '暖色', value: '1.00'),
                            _PanelSlider(label: '景深', value: '1.00'),
                            _PanelSlider(label: '渐隐', value: '0.58'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await _captureBoundary(tester, key, previewPath);
    },
  );
}

class _PanelSlider extends StatelessWidget {
  const _PanelSlider({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: CupertinoColors.secondaryLabel),
            ),
          ),
          const Expanded(
            child: SizedBox(
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFB87A3C)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
                fontSize: 11, color: CupertinoColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
