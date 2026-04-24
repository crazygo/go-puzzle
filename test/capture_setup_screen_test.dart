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

    final startButton = find.widgetWithText(CupertinoButton, '开始对弈');
    expect(startButton, findsOneWidget);
  });

  testWidgets('capture setup restores saved selection', (tester) async {
    SharedPreferences.setMockInitialValues({
      'capture_setup.difficulty': 'advanced',
      'capture_setup.board_size': 13,
      'capture_setup.capture_target': 10,
    });

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('高级'), findsOneWidget);
    expect(find.text('13 路'), findsWidgets);
    expect(find.textContaining('吃10子'), findsWidgets);
  });

  testWidgets('segment control updates selected option on tap', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pumpAndSettle();

    // Difficulty defaults to '中级'; tap '高级' to change it.
    await tester.tap(find.text('高级'));
    await tester.pumpAndSettle();

    TextStyle styleOf(String label) {
      return tester
          .widget<AnimatedDefaultTextStyle>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          )
          .style;
    }

    expect(styleOf('高级').color, CupertinoColors.activeBlue);
    expect(styleOf('中级').color, const Color(0xFF5D6473));
  });

  testWidgets('capture game uses Cupertino back affordance', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final startButton = find.widgetWithText(CupertinoButton, '开始对弈');
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
