import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const shouldCapture = bool.fromEnvironment('CAPTURE_SCREENSHOTS');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'captures first screen screenshot',
    skip: !shouldCapture,
    (tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize =
          const Size(1170, 2532); // iPhone 12/13/14 portrait
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const GoPuzzleApp());
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(GoPuzzleApp),
        matchesGoldenFile('first_screen.png'),
      );
    },
  );
}
