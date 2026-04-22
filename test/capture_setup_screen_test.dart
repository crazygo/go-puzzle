import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('capture setup updates the summary', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pumpAndSettle();

    expect(find.text('吃子练习'), findsOneWidget);
    expect(find.text('练习设置'), findsOneWidget);
    expect(find.text('难度'), findsOneWidget);
    expect(find.text('中级 · 9路 · 吃5子'), findsOneWidget);

    await tester.tap(find.text('13路'));
    await tester.pumpAndSettle();
    expect(find.text('中级 · 13路 · 吃5子'), findsOneWidget);

    await tester.tap(find.text('高级'));
    await tester.pumpAndSettle();
    expect(find.text('高级 · 13路 · 吃5子'), findsOneWidget);

    final startButton = find.widgetWithText(CupertinoButton, '开始练习');
    expect(startButton, findsOneWidget);
  });

  testWidgets('capture setup restores saved selection', (tester) async {
    SharedPreferences.setMockInitialValues({
      'capture_setup.difficulty': 'advanced',
      'capture_setup.board_size': 13,
      'capture_setup.capture_target': 10,
    });

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pumpAndSettle();

    expect(find.text('高级 · 13路 · 吃10子'), findsOneWidget);
  });

  testWidgets('capture game uses Cupertino back affordance', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CupertinoButton, '开始练习'));
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<CupertinoNavigationBar>(
      find.byType(CupertinoNavigationBar),
    );
    expect(navigationBar.leading, isNull);
    expect(navigationBar.previousPageTitle, '吃子练习');
  });
}
