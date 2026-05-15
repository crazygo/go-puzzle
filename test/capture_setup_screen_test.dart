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
    expect(find.text('吃 5 子取胜 · 9 路 · 十字'), findsOneWidget);
    // Default AI style is now 'adaptive' (战力优先).
    expect(find.text(CaptureAiStyle.adaptive.label), findsOneWidget);
    expect(find.text('中级 · 9 路 · 吃5子'), findsNothing);

    final startButton = find.widgetWithText(CupertinoButton, '执黑先行');
    expect(startButton, findsOneWidget);
  });

  testWidgets('capture setup restores board size from saved selection',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'capture_setup.board_size': 13,
    });

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Board size should be restored.
    expect(find.text('13 路'), findsNothing);
    expect(find.text('吃 5 子取胜 · 13 路 · 十字'), findsOneWidget);
  });

  testWidgets('selected play mode is restored after app restart',
      (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('调整 ›'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final territoryOption = find.text('围空');
    await tester.dragUntilVisible(
      territoryOption,
      find.byType(Scrollable),
      const Offset(0, -120),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(territoryOption);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final doneButton = find.text('完成');
    await tester.ensureVisible(doneButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(doneButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('围空 · 9 路 · 十字'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('围空 · 9 路 · 十字'), findsOneWidget);
    expect(find.text('吃 5 子取胜 · 9 路 · 十字'), findsNothing);

    await tester.tap(find.text('调整 ›'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('围空'), findsWidgets);
  });

  testWidgets('capture setup reflects selected play mode in header',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'capture_setup.play_mode': 'territory',
    });

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('围空 · 9 路 · 十字'), findsOneWidget);
    expect(find.text('吃 5 子取胜 · 9 路 · 十字'), findsNothing);
  });

  testWidgets('territory mode disables AI style selection in setup',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'capture_setup.play_mode': 'territory',
    });

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('调整 ›'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('围空模式固定使用围空引擎，风格选项不生效；仅难度生效。'), findsOneWidget);
    expect(find.text('选择 AI 风格'), findsNothing);
  });
  testWidgets('difficulty mode segment control updates on tap', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('调整 ›'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Default is '不分伯仲'; tap '指定等级' to change it.
    final manualOption = find.text('指定等级');
    await tester.dragUntilVisible(
      manualOption,
      find.byType(Scrollable),
      const Offset(0, -120),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(manualOption);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    Text textWidget(String label) {
      return tester.widget<Text>(find.text(label));
    }

    expect(textWidget('指定等级').style?.color, const Color(0xFF8A5A2B));
    expect(textWidget('不分伯仲').style?.color, const Color(0xFF5A4B3F));
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
