import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/main.dart';

void main() {
  testWidgets('capture setup screen shows redesigned sections and updates summary', (
    tester,
  ) async {
    await tester.pumpWidget(const GoPuzzleApp());
    await tester.pumpAndSettle();

    expect(find.text('吃子练习'), findsOneWidget);
    expect(find.text('本局设置'), findsOneWidget);
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
}
