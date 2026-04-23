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
    await tester.pumpAndSettle();

    expect(find.text('益智围棋'), findsOneWidget);
    expect(find.text('对弈'), findsOneWidget);
    expect(find.text('难度'), findsOneWidget);
    expect(find.text('中级 · 9路 · 吃5子'), findsNothing);

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

    expect(find.text('高级'), findsOneWidget);
    expect(find.text('13路'), findsOneWidget);
    expect(find.text('吃10子'), findsOneWidget);
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
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CupertinoButton, '开始练习'));
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<CupertinoNavigationBar>(
      find.byType(CupertinoNavigationBar),
    );
    expect(navigationBar.leading, isNull);
    expect(navigationBar.previousPageTitle, '益智围棋');
  });
}
