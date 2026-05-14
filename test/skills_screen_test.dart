import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai_tactics.dart';
import 'package:go_puzzle/main.dart';
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
    await tester.pumpAndSettle();
  }

  testWidgets('skills tab loads tactics dataset and filters by category',
      (tester) async {
    await pumpTacticsList(tester);

    expect(find.text('謎題'), findsWidgets);
    expect(find.text('AI 測試題集'), findsOneWidget);
    expect(find.text('全部 2'), findsOneWidget);
    expect(find.text('棋形生死 1'), findsOneWidget);
    expect(find.text('gf-9-001'), findsOneWidget);

    await tester.tap(find.text('對殺 1'));
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

    // Scroll down to bring the AI panel into view (lazy ListView).
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
      warnIfMissed: false,
    );
    // One pump brings the FutureBuilder into the viewport; a second pump lets
    // it process the now-completed _buildAdvice future and rebuild to show the
    // advice panel.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AI 建議'), findsOneWidget);
    expect(find.text('Oracle 參考'), findsOneWidget);
    expect(find.text('點棋盤上的空點，可以暫時試下一手。綠色標記預設顯示 AI 首選。'), findsOneWidget);
  });

  testWidgets('main puzzle tab is wired to tactics dataset screen',
      (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SkillsScreen, skipOffstage: false), findsOneWidget);
  });
}
