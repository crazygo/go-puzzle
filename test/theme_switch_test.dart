import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/main.dart';
import 'package:go_puzzle/theme/app_theme.dart';
import 'package:go_puzzle/widgets/go_three_board_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('settings screen switches app theme', (tester) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester
          .widget<CupertinoApp>(find.byType(CupertinoApp))
          .theme!
          .primaryColor,
      AppThemePalette.agarwood.primary,
    );

    await tester.tap(find.text('設定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(AppVisualTheme.classic.label));
    await tester.pump();

    expect(
      tester
          .widget<CupertinoApp>(find.byType(CupertinoApp))
          .theme!
          .primaryColor,
      AppThemePalette.classic.primary,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.app_theme'), AppVisualTheme.classic.name);
  });

  testWidgets('app restores saved theme', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.app_theme': AppVisualTheme.classic.name,
    });

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester
          .widget<CupertinoApp>(find.byType(CupertinoApp))
          .theme!
          .primaryColor,
      AppThemePalette.classic.primary,
    );
  });

  testWidgets('classic theme removes home 3D board', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings.app_theme': AppVisualTheme.classic.name,
    });

    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GoThreeBoardBackground), findsNothing);
    expect(find.text('下一盤'), findsOneWidget);
  });
}
