import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/screens/main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Font helpers ─────────────────────────────────────────────────────────────

const _kTestFontFamily = 'NotoSansSC';

/// Path where ensure-test-fonts.sh writes the full CJK font.
String get _subsetFontPath =>
    '${Directory.current.path}/.cache/fonts/NotoSansSC.ttf';

/// Loads the full NotoSansSC font and CupertinoIcons into Flutter's font
/// registry so CJK glyphs and tab-bar icons render correctly in the headless
/// renderer.
Future<void> _loadTestFont() async {
  // 1. CupertinoIcons — resolve path via package_config.json so it works on
  //    every machine and CI without hardcoding a pub-cache version string.
  final iconTtf = _resolvePackageAsset(
    'cupertino_icons',
    'assets/CupertinoIcons.ttf',
  );
  if (iconTtf != null) {
    final iconLoader = FontLoader('CupertinoIcons')
      ..addFont(Future.value(ByteData.sublistView(await iconTtf.readAsBytes())));
    await iconLoader.load();
  } else {
    debugPrint('[screenshot_test] WARNING: CupertinoIcons.ttf not found');
  }

  // 2. NotoSansSC subset for CJK characters
  final fontFile = File(_subsetFontPath);
  if (!fontFile.existsSync()) {
    debugPrint(
      '[screenshot_test] WARNING: NotoSansSC.ttf not found at $_subsetFontPath\n'
      '  Run: bash scripts/ensure-test-fonts.sh',
    );
    return;
  }
  final bytes = await fontFile.readAsBytes();
  final loader = FontLoader(_kTestFontFamily)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// Reads `.dart_tool/package_config.json` and returns the [File] for
/// [assetPath] inside [packageName], or `null` if not found.
File? _resolvePackageAsset(String packageName, String assetPath) {
  final configFile =
      File('${Directory.current.path}/.dart_tool/package_config.json');
  if (!configFile.existsSync()) return null;

  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = config['packages'] as List<dynamic>;
  for (final p in packages) {
    if ((p as Map<String, dynamic>)['name'] == packageName) {
      final rootUri = p['rootUri'] as String;
      // rootUri is either file:// absolute or relative to the config file.
      final Uri uri;
      if (rootUri.startsWith('file://')) {
        uri = Uri.parse(rootUri);
      } else {
        uri = configFile.parent.uri.resolve(rootUri);
      }
      final candidate = File(uri.toFilePath() + '/' + assetPath);
      return candidate.existsSync() ? candidate : null;
    }
  }
  return null;
}

// ── Test-only app widget ─────────────────────────────────────────────────────

/// Mirrors [GoPuzzleApp] but sets [_kTestFontFamily] on every Cupertino text
/// style so that CJK characters are rendered via the loaded subset font.
class _TestApp extends StatelessWidget {
  const _TestApp();

  static TextStyle _f(TextStyle base) =>
      base.copyWith(fontFamily: _kTestFontFamily);

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.systemBlue,
          textStyle: _f(const TextStyle(fontSize: 17)),
          actionTextStyle: _f(const TextStyle(
            fontSize: 17,
            color: CupertinoColors.activeBlue,
          )),
          tabLabelTextStyle: _f(const TextStyle(
            fontSize: 10,
            letterSpacing: -0.24,
            color: CupertinoColors.inactiveGray,
          )),
          navTitleTextStyle: _f(const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: CupertinoColors.label,
          )),
          navLargeTitleTextStyle: _f(const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.label,
          )),
          navActionTextStyle: _f(const TextStyle(
            fontSize: 17,
            color: CupertinoColors.activeBlue,
          )),
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}

// ── Test ─────────────────────────────────────────────────────────────────────

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

      // Load CJK font before rendering (must happen before pumpWidget).
      await tester.runAsync(_loadTestFont);

      // Use 1× pixel ratio so toImage() generates a modest-sized image
      // (390×844 px) that the headless software renderer can handle quickly.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844); // iPhone 12 logical pts
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final captureKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(key: captureKey, child: const _TestApp()),
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
        return image.toByteData(format: ui.ImageByteFormat.png);
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
