import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

enum BoardSizeOption {
  nine(9, '9路吃子'),
  thirteen(13, '13路吃子'),
  nineteen(19, '19路围空');

  final int size;
  final String label;
  const BoardSizeOption(this.size, this.label);
}

class SettingsProvider extends ChangeNotifier {
  static const _appThemeKey = 'settings.app_theme';
  static const _developerModeKey = 'settings.developer_mode';
  static const _showMoveLogKey = 'settings.show_move_log';

  AppVisualTheme _appTheme = AppVisualTheme.agarwood;
  BoardSizeOption _boardSize = BoardSizeOption.nine;
  bool _showHints = true;
  bool _showMoveNumbers = false;
  bool _showCaptureWarning = true;
  bool _soundEnabled = true;
  bool _hapticEnabled = true;
  bool _developerMode = false;
  bool _showMoveLog = false;

  AppVisualTheme get appTheme => _appTheme;
  BoardSizeOption get boardSize => _boardSize;
  bool get showHints => _showHints;
  bool get showMoveNumbers => _showMoveNumbers;
  bool get showCaptureWarning => _showCaptureWarning;
  bool get soundEnabled => _soundEnabled;
  bool get hapticEnabled => _hapticEnabled;
  bool get developerMode => _developerMode;
  bool get showMoveLog => _showMoveLog;

  SettingsProvider() {
    _restorePreferences();
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_appThemeKey);
    final restoredTheme = AppVisualTheme.values.firstWhere(
      (theme) => theme.name == savedTheme,
      orElse: () => _appTheme,
    );
    final restoredDeveloperMode = prefs.getBool(_developerModeKey) ?? false;
    final restoredShowMoveLog = prefs.getBool(_showMoveLogKey) ?? false;
    if (restoredTheme == _appTheme &&
        restoredDeveloperMode == _developerMode &&
        restoredShowMoveLog == _showMoveLog) {
      return;
    }

    _appTheme = restoredTheme;
    _developerMode = restoredDeveloperMode;
    _showMoveLog = restoredShowMoveLog;
    notifyListeners();
  }

  Future<void> setAppTheme(AppVisualTheme theme) async {
    if (_appTheme == theme) return;

    _appTheme = theme;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appThemeKey, theme.name);
  }

  void setBoardSize(BoardSizeOption size) {
    _boardSize = size;
    notifyListeners();
  }

  void setShowHints(bool value) {
    _showHints = value;
    notifyListeners();
  }

  void setShowMoveNumbers(bool value) {
    _showMoveNumbers = value;
    notifyListeners();
  }

  void setShowCaptureWarning(bool value) {
    _showCaptureWarning = value;
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
    notifyListeners();
  }

  void setHapticEnabled(bool value) {
    _hapticEnabled = value;
    notifyListeners();
  }

  Future<void> setDeveloperMode(bool value) async {
    if (_developerMode == value) return;

    _developerMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_developerModeKey, value);
  }

  Future<void> setShowMoveLog(bool value) async {
    if (_showMoveLog == value) return;

    _showMoveLog = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showMoveLogKey, value);
  }
}
