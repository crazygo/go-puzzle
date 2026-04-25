import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('capture setup shows updated copy', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('小闲围棋'), findsOneWidget);
    expect(find.text('AI 陪你下好每一步'), findsOneWidget);
    expect(find.text('AI 风格'), findsOneWidget);
    expect(find.text('中级 · 9 路 · 吃5子'), findsNothing);

    final startButton = find.widgetWithText(CupertinoButton, '执黑开始');
    expect(startButton, findsOneWidget);
  });

  testWidgets('capture setup restores saved selection', (tester) async {
    SharedPreferences.setMockInitialValues({
      'capture_setup.difficulty': 'advanced',
      'capture_setup.board_size': 13,
    });

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('高级'), findsOneWidget);
    expect(find.text('13 路'), findsWidgets);
    expect(find.textContaining('吃5子'), findsWidgets);
  });

  testWidgets('segment control updates selected option on tap', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Difficulty defaults to '中级'; tap '高级' to change it.
    await tester.tap(find.text('高级'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    Text textWidget(String label) {
      return tester.widget<Text>(find.text(label));
    }

    expect(textWidget('高级').style?.color, const Color(0xFF8A5A2B));
    expect(textWidget('中级').style?.color, const Color(0xFF5A4B3F));
  });

  testWidgets('capture game uses Cupertino back affordance', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final startButton = find.widgetWithText(CupertinoButton, '执黑开始');
    await tester.dragUntilVisible(
      startButton,
      find.byType(Scrollable),
      const Offset(0, -200),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final navigationBar = tester.widget<CupertinoNavigationBar>(
      find.byType(CupertinoNavigationBar),
    );
    expect(navigationBar.leading, isNull);
    expect(navigationBar.previousPageTitle, '小闲围棋');
  });
}
