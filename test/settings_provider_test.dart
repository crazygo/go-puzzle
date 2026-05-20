import 'package:flutter_test/flutter_test.dart';
import 'package:go_puzzle/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('show move log defaults on for a fresh install', () async {
    SharedPreferences.setMockInitialValues({});

    final settings = SettingsProvider();
    await Future<void>.delayed(Duration.zero);

    expect(settings.showMoveLog, isTrue);
  });

  test('show move log restores an explicit saved off value', () async {
    SharedPreferences.setMockInitialValues({
      'settings.show_move_log': false,
    });

    final settings = SettingsProvider();
    await Future<void>.delayed(Duration.zero);

    expect(settings.showMoveLog, isFalse);
  });
}
