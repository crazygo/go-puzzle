import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/game/capture_ai_tactics.dart';
import 'package:go_puzzle/main.dart';
import 'package:go_puzzle/providers/settings_provider.dart';
import 'package:go_puzzle/providers/tactics_challenge_provider.dart';
import 'package:go_puzzle/widgets/daily_challenge_card.dart';
import 'package:go_puzzle/screens/skills_screen.dart';
import 'package:go_puzzle/screens/tactics_problem_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final problems = [
    _problem(
      id: 'gf-9-001',
      category: 'group_fate',
      currentPlayer: 'black',
      notes: 'Black can settle by capturing.',
    ),
    _problem(
      id: 'cr-9-001',
      category: 'capture_race',
      currentPlayer: 'white',
      tactic: 'shortage_of_liberties',
      notes: 'White can win the race locally.',
    ),
    _problem(
      id: 'trap-9-001',
      category: 'trap',
      currentPlayer: 'black',
      tactic: 'ladder',
      notes: 'Black can start a ladder.',
    ),
    _problem(
      id: 'ex-9-001',
      category: 'exchange',
      currentPlayer: 'white',
      tactic: 'snapback',
      notes: 'White can use snapback.',
    ),
    _problem(
      id: 'mt-9-001',
      category: 'multi_threat',
      currentPlayer: 'black',
      tactic: 'net_geta',
      notes: 'Black has two threats.',
    ),
  ];

  Widget app({TacticsChallengeProvider? provider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider<TacticsChallengeProvider>(
          create: (_) =>
              provider ??
              TacticsChallengeProvider(
                problemsFutureOverride: Future.value(problems),
              ),
        ),
      ],
      child: CupertinoApp(
        home: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.play), label: '下棋'),
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.circle), label: '歷史'),
            ],
          ),
          tabBuilder: (context, index) {
            if (index == 0) {
              return const CupertinoPageScaffold(
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: DailyChallengeCard(),
                    ),
                  ),
                ),
              );
            } else {
              return SkillsScreen(
                problemsFuture: Future.value(problems),
                today: DateTime(2026, 6, 5),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester,
      {TacticsChallengeProvider? provider}) async {
    await tester.pumpWidget(app(provider: provider));
    await tester.pumpAndSettle();
  }

  Widget skillsOnlyApp(TacticsChallengeProvider provider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider<TacticsChallengeProvider>.value(value: provider),
      ],
      child: CupertinoApp(
        home: SkillsScreen(
          problemsFuture: Future.value(problems),
          today: DateTime(2026, 6, 5),
        ),
      ),
    );
  }

  testWidgets(
      'shows daily challenge on capture game tab and stats on skills tab',
      (tester) async {
    await pumpApp(tester);

    // Default tab is "下棋" (index 0), where today's challenge should be visible
    expect(find.text('今日挑戰'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
    expect(find.text('開始解棋'), findsOneWidget);
    expect(find.text('調整 ›'), findsOneWidget);

    // Switch to "歷史" tab (index 1)
    await tester.tap(find.text('歷史'));
    await tester.pumpAndSettle();

    expect(find.text('解棋記錄'), findsOneWidget);
    expect(find.text('還沒有記錄，開始解棋吧。'), findsOneWidget);
  });

  testWidgets('skills screen exits loading when provider finishes after build',
      (tester) async {
    final completer = Completer<List<CaptureAiTacticsProblem>>();
    final provider = TacticsChallengeProvider(
      problemsFutureOverride: completer.future,
    );

    await tester.pumpWidget(skillsOnlyApp(provider));
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('解棋記錄'), findsNothing);

    completer.complete(problems);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.text('解棋記錄'), findsOneWidget);
    expect(find.text('還沒有記錄，開始解棋吧。'), findsOneWidget);
  });

  testWidgets('adjust toggle reveals difficulty and type filter pills',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('難度'), findsNothing);
    expect(find.text('類型'), findsNothing);

    await tester.tap(find.text('調整 ›'));
    await tester.pumpAndSettle();

    expect(find.text('級別'), findsOneWidget);
    expect(find.text('類型'), findsOneWidget);
    expect(find.text('15K'), findsOneWidget);
    expect(find.text('1K'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('吃子'), findsOneWidget);
    expect(find.text('死活'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
  });

  testWidgets('start launches today\'s first problem directly', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('開始解棋'));
    await tester.pumpAndSettle();

    // Should navigate directly to TacticsProblemScreen showing the first problem.
    expect(find.byType(TacticsProblemScreen), findsOneWidget);
  });

  testWidgets('opening a problem does not record history until passed',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('開始解棋'));
    await tester.pumpAndSettle();

    expect(find.text('等待黑棋落子'), findsWidgets);
    expect(find.text('跳過'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('歷史'));
    await tester.pumpAndSettle();

    expect(find.text('還沒有記錄，開始解棋吧。'), findsOneWidget);
  });

  testWidgets('main training tab is wired to skills screen', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SkillsScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('歷史', skipOffstage: false), findsWidgets);
  });
}

CaptureAiTacticsProblem _problem({
  required String id,
  required String category,
  required String currentPlayer,
  String? tactic,
  String notes = '',
}) {
  return CaptureAiTacticsProblem.fromJson(
    {
      'id': id,
      'category': category,
      'boardSize': 9,
      'currentPlayer': currentPlayer,
      'capturedByBlack': 2,
      'capturedByWhite': 1,
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
      if (tactic != null) 'metadata': {'tactic': tactic},
      if (notes.isNotEmpty) 'notes': notes,
    },
    index: 0,
  );
}
