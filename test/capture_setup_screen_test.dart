import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai.dart';
import 'package:go_puzzle/main.dart';
import 'package:go_puzzle/widgets/page_hero_banner.dart';
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
    // Motivation text is now rendered by the animated _MotivationHeroTitle
    // widget rather than through PageHeroBanner.subtitle; just verify the
    // banner is present and the rest of the page copy is correct.
    expect(find.byType(PageHeroBanner), findsOneWidget);
    expect(find.text('下一盘'), findsOneWidget);
    expect(find.text('先吃5子为胜'), findsOneWidget);
    expect(find.text(CaptureAiStyle.hunter.label), findsOneWidget);
    expect(find.text('中级 · 9 路 · 吃5子'), findsNothing);

    final startButton = find.widgetWithText(CupertinoButton, '执黑先行');
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
    expect(find.text('先吃5子为胜'), findsOneWidget);
  });

  testWidgets('segment control updates selected option on tap', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('调整 ›'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Difficulty defaults to '中级'; tap '高级' to change it.
    final advancedOption = find.text('高级');
    await tester.dragUntilVisible(
      advancedOption,
      find.byType(Scrollable),
      const Offset(0, -120),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(advancedOption);
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

    final startButton = find.widgetWithText(CupertinoButton, '执黑先行');
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
