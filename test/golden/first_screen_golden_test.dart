import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('capture first screen renders', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize =
        const Size(1170, 2532); // iPhone 12/13/14 portrait
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('小闲围棋'), findsWidgets);
    expect(find.text('AI 风格'), findsOneWidget);
    expect(find.text('开始对弈'), findsOneWidget);
  });
}
