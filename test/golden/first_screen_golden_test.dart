import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/screens/main_screen.dart';

void main() {
  testWidgets('capture first screen', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1170, 2532); // iPhone 12/13/14 portrait
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const configuredDir = String.fromEnvironment('SCREENSHOT_OUTPUT_DIR');
    final outputDir = configuredDir.isEmpty
        ? Directory('${Directory.systemTemp.path}/go-puzzle-screenshots')
        : Directory(configuredDir);
    await outputDir.create(recursive: true);

    await tester.pumpWidget(const CupertinoApp(home: MainScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('${outputDir.path}/first_screen.png'),
    );
  });
}
