import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai_tactics.dart';
import 'package:go_puzzle/main.dart';
import 'package:go_puzzle/screens/daily_puzzle_screen.dart';
import 'package:go_puzzle/screens/skills_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final problems = [
    CaptureAiTacticsProblem.fromJson(
      {
        'id': 'gf-9-001',
        'category': 'group_fate',
        'boardSize': 9,
        'currentPlayer': 'black',
        'capturedByBlack': 3,
        'capturedByWhite': 2,
        'diagram': [
          '..W......',
          '.WB.B....',
          '..B......',
          '...BWB...',
          '...BWB...',
          '....B....',
          '.....W...',
          '....B....',
          '.........',
        ],
        'notes': 'Black can settle by capturing.',
      },
      index: 0,
    ),
    CaptureAiTacticsProblem.fromJson(
      {
        'id': 'cr-9-001',
        'category': 'capture_race',
        'boardSize': 9,
        'currentPlayer': 'white',
        'capturedByBlack': 2,
        'capturedByWhite': 3,
        'diagram': [
          '.........',
          '..B......',
          '.BW.W....',
          '..W......',
          '...WBW...',
          '...WBW...',
          '....W....',
          '..B......',
          '.........',
        ],
        'metadata': {'tactic': 'ladder'},
        'notes': 'White can win the race locally.',
      },
      index: 1,
    ),
  ];

  Widget app() {
    return CupertinoApp(
      home: SkillsScreen(
        problemsFuture: Future.value(problems),
      ),
    );
  }

  Future<void> pumpTacticsList(WidgetTester tester) async {
    await tester.pumpWidget(app());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('AI 测试题集').evaluate().isNotEmpty) {
        break;
      }
    }
  }

  testWidgets('skills tab loads tactics dataset and filters by category',
      (tester) async {
    await pumpTacticsList(tester);

    expect(find.text('谜题'), findsWidgets);
    expect(find.text('AI 测试题集'), findsOneWidget);
    expect(find.text('全部 2'), findsOneWidget);
    expect(find.text('棋形生死 1'), findsOneWidget);
    expect(find.text('gf-9-001'), findsOneWidget);

    await tester.tap(find.text('对杀 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('cr-9-001'), findsOneWidget);
    expect(find.text('gf-9-001'), findsNothing);
  });

  testWidgets('skills tab opens tactics problem detail', (tester) async {
    await pumpTacticsList(tester);

    await tester.tap(find.text('gf-9-001'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AI 建议'), findsOneWidget);
    expect(find.text('Oracle 参考'), findsOneWidget);
    expect(find.text('点棋盘上的空点，可以临时试下一手。绿色标记默认显示 AI 首选。'), findsOneWidget);
  });

  testWidgets('main puzzle tab is wired to tactics dataset screen',
      (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SkillsScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(DailyPuzzleScreen, skipOffstage: false), findsNothing);
  });
}
